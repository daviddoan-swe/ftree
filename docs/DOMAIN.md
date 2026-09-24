# Family Tree — Domain Model

## 1. Domain Philosophy

The family tree is fundamentally a graph of people and relationships.

It must not be modeled as a rigid binary tree.

A Person is an entity.

A Relationship connects people.

An authenticated User is not automatically the same thing as a Person.

Genealogical data is frequently incomplete, inconsistent, or contradictory.
The domain must be able to represent imperfect data and report problems,
rather than refusing to store anything that is not clean.

---

## 2. Family

A Family represents a managed family-tree dataset.

"Family" here means a **dataset and access boundary**, not a kinship group.
It is the unit of authorization and, later, of synchronization.

Conceptual fields:

* id
* name
* description
* usesLunarCalendar

Timestamps are not domain fields — see §15.2.

`usesLunarCalendar` is a property of the family, not of whoever is looking at
it. A giỗ is a fact about the family: a grandchild abroad, reading the
application in another language, must still see it. Deciding from the viewer's
locale would hide the one feature that matters most to relatives far from home.

It defaults to false, because the domain cannot read a locale and must not try.
The UI seeds it at creation and lets the user change it.

A Family contains:

* Persons
* Relationships
* FamilyMemberships (introduced with authentication — see §12)

A person belongs to a family-tree context.

Cross-family relationships are outside V1.

A family's graph may be **disconnected**. Isolated Persons and unconnected
sub-trees are valid; a Family is not required to form a single tree.

---

## 3. Person

Person represents an individual appearing in a family tree.

Conceptual fields:

* id
* familyId
* displayName
* givenName
* additionalNames
* familyName
* birthFamilyName
* sex
* birthDate
* deathDate
* birthPlace
* deathPlace
* biography
* profileMediaRef

Timestamps are not domain fields — see §15.2.

Most biographical information is optional.

Historical records are frequently incomplete, so the domain must not require information merely because modern applications normally collect it.

---

### 3.1 Name Fields

`displayName` is **stored and user-editable**, and must be non-empty.

* When creating a Person, the UI suggests a default composed from the name parts.
* After creation, `displayName` is independent of the parts.
* Rationale: mononyms, patronymics, religious names, and non-Western name
   ordering cannot be produced reliably by composing three fields. A stored
   display name is the only representation that always renders correctly.
* Accepted trade-off: `displayName` can drift from the parts. The UI should
   offer to re-derive it, but must never overwrite it silently.

`additionalNames` is a single optional free-text field, not a `middleName`.

* Real records carry zero, one, or several additional names.
* A single `middleName` field is wrong in both directions.

`birthFamilyName` is the surname at birth (maiden name).

* This is core genealogical data, not an edge case: it is how a person is
   linked into their parents' branch.
* It is cheap now and expensive later — retrofitting it requires changing the
   entry UI, the local schema, the cloud schema, and the sync payload at once,
   at a point where users no longer remember the missing values.

Alternate spellings and name variants across records are **deferred**.

---

### 3.2 Sex

`sex` records biological sex as used for genealogical records.

Value domain — fixed, and every value is explicit:

* `male`
* `female`
* `unknown`

`unknown` is a first-class value, not an absent one. "We do not know this
person's sex" and "this field has not been filled in" are the same statement in
genealogy, and both must be representable without null.

The vocabulary is `sex`, not `gender`. PRODUCT.md uses the same term.

Nothing in the domain derives parental role from `sex`. A parent-child edge does
not become a "father" or "mother" edge. If the tree UI wants to label or order
parents, that is a presentation decision made in the layout/rendering layer,
using `sex` as a hint, and it must handle `unknown` without collapsing the
layout.

---

### 3.3 Profile Media

`profileMediaRef` is an **opaque nullable string** in V1.

It is not a foreign key. The Media entity does not exist until the media
milestone, and declaring referential integrity against a table that will not
exist for many milestones creates a constraint nobody can satisfy.

---

### 3.4 Person Must Not Contain Relationships

Person must NOT contain:

* fatherId
* motherId
* spouseId
* childIds
* siblingIds

Relationships must be derived from Relationship entities.

This avoids coupling Person to assumptions about family structure.

### 3.5 Living or dead — derived, and one-way

A person **has died** when a death date or a place of death is recorded:

```sh
hasDied = deathDate != null || deathPlace != null
```

Either field is somebody writing down that this person died. Neither is a
record that says nothing on the subject.

