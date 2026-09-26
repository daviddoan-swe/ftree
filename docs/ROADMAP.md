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
* ~~improve tests~~ — the three files in `lib` that had none: `date_display`,
  `issue_text`, `validation_prompts`. Bounded deliberately at those rather
  than chased as coverage
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

## M6.5 — A family that can leave the device

Not planned, and not part of M6. It arrived from a question with an
uncomfortable answer: *what happens to somebody's gia phả when they reinstall
the application?* Nothing good. Both platforms delete the private directory
the SQLite file lives in, there was no export, and cloud synchronisation does
not protect anything until M9. A hundred years of transcription sat one
uninstall from gone.

So PRODUCT.md gained §9.1 and a success criterion, and this is the work that
answers it.

### JSON, and not the two obvious alternatives

**Not a copy of `ftree.sqlite`.** Simpler and exact, but it can only *replace*
what the receiving device holds — two relatives could not each contribute.

**Not GEDCOM**, though GEDCOM is the international interchange format and
belongs on the roadmap for its own sake: a family should never be locked into
this application. It cannot carry a lunar date, and its identifiers are local
to one file — `@I1@` means "the first individual in *this* file", which is
exactly the collision problem UUID v7 exists to avoid. The two formats do
different jobs.

A correction while this was written: an earlier note here claimed GEDCOM could
not express a date known only to the year. The opposite is true — `1887`,
`MAR 1887`, `ABT 1890`, `BET 1880 AND 1890` are native to it, because it was
written by people with this exact problem.

### The merge rule: add only, never overwrite

Anything already on the device is left exactly as it is, including the family's
own name and calendar setting. Choosing the file's copy over the device's is
conflict resolution, which needs to know which is newer, and §15.3 says device
clocks cannot answer that.

The cost is stated in the interface rather than discovered: a correction made
on a relative's device does not travel. That is the honest limit of exchanging
files, and it is why M9 still has work to do.

Two kinds of duplicate, because ids alone are not enough: an edge is already
here when its id matches *or* when the same relationship exists under another
id — two devices each minting one for the same marriage. Matching on the key
catches it, and the difference is what the reader is told: "already here"
rather than "refused".

Each accepted edge is validated against a graph holding the ones accepted
before it, rebuilt each time. A cycle can be closed by two edges that are each
valid alone — the merge case ARCHITECTURE §3.3 ③ describes — so judging them
all against the starting graph would let one through, and a cycle hangs the
tree screen forever. About a second for a thousand people, paid once.

### One transaction, measured

`saveAll` writes the family, its people and their edges together or not at all.
The single-row writes could not express that: a thousand committed rows and an
interruption leaves a family half entered, with edges naming people who are not
there.

|              | row by row | one transaction |         |
| ------------ | ---------: | --------------: | ------- |
| 300 people   |     839 ms |          106 ms | 7.9× |
| 1000 people  |   1,149 ms |          238 ms | 4.8× |

Speed is the side effect. The point is that there is no half state.

### What running it found that the tests did not

Two defects, both invisible to 837 passing tests, both obvious within a minute
of using the feature on a device that had been used.

**A write did not clear the tombstone it landed on.** Importing into a family
somebody had deleted wrote three hundred people, reported success, and showed
none of them: `insertOnConflictUpdate` updates only the columns it is given,
and `deletedAt` was in none of the mappers' companions. The rows were there and
every read filtered them out. The rule now stated in `mappers.dart`: writing a
row asserts that it exists, a tombstone asserts that it does not, and both
cannot hold. `savePerson` had the same hole — nothing had reached it because a
person created in the application always gets a fresh id.

**An import that worked said nothing.** The string for reporting it had been
written and never called. The reader was returned to the list they started
from with no way to tell whether anything had happened.

Neither was a weak test. Both were conditions no test had thought to create,
which is the argument for ARCHITECTURE §14.1 made again: run it and look.

### Left for later, deliberately

* **Exporting a subset** — only the deceased, say. ARCHITECTURE §11.1 requires
  the protocol to be *able* to carry part of a family; it does not require V1
  to offer it.
* **Opening a file straight from a chat application.** Needs document types
  registered on both platforms.
* **Recognising that two records are the same person.** DOMAIN §14.1 calls this
  the hardest problem in genealogy software, and V1 does not attempt it.

---

## M7 — Cloud Foundation

