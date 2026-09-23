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

**Complete** — tagged `m1.5`. One caveat carried forward: the Tết and
can-chi reference tables are still provisional, written from memory rather
than checked against a published almanac. Replace them before anyone relies
on a computed giỗ date.

Both now live in `test/support/lunar_reference.dart`, so the replacement is
one file. They are the **only** place the lunar code is measured against the
outside world — everything else in those tests is a self-consistency or
structural property that holds whatever the algorithm computes. A wrong value
there confirms a wrong implementation instead of catching it.

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

**Complete** — tagged `m2`. Six deliberately looped graphs are tested, including
one where a clean branch hangs off the loop and must still be reported in full.

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

**Complete** — tagged `m3`. Reopening is verified against a real file on disk,
not an in-memory database, since only that proves the data was written rather
than remembered.

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

**Complete** — tagged `m4`. The throwaway renderer earned its place: it found
three defects that thirty-seven passing tests had not, each invisible until a
chart contained both a couple and a branch.

Known limitations, recorded rather than fixed:

* A family graph is not a tree. Someone with parents in two branches is drawn
  once, under whichever branch reaches them first.
* Children keep the order the data records, so connectors can cross when two
  marriages genuinely interleave. Birth order was judged the more important of
  the two — a gia phả is read by it.
* A graph containing a cycle draws as an ordinary chart with the closing edge
  simply absent. Detecting and reporting such data belongs to synchronisation
  (DOMAIN.md §6.2), not to the layout.

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

Relationships are created and removed from the person being looked at, not from
a screen of their own. Errors block; warnings are confirmable, as with person
entry.

Exit criteria:

A complete family tree can be created and explored locally on iOS and Android.

**Complete** — tagged `m5`. Two defects were found only by running the tree on
a simulator and looking at it, exactly as ARCHITECTURE §14.1 anticipated, and
neither was visible to the layout's unit tests:

* a second wife's children hung from the midpoint between the husband and that
  wife, which for a second marriage is the *first* wife's box — so the chart
  said the children were hers. Each marriage now drops into the gap before its
  own spouse, and a test asserts no connector passes through a box.
* the two marriages' horizontal bars sat at one depth and read as a single
  bar. Each marriage now gets its own depth.

The throwaway layout renderer at `lib/dev/layout_preview.dart` is deleted: the
real tree screen replaces it.

---

## M6 — Local V1 Stabilization

Before cloud work:

* ~~review domain~~ — sibling order, below
* ~~review schema~~ — indexes and migration proof, below
* ~~profile tree rendering~~ — measured, below
* ~~fix UX issues~~ — the tree screen's, below; more will arrive with use
* improve tests
* ~~validate larger synthetic family trees~~ — `lib/dev/`, below
* ~~decide the living/deceased policy~~ — **decided**: a death date *or* a
  place of death means the person has died (DOMAIN.md §3.5). Derived, not
  stored, and one-way — it proves a death, never a life. The person form now
  refuses to record a death it cannot hold. What remains for Viewer-facing
  privacy is per-person filtering, not the predicate (ARCHITECTURE §11.1)

Exit criteria:

Local-only version is stable enough that cloud functionality does not need to compensate for fundamental domain problems.

### Backfilled before the M6 tasks proper

`deletePerson` and `deleteFamily` had existed since M3, with repository tests,
and no screen called either. Editing a family did not exist at all: it could be
created and never corrected. Recording a family is a transcription session, and
one that can only add turns every typo into permanent damage — so this was
closed first (PRODUCT.md §3).

* A person is deleted from the foot of their own profile, below everything
  recorded about them.
* A family is edited or deleted by swiping its row in the list. Managing an
  entry from inside itself reads oddly, and an empty family — the one most
  likely to have been created by mistake — has no list of people to scroll to
  the bottom of.
* The swipe only reveals the buttons. There is no full-swipe shortcut: a
  gesture that easy must never be the last step before losing a family.
* `flutter_slidable` was adopted for this (ARCHITECTURE.md §4.1).

Two defects found by running it rather than by testing it:

* The form sheet fed the reported keyboard inset straight into `EdgeInsets`,
  which asserts it is not negative. iOS reports a negative bottom inset for a
  frame, and the sheet took the screen behind it down with it. A platform
  measurement is not a value to trust unexamined. The regression test injects
  the negative inset directly rather than trying to reproduce a gesture.
* Two widget tests passed without testing anything — one swipe missed its
  target, and one assertion could not distinguish which of two identical
  buttons was showing. Both were rewritten and then checked by breaking the
  code they cover.

From the schema review: **nothing was indexed but the primary keys.** Loading a
family scanned the whole `persons` and `relationships` tables, and deleting a
person scanned `relationships` to find their edges. Schema v2 adds four indexes
and, more importantly, establishes how migrations are proved — captured schema
history, replayed in tests, and checked on a real device database that held 34
people (ARCHITECTURE.md §8.1, §8.2).

