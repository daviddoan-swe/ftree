# Family Tree — Development Roadmap

## M0 — Project Bootstrap

Goal: establish a clean working baseline.

Tasks:

* Create Flutter project
* Configure Git repository
* Add CLAUDE.md
* Add project documentation
* Verify Android build
* Verify iOS build
* Run Flutter tests
* Run static analysis

Exit criteria:

Application builds and runs on both development platforms.

**Complete** — tagged `m0`. Verified on iPhone 17 Pro (iOS 26.5) and
Pixel_7_API_36 (Android 16, x86_64): the app renders and responds to input on
both, not merely builds.

---

## M1 — Core Domain

Scope note: validation at this milestone is entity-level and pair-level only.
Anything requiring the whole graph — cycle detection above all — belongs to M2,
because a `Relationship` cannot validate itself (DOMAIN.md §13.1).

Implement:

* Family
* Person
* Relationship
* relationship types
* `GenealogicalDate` — partial dates with optional month/day and an approximate
  flag (DOMAIN.md §4)
* `ValidationResult` / `ValidationIssue` with error and warning severities
  (DOMAIN.md §9)
* UUID v7 identifier generation
* canonical id ordering for symmetric relationship types
* entity-level and pair-level validation

Tests:

* valid parent-child
* self-parent rejection
* duplicate relationship rejection
* spouse symmetry, including `(B, A)` colliding with an existing `(A, B)`
* self-spouse rejection
* empty `displayName` and empty `Family.name` rejection
* partial-date construction, ordering, and indeterminate comparison
* date warnings are non-blocking, and are suppressed when the comparison is
  indeterminate (DOMAIN.md §4.3)

Exit criteria:

Core entities, the date model, the validation severity model, and basic
relationship invariants are covered by tests.

**Complete** — tagged `m1`. Domain purity is enforced by a test that scans
`lib/domain` for forbidden imports rather than left to convention.

---

## M1.5 — Lunar Calendar

Still pure Dart: no UI, no persistence, no dependencies.

Implement:

* Vietnamese lunar ↔ Gregorian conversion
* can-chi (Đinh Hợi, Giáp Tý…) derived from a lunar year, and the reverse
  lookup given a century
* the next Gregorian date on which a given lunar date falls — the calculation
  giỗ rests on

Tests:

* conversion verified against a published table of Tết dates across several
  decades
* leap months (tháng nhuận) in both directions
* round trip Gregorian → lunar → Gregorian
* dates either side of Tết, where the lunar year changes mid-Gregorian-year

Exit criteria:

A lunar date can be converted in both directions and verified against an
external reference, and the next occurrence of a lunar anniversary can be
computed.

Why here rather than later: without conversion, a user transcribing a family
record must leave the application, convert each date by hand on some other
site, and type it back. A tree of 200 people means up to 400 manual
conversions, and every one of them can be wrong — producing bad Gregorian data
that nothing can later detect. Landing this before the M5 data-entry screens
also means those screens are built dual-calendar from the start rather than
retrofitted.

Must use the **Vietnamese** lunar calendar, based on UTC+7. The Chinese
calendar uses UTC+8 and differs by a day for some dates, so a Chinese
implementation cannot be adopted without verification.

---

## M2 — Family Graph

Implement graph operations:

* parents
* children
* spouses
* siblings — per the contract in DOMAIN.md §8.1: excludes self, deduplicated,
  carries `sharedParentCount`, excludes step-siblings
* ancestors
* descendants

Implement graph-level validation:

* ancestry-cycle detection on the write path
* cross-family and dangling-endpoint rejection
* `familyId` consistency between a relationship and its endpoints
* ancestor/descendant spouse warning

All traversals use a visited set and terminate on cyclic input.

Tests should cover multiple generations, invalid cycles, half siblings, and a
deliberately cycle-containing graph that traversals must survive rather than hang
on.

Exit criteria:

Genealogical relationships can be queried without UI or database dependencies,
and a corrupt graph cannot hang the traversals.

---

## M3 — Local Persistence

Introduce:

* Drift
* SQLite
* schema
* migrations
* a single local repository (split only when a caller demands it)

Persist:

* Family
* Person
* Relationship

The initial schema must already include (ARCHITECTURE §8):

* partial dates as ISO-prefix text plus `isApproximate`
* `updatedAt` and nullable `deletedAt` on every synchronizable table, filtered on
  read by the repository
* `ON DELETE CASCADE` from relationships to both person endpoints
* `UNIQUE (familyId, type, personAId, personBId)`
* UUID v7 primary keys, never composite with `familyId`

These are schema decisions, not synchronization decisions. They do not require
the sync design and cannot be added cheaply afterwards.