Introduce Supabase.

### Two decisions taken before any of it is built

**The application keeps reading and writing SQLite.** The cloud repository is
built and proved against the same contract, and is not wired into any screen
until M9 brings synchronisation. Reading from the server when there is a
network would show cloud data sooner and cost the thing CLAUDE.md §1 lists
fourth — a gia phả that opens on a train. It would also have to be taken apart
again at M9.

What this means in practice: nothing in `lib/features` changes at M7. The
milestone is finished when a signed-in developer can reach cloud-backed data
*through the repository contract*, not when a screen shows it.

**A server-assigned sequence column is added now, and left unused.** M7 has no
need of it. It is the only way to answer "which copy is newer", because
`updatedAt` cannot (§15.3) — and without an answer to that, merging two edits
of the same person field by field is not merely unbuilt but impossible.

That question came up while the file import was being built: two editors
change different fields of one person, and the merge should take both. It
needs three versions, not two — theirs, theirs, and the common ancestor — and
an ordering to say which is which. Adding a monotonic column later means
back-filling every row on every installed device, which is the shape of cost
§18 exists to warn about.

Implement:

* ~~PostgreSQL schema~~ — `supabase/migrations/…_schema.sql`
* ~~authentication~~ — `lib/data/cloud/cloud_session.dart`
* ~~FamilyMembership~~ — the entity arrives here, with the first real `userId`
  (DOMAIN.md §12.1)
* ~~remote repositories~~ — `SupabaseFamilyRepository`, held to the same
  contract as the SQLite one
* ~~database migrations~~ — four, replayable with `supabase db reset`
* ~~initial security configuration~~ — RLS on every table, policies per role

Exit criteria:

Authenticated development users can securely access cloud-backed test data.
**Met**, against a Postgres running on the developer's own machine. A cloud
project of its own is not needed to develop against and is not set up.

### One contract, two stores

`test/support/repository_contract.dart` holds sixteen checks written against
`FamilyRepository` rather than against either store. SQLite answers them in the
ordinary suite; Postgres answers the same ones, **unchanged**, in `test/cloud/`.

That the file is imported rather than adapted is the point. Two implementations
each passing tests of their own prove nothing about swapping one for the other,
which is what M9 is going to do.

Running it against Postgres for the first time failed fourteen of sixteen, all
on one thing, and the thing was worth finding.

### Creating a family and editing one are different acts

Postgres judges `INSERT … ON CONFLICT DO UPDATE` against the UPDATE policies
whether or not anything conflicts. Creating a family asks for a role in a
family nobody has a role in yet — the owner arrives a moment later, from the
trigger — so an upsert of a *new* family was always refused, while an upsert of
an existing one, or of a person into a family already owned, worked.

Not a fault in the policies. Anyone signed in may start a family; only its
owner or editor may change one. SQLite has no way to tell those apart and so
never had to. `save_family_all` now branches, and `saveFamily` goes through it.

### Three promises PostgREST cannot keep

Every request it serves is its own transaction, and the contract promises more:
`saveAll` is all or nothing, `deletePerson` must take the person's edges with
them, `deleteFamily` likewise. Left as separate requests, an interruption
between them leaves the half state each promise exists to prevent — most
sharply a tombstoned person whose edges still point at them and still
synchronise as real (§15.1).

So all three are functions, and all three are `SECURITY INVOKER`: the policies
judge every statement inside them exactly as from outside. Only two functions
step around RLS — `my_role`, because a policy that reads the table it guards
recurses for ever, and `owner_on_create`, because the creator of a family holds
no membership at the instant they need one. Each is a hole in the wall and each
says why where it is written.

### What is deliberately not here

**No permission check in the Dart.** One would be a second, weaker copy of a
rule the server already enforces, and the first to fall out of step. What the
policies allow is what happens.

**No screen.** `lib/features` is untouched by this milestone. The decision was
taken before any of it was built (above), and holds: reading from the server
when there is a network would cost offline use and be dismantled again at M9.

**A refused UPDATE does not look like one.** Worth carrying into M9: a
forbidden INSERT throws 42501, but `USING` decides which rows an UPDATE can
see, so a forbidden one matches nothing, changes nothing, and reports success —
HTTP 204. A viewer who edits a name is told it worked. Whatever eventually
writes through this has to ask for the changed rows back rather than trust the
status.

---

## M8 — Family Sharing and Authorization

