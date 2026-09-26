-- Dates the member screen needs, and the address behind a used code.
--
-- Both are already stored; neither was being handed out. `family_members`
-- answered who is in and in what capacity but not since when, and the
-- invitation rows carry `accepted_by` as a uuid, which is not something to put
-- in front of anybody.
--
-- The address requires a join onto `auth.users`, which PostgREST cannot reach,
-- so the invitation list moves from a table read to a function for the same
-- reason `family_members` is one. Both are `SECURITY DEFINER` — a hole in the
-- wall — and both close it the same way, by asking `my_role` themselves.

-- ------------------------------------------------------ family_members --

-- Replaced rather than amended: the return type gains a column, and Postgres
-- will not change that in place.
DROP FUNCTION IF EXISTS family_members(uuid);

CREATE FUNCTION family_members(target uuid)
RETURNS TABLE (
  user_id   uuid,
  role      text,
  email     text,
  name      text,
  joined_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT m.user_id,
         m.role,
         u.email::text,
         nullif(trim(u.raw_user_meta_data->>'name'), ''),
         -- When the membership row was written, which is when they used the
         -- code. Not the invitation's `accepted_at`: an owner promoted from
         -- the member list never used one, and the founder of a family was
         -- written in by the trigger. This column exists for all of them.
         m.created_at
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

-- --------------------------------------------- family_invitation_list --

-- Every invitation ever made for a family, newest first, with the address of
-- whoever used it.
--
-- Used and revoked ones are included. They are the record of who let whom in,
-- and a list that hid them would answer "who has been invited?" with half the
-- truth.
--
-- No `token_hash` and no code. The hash is the only thing standing between a
-- copy of this table and a way in, and nothing on a screen has any use for it.
CREATE OR REPLACE FUNCTION family_invitation_list(target uuid)
RETURNS TABLE (
  id                uuid,
  family_id         uuid,
  role              text,
  created_at        timestamptz,
  expires_at        timestamptz,
  accepted_at       timestamptz,
  accepted_by_email text,
  revoked_at        timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT i.id,
         i.family_id,
         i.role,
         i.created_at,
         i.expires_at,
         i.accepted_at,
         u.email::text,
         i.revoked_at
    FROM family_invitations i
    LEFT JOIN auth.users u ON u.id = i.accepted_by
   WHERE i.family_id = target
     AND my_role(target) = 'owner'
   ORDER BY i.created_at DESC;
$$;

-- PUBLIC is not enough on its own: Supabase grants EXECUTE to `anon` and
-- `authenticated` by default, so the role has to be named.
REVOKE EXECUTE ON FUNCTION family_invitation_list(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION family_invitation_list(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION family_invitation_list(uuid) TO authenticated;