**Derived rather than stored.** No column can be wrong about it, no migration
is needed, and nothing has to be back-filled: the place of death was always
the second half of the answer, and only the date was being read.

**One-way, deliberately.** It proves a death; it never proves a life.
`!hasDied` means *nothing was recorded* — which for most of a gia phả is the
truth. Nothing may present that as "living"; where the distinction matters,
say "no death recorded".

Consequences elsewhere:

* An age is the span to the death date. Where a death is recorded without a
   date, there is no age to show — counting to today would age a dead man.
* A person is drawn back in grey once `hasDied`.
* The interface may not let somebody assert a death it cannot store. The
   person form's switch requires a date or a place before it will save, because
   an empty claim would vanish the moment it was written.

**A death with no evidence cannot be recorded — decided, and left.** A person
the family knows has died, but whose date and place nobody remembers, cannot be
marked dead at all, and in a gia phả reaching back three centuries that is
common. They are shown the same as somebody nothing is known about.

The alternative is to store the fact separately from its evidence: a `hasDied`
column, plus the rule that a recorded date or place still implies death on its
own, so the flag could only ever *add* to the answer and never subtract from it.
That keeps §3.5's one-way property intact.

It is not built. The present rule cannot be wrong about anything, because it
derives the answer from fields that are already there; a stored flag introduces
a way for the record to contradict itself, in exchange for a grey box. The
reversal is a plain migration rather than one of the unrecoverable kind (§18),
so the cost of waiting is the gap itself and nothing more.

The privacy question this feeds — hiding living people from Viewers — is a
separate matter and needs per-person filtering (ARCHITECTURE §11.1).

---

## 4. Dates

Genealogical dates are routinely partial.

Common cases:

* exact date known
* month and year known
* only year known
* approximate ("about 1887")
* unknown

### 4.1 Representation — decided, not deferred

A genealogical date is:

```kt
GenealogicalDate {
  year           : int        // Gregorian; required when a date is present
  month          : int?       // 1-12, null if unknown
  day            : int?       // 1-31, null if unknown
  isApproximate  : bool       // "about", "circa"
  lunar          : LunarDate? // display and provenance only — see §4.4
}
```

Precision is **derived** from which components are present (day → month → year).
There is no separate precision enum, so precision cannot contradict the value.

An entirely unknown date is `null`.

Suggested storage: one TEXT column in ISO-prefix form (`YYYY`, `YYYY-MM`,
`YYYY-MM-DD`) plus one boolean column. ISO-prefix text sorts correctly
lexicographically and survives both SQLite and PostgreSQL unchanged.

### 4.2 Why this is not deferrable

Storing a plain nullable exact date destroys information permanently. A record
known only as "1887" is entered as `1887-01-01`, and after any later migration
it is indistinguishable from an actual 1 January. The loss is user-entered,
irreversible, and replicated to every device and to the cloud.

The cost of doing this at the start is roughly a day. The cost of not doing it
cannot be recovered by any later schema change.

This also determines whether GEDCOM import is ever viable, since partial and
qualified dates are precisely what GEDCOM carries.

### 4.3 Comparison semantics

Comparison of partial dates is a **partial order**.

`1887` and `1887-03-15` cannot be ordered — the first may be before, after, or
equal to the second.

Rule: date-based checks (§9) must only produce a warning when the ranges are
**disjoint**. Overlapping or indeterminate comparisons produce nothing. This
prevents partial data from generating a permanent wall of false warnings.

BC/BCE dates and date ranges ("between 1880 and 1890") are out of scope for V1.

### 4.4 Lunar calendar

Vietnamese genealogical sources are written in the lunar calendar, and giỗ —
the death anniversary — is observed on the lunar date. Modern records use the
Gregorian calendar. A single family tree will contain both.

**The Gregorian date is mandatory and is the only basis for comparison.**

```kt
LunarDate {
  year         : int
  month        : int?   // 1-12
  day          : int?   // 1-30 — a lunar month has 29 or 30 days
  isLeapMonth  : bool   // tháng nhuận
}
```

The user converts to Gregorian when entering data. The lunar date is then
recorded alongside, optional, and used only for display and provenance.

Rules:

* Ordering, intervals, and every warning in §9.2 read the Gregorian value
   alone. A lunar annotation can never change whether a warning fires.
