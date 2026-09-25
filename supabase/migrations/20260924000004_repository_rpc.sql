-- The two repository operations that cannot be done over PostgREST.
--
-- `FamilyRepository` promises two things PostgREST cannot express, because
-- every request it serves is its own transaction:
--
--   saveAll      — a family, its people and their edges, together or not at all
--   deletePerson — a person **and every edge naming them**, in one act
--
-- Sent as separate requests those are separate transactions, and an
-- interruption between them leaves exactly the half state each promise exists
-- to prevent: a family with the people but not the edges, or a tombstoned
-- person whose edges still point at them and still synchronise as real.
--
-- So they are functions. One request, one transaction, one answer.
--
-- ## These do not step around the policies
--
-- Both are SECURITY INVOKER — the default, stated here because it is the whole
-- of their safety. They run as the caller, so every statement inside is judged
-- by the same policies as the same statement sent from outside. A viewer
-- calling `save_family_all` writes nothing, for the same reason a viewer
-- PATCHing a row writes nothing.
--
-- This is the opposite of `my_role`, `owner_on_create` and `family_is_claimed`,
-- which must step outside RLS to do their jobs. The difference is deliberate
-- and worth keeping straight: a SECURITY DEFINER function is a hole in the
-- wall, and there are three of them, all narrow, each explained where it is
-- written.

-- ---------------------------------------------------------------- saveAll --

-- Rows arrive as JSON arrays because their shape belongs to the domain, not to
-- this function: adding a column to `persons` must not mean changing a
-- signature here.
--
-- `jsonb_populate_recordset` does the mapping, and is strict about types — a
-- malformed payload fails the whole call rather than writing part of it.
--
-- One limit worth stating: the existence check below reads through the same
-- policies as everything else, so a family belonging to somebody else looks
-- absent, and the insert that follows meets the primary key rather than the
-- policy. Both refuse — but a constraint name is no use to anybody, so that
-- insert names the case instead (PRODUCT.md §4.2).
CREATE OR REPLACE FUNCTION save_family_all(
  family        jsonb DEFAULT NULL,
  people        jsonb DEFAULT '[]'::jsonb,
  edges         jsonb DEFAULT '[]'::jsonb
) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  -- The family first, then its people, then the edges between them: the
  -- foreign keys require that order.
  --
  -- Creating and editing are branched apart rather than left to ON CONFLICT,
  -- and this is not tidiness. Postgres judges `INSERT ... ON CONFLICT DO
  -- UPDATE` against the UPDATE policies whether or not anything conflicts —
  -- and the UPDATE policies want a role in a family that, at the moment it is
  -- being created, nobody has yet. The owner arrives a moment later, from the
  -- trigger. An upsert of a new family is therefore always refused.
  --
  -- The two acts really are different here in a way they are not in SQLite:
  -- anyone signed in may start a family, only its owner or editor may change
  -- one. The branch says so.
  IF family IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM families WHERE id = (family->>'id')::uuid) THEN
      UPDATE families SET
        name                = incoming.name,
        description         = incoming.description,
        uses_lunar_calendar = incoming.uses_lunar_calendar,
        updated_at          = incoming.updated_at,
        -- Writing a row asserts that it exists (§15.2). Left alone, a row
        -- written over a tombstone lands in the table and stays invisible.
        deleted_at          = NULL
      FROM jsonb_populate_record(NULL::families, family) AS incoming
      WHERE families.id = incoming.id;
    ELSE
      -- A family this caller cannot see may still be there. To a non-member
      -- the row is absent rather than forbidden, so the check above says no
      -- and this insert meets `families_pkey` — the two-devices-one-file case
      -- (PRODUCT.md §4.2). `family_is_claimed` lets the client ask first, but
      -- asking and inserting are two requests and two devices can fall
      -- between them, so the refusal is named here as well. Named, not
      -- swallowed: nothing is written either way.
      BEGIN
        INSERT INTO families
          SELECT * FROM jsonb_populate_record(NULL::families, family);
      EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'family_already_claimed'
          USING HINT = 'Somebody else shared this family first.';
      END;
    END IF;
  END IF;

  INSERT INTO persons SELECT * FROM jsonb_populate_recordset(NULL::persons, people)
  ON CONFLICT (id) DO UPDATE SET
    display_name              = EXCLUDED.display_name,
    given_name                = EXCLUDED.given_name,
    additional_names          = EXCLUDED.additional_names,
    family_name               = EXCLUDED.family_name,
    birth_family_name         = EXCLUDED.birth_family_name,
    sex                       = EXCLUDED.sex,
    birth_date_iso            = EXCLUDED.birth_date_iso,
    birth_date_approximate    = EXCLUDED.birth_date_approximate,
    birth_lunar_year          = EXCLUDED.birth_lunar_year,
    birth_lunar_month         = EXCLUDED.birth_lunar_month,
    birth_lunar_day           = EXCLUDED.birth_lunar_day,
    birth_lunar_is_leap_month = EXCLUDED.birth_lunar_is_leap_month,
    death_date_iso            = EXCLUDED.death_date_iso,
    death_date_approximate    = EXCLUDED.death_date_approximate,
    death_lunar_year          = EXCLUDED.death_lunar_year,
    death_lunar_month         = EXCLUDED.death_lunar_month,
    death_lunar_day           = EXCLUDED.death_lunar_day,
    death_lunar_is_leap_month = EXCLUDED.death_lunar_is_leap_month,
    birth_place               = EXCLUDED.birth_place,
    death_place               = EXCLUDED.death_place,
    biography                 = EXCLUDED.biography,
    profile_media_ref         = EXCLUDED.profile_media_ref,
    updated_at                = EXCLUDED.updated_at,
    deleted_at                = NULL;

  INSERT INTO relationships
    SELECT * FROM jsonb_populate_recordset(NULL::relationships, edges)
  ON CONFLICT (id) DO UPDATE SET
    type        = EXCLUDED.type,
    person_a_id = EXCLUDED.person_a_id,
    person_b_id = EXCLUDED.person_b_id,
    updated_at  = EXCLUDED.updated_at,
    deleted_at  = NULL;
END $$;

-- ----------------------------------------------------------- deletePerson --

-- The person and every edge naming them, from either end.
--
-- The second half is the one that matters. Without it the edges stay live:
-- reads skip them as unresolvable, but synchronisation carries them to other
-- devices as real relationships pointing at somebody who is not there (§15.1).
--
-- One timestamp for both statements. A tombstone that left `updated_at` behind
-- would look older than the row it replaces, and synchronisation orders by
-- change (§15.2).
CREATE OR REPLACE FUNCTION delete_person_deep(person uuid, at timestamptz)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE persons
     SET deleted_at = at, updated_at = at
   WHERE id = person;

  UPDATE relationships
     SET deleted_at = at, updated_at = at
   WHERE person_a_id = person OR person_b_id = person;
END $$;

-- ------------------------------------------------------------ deleteFamily --

-- A family, its people, and their edges, all tombstoned together.
CREATE OR REPLACE FUNCTION delete_family_deep(family uuid, at timestamptz)
RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
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
