-- A deleted family cannot be joined, and cannot be invited into.
--
-- `20260927000001` closed a tombstoned family to writing. This closes the
-- other door into it, which was open and did not look like a door at all.
--
-- What happened on a real pair of phones: an owner made a code for a family
-- the server had already tombstoned, sent it, and the other device accepted
-- it. `accept_invitation` had nothing to say about the family being gone, so
-- the membership was written and the join *succeeded* — and then the download
-- that follows it returned nothing, because reading a family skips tombstones.
-- The screen fell through to its catch-all and said "It did not go through:"
-- with no reason after the colon, which is the least useful sentence in the
-- application.
--
-- Two guards, because the code can be made before the deletion and used after
-- it. The insert is the tidy one; the accept is the one that matters.
DROP POLICY invitations_insert_owner ON family_invitations;

CREATE POLICY invitations_insert_owner ON family_invitations
  FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) = 'owner'
              AND invited_by = auth.uid()
              AND family_is_live(family_id));

CREATE OR REPLACE FUNCTION accept_invitation(code text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  invitation family_invitations%ROWTYPE;
  me uuid := auth.uid();
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'invitation_needs_an_account';
  END IF;

  SELECT * INTO invitation
    FROM family_invitations
   WHERE token_hash = invitation_code_hash(code)
     FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invitation_not_found';
  END IF;

  IF invitation.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'invitation_revoked';
  END IF;

  IF invitation.accepted_at IS NOT NULL THEN
    RAISE EXCEPTION 'invitation_already_used';
  END IF;

  IF invitation.expires_at <= now() THEN
    RAISE EXCEPTION 'invitation_expired';
  END IF;

  -- The new one. Checked before the membership is written, so a refused join
  -- leaves nothing behind — the alternative is somebody holding a membership
  -- of a gia phả that does not exist, which nothing in the application knows
  -- how to show or how to undo.
  --
  -- The code is **not** marked used. There is nothing to protect it from: the
  -- family is gone, and if its owner brings it back the code should still
  -- work.
  IF NOT family_is_live(invitation.family_id) THEN
    RAISE EXCEPTION 'invitation_family_deleted';
  END IF;

  INSERT INTO family_memberships (family_id, user_id, role, updated_at)
  VALUES (invitation.family_id, me, invitation.role, now())
  ON CONFLICT (family_id, user_id) DO UPDATE
    SET role = EXCLUDED.role, updated_at = now(), deleted_at = NULL;

  UPDATE family_invitations
     SET accepted_at = now(), accepted_by = me
   WHERE id = invitation.id;

  RETURN invitation.family_id;
END $$;

REVOKE EXECUTE ON FUNCTION accept_invitation(text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION accept_invitation(text) FROM anon;
GRANT  EXECUTE ON FUNCTION accept_invitation(text) TO authenticated;