* `Family.usesLunarCalendar` decides what is *offered and shown*, never what is
   stored. Turning it off on a family that already has lunar readings hides
   them; it must not erase them. They record what the source document said, and
   a display setting has no business destroying that.
* Nothing verifies that the two agree. That requires the conversion described
   below; once it exists, a mismatch becomes a good warning candidate.
* Day is bounded at 30 rather than resolved exactly, because knowing whether a
   given lunar month has 29 or 30 days requires the astronomical calculation.

Why the lunar value is stored rather than derived: the conversion does not
exist yet, so without storage there is no way to show a lunar date or compute
giỗ at all. Storage also preserves what the source document said, not merely
the user's hand conversion of it, which may be wrong.

Lunar↔Gregorian conversion is deferred. When it is built it must use the
**Vietnamese** lunar calendar: it is based on UTC+7 rather than the UTC+8 of
the Chinese calendar, so the two differ by a day for some dates. A Chinese
implementation cannot be adopted without verification.

Can-chi year names (Đinh Hợi, Giáp Tý) are derivable from the lunar year and
are a display concern, not stored. Note for data entry: can-chi repeats every
60 years, so a source giving only the name needs a century from the user.

---

## 5. Relationship

Relationship represents a genealogical relationship between people.

Initial relationship types:

* parentChild
* spouse

Conceptual fields:

* id
* familyId
* type
* personAId
* personBId

Timestamps are not domain fields — see §15.2.

Additional metadata may be introduced only when required.

---

### 5.1 Column Semantics Depend on Type

The same two columns carry different meaning per type. This must be stated
explicitly, because it is not visible from the schema and is a likely source of
defects.

| type          | personAId       | personBId       | ordering                  |
| ------------- | --------------- | --------------- | ------------------------- |
| `parentChild` | the parent      | the child       | directional, meaningful   |
| `spouse`      | lower id        | higher id       | canonical, **no meaning** |

For symmetric types, the two ids are sorted before storage (lexicographic
comparison of the id strings). This is what makes symmetry enforceable: `(B, A)`
becomes `(A, B)` on the way in and collides with the existing row.

Uniqueness constraint:

```sql
UNIQUE (familyId, type, personAId, personBId)
```

Without canonical ordering, this constraint does not prevent duplicate spouse
records — only the ordering makes it work.

### 5.2 familyId Consistency

`Relationship.familyId` is denormalized deliberately: it lets server-side
authorization filter edges without a join.

Because it is denormalized, it needs a rule:

> A Relationship's `familyId` must equal the `familyId` of **both** Persons it
> connects.

Enforced on write.

---

## 6. Parent-Child Relationship

Parent-child is directional.

Example:

A → B

means:

A is a parent of B.

It should not require the application to know whether A is the biological father or mother merely to represent parenthood.

Future versions may introduce relationship attributes such as:

* biological
* adoptive
* step-parent
* guardian

These distinctions should not be required for V1.

When they are introduced, uniqueness stays on the **pair**, with the
classification as a mutable attribute. A step-parent who later adopts is a
change of status, not a second edge.

---

### 6.1 Parent-Child Rules

The system must reject:

#### Self-parent

A cannot be a parent of A.

#### Duplicate relationship

If A → B already exists, the same parent-child relationship must not be created
again.

#### Ancestry cycles

If A → B and B → C exist, then C → A must be rejected.

---

### 6.2 Acyclicity Is Enforced, Detected, and Repaired — Not Assumed

A valid genealogical ancestry graph is acyclic with respect to parent-child
edges. However, **acyclicity cannot be guaranteed** in a system that permits
offline editing on multiple devices.

Two devices editing offline can each add an individually valid edge that
together form a cycle. Neither device can detect it, because neither has the
other's edge. The cycle appears at merge time.

Therefore acyclicity is treated in three parts:

**Write path — enforce.**
Adding A → B is rejected if A is already a descendant of B. This is a
graph-level check (§13), not an entity-level one.

**Read path — tolerate.**
Every traversal maintains a visited set and terminates on revisit. This is part
of the contract of `ancestors`, `descendants`, and any layout traversal — not
defensive coding, and not optional. Without it, a single synced cycle hangs or
crashes the tree screen.

**Merge path — detect and report.**
Synchronization must be able to detect a cycle introduced by merging and surface
it to the user for resolution. It must never silently delete an edge to restore
acyclicity: the user's data is more authoritative than the invariant.

---

## 7. Spouse Relationship

Spouse is conceptually symmetric.

If A spouse B, then B spouse A represents the same relationship.

