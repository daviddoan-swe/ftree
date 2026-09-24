-- Who may read and write what (CLAUDE.md §8, DOMAIN §12.1).
--
-- Until now every table denied everyone: RLS was on and no policy existed.
-- These are the openings, and each one is as narrow as the job allows.
--
-- ## USING and WITH CHECK are different questions
--
--   USING      — may I touch the row that is *already there*?
--   WITH CHECK — is the row I am *leaving behind* allowed?
--
-- An UPDATE is judged by both, and the difference is not academic. With USING
-- alone an editor could change a person's `family_id` to a family they have no
-- part in: the old row passes, and nothing looks at the new one. The person
-- would leave their family and land in a stranger's.
--
-- ## Deletion is not granted at all
--
-- No policy mentions DELETE. Removing a row outright is not something a client
-- does: deletion is soft everywhere (§15.1), and the hard delete exists only as
-- a cascade for a purge or a migration, run by somebody with the keys.
--
-- Tombstoning is an UPDATE, which is why the family rules below have to say who
-- may set `deleted_at` rather than who may call DELETE.
--
-- ## A refused UPDATE does not look like a refusal
--
-- Worth knowing before any client is written against this. An INSERT a policy
-- forbids fails loudly — 42501, `new row violates row-level security policy`.
-- An UPDATE does not. `USING` decides which rows the statement can *see*, so a
-- forbidden row is simply not there: the statement matches nothing, changes
-- nothing, and reports success. Over PostgREST that is HTTP 204.
--
-- So a viewer who edits a name is told it worked. Whatever calls this has to
-- ask for the changed rows back and check it got them, rather than trusting
-- the status. It is also why the checks on these policies read the data
-- afterwards instead of reading the response code — an earlier pass of them
-- did trust the code, and proved nothing.

-- ------------------------------------------------------------------ family --

-- Anyone signed in may start a family of their own. They hold no membership at
-- this instant — the trigger writes it immediately afterwards — so there is
-- nothing narrower to ask for here.
CREATE POLICY families_insert ON families FOR INSERT TO authenticated
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY families_read ON families FOR SELECT TO authenticated
  USING (my_role(id) IS NOT NULL);

-- An owner may change anything about the family, including tombstoning it.
CREATE POLICY families_update_owner ON families FOR UPDATE TO authenticated
  USING      (my_role(id) = 'owner')
  WITH CHECK (my_role(id) = 'owner');

-- An editor may correct the name or the notes, and may **not** delete the
-- family — which, deletion being soft, means may not set `deleted_at`. Stated
-- on both sides so they can neither tombstone a live family nor revive a
-- tombstoned one.
--
-- Policies for one command are OR'd together, so an owner is unaffected by the
-- extra condition here.
CREATE POLICY families_update_editor ON families FOR UPDATE TO authenticated
  USING      (my_role(id) = 'editor' AND deleted_at IS NULL)
  WITH CHECK (my_role(id) = 'editor' AND deleted_at IS NULL);

-- ------------------------------------------------------- people and edges --

-- Reading is the whole of what a viewer may do, and it is all any member needs
-- for the tree to draw.
CREATE POLICY persons_read ON persons FOR SELECT TO authenticated
  USING (my_role(family_id) IS NOT NULL);

CREATE POLICY persons_insert ON persons FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) IN ('owner', 'editor'));

-- Both halves, and both naming `family_id`: the first asks about the family
-- the person is in, the second about the family they would end up in.
CREATE POLICY persons_update ON persons FOR UPDATE TO authenticated
  USING      (my_role(family_id) IN ('owner', 'editor'))
  WITH CHECK (my_role(family_id) IN ('owner', 'editor'));

CREATE POLICY relationships_read ON relationships FOR SELECT TO authenticated
  USING (my_role(family_id) IS NOT NULL);

CREATE POLICY relationships_insert ON relationships
  FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) IN ('owner', 'editor'));

CREATE POLICY relationships_update ON relationships
  FOR UPDATE TO authenticated
  USING      (my_role(family_id) IN ('owner', 'editor'))
  WITH CHECK (my_role(family_id) IN ('owner', 'editor'));

-- -------------------------------------------------------------- membership --

-- Members see who else is in the family. Knowing who can read a gia phả is
-- part of knowing whether it is private.
--
-- These are the policies the recursion trap is about: each one calls
-- `my_role`, which reads this very table. It is SECURITY DEFINER, so its query
-- runs outside RLS and the loop never starts. Written the obvious way — a
-- subquery over `family_memberships` — Postgres would evaluate the policy to
-- evaluate the policy, for ever.
CREATE POLICY memberships_read ON family_memberships
  FOR SELECT TO authenticated
  USING (my_role(family_id) IS NOT NULL);

-- Only an owner hands out or changes roles. An editor who could promote
-- themselves would make the distinction between them meaningless.
CREATE POLICY memberships_insert ON family_memberships
  FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) = 'owner');

CREATE POLICY memberships_update ON family_memberships
  FOR UPDATE TO authenticated
  USING      (my_role(family_id) = 'owner')
  WITH CHECK (my_role(family_id) = 'owner');
