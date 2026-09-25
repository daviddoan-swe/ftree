-- Letting a second person into a family (PRODUCT.md §5.1, ROADMAP M8).
--
-- Sharing put one family on the server under one account. Until now that is
-- where it ends: the family is up there and exactly one person can reach it,
-- which is not what §4.2 promises — an account is what a family needs in order
-- to be kept by *more than one* person.
--
-- ## The shape of an invitation
--
-- A secret code the owner passes on by hand, through Zalo or a message or
-- whatever they already use. The server never stores it. It stores a hash, and
-- the code itself exists in two places only: the message the owner sent, and
-- the owner's own device (which already holds the whole gia phả, so it learns
-- nothing new by remembering one code).
--
-- If a database backup ever escapes, what escapes with it is a column of
-- hashes. Nothing in it opens a family.
--
-- Single use and seven days, and the first of those does more than limit
-- damage: **it makes theft visible**. Somebody who intercepts a code and uses
-- it first leaves the intended reader looking at "this code has already been
-- used", which tells the owner something is wrong. A code that worked twice
-- would be stolen in silence.
--
-- ## Owner is invitable, on purpose
--
-- A gia phả is meant to outlive one person, and a family kept by a single
-- account dies with that account — a lost phone, a forgotten password, a
-- person who dies. `keep_an_owner` has always required *at least* one owner
-- rather than exactly one, so nothing in the schema ever forbade a second.
--
-- It also unblocks §4.3: where the wrong person pressed Chia sẻ first, they
-- can hand the family back by inviting the right person as owner. The
-- interface asks before sending that one, because an owner can delete the
-- family and can make further owners, and there is no walking it back.
--
-- ## Why there is no approval step
--
-- The owner decides twice already — when they create the code, and when they
-- choose who to send it to. A third decision, taken later against an email
-- address they may never have seen, would be a gate clicked through rather
-- than a gate. What matters instead is being able to see who is in the family
-- and remove somebody, and both of those already work: `memberships_read`
-- shows members to each other, `memberships_update` lets an owner tombstone
-- one, and `keep_an_owner` refuses to let the last owner go.

-- ------------------------------------------------------------------ table --

-- No `updated_at`, and no `deleted_at`. §15 asks for both on every table that
-- synchronises, and this one does not: invitations live on the server and are
-- never written into a device's database. `revoked_at` is the end state a
-- tombstone would otherwise carry, and the rows are kept rather than removed
-- because they are the record of who let whom in — worth having in a document
-- meant to outlive the people in it.
CREATE TABLE family_invitations (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id   uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,

  -- All three, owner included. Stored by name like every other role.
  role        text NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),

  -- Hex sha256 of the canonical form of the code. Unique so that two
  -- invitations can never collide, and so the lookup in `accept_invitation`
  -- is an index probe rather than a scan of every invitation ever made.
  token_hash  text NOT NULL UNIQUE,

  invited_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,

  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  revoked_at  timestamptz
);

-- The owner's list of invitations for one family.
CREATE INDEX family_invitations_by_family
  ON family_invitations (family_id, created_at DESC);

ALTER TABLE family_invitations ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------- the openings --

-- Supabase grants every new table in `public` to anon and authenticated by
-- default, so the narrowing is done by taking it back first. Written the other
-- way round — granting without revoking — leaves the defaults standing, which
-- is the same trap `family_is_claimed` fell into with EXECUTE.
REVOKE ALL ON family_invitations FROM anon, authenticated;
GRANT SELECT, INSERT ON family_invitations TO authenticated;

-- Revoking is the only update anybody may make, and it is granted one column
-- at a time rather than checked in a policy. A policy cannot easily say "you
-- may change this column and no other" — RLS has no view of the old row in
-- WITH CHECK — whereas a column grant says exactly that and says it in the
-- one place somebody auditing this would look.
GRANT UPDATE (revoked_at) ON family_invitations TO authenticated;

-- Only an owner, because only an owner invites (PRODUCT §5.1). Editors are
-- left out deliberately: an editor who could invite editors would widen the
-- circle without the owner ever seeing it, and a circle is far easier to
-- widen than to narrow.
CREATE POLICY invitations_read_owner ON family_invitations
  FOR SELECT TO authenticated
  USING (my_role(family_id) = 'owner');

-- `invited_by = auth.uid()` is not decoration. Without it an owner could write
-- somebody else's name into the record of who let a stranger in.
CREATE POLICY invitations_insert_owner ON family_invitations
  FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) = 'owner' AND invited_by = auth.uid());

-- An invitation already used cannot be revoked, because revoking does not
-- remove the person it let in — that is tombstoning their membership, a
-- different act on a different table. Letting the button appear on a used
-- invitation would promise something it does not do.
CREATE POLICY invitations_revoke_owner ON family_invitations
  FOR UPDATE TO authenticated
  USING      (my_role(family_id) = 'owner' AND accepted_at IS NULL)
  WITH CHECK (my_role(family_id) = 'owner');

-- -------------------------------------------------------- canonical codes --

