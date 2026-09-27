-- Who let each person in.
--
-- `invited_by` was always stored and never handed out — as a uuid it is not
-- something to put in front of anybody, and the name behind it needs a join
-- onto `auth.users` that only a function can make.
--
-- It is the one fact the invitation list has that the member list does not.
-- A used invitation otherwise repeats what the member row already says: who
-- joined, in what capacity, on what day. This is what makes it a record of
-- **who let whom in** rather than a second copy of the membership.
--
-- Replaced rather than amended: the return type gains two columns, and
-- Postgres will not change that in place.
DROP FUNCTION IF EXISTS family_invitation_list(uuid);

CREATE FUNCTION family_invitation_list(target uuid)
RETURNS TABLE (
  id                uuid,
  family_id         uuid,
  role              text,
  created_at        timestamptz,
  expires_at        timestamptz,
  accepted_at       timestamptz,
  accepted_by_email text,
  revoked_at        timestamptz,
  invited_by_name   text,
  invited_by_email  text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT i.id,
         i.family_id,
         i.role,
         i.created_at,
         i.expires_at,
         i.accepted_at,
         took.email::text,
         i.revoked_at,
         nullif(trim(gave.raw_user_meta_data->>'name'), ''),
         gave.email::text
    FROM family_invitations i
    -- Inner would be wrong for neither: `accepted_by` is null until somebody
    -- uses it, and an inviter whose account has gone takes the row with it
    -- today, but may not always (`ON DELETE CASCADE`, worth revisiting if
    -- this list is ever to be relied on as a log).
    LEFT JOIN auth.users took ON took.id = i.accepted_by
    LEFT JOIN auth.users gave ON gave.id = i.invited_by
   WHERE i.family_id = target
     AND my_role(target) = 'owner'
   ORDER BY i.created_at DESC;
$$;

REVOKE EXECUTE ON FUNCTION family_invitation_list(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION family_invitation_list(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION family_invitation_list(uuid) TO authenticated;