A single record represents both directions. Symmetry is enforced by the
canonical ordering in §5.1, not by storing two rows.

---

### 7.1 Spouse Rules

Reject:

* A spouse A
* a second A–B spouse record in either column order

A person may have multiple spouse relationships over their lifetime.

The domain must therefore not enforce one-spouse-per-person globally.

Relationship dates/status may be added later when product requirements become
concrete.

Note for later: pair-uniqueness is a **V1 simplification**, not a permanent
truth. Divorce and remarriage to the same person requires two records once dates
and status exist. Nothing in the code or the UI may treat the A–B pair as a
stable identity or use it as a key.

---

## 8. Sibling Relationship

Sibling is derived, not stored.

For example:

A → C
A → D

allows C and D to be identified as siblings through their shared parent.

A dedicated sibling relationship is not persisted.

---

### 8.1 Sibling Contract

The layout engine consumes this, so the contract is fixed here rather than left
to the implementation.

`siblings(p)` returns people who share **at least one** parent with `p`.

* `p` is **excluded** from its own sibling list.
* Results are **deduplicated**. Sharing both parents yields one entry, not two.
* Each result carries `sharedParentCount`, so full siblings (2) and half
   siblings (1) are distinguishable by the caller without a second query.
* Step-siblings (children of a parent's spouse, with no shared parent) are
   **not** included.
* With only one recorded parent, full and half siblings are indistinguishable.
   This is a limitation of the data, not a defect.
* Results come back eldest first as far as the recorded birth dates say, by the
   rule in §13.3.

---

## 9. Validation: Errors and Warnings

Genealogical source data is messy. A model with only accept/reject will reject
correctly transcribed records and become unusable on real family documents.

Validation therefore returns a result, not a boolean:

```scala
ValidationSeverity = error | warning

IssueCode          // a stable identifier, each declaring its own severity
  familyNameEmpty(error)
  deathBeforeBirth(warning)
  …

ValidationIssue {
  code            : IssueCode
  involvedIds     : person/relationship ids
  severity        : read through code
}

ValidationResult {
  issues          : list of ValidationIssue
  hasErrors       : any issue whose severity is error
}
```

Severity belongs to the **code**, not to the individual issue. Carried per
issue, nothing would stop the same condition being raised as an error at one
call site and a warning at another. Attaching it to the code makes that
unrepresentable. A condition that genuinely needs both severities should become
two codes with two names.

Issues carry no human-readable message. Those belong to the presentation layer:
the domain must run without Flutter, and messages need localisation.

**Errors** block the write. They represent structurally impossible data.

**Warnings** do not block. They are surfaced to the user, who may confirm and
proceed.

### 9.1 Errors (blocking)

* Relationship endpoints are the same person
* Duplicate relationship (same type, same pair)
* Parent-child edge that closes an ancestry cycle
* Relationship references a Person that does not exist
* Relationship `familyId` differs from either Person's `familyId`
* Persons in a relationship belong to different Families
* `Person.displayName` empty
* `Family.name` empty

### 9.2 Warnings (non-blocking, user may override)

* Death date before birth date
* Parent born after child
* Child born more than one year after the parent's death
   (posthumous birth is real — this is a warning, never an error)
* Implausible parental age (below ~12 or above ~70 at a child's birth)
* Lifespan beyond ~120 years
* Spouses who are also ancestor/descendant of one another
   (cousin marriage is historically common; parent-child marriage is almost
   always a data-entry error — but it is the user's data)

Every warning is subject to the partial-date rule in §4.3: no warning is
produced when the comparison is indeterminate.

### 9.3 Why this must exist at the start

Today a validation call returns `true`/`false`. Changing it later to return a
severity-bearing result changes the signature of every caller, from domain
through application to UI. At the first milestone that is a handful of call
sites. Six milestones later it is not.

V1 does not persist warning overrides — a confirmed warning may reappear when
the record is next edited. Accepted for V1; revisit if it proves annoying.

---

## 10. Ancestors and Descendants

Ancestors are derived by traversing parent-child relationships upward.

Descendants are derived by traversing them downward.

Using:

A → B
B → C
C → D

* Ancestors of D: C, B, A
* Descendants of A: B, C, D

Neither is stored.

Both traversals maintain a visited set and terminate on revisit (§6.2).

---

## 11. Generation

Generation is derived from graph context.

It is not stored on Person.

The tree-layout system is responsible for translating genealogical relationships
into display positions.

### 11.1 Đời is counted from the thuỷ tổ, not from what is on screen

The layout numbers its generations from whatever the chart is drawn from,
because that is what it needs in order to place boxes. **What is shown to the
reader is not that number.**

In a gia phả, đời thứ năm is a fact about a person. Redraw the chart from
somebody's son and the layout calls him generation zero; calling him Đời 1 on
screen would be telling the reader something false about their own family. So
the number displayed is counted from the family's founding ancestor and does
not move when the view does.

**The founding ancestor is whoever has no recorded parents and the most
descendants** (`FamilyGraph.foundingAncestor`). Both halves are needed, and the
first half alone is the trap: every spouse who married in has no parents on
record either. In a three-hundred-person family that is eighty-six people, and
picking the first of them would count the family from somebody's wife. Nor is
descendant count enough by itself — the founder's eldest son may carry nearly
as many, and a gia phả does not count from him.

Counting this way reaches everybody, including those who married in: a spouse
takes their partner's generation rather than one of their own.

Two limits, recorded rather than solved. A family holding several unconnected
lines gets the largest of them counted and the rest left unnumbered. A cycle
severe enough to leave nobody parentless has no founder at all, and the screen
falls back to the first person it holds (§6.2).

---

## 12. User vs Person

This distinction is fundamental.

**User** represents someone authenticated into the application.

**Person** represents someone recorded in a family tree.

Examples:

A deceased ancestor can be a Person but cannot be a User.

A researcher or trusted family friend can be a User with Viewer permission
without necessarily being a Person in the tree.

Future functionality may optionally link a User to a Person, but they must remain
separate entities.

---

### 12.1 FamilyMembership — deferred to the authentication milestone

FamilyMembership represents authorization for an authenticated User to access a
Family.

Conceptual fields:

* id
* familyId
* userId
* role — `owner` | `editor` | `viewer`
* createdAt
* updatedAt

**It is not implemented in the local-only milestones.** It holds a `userId`, and
until authentication exists there is no user id to hold. Building it earlier
produces permission-checking code written against an imaginary current user,
which is then rewritten once the real auth model is known.

The concept stays documented here; the entity arrives with authentication.

Rules to implement when it does — these become server-side authorization
policies, where an error is a security hole rather than a UI defect:

* `UNIQUE (familyId, userId)` — one membership row per user per family
* A Family must always have at least one `owner`
* The last remaining `owner` cannot be demoted or removed
* The creator of a Family becomes its `owner`

FamilyMembership is an access-control concept. It is separate from Person.

---

## 13. Family Graph

The domain exposes a graph service capable of answering:

* parents of Person
* children of Person
* spouses of Person
* siblings of Person
* ancestors of Person
* descendants of Person

Conceptually:

Persons + Relationships
↓
FamilyGraph
↓
Traversal/query operations

FamilyGraph must remain independent of Flutter rendering.

### 13.1 Relationship Validation Belongs to the Graph

Relationship validation is a **graph-level service operation**, not a constructor
check on `Relationship`.

Cycle detection requires knowledge of the whole graph, so a `Relationship`
cannot validate itself. Adding an edge goes through the graph, not through the
entity.

### 13.2 The Graph Is Built In Memory — decided

A Family's Persons and Relationships are loaded into memory in full and the
graph is built there.

At the target scale — thousands of people (PRODUCT §8) — this is a few megabytes
and is not a concern on a mobile device.

Consequences, all of them simplifying:

* Validation, traversal, and layout all operate on in-memory structures
* No query optimization is required in V1
* Every database question is deferred until there are real measurements

If a family ever grows past what fits comfortably, this is revisited with data.

### 13.3 Children come back eldest first, as far as the dates say

A gia phả is read from Con Cả down. Which row the transcriber happened to fill
in first says nothing about who was born first, so `children(p)` — and
`siblings(p)`, which is built from it — order by recorded birth date.

The death date takes no part. Neither does whether anyone is living: ordering
must not change as people die.

**Only where there is evidence.** Comparing partial dates gives *before*,
*after*, or *cannot tell* (§4.3), and most people in an old record have no
birth date at all. So a person moves ahead of another only when
`definitelyBefore` says so, and stops at the first one they cannot pass. Two
consequences, both deliberate:

* Children with no recorded birth are not moved, and nobody is moved past
   them. Passing them would be a reordering with nothing behind it.
* Where nothing is known, the order the relationships were created survives —
   which for a transcription is usually the order of the book being copied.

The result can be incomplete; it is never wrong. That is the same bargain §4.3
makes when it keeps a warning silent rather than guess.

**This is not `sort`.** A comparator answering "equal" to *cannot tell* is not
transitive — 1900, an unrecorded date, and 1800 form a cycle — and Dart's
`List.sort` is not stable either, so it would return an arbitrary arrangement.
The ordering is an insertion pass instead, quadratic in a number that is under
twenty.

Computed once when the graph is built, because the graph is immutable (§13.2)
and `children` is asked repeatedly: once per parent by `siblings`, once per
node by `descendants`, and again by the layout.

An explicit sibling-order field on the relationship would record what a
document states when no dates exist at all. It is not in V1: it costs a schema
column and a migration, and is only worth it if this proves insufficient on
real data.

---

## 14. Identity

Entities use identifiers that work across local and cloud environments and can
be generated offline without a server round trip.

**UUID v7**, not v4.

v7 is time-ordered, so identifiers created near each other sort near each other.
This materially improves index locality in both SQLite and PostgreSQL, and it is
still fully client-generatable. Choosing it now costs a library selection;
changing it later is a primary-key migration across every table on every
installed device.

### 14.1 Ids Are Globally Unique

`Person.id` is globally unique on its own.

**No composite `(familyId, personId)` keys anywhere.** `familyId` is a label on
a globally identified row, never part of its identity.

Reason: two relatives independently building trees will both record the same
ancestor. Deciding "these two records are the same human" is the hardest data
problem in genealogy software, and V1 does not attempt it — but a composite key
makes it structurally impossible later, whereas global ids leave merge as a
matter of relabelling.

---

## 15. Deletion

### 15.1 Deletion is soft; the cascade is a safety net

Deleting anything writes a tombstone. Nothing in normal operation removes a row.

Orphaned edges — relationships pointing at a person who is gone — are the most
common corruption for this schema shape, and they surface as crashes or blank
nodes in the tree. Two separate mechanisms guard against them, and it matters
which does the work:

**The repository is the mechanism.** Deleting a Person sets `deletedAt` on that
Person *and on every relationship naming them*, in one transaction. Without the
second half, the edges stay live: reads would skip them as unresolvable, but
synchronization would still carry them to other devices as real relationships
pointing at somebody who is not there.

**`ON DELETE CASCADE` on both foreign keys is the safety net.** It only fires on
a physical delete, and soft deletion never performs one — so in normal operation
it never runs at all. It exists for a purge, a migration, or a defect that
removes a row outright.

An earlier version of this section named the cascade as the mechanism, which
cannot be true alongside §15.2: a row that is never physically deleted never
triggers one.

### 15.2 Tombstones and change metadata — decided, at the persistence milestone

Every synchronizable table carries:

* `updatedAt`
* `deletedAt` — nullable; a set value means deleted

Deletion sets `deletedAt`. Repositories filter deleted rows on read, and stamp
`updatedAt` at the same time — a tombstone that left `updatedAt` behind would
look older than the row it replaces, and synchronization orders by change.

**The domain entities do not carry these fields.** This is a persistence-layer
concern and the domain stays clean.

Why this cannot wait for the synchronization milestone: rows hard-deleted before
tombstones exist leave no record of the deletion. On first sync, any peer still
holding the row re-proposes it, and it returns. To the user this reads as
"deleted relatives keep coming back", and there is no way to recover the intent
after the fact.

**A write clears the tombstone it lands on.** Writing a row asserts that it
exists; a tombstone asserts that it does not. Both cannot hold, so the write
wins and `deletedAt` is set back to null.

This is not a detail of the storage layer. Found the other way round — by a
row-level write that left the mark in place — it reads as data vanishing: an
import into a deleted family wrote three hundred people, reported success, and
showed none of them, because reads filter on exactly that column. The rows were
in the table and invisible, with nothing to say why.

The rule belongs to every write, not only to bulk ones. A person created in the
application always gets a fresh id, so nothing reached it until a file carried
an id the device had already tombstoned.

When synchronization arrives this needs stating again from the other side: a
peer proposing a row it has *deleted* is sending a tombstone, not a write, and
the two paths must stay distinguishable.

### 15.3 updatedAt Is Metadata, Not a Conflict Resolver

`updatedAt` records when a row changed. It must **not** be used to decide which
side wins a conflict.

Device wall-clocks are not comparable — they drift, and users change them. A
device with a wrong date would win every conflict permanently.

Conflict ordering will use a server-assigned sequence or a hybrid logical clock,
designed when synchronization requirements are concrete. **The column arrives
at M7**, unused, because adding a monotonic column later means back-filling
every row on every installed device.

**Open, for M9: merging two edits of one person.** Two editors change different
fields — one the birth date, one the name — and the merge should take both.
Nothing today does this: the file import skips a person whose id is already
here, and `savePerson` replaces the whole row.

It needs three versions rather than two. Given only the two edited copies there
is no way to tell whether one side changed a field or the other side changed it
back; both stories produce the same pair. So it needs the common ancestor as
well — a stored base, per-field stamps, or a CRDT register per field — and all
three need an ordering, which is what the sequence column is for.

Where both editors changed the *same* field, nothing may choose for them. One
of the two is the truth about somebody's ancestor. Both are kept and the reader
decides, by the rule §6.2 already states for cycles: the user's data is more
authoritative than the invariant.

---

## 16. Tree Layout

Genealogical domain relationships and visual tree layout are separate concerns.

The domain provides:

* people
* relationships
* graph traversal

The layout engine determines:

* generation
* node positions
* spouse grouping
* branch placement
* coordinates

The Flutter UI renders those results.

Therefore:

Domain Graph
↓
Tree Layout
↓
Flutter Renderer

Tree-layout concerns must not leak into Person or Relationship.

---

## 17. Domain Invariants

### 17.1 Hard invariants

1. Person belongs to a valid Family.
2. `Person.displayName` is non-empty.
3. `Family.name` is non-empty.
4. Relationship connects two Persons that exist.
5. The two endpoints of a Relationship are always distinct Persons.
6. Related Persons belong to the same Family in V1.
7. A Relationship's `familyId` equals the `familyId` of both endpoints.
8. Duplicate relationships are rejected — `UNIQUE (familyId, type, personAId, personBId)`.
9. Symmetric relationship types are stored with canonically ordered ids.
10. Parent-child relationships must not create ancestry cycles **on the write path**;
   cycles arriving via merge are detected and reported, not assumed impossible.
11. All graph traversals terminate in the presence of a cycle.
12. Relationships are represented independently from Person.
13. Authentication identity is separate from genealogical identity.

### 17.2 Advisory warnings

Non-blocking, user-overridable. Enumerated in §9.2.

### 17.3 Explicit non-invariants

Stated affirmatively so that no future schema or validation change introduces
them by accident:

* A Person may have **any number** of parents. There is no maximum of two.
   Biological plus adoptive parents exceed two routinely.
* A Person is not required to have any parents, children, or spouses.
* A Person may have any number of spouse relationships.
* No date field is required, and no date is required to be complete.
* A Person need not correspond to any User.
* A Family's graph need not be connected.

These rules are protected by domain logic and unit tests.

---

## 18. V1 Decisions Locked

Recorded so they are not relitigated, and so their cost of reversal is visible.

| Decision                                             | Section | Cost if changed later                                |
| ---------------------------------------------------- | ------- | ---------------------------------------------------- |
| Partial dates (`year` + optional month/day + approx)  | §4      | Unrecoverable — precision is lost at data entry       |
| Lunar date stored alongside a mandatory Gregorian one | §4.4    | Unrecoverable — the source's lunar reading is lost    |
| `updatedAt` + `deletedAt` on all syncable tables      | §15.2   | Deleted records resurrect on first sync; no recovery  |
| Acyclicity: enforce / detect / repair, never assume   | §6.2    | Hangs and crashes on synced data                      |
| Validation returns severities, not a boolean          | §9      | Signature change across every layer                   |
| UUID v7                                               | §14     | Primary-key migration on every device                 |
| Globally unique ids; no composite `(familyId, id)`    | §14.1   | Family merge becomes structurally impossible          |
| Canonical id ordering + unique index on relationships | §5.1    | Coordinated migration across all devices and Postgres |
| Fixed `sex` value domain with first-class `unknown`   | §3.2    | Migration with no correct answer for existing rows    |
| `birthFamilyName` present from the start              | §3.1    | Values no longer known by the time it is added        |
| FamilyGraph built in memory per family                | §13.2   | Low — revisit with measurements                       |
| Death derived only; no stored `hasDied` flag          | §3.5    | Low — one column and a migration                      |