Implement:

* **signing in, reached from Chia sẻ** — the first screen in the application
  that knows an account exists (PRODUCT §4.1). Done
* **Chia sẻ** — one family up, on one action in one row, beside Xuất. Done
* **marking a family as shared** — one column in the local schema, because the
  device cannot ask the server while offline (PRODUCT §4.2)
* **asking whether a family is already claimed** — the one question the device
  cannot answer, because the mark records what *this* device did and a file
  puts the same family on two of them (PRODUCT §4.3)
* Owner
* Editor
* Viewer
* **invitations** — only an owner may send one; any role may be received,
  owner included, behind a confirmation (PRODUCT §5.1). A secret code the owner
  passes on by hand, stored only as a hash. Done
* **members, changing a role and removing one** — the other half of there
  being no approval step (PRODUCT §5.3, §5.6). Owner-only, behind a swipe.
  Done
* **signing out** — and the local marks and codes that go with it
  (PRODUCT §5.9). Done
* **what each role may do on the device** — the controls the interface offers,
  mirroring the server policies rather than replacing them (PRODUCT §5.0). Done
* **keeping those roles in step** — one request for every role this account
  holds, asked when the application opens. The only thing that reaches a device
  before M9. Done
* Row Level Security

### Where signing in lives, and why it is here rather than at M7

Not at the door. The application works with no account and no network, and
most people will only ever want that (PRODUCT §4.1). A sign-in wall in front
of it is a wall in front of the whole application.

It sits behind **Chia sẻ**, one action on one family, beside export, edit and
delete. Pressing it is somebody saying they want a record kept by more than one
person, which is the only thing an account buys.

M7 did not need it. Authentication is four functions in
`lib/data/cloud/cloud_session.dart`, exercised against a real auth server; a
screen is a way for a person to call three of them. What a screen adds is the
human path and **a session that survives closing the application** — and that
second one has never been checked, because the checks mock the device storage
a session would live in. It is a simulator job, like the share sheet.

### What the shared-family decision costs, measured against what exists

Less than expected, because of two decisions already taken.

Ids are UUID v7 and globally unique (§14.1), so a family pushed up keeps the id
it had — no renumbering, no translation table. Had this been an auto-increment
integer, this is where it would have stopped.

`owner_on_create` reads the creator from the token, and fires on INSERT
whatever id the client supplied. So whoever presses Chia sẻ becomes owner with
nothing added, and `save_family_all` already branches insert from update in the
way that needs.

What is missing is one column: the device has to remember which families are
shared. It travels with the synchronisation metadata the local schema needs
anyway.

### Chia sẻ is offered once, and what happens when it is not

Checked against the running stack rather than reasoned about, because the
question — *what if the family is already up there?* — has three answers and
only one of them was obvious.

**Sharing the same family twice is harmless.** The second press takes the
update branch, and `owner_on_create` fires only on insert, so there is still
exactly one membership row. Nothing is duplicated.

**Sharing a family somebody else already shared is refused** — and used to be
refused with `23505 duplicate key value violates unique constraint
"families_pkey"`. The effect was right, in that nobody took over a family that
was not theirs, but that sentence tells a person nothing and the case is not
rare: it is the ordinary consequence of the file export. One person sends a
copy, the other imports it, and both devices now hold a family with the same
id. Whichever presses second meets this.

**Done, in two halves** (PRODUCT §4.3). The device cannot answer the question
by itself — a family belonging to somebody else reads as absent, not as
forbidden, so an `EXISTS` from the client says "no" and the insert that follows
meets the primary key. So `family_is_claimed` answers it, SECURITY DEFINER
because seeing past the read policy is the whole job, returning a boolean and
nothing else. And `save_family_all` names the refusal — `family_already_claimed`
— rather than letting a constraint surface, because asking and inserting are
two requests and two devices can fall between them.

Saying so leaks nothing: whoever meets it already holds the whole family, which
is how they came to have its id. Ids are UUID v7, so nothing can be found by
guessing.

**The measured surprise: revoking PUBLIC does not revoke `anon`.** The function
was written with `REVOKE EXECUTE ... FROM PUBLIC`, which looks sufficient and
is not. Supabase sets default privileges granting EXECUTE on new functions in
`public` to anon, authenticated and service_role, so each role holds a grant of
its own made at creation time. The first version therefore answered anonymous
callers, and — being SECURITY DEFINER — answered them truthfully. A test that
signed nobody in caught it; reasoning about it had not.

