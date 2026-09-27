-- Nothing is written into a family its owner has deleted.
--
-- Deleting a family reaches every device (PRODUCT §5.10). What it did not
-- reach was a *file*: an export taken before the deletion is outside anything
-- the server can recall, and importing one put the family back — locally, and
-- then on the server at the next push, and then on everybody's phone. An
-- editor or a viewer holding an old backup could undo the owner's decision for
-- the whole household, and nobody would be told.
--
-- Only the owner may bring one back (PRODUCT §5.10). `families_update_owner`
-- already says so for the family row itself, and an editor's attempt at it is
-- refused in the silent shape — an UPDATE whose `USING` excludes every row.
--
-- The hole was the people. `persons_update` says only "owner or editor", so an
-- editor's `save_family_all` went on to write every person with
-- `deleted_at = NULL` while the family row stayed tombstoned: a deleted family
-- full of living people, which is the emptied-family defect of
-- `20260925000002` turned inside out.
--
-- So the rule is stated once, plainly: a tombstoned family is closed to
-- writing. The owner is not blocked by it — `save_family_all` writes the
-- family row first, and by the time it reaches the people the tombstone it
-- would have tripped on is already gone, in the same statement batch.
CREATE OR REPLACE FUNCTION family_is_live(target uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM families WHERE id = target AND deleted_at IS NULL
  );
$$;

REVOKE EXECUTE ON FUNCTION family_is_live(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION family_is_live(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION family_is_live(uuid) TO authenticated;

DROP POLICY persons_insert ON persons;
CREATE POLICY persons_insert ON persons FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) IN ('owner', 'editor')
              AND family_is_live(family_id));

DROP POLICY persons_update ON persons;
CREATE POLICY persons_update ON persons FOR UPDATE TO authenticated
  USING      (my_role(family_id) IN ('owner', 'editor'))
  -- `USING` is deliberately left alone. It decides which rows the statement
  -- can see, and tombstoning the family's people is exactly what
  -- `delete_family_deep` does — blocking it there would make deleting a
  -- family impossible. `WITH CHECK` decides what a row may become, and what
  -- it may not become is alive again inside a family that is not.
  WITH CHECK (my_role(family_id) IN ('owner', 'editor')
              AND family_is_live(family_id));

DROP POLICY relationships_insert ON relationships;
CREATE POLICY relationships_insert ON relationships
  FOR INSERT TO authenticated
  WITH CHECK (my_role(family_id) IN ('owner', 'editor')
              AND family_is_live(family_id));

DROP POLICY relationships_update ON relationships;
CREATE POLICY relationships_update ON relationships
  FOR UPDATE TO authenticated
  USING      (my_role(family_id) IN ('owner', 'editor'))
  WITH CHECK (my_role(family_id) IN ('owner', 'editor')
              AND family_is_live(family_id));
