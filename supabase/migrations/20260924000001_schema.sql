-- The three tables a family is made of, mirroring the local SQLite schema
-- (ARCHITECTURE §8.1, DOMAIN §3–§5).
--
-- Row Level Security is enabled in this same file, on every table, before any
-- of them can hold a row. Not as a later hardening step: PostgREST serves every
-- table through the anon key, and that key ships inside the application where
-- anybody can read it. A table created without RLS is a public table, and
-- nothing warns about it.
--
-- No policies yet. RLS with no policy denies everything, which is the right
-- state for a table whose owner does not exist until the membership migration
-- adds it. Deny-by-default is a safe intermediate; allow-by-default is not.

-- ---------------------------------------------------------------- ordering --

-- One sequence for every change to every table.
--
-- Its purpose is to answer "which copy is newer" when two devices have both
-- edited a row. `updated_at` cannot: device clocks drift and users change them,
-- so a machine with a wrong date would win every conflict permanently
-- (DOMAIN §15.3).
--
-- Shared rather than one per table, because the question is asked across a
-- family, not within a table.
--
-- **Unused at M7.** It is here now because adding a monotonic column later
-- means back-filling every row on every installed device, and because nothing
-- can be merged field by field without an ordering to reason about.
CREATE SEQUENCE change_seq AS bigint;

-- Stamps a row with the next change number, on insert and on every update.
--
-- The server assigns it; a client cannot. That is the whole point — the value
-- has to come from somewhere every device agrees about.
CREATE OR REPLACE FUNCTION stamp_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.change_seq := nextval('change_seq');
  RETURN NEW;
END $$;

-- ----------------------------------------------------------------- family --

CREATE TABLE families (
  id                  uuid PRIMARY KEY,
  name                text NOT NULL,
  description         text,
  uses_lunar_calendar boolean NOT NULL DEFAULT false,

  -- On every synchronisable table since the persistence milestone (§15.2).
  -- A row is deleted by marking it, never by removing it: a row erased
  -- outright leaves no record of the deletion, and any peer still holding it
  -- proposes it back on the first sync.
  updated_at          timestamptz NOT NULL DEFAULT now(),
  deleted_at          timestamptz,
  change_seq          bigint NOT NULL DEFAULT 0
);

-- ----------------------------------------------------------------- person --

-- Twelve date columns — six per date — rather than a blob each. Explicit
-- columns keep the ISO-prefix text sortable, which is why §4.1 chose that form
-- over JSON. The precision of a date lives in which components are present, and
-- that is the thing §4.2 says cannot be recovered once lost.
CREATE TABLE persons (
  id                        uuid PRIMARY KEY,
  family_id                 uuid NOT NULL REFERENCES families(id)
                              ON DELETE CASCADE,

  display_name              text NOT NULL,
  given_name                text,
  additional_names          text,
  family_name               text,
  -- Surname at birth. Present from the first schema because by the time
  -- anybody notices it missing, the values are no longer known (§3.1).
  birth_family_name         text,

  -- Stored by name, not by number, so adding a value later does not renumber
  -- the rows that already exist (§3.2).
  sex                       text NOT NULL
                              CHECK (sex IN ('male', 'female', 'unknown')),

  birth_date_iso            text,
  birth_date_approximate    boolean NOT NULL DEFAULT false,
  birth_lunar_year          integer,
  birth_lunar_month         integer,
  birth_lunar_day           integer,
  birth_lunar_is_leap_month boolean NOT NULL DEFAULT false,

  death_date_iso            text,
  death_date_approximate    boolean NOT NULL DEFAULT false,
  death_lunar_year          integer,
  death_lunar_month         integer,
  death_lunar_day           integer,
  death_lunar_is_leap_month boolean NOT NULL DEFAULT false,

  birth_place               text,
  death_place               text,
  biography                 text,
  -- Deliberately not a foreign key: the media table does not exist until a
  -- much later milestone, and a constraint against a table that will not exist
  -- for months is one nobody can satisfy.
  profile_media_ref         text,

  updated_at                timestamptz NOT NULL DEFAULT now(),
  deleted_at                timestamptz,
  change_seq                bigint NOT NULL DEFAULT 0
);

-- ----------------------------------------------------------- relationship --

-- The two endpoint columns mean different things depending on type, which is
-- invisible in the schema and a likely source of defects (§5.1):
--
--   parentChild : person_a is the parent, person_b the child. Directional.
--   spouse      : the lower id first. Canonical, and carries no meaning.
--
-- The canonical order is what makes the uniqueness constraint work. Without it
-- (B, A) is a different row from (A, B) and a marriage can be recorded twice.
CREATE TABLE relationships (
  id           uuid PRIMARY KEY,
  -- Denormalised on purpose: it lets a policy filter edges without a join,
  -- which is the difference between a readable policy and an unreadable one.
  -- That it matches both endpoints' family is checked where both are available
  -- (§5.2).
  family_id    uuid NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  type         text NOT NULL CHECK (type IN ('parentChild', 'spouse')),
  person_a_id  uuid NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  person_b_id  uuid NOT NULL REFERENCES persons(id) ON DELETE CASCADE,

  updated_at   timestamptz NOT NULL DEFAULT now(),
  deleted_at   timestamptz,
  change_seq   bigint NOT NULL DEFAULT 0,

  CONSTRAINT relationships_unique_pair
    UNIQUE (family_id, type, person_a_id, person_b_id)
);

-- ---------------------------------------------------------------- indexes --

-- Every read filters by a foreign key, and Postgres indexes none of them on its
-- own. Both columns rather than the key alone, because `deleted_at IS NULL` is
-- part of every read and is a usable index condition.
--
-- Not partial indexes over the live rows. The smaller index is tempting, but
-- synchronisation has to read exactly the tombstones a partial index leaves
-- out (§15.2) — a trap that only springs later.
CREATE INDEX persons_by_family ON persons (family_id, deleted_at);
CREATE INDEX relationships_by_family ON relationships (family_id, deleted_at);
CREATE INDEX relationships_by_person_a ON relationships (person_a_id);
CREATE INDEX relationships_by_person_b ON relationships (person_b_id);

-- Measured on SQLite at M6: the first two are worth nothing to a whole-family
-- read, which touches most of the table, and a great deal to deleting one
-- person — 2.8× — which is a handful of rows out of thousands. They are kept
-- because the read loses nothing by their presence and a server reads by
-- family under a different engine.

-- --------------------------------------------------------------- stamping --

CREATE TRIGGER families_change BEFORE INSERT OR UPDATE ON families
  FOR EACH ROW EXECUTE FUNCTION stamp_change();
CREATE TRIGGER persons_change BEFORE INSERT OR UPDATE ON persons
  FOR EACH ROW EXECUTE FUNCTION stamp_change();
CREATE TRIGGER relationships_change BEFORE INSERT OR UPDATE ON relationships
  FOR EACH ROW EXECUTE FUNCTION stamp_change();

-- --------------------------------------------------------------- security --

-- Read the note at the top of this file before moving these lines anywhere.
ALTER TABLE families ENABLE ROW LEVEL SECURITY;
ALTER TABLE persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE relationships ENABLE ROW LEVEL SECURITY;