**Who owns it when two people can both press: the first.** A file carries no
proof of authorship, and cannot, because at export time there may be no account
on the device to sign it. Handing a family over afterwards is deferred
(PRODUCT §4.3).

**A member pressing Chia sẻ on a family already shared is the one to prevent.**
It takes the update branch and is allowed — and `saveAll` upserts the people
and edges too, so a local copy would land on top of the shared one. That is
"my copy wins", which is precisely the conflict resolution that cannot be done
without an ordering nobody has yet (§15.3).

So **Chia sẻ is offered only for a family that is not shared**. Once it is, the
action on that family is *invite somebody*, not share it again. The column that
remembers which families are shared is what makes the distinction visible
without asking the server.

### What the button does, and the third state nobody had named

`shareFamily` asks before anything, including before signing in: creating an
account somebody did not want cannot be undone either. Then one of three things
is true, and which one is decided by asking the server rather than by trusting
the local mark — the mark records what *this device* did, and a file puts the
same family, keeping its id, onto another device.

1. **Nobody holds it.** Up it goes; whoever pressed becomes the owner.
2. **We hold it and this device forgot.** A reinstall, or a restore from one's
   own exported file. The mark is **recovered** and nothing is sent. This state
   had not been named before building the button, and naming it retired a rule
   that had looked reasonable — *a device that imported a file may not share* —
   which would have caught the person restoring their own backup. The two acts
   are identical to the device and opposite to the person; only the server can
   tell them apart.
3. **Somebody else holds it.** Said plainly, with the way in: an invitation.

Cases 2 and 3 are separated by whether this account can *read* the family. A
family somebody else owns is absent rather than forbidden, so "can I see it" and
"am I a member" are the same question — which is why the policies being written
as absence rather than as refusal keeps paying off.

The mark is written **after** the send, never before. Written first it would
survive a failure and hide the button that would have tried again.

### Three things the screen was told by the server, not by documentation

**A wrong password and an unknown address come back identically**, both
`invalid_credentials`. That is the server declining to say who is registered, so
the wording has to keep the secret: "that email and password do not match",
never "wrong password". Had the codes been guessed rather than read off the
running stack, the interface would have leaked what the server withheld.

**Signing up can succeed with no session.** Where addresses are confirmed, the
account exists and there is no token until a link is followed. So "did it work"
and "are we signed in" are different questions, and the screen has to answer the
second. The local stack runs with `enable_confirmations = false` and therefore
cannot produce this at all — the first case production meets is the one no
available server can exercise, which is why the attempt is a parameter.

**The minimum password length belongs to creating, not to signing in.** An
account made when the minimum was lower still has the password it has. A screen
that applied the rule on the way in would lock its owner out over a rule that
was never theirs.

### What building invitations turned up

**Three of the four checks inside the hole are the whole feature.**
`accept_invitation` is SECURITY DEFINER, so nothing inside it is protected by a
policy and every guard is one somebody wrote by hand. Removing the revoked
check makes the owner's Huỷ button decoration; removing the accepted check
turns one code into a crowd; removing the expiry check revives last year's
codes. Each was broken deliberately and each turns a check red.

**Two pieces of the feature needed no server code at all.** Listing members and
removing one were already possible: `memberships_read` lets members see each
other, `memberships_update` lets an owner change a row, and `keep_an_owner`
already refuses to let the last owner go. Only the screen was missing. Worth
noticing before writing a migration — the policies had been sized for this
without anybody planning it.

**But listing members needed one thing nobody had thought of.** A membership
row holds a `user_id`, and no client may read `auth.users` — rightly, since
that is every account on the server. So the member list would have shown
uuids, which answers none of what §5 says the list is for. Hence
`family_members`, the fifth SECURITY DEFINER function: it returns addresses to
somebody already in that family, nothing else from `auth.users`, and nothing at
all to anybody else.

**The join path reuses the import path, and had to.** Accepting an invitation
and importing a file end in the same act — a family, its people, their edges,
and an id that may already be on this device. Sharing the code was not for
tidiness: somebody sent the exported file first, who imported it and added
their own branch, would have had that branch overwritten by a download. The
add-only merge was already written and already tested; the only work was not
writing a second one.

### Left open, on purpose