Exit criteria:

Application can create, close, reopen, and recover family data locally.
Deleting a person leaves no orphaned relationships, and deletions leave
tombstones.

---

## M4 — Tree Layout Engine

Create a UI-independent layout engine.

Input:

* Persons
* Relationships
* selected root/context

Output:

* nodes
* coordinates
* relationship edges
* generation/layout information

Initial support:

* multiple generations
* parent-child connections
* spouse grouping

Build a throwaway renderer — boxes and straight lines, no styling — as soon as
the engine emits its first coordinates, and develop against it (ARCHITECTURE
§14.1). Unit tests cannot detect overlapping nodes, crossed connectors, or a
layout that simply does not read as a family tree.

Exit criteria:

Layout can be tested without Flutter widgets, and has been visually verified
against non-trivial trees including half siblings and multiple marriages.

---

## M5 — Core Flutter UI

Implement:

* family screen
* person creation
* person editing
* person profile
* family tree
* pan
* zoom
* node selection

Person entry must support partial dates and must surface validation warnings as
confirmable rather than blocking.

Interface strings are externalised from the first screen, not hardcoded and
extracted later (PRODUCT.md §1.1). Vietnamese and English at minimum.

Date entry offers both calendars when the family uses the lunar one, and shows
both readings wherever a date is displayed. The conversion for this lands at
M1.5, so these screens can be built dual-calendar rather than retrofitted.

Exit criteria:

A complete family tree can be created and explored locally on iOS and Android.

---

## M6 — Local V1 Stabilization

Before cloud work:

* review domain
* review schema
* profile tree rendering
* fix UX issues
* improve tests
* validate larger synthetic family trees
* decide the living/deceased policy — `deathDate == null` is not a reliable
  indicator, and Viewer-facing privacy depends on it (ARCHITECTURE §11.1)

Exit criteria:

Local-only version is stable enough that cloud functionality does not need to compensate for fundamental domain problems.

---

## M7 — Cloud Foundation

Introduce Supabase.

Implement:

* PostgreSQL schema
* authentication
* FamilyMembership — the entity arrives here, with the first real `userId`
  (DOMAIN.md §12.1)
* remote repositories
* database migrations
* initial security configuration

Exit criteria:

Authenticated development users can securely access cloud-backed test data.

---

## M8 — Family Sharing and Authorization

Implement:

* Owner
* Editor
* Viewer
* invitations
* Row Level Security

Membership rules to enforce server-side (DOMAIN.md §12.1):

* one membership row per user per family
* at least one owner per family at all times
* the last owner cannot be demoted or removed
* the creator of a family becomes its owner

Test authorization server-side.

Exit criteria:

Unauthorized users cannot access another family's private data.

---

## M9 — Synchronization

Design and implement:

* local/cloud synchronization
* change detection
* offline modifications
* synchronization status
* initial conflict handling
* deletion behavior via the tombstones introduced at M3

Constraints already fixed (ARCHITECTURE §12):

* conflict ordering uses a server-assigned sequence or hybrid logical clock,
  never device wall-clocks
* the protocol transmits a subset of a family, not necessarily the whole family
* ancestry cycles produced by merging are detected and reported for user
  resolution, never silently repaired by deleting an edge

Avoid unnecessary synchronization complexity.

Exit criteria:

Two authorized devices can make supported changes and converge to a consistent family dataset.

---

## M10 — Media

Implement:

* profile photos
* image resizing
* image compression
* thumbnails
* object storage
* local caching

Measure:

* storage size
* bandwidth
* upload performance

Exit criteria:

Family photos work without unnecessarily large storage or bandwidth usage.

---

## M11 — Production Hardening

Implement/review:

* error handling
* privacy
* security
* performance
* database indexes
* backup strategy
* logging
* crash reporting as appropriate
* release configuration

Exit criteria:

Application is suitable for controlled real-world family use.

---

## M12 — Distribution

iOS:

* signing
* TestFlight
* controlled testing

Android:

* signing
* internal testing
* controlled testing

Collect feedback before adding major new features.

---

# Future — Not Committed

Possible future features:

* GEDCOM import/export
* date ranges, non-Gregorian calendars, and BC dates
  (partial and approximate dates are already in V1 — DOMAIN.md §4)
* name variants and alternate spellings
* linking a User to a Person
* merging duplicate Persons across families
* adoption/guardian relationship types
* events and family timeline
* documents
* richer media
* family history stories
* advanced search
* optional AI-assisted features
* web client

These are not part of the current committed roadmap.

They should not influence implementation unless they affect a difficult-to-change foundational decision.