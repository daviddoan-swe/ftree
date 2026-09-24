-- Who may do what with which family (DOMAIN §12.1).
--
-- A role belongs to the *pair* (user, family), not to a user. The same person
-- is owner of the gia phả they keep and viewer of a cousin's.
--
-- Deliberately not built during the local milestones: the row holds a user id,
-- and until authentication existed there was no id to hold. Building it earlier
-- would have produced permission checks written against an imaginary current
-- user.
--
-- ## Where the rules are enforced, and why it is here
--
-- Three of the four rules below are statements about a *set* of rows — "a
-- family always has at least one owner" cannot be checked by looking at the row
-- being changed. CHECK sees one row, so they are triggers.
--
-- All four are in the database rather than in the application because an error
-- here is a security hole rather than a defect. A client can send any statement
-- it likes; this is what refuses.

CREATE TABLE family_memberships (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id  uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Stored by name, as `sex` and `type` are: adding a role later does not
  -- renumber the rows that already exist.
  role       text NOT NULL CHECK (role IN ('owner', 'editor', 'viewer')),

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,

  -- Rule 1: one membership row per user per family.
  CONSTRAINT family_memberships_one_per_user UNIQUE (family_id, user_id)
);

-- No `change_seq`. That column orders changes for synchronisation, and a
-- membership is not family data — it never travels to a device. Giving it one
-- would say that it does.

CREATE INDEX family_memberships_by_user
  ON family_memberships (user_id, deleted_at);

ALTER TABLE family_memberships ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------- rules 2 and 3: an owner remains --

-- "A family always has at least one owner", and "the last owner cannot be
-- demoted or removed", are the same rule seen from two sides: no change may
-- leave a family ownerless.
--
-- Fires on the ways a row stops being a live owner — demoted, tombstoned, or
-- removed outright. Deletion here is soft like everywhere else, so the usual
-- case is an UPDATE that sets `deleted_at`.
CREATE OR REPLACE FUNCTION keep_an_owner() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  -- Nothing is lost unless this row was a live owner to begin with.
  IF OLD.role <> 'owner' OR OLD.deleted_at IS NOT NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- A family that is itself being removed needs no owner. Without this the
  -- rule makes a family impossible to delete outright: the cascade takes the
  -- memberships with it, and this trigger refuses the last one.
  --
  -- Deletion is soft in normal operation, so nothing would have met it for a
  -- long time — but §15.1 keeps the cascade as the safety net for a purge, a
  -- migration, or a defect, and a safety net that cannot fire is not one.
  IF NOT EXISTS (SELECT 1 FROM families WHERE id = OLD.family_id) THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- An update that leaves it a live owner changes nothing about ownership.
  IF TG_OP = 'UPDATE'
     AND NEW.role = 'owner'
     AND NEW.deleted_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM family_memberships
    WHERE family_id = OLD.family_id
      AND role = 'owner'
      AND deleted_at IS NULL
      AND id <> OLD.id
  ) THEN
    RAISE EXCEPTION 'a family must always have at least one owner'
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN COALESCE(NEW, OLD);
END $$;

CREATE TRIGGER family_memberships_keep_an_owner
  BEFORE UPDATE OR DELETE ON family_memberships
  FOR EACH ROW EXECUTE FUNCTION keep_an_owner();

-- ------------------------------------------ rule 4: the creator is the owner --

-- Derived from the token, never from the payload. A client that could say who
-- created a family could say somebody else did.
--
-- SECURITY DEFINER because the user inserting the family has, at this moment,
-- no membership and therefore no policy permitting them to write one. This is
-- the one door that must open before any of them apply.
--
-- `auth.uid()` is null when there is no authenticated user — a migration, a
-- seed, an administrator working directly in the database. There is no creator
-- to record then, so no membership is written, and such a family is reachable
-- only the same way it was made. That is a deliberate hole rather than an
-- oversight: refusing would make the database unseedable.
CREATE OR REPLACE FUNCTION owner_on_create() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    INSERT INTO family_memberships (family_id, user_id, role)
    VALUES (NEW.id, auth.uid(), 'owner');
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER families_owner_on_create
  AFTER INSERT ON families
  FOR EACH ROW EXECUTE FUNCTION owner_on_create();

-- ----------------------------------------------- the role of the caller --

-- What the current user may do in one family, or null if they are not in it.
--
-- SECURITY DEFINER for a specific reason: a policy on `family_memberships`
-- that reads `family_memberships` recurses forever, because evaluating the
-- policy runs the query the policy is guarding. Running as the function's
-- owner steps outside RLS and ends the loop.
--
-- STABLE so the planner may call it once per statement rather than once per
-- row, which is the difference between a policy that costs nothing and one
-- that scans a membership table per person in the family.
CREATE OR REPLACE FUNCTION my_role(target uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT role FROM family_memberships
  WHERE family_id = target
    AND user_id = auth.uid()
    AND deleted_at IS NULL
$$;