Doing this before the M11 hardening pass was deliberate. The index is standard
practice rather than speculative tuning, but the reason to spend the time now
is that M7 brings Postgres and a run of schema changes, and until this landed
nothing had ever demonstrated that a migration works. What it did *not* answer
is how much time the indexes save. They have since been measured, and the
answer is below.

From the domain review: **sibling order was not modelled.** `children()`
returned the order the parent-child edges happened to be created in, while the
layout treated that as birth order — so entering Con Thứ first drew a chart
that read wrong, and two devices editing offline could disagree. Children are
now ordered by recorded birth date wherever the dates decide it, and left alone
wherever they do not (DOMAIN.md §13.3). An explicit order field on the
relationship was considered and deferred: it costs a column and a migration,
and is only worth it if this proves insufficient on real data.

### Looking at it large: a generated gia phả

The interface had only ever been judged against the three or four people a
manual test creates. `lib/dev/` generates a family instead — twelve generations
and three hundred people by default — and `flutter run -t lib/dev/main_dev.dart`
runs the shipping application against it: the same providers, the same screens,
only the data replaced.

Two properties were worth more than realism:

* **Deterministic.** The same seed gives the same family, so a screenshot can be
  compared with a later one and a measurement with a later measurement. Ids come
  from `newId` with an injected clock, and the family's id is drawn before the
  current year is read — otherwise a second copy would install itself on 1
  January.
* **Clean.** Every person and every relationship passes the domain rules with no
  issue of any severity, not merely no blocking error. Data the application
  itself objects to says nothing about the interface. A test asserts it, and a
  second test reverses a parent-child edge to prove the first one would notice.

The shape is allocated rather than grown: three children a couple puts sixty
thousand people in generation ten. Each generation is aimed at a share
proportional to its depth, which gives the narrow trunk widening toward the
present that a real gia phả has — branches are lost, one line carries the record
forward, and only the last few generations have names anyone still knows. The
dates are the other constraint: a birth is read from its generation rather than
from its parents, because a per-parent offset compounds over eleven generations
until the youngest are born after today and every edge earns a warning.

It writes into the **normal** database beside any real family, and
`--dart-define=RESET=true` erases the generated family alone, by the id its seed
produced. A blanket "clear the development data" is the obvious thing to write
here and would take a hundred years of somebody's family history with it.

`lib/dev/` is unreachable from `lib/main.dart`, so none of it reaches a release
build and there is no debug flag to remember to turn off.

What this does **not** do is measure anything beyond the two timings the entry
point prints, because those cost nothing to collect. The measuring is a harness
of its own, below.

### What three hundred people did to the tree screen

The rules this arrived at are recorded as ARCHITECTURE.md §14.2 and §14.3.
What follows is how they were found, and the measurements that argued for
them.

Running it was the point, and the first measurement settled what the screens
needed. A chart of that family, at a zoom the names can still be read at,
measures **fifty-three screens across and one and a bit down**. Fitted to a
phone instead it comes out at 0.011 — boxes under two points wide. Neither
is a view of anything.

That width is not a defect to optimise away. A tidy tree is exactly as wide as
it has leaves, and 196 of the 300 are childless; the predicted width from the
leaf count and the measured width agree within 15%. No arrangement of the same
people is narrower. The chart had to show fewer of them, or show them turned.

**Folding.** A chart opens three generations deep — twenty-three people rather
than three hundred, and 4.3 screens rather than 53. `collapseToDepth` names who
to fold: the last visible generation **and everyone below it**, so opening one
fold reveals exactly one generation and the chart never widens by more than was
asked for. A folded box carries the number standing behind it, counted after
placement rather than before, because a descendant of a folded person may have
been drawn anyway through another branch and putting a number on people the
reader can already see would be a lie.

**Orientation.** The two axes are bounded differently: depth can be folded,
the width of a generation cannot — a rule that hides siblings hides whoever
carries the line, and on this family the first three children are childless
while the fourth and sixth hold 208 of the 214 between them. So the foldable
axis is the one to put across the narrow side of a phone. Turned sideways,
the same folded chart is **1.07 × 1.16 screens**, where upright it was 4.3 across — a
shape a phone can be scrolled through rather than one it cannot hold.

The placement pass never knew about x and y — it packs along one axis and steps
along another — so the two orientations differ in one function, where those
become a point. The spacing constants are named for what they measure rather
than for a direction, because `slotWidth` is a height once the page is turned.

Which way a chart opens is **measured, not counted**: whichever is narrower
wins, because a phone scrolls down readily and sideways badly. Counting people
gets it wrong in both directions — a line of descent fourteen deep is fine
upright, and one generation of twelve is not. Once the reader turns the page
themselves the measuring stops, or the chart would turn back under them the
next time somebody was added.