**Email or phone number — decided: email and a password** (PRODUCT §4.3 is the
ownership question; this is §4.4). Not on price. Twilio charges about $0.29 per
message to a Vietnamese number, which is affordable; Decree 91/2020 is not.
Sending an OTP to a Vietnamese number needs a brandname registered with Viettel,
Vinaphone or MobiFone, weeks of approval, and since August 2024 the registered
name in every message. A private family application has none to register.

Email and a password is the only remaining option that depends on nobody — no
carrier, no Google, no Facebook, no Zalo — and `auth.uid()` is the same value
whatever somebody signed in with, so a provider can be added later without
touching a policy, a membership or a trigger.

**Handing a family over.** The first to press Chia sẻ owns it, and there is no
fairer rule the data supports (PRODUCT §4.3). Transferring ownership afterwards
is wanted and deferred: it needs an owner willing to do it, so it is a
conversation between people with a button at the end. Until then the way out is
that the owner invites the right person as an editor.

**Listing families from two places.** A family may be local, both, or — for
somebody just invited — on the server alone. That third state is new, and it is
the point at which the single repository becomes awkward rather than before
(ARCHITECTURE §7). M9's.

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

Also waiting here, because until two copies can speak it delivers nothing a
file does not: **a reusable code for a whole branch, gated by approval**
(PRODUCT §5.8). It revisits two M8 decisions rather than extending them —
single use, and no approval — and the reasoning for revisiting them is written
out there. The short of it: reusable and approval need each other, and the
argument against a queue does not reach a code whose owner never chose a
recipient.

Built in steps, because each one stands on its own and the first delivers most
of what is currently missing.

**Step 1 — pulling. Done.** `WHERE change_seq > lastSeen`, one number per
family, asked when somebody opens that family. `0` means nothing has been
taken, so the first download and every later pull are the same request and
there is no second path to keep in step with the first.

Two things had to exist for it. `families.lastSeen` records where a device got
to, written inside the same transaction as the rows and *last* — written first,
a pull interrupted halfway would leave the remainder below a number already
recorded, and nothing would ever ask for those rows again. And `unsent` on
every synchronising row says which changes are this device's and have not been
sent: a flag rather than a comparison against `updatedAt`, because that would
be asking the device's own clock whether an edit came after the last sync, and
a clock that steps backwards drops the edit silently.

A row marked unsent is **held**, not merged. Landing the server's version on
top of somebody's work is the one failure a pull must not have, and until
pushing exists there is nothing to reconcile against — the work has nowhere to
have gone. Held ids come back so a screen can say so; choosing between two
versions is step 3's, and it needs both to exist.

**Step 2 — pushing. Done.** What `unsent` was put there for, and what makes an
editor's changes reach anybody else — until this landed, "editor" was close to
a label: they could edit, but only their own copy, which nobody would ever see.

Push then pull, in that order, because a pull holds every unsent row rather
than landing on it. Pushing first is what lets those rows stop being held and
start being merged.

Two things the server insisted on.

Removals cannot ride with the rest. `save_family_all` clears `deleted_at` on
everything it writes, because writing a row asserts that it exists — so a
tombstone sent through it brings the person back to life. They go by the
functions built for them.

And a push cannot trust silence. A policy that refuses an UPDATE makes the
statement match nothing, change nothing and raise nothing; clearing `unsent` on
the absence of an error would drop somebody's work and never retry it. So every
row leaves carrying one timestamp, and afterwards the server is asked which
rows it holds with exactly that timestamp. Those are the ones that landed.

The two refusals do not look alike, which is worth knowing: a viewer pushing a
*person* is refused loudly, because `save_family_all` reaches that table
through an INSERT and `persons_insert` raises 42501. A viewer removing a
*relationship* is refused in silence, because that is a plain UPDATE. Both are
checked, and the second is the one the confirmation exists for.

**Step 3 — conflict. Done, for people.** Two relatives filling in different
halves of the same person now merge without anybody being asked.

It needs three versions, not two. Given only mine and theirs there is no
telling an edit from an absence of one — both look like values. The device
therefore keeps the row exactly as the server last gave it, from the first
local edit until that edit has gone, and `persons.baseFields` is where. The
base is kept on the *first* edit only: overwritten by the second, a merge would
compare this device's work against itself, find no change where there was one,
and hand the field back to the other side.

