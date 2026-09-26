-- Deleting a whole family, for everybody (ROADMAP M9, step 4).
--
-- `delete_family_deep` already tombstoned a family, its people and their edges
-- together, and it runs as the caller so Row Level Security applies to every
-- statement in it. That was almost enough, and the gap it left is the kind
-- worth naming: the policies are not uniform across the three tables.
--
--   * `families_update_editor` forbids an editor setting `deleted_at`, on both
--     halves, so the family row survives an editor's attempt.
--   * `persons_update` and `relationships_update` say only `owner` or
--     `editor` — nothing about `deleted_at`, because an editor removing one
--     person is ordinary work.
--
-- So an editor calling it emptied the family and left it standing: every person
-- and every edge tombstoned, the family row untouched, no error raised, because
-- an UPDATE a policy forbids changes nothing and reports success. A gia phả of
-- three hundred people reduced to a name, and nothing anywhere to say why.
--
-- Unreachable until now, because nothing called it. Step 4 calls it, so the
-- check is written down here rather than left to the client: an editor may
-- delete people, and may not delete the family they are in.
--
-- The whole body is one transaction, so raising before the first UPDATE leaves
-- nothing half-done.
CREATE OR REPLACE FUNCTION delete_family_deep(family uuid, at timestamptz)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF my_role(family) IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'only the owner may delete a family'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  UPDATE relationships
     SET deleted_at = at, updated_at = at
   WHERE family_id = family;

  UPDATE persons
     SET deleted_at = at, updated_at = at
   WHERE family_id = family;

  UPDATE families
     SET deleted_at = at, updated_at = at
   WHERE id = family;
END $$;