**Placement.** Three rounds of "it moves when I do not expect it to", and each
one was the same fault: two rules where there should have been one.

* The gap above the ancestor was in chart units and so shrank with the zoom,
  and a chart that fitted was centred whole while one that did not was anchored
  on its root — so no two families opened alike, and crossing that threshold
  moved everything.
* Opening and fitting were separate arithmetic, so the chart opened against the
  top and jumped to the middle the moment the fit button was pressed.

One function now, used by both: a chart that fits is centred, one that does not
opens on its ancestor a fixed inset in, and the two agree exactly where they
meet, so nothing jumps at any size. Centred on the ancestor rather than on the
middle of the drawing: descendants pile up down a few branches, so the two are
**263 points apart at three generations and 617 at five** on this family. The
second is wider than the screen.

Folding costs room below, so opening a fold now pans the least distance that
brings the new generation into sight, keeping the zoom, and does nothing at all
when those people are already on screen. It slides rather than jumping, and a
finger on the chart stops the slide. Zooming out stops where the whole chart is
visible, and a chart shoved aside settles back — but only along an axis it no
longer fills, and never after a tap, which ends an interaction without having
moved anything.

**What the interface still cannot do** is fit a generation of nine on a phone.
Three point six boxes fit across it at a readable size; folding bounds the
depth and turning the page bounds what that costs, but a wide generation is
still read by scrolling. The form that would fit — the indented outline a gia
phả is written in on paper, measured at 0.95 screens wide — is recorded here as
the option not taken rather than as work outstanding. Use the chart on real
data first.

### What the tree screen actually costs

`test/performance/tree_rendering.dart`. Deliberately not named `_test.dart`, so
the suite does not carry it; run it with `flutter test` and the path. A harness
rather than a page of numbers, because a measurement nobody can repeat is a
measurement nobody can check.

It runs in the Dart VM under JIT against a recording canvas, not AOT on a phone
against a GPU. The absolute figures are therefore an upper bound and the
*ratios* are what carry over. Median of twenty-one runs — one run in twenty
meets the garbage collector, and a mean carries that into every conclusion.

A thousand people, twelve generations, drawn five đời deep with the generations
as rows:

| | |
| ----------------------------------- | -------: |
| `TreePainter.paint`, 192 boxes      | 47.8 ms  |
| — of which laying out the labels    | 31.9 ms  |
| — of which rebuilding the drop points | 0.03 ms |
| `layoutDescendants`                 |  0.9 ms  |
| `FamilyGraph(...)`                  |  0.6 ms  |
| `generations()` on a fresh graph    |  3.0 ms  |
| `loadFamily`                        | 29.2 ms  |

**A suspicion recorded here was wrong.** `_barsByParent` walks every edge on
every paint and was named as a likely cost; it is five hundredths of a
millisecond, 0.05% of a paint. Nothing there is worth touching, and the note
that said otherwise is now this paragraph.

The cost is the **labels**: every box builds a `TextPainter` and lays it out
again from nothing, sixty-seven per cent of the paint. What takes the sting out
is that panning and zooming do not repaint at all — `InteractiveViewer`
transforms a layer that is already drawn. The 47 ms is paid when the layout
changes: opening the screen, turning the page, redrawing from somebody else —
and selecting a person, because that rebuilds and `TreeLayout` has no value
equality, so `shouldRepaint` sees a new object every time.

What keeps this off the list of work: **at three hundred people the same paint
is 10.9 ms**, inside a frame. A thousand is the synthetic family, not a gia phả
anybody has. Caching a person's laid-out label by id would cut two thirds of
the paint and is the obvious repair — to be done when somebody reports a stall
on real data, and not before (§5, avoid premature optimization).

### What the indexes are worth

The question ARCHITECTURE.md §8.1 left open, measured on the same harness at a
thousand people. The answer has two halves and only one of them was expected:

| | with indexes | without | |
| -------------- | ------: | ------: | ---- |
| `loadFamily`   | 29.2 ms | 28.7 ms | 0.98× |
| `deletePerson` |  0.65 ms |  1.80 ms | 2.77× |

Reading a whole family touches most of both tables, and for that a sequential
scan beats consulting an index — `persons_by_family` and
`relationships_by_family` earn nothing on the read they were named for. What
they do earn is on `deleteFamily`, which is the same filter over a table it
does not read whole.

`relationships_by_person_a` and `relationships_by_person_b` are worth what was
hoped: finding one person's edges is a handful of rows out of thousands, which
is the shape an index wins, and deleting a person is **2.8× faster** for having
them.

So the decision to index was right and the reasoning written down for it was
not. Both indexes stay: the read loses nothing measurable by their presence,
and M7 brings a server where the same tables are read by family under a
different engine.

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
* database indexes — the read and delete paths were indexed at M6
  (ARCHITECTURE.md §8.1); what remains is whatever measurement turns up
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