-- Whether a family id is already taken on the server (PRODUCT.md §4.2).
--
-- ## The case this exists for
--
-- A file carries a family keeping its id (DOMAIN §14.1), so a gia phả that A
-- built and sent to B arrives on B's device as the same family rather than as
-- a copy of it. Both devices can then press Chia sẻ, and both aim at one row.
--
-- Whoever presses first becomes its owner, because `owner_on_create` reads the
-- token of whoever inserted. The second one has to be told so — and the device
-- cannot work it out alone. To a non-member the family is not forbidden, it is
-- **absent** (`20260924000003_policies.sql`), so an `EXISTS` sent by the client
-- answers "no" and the insert that follows meets the primary key.
--
-- Hence one question the client cannot answer and the server can.
--
-- ## Why SECURITY DEFINER, and what it is allowed to say
--
-- Seeing past the read policy is the entire job, and SECURITY INVOKER cannot.
-- So this is the third hole in the wall, and the narrowest: it returns a
-- boolean. Not the name, not the size, not the owner, nothing about the people.
--
-- Confirming that a given id exists is not a leak worth weighing. Ids are
-- version 7 UUIDs, so they cannot be guessed, and anybody already holding one
-- learns the same fact from the primary-key violation this replaces.
--
-- Only a signed-in caller may ask. The answer is wanted in order to decide
-- whether to share, which needs an account anyway, so `anon` is not granted it.
--
-- ## Tombstones count as taken
--
-- Deliberately no `deleted_at IS NULL`. A tombstoned family still holds its
-- primary key, so an insert over it would still fail; calling it unclaimed
-- would send the client into precisely the error this exists to prevent.
CREATE OR REPLACE FUNCTION family_is_claimed(target uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM families WHERE id = target);
$$;

-- `anon` is revoked by name, and that is not belt and braces. Supabase sets
-- default privileges granting EXECUTE on new functions in `public` to anon,
-- authenticated and service_role, so the grant is made to each role
-- explicitly at creation and revoking PUBLIC leaves it standing. Written from
-- the other direction the first time, this function answered anonymous
-- callers — and, being SECURITY DEFINER, answered them truthfully.
REVOKE EXECUTE ON FUNCTION family_is_claimed(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION family_is_claimed(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION family_is_claimed(uuid) TO authenticated;