Per field: neither moved it, it stays; one moved it, that side wins; both moved
it the same way, they agree; both moved it differently, **conflict**, and
nothing is chosen. Nothing is chosen because there is nothing to choose by — a
later `change_seq` says which write reached the server second, not which
reading of a hundred-year-old record is right.

A conflict has to outlive the pull that found it, so the other version is kept
in `persons.theirsFields`. `lastSeen` moves past the change either way, and a
conflict only reported would never be offered again: the disagreement would
quietly become this device's version winning. For the same reason a row in
conflict is **not pushed**, though it is unsent — pushing would settle it in
this device's favour with nobody asked.

Only people. A family has three mergeable fields and a relationship has none
worth merging — changing which two people an edge joins makes it a different
edge — so both keep step one's behaviour and hold.

**Step 3b — asking. Done.** The disagreement is now put to somebody, field by
field, and the answer is written down.

The questions are not stored. Which fields disagree follows from the three
versions the row already holds, so `Conflicts` re-runs the merge to find them.
A stored list would be a fourth thing to keep in step with the other three, and
could go stale — somebody edits the person again and the question is about a
value that is nobody's any more.

The screen shows both versions **and the one they started from**. Two values
alone do not say which way either side moved; `Cụ Tổ` → `Cụ Tổ (tôi)` against
`Cụ Tổ` → `Cụ Tổ (họ)` is a different question from one side leaving the field
untouched. A field somebody deliberately cleared is labelled as emptied rather
than drawn blank, because a blank row beside a filled one reads as the screen
having failed to load it.

This device's version is selected to begin with, and pressing on through keeps
it. Defaulting to the server would settle disagreements on behalf of anybody who
did not read the screen, in favour of whichever device pushed second.

Settling moves the base on to **what the server held**, not to what was chosen.
This is the part that is easy to get wrong and silent when wrong: the answer
still has to be pushed, and until the server takes it the next pull carries
their version again. With the base at the server's version that pull changes
nothing. With the base at the chosen version the rejected value walks straight
back in, and nobody is asked a second time. There is a test for exactly that
sequence.

Dates are asked about by their pieces — `birthDateIso`, `birthDateApproximate`,
the four lunar components — so adding a lunar reading to a date somebody else
corrected the year of is two independent answers, not one disagreement about a
whole date (§4.4).

**Step 4 — deletion travelling both ways. Done.** Tombstones already went up
and came down; what was missing was what happens when one meets an edit, and it
was missing in a way that undid deletions silently in both directions.

Measured before it was changed, not assumed:

* **They removed somebody this device was editing.** The pull held the row and
  reported it. The row stayed live and unsent, so the *next push* sent the
  person up alive through `save_family_all`, which clears `deleted_at` on
  everything it writes — and the person came back for everybody. The relative
  who removed them saw them return with no explanation.
* **This device removed somebody the server was changing.** `_merge` wrote the
  row through `personToRow`, which also clears `deleted_at`, so a clean merge
  revived them locally. Only a clean merge: where both sides touched the same
  field the conflict branch wrote nothing and the tombstone survived by luck.
  That is why the first test written for it passed with the guard removed.

Neither answer may be taken quietly — applying the tombstone destroys work that
cannot be recovered, ignoring it reverses a deletion nobody was told about — so
both are held as questions and put to somebody (PRODUCT §5.10). `theirsFields`
carries the first direction; the second needs `persons.theirsDeleted`, because a
removal has no fields to keep. Schema v8.

Asked as **one question about the person**, not field by field: there is no
version of somebody both gone and corrected. The answer already selected is
whatever the device holds — alive when the server removed them, a tombstone when
this device's own owner pressed delete — so pressing on through never reverses a
deliberate decision in either direction.

`unsent` is set only where the answer is news to the server: keeping somebody
they removed has to go up and revive them; standing by a removal made here has
to go up and take them away. The other two answers agree with what the server
already holds.

**Relationships are not asked about.** An edge carries no recorded detail, only
which two people it joins, and changing that makes it a different edge, so a
tombstone for one is applied even over an unsent edge. Holding it was the bug:
held forever, and then pushed back as a living edge.