-- What gets hashed, on both sides.
--
-- The code is read off one screen and typed into another, so it arrives with
-- whatever the person did to it on the way: lower case, spaces, the hyphens
-- kept or dropped. Hashing the raw text would refuse `k7p2 9xmr4t` for a code
-- issued as `K7P2-9XMR-4T`, and the person would have no idea why.
--
-- IMMUTABLE and written here rather than inline so the device and the server
-- cannot drift apart on what "the same code" means.
CREATE OR REPLACE FUNCTION canonical_invitation_code(code text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path = public AS $$
  SELECT upper(regexp_replace(code, '[^A-Za-z0-9]', '', 'g'));
$$;

CREATE OR REPLACE FUNCTION invitation_code_hash(code text) RETURNS text
LANGUAGE sql IMMUTABLE STRICT SET search_path = public AS $$
  SELECT encode(
    sha256(convert_to(canonical_invitation_code(code), 'utf8')), 'hex'
  );
$$;

-- ------------------------------------------------------------- accepting --

-- The fourth SECURITY DEFINER function, and the one that needs the most care.
--
-- It has to step outside RLS because the person calling it is, by definition,
-- not a member yet. To them the family is absent, and so is the invitation
-- written for them: `SELECT ... WHERE token_hash = ...` returns no rows, not a
-- refusal. And they cannot insert their own membership either — that policy
-- asks for an owner, and it must, or anybody could add themselves to anything.
--
-- So: to get in you must already be in. This is the way through, and being a
-- hole in the wall it carries every check by hand. Each of the four below is
-- load-bearing. Without the expiry check a code from last year still works;
-- without the revoke check the owner's Huỷ button means nothing; without the
-- accepted check one code admits a crowd; and taking the user from a parameter
-- instead of `auth.uid()` would let the caller add somebody else entirely.
--
-- `SET search_path` is part of the safety, not tidiness: unpinned, a caller
-- could put a schema of their own in front and have this run their `sha256`
-- with the function owner's rights.
CREATE OR REPLACE FUNCTION accept_invitation(code text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  invitation family_invitations%ROWTYPE;
  me         uuid := auth.uid();
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'invitation_needs_an_account';
  END IF;

  -- FOR UPDATE, so that two people racing on one code cannot both be let in:
  -- the second waits, then reads the row the first has just marked accepted.
  SELECT * INTO invitation
    FROM family_invitations
   WHERE token_hash = invitation_code_hash(code)
     FOR UPDATE;

  -- One message for "no such code", deliberately. Telling the difference
  -- between a code that never existed and one that belongs elsewhere would
  -- turn this into an oracle for guessing codes.
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_found';
  END IF;

  IF invitation.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'invitation_revoked';
  END IF;

  -- Said apart from the others on purpose. "Already used" is the sentence that
  -- tells the intended reader, and through them the owner, that somebody else
  -- got there first.
  IF invitation.accepted_at IS NOT NULL THEN
    RAISE EXCEPTION 'invitation_already_used';
  END IF;

  IF invitation.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation_expired';
  END IF;

  -- Upsert rather than insert, and this is what makes handing a family back
  -- possible (§4.3): somebody already an editor, invited as owner, is promoted
  -- rather than refused. `deleted_at = NULL` revives a membership that was
  -- removed, since being invited again is a decision to let them back in.
  --
  -- A demotion is possible by the same route, and is not guarded here — the
  -- `keep_an_owner` trigger refuses it where it would leave the family without
  -- an owner, which is the only case that breaks anything.
  INSERT INTO family_memberships (family_id, user_id, role, updated_at)
  VALUES (invitation.family_id, me, invitation.role, now())
  ON CONFLICT (family_id, user_id) DO UPDATE
    SET role       = EXCLUDED.role,
        deleted_at = NULL,
        updated_at = now();

  UPDATE family_invitations
     SET accepted_at = now(), accepted_by = me
   WHERE id = invitation.id;

  RETURN invitation.family_id;
END $$;

-- Only a signed-in caller. There is nothing here for anon: accepting means
-- becoming somebody, and anon is nobody.
REVOKE EXECUTE ON FUNCTION accept_invitation(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION accept_invitation(text) FROM anon;
GRANT  EXECUTE ON FUNCTION accept_invitation(text) TO authenticated;

-- ------------------------------------------------------- who is in a family --

-- The administration of a family, by name.
--
-- `memberships_read` already lets a member read the rows, but a row holds a
-- `user_id` and nothing a person recognises. Names and addresses live in
-- `auth.users`, which no client may read — rightly, since that table is every
-- account on the server.
--
-- So: the fifth hole in the wall. It is narrow in the way that matters. The
-- guard is the first thing it does, and **only an owner** gets anything back
-- (PRODUCT §5.6): an editor or a viewer asking about their own family is
-- answered with nothing, exactly as somebody outside it is.
--
-- That is a reversal of what §5 used to say — that members see each other,
-- because knowing who can read a gia phả is part of knowing whether it is
-- private. The decision went the other way: managing the circle is the owner's
-- job, and the list is where somebody is demoted or put out, which is not a
-- thing to do in front of an audience. What an editor loses is the ability to
-- see who else has access; what they keep is that the owner they trusted chose
-- everybody in it.
--
-- Nothing else from `auth.users` comes out. Not the password hash, obviously,
-- but not the confirmation state or the last sign-in either: none of that is
-- any of a relative's business.
--
-- The name comes from the metadata an account carries from the moment it is
-- created. It can be absent — an account made before names were asked for, or
-- one whose owner left the box empty — and the interface has to cope rather
-- than invent one.
CREATE OR REPLACE FUNCTION family_members(target uuid)
RETURNS TABLE (user_id uuid, role text, email text, name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT m.user_id,
         m.role,
         u.email::text,
         nullif(trim(u.raw_user_meta_data->>'name'), '')
    FROM family_memberships m
    JOIN auth.users u ON u.id = m.user_id
   WHERE m.family_id = target
     AND m.deleted_at IS NULL
     AND my_role(target) = 'owner'
   ORDER BY m.created_at;
$$;

REVOKE EXECUTE ON FUNCTION family_members(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION family_members(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION family_members(uuid) TO authenticated;