**A whole family now goes for everybody, and the server had a hole in it.**
`delete_family_deep` runs as the caller, and the three tables' policies are not
uniform: `families_update_editor` forbids an editor setting `deleted_at`, but
`persons_update` says only "owner or editor" because removing one person is
ordinary work. An editor reaching that function would therefore have tombstoned
every person and every edge while the family row survived — three hundred people
reduced to a name, no error raised, because a refused UPDATE changes nothing and
reports success. Unreachable while nothing called it; step 4 calls it, so
`20260925000002_family_deletion.sql` raises `insufficient_privilege` first.

The push sends it **instead of the rest** — one call does all three tables, so
anything sent before would be undone by it and anything after left alive in a
family that is gone, and a three-hundred-person gia phả costs one round trip
instead of three hundred.

Its refusal is the **loud** shape, which is worth writing down because step 2's
whole confirmation machinery exists for the silent one. `delete_family_deep`
raises, so the push throws and the caller leaves everything flagged without
reaching the read-back. `test/cloud/push.dart` signs an editor in against a
real Postgres and watches it throw, then signs the owner back in and checks
that nothing was half-done — the raise comes before the first statement, so the
people are untouched too.

The confirmation for this one path also reads **one row, not three hundred**.
The function is a single transaction, so the family carrying the batch's
timestamp means every person and edge in it does; asking row by row would put
some eleven kilobytes of `id=in.(...)` into a request line.

Two defects found by running it on a device rather than in a test, both in the
local migration path and both older than step 4:

* **An interrupted upgrade seals the device.** A phone was found at
  `user_version` 4 whose `families` table already carried v5's `my_role`: a
  step had committed and the version had not. Every launch after that replayed
  from 4 and died on `duplicate column name`, with no way out from inside the
  application. Reachable in the ordinary way — the upgrade runs at launch, and
  swiping the application away or being jetsammed is enough.
* **v6 sealed work it called sent.** Adding `unsent` gave every existing row
  the column default, false. The comment claimed that "cannot lose anything",
  weighing the pull alone: a row marked *sent* is one the push will never
  offer, and before v6 there was no push, so anything edited after the family
  was last uploaded had gone nowhere. Measured, not reasoned — a person added
  on a v5 device two minutes after its last upload, present on that phone and
  on no server, still invisible to synchronisation after the upgrade. It cannot
  recur past v6, so only devices older than it can be carrying sealed work, and
  the repair belongs in a reconciliation against the server: the device cannot
  tell which of its rows were already sent, and the server can.

Neither is fixed here. The migrations are left exactly as they shipped, because
one that has run on a device is history.

Found on the way: `drift_schema_v7.json` was missing the `persons_by_family`
index. It was dumped while the `_MergeColumns` mixin still sat between
`@DataClassName` and the class, and the migration test's loop stopped at v6, so
nothing ever started from v7. Re-dumped, and the loop now runs to v7.

**The order, which was wrong, and which made steps 3 and 3b unreachable.**
Found by asking how to make the question screen appear on two real devices: it
could not be made to appear at all.

`syncFamily` sent before it fetched. `markSent` clears `baseFields` along with
the flag — right on its own terms, because once the server holds this version
there is no earlier one the two sides started from — so the pull behind a push
had two versions where a merge needs three. Unable to tell an edit from an
absence of one, it landed the server's row outright and this device's work went
with it. No merge ran, no disagreement was recorded, nobody was asked. Every
test of steps 3 and 3b called the pull directly, so all of them passed while
the path through the application could not reach them.

The same defect sat at the other boundary once sending moved to *leaving* the
screen: a send with no fetch in front of it writes over whatever arrived while
the screen was open, and the device that wrote that version has already cleared
the flag that would send it again. Both are now fetch-then-send, and
`test/data/sync/sync_order_test.dart` states the requirement where it can be
checked — as a property of the two pieces, since `syncFamily` itself opens with
`isSignedIn` and cannot be reached from a test process.

**When a synchronisation runs.** Opening a family fetches and then sends;
leaving it does the same. Opening was never enough on its own: work written
during a visit sat on the device until somebody opened that family *again*, so
a person added to a family nobody returned to reached nobody. Leaving is the
moment somebody has finished writing, which makes it the moment the writing
should go.

Still to do:

* **Step 5 — synchronisation status**, so it is not a black box: last brought
  down, and what is still waiting to go up. It should carry a synchronise-now
  control: whatever moments are chosen, somebody sometimes wants to press it.

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

* GEDCOM import/export — so a family is never locked into this application.
  The application's own file format is done (M6.5) and does a different job
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