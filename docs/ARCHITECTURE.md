# Family Tree — Architecture

## 1. Architecture Goals

The architecture should optimize for:

* maintainability
* low total operating cost
* cross-platform development
* offline capability
* privacy
* testability
* gradual evolution

Avoid infrastructure or abstraction that is not justified by current requirements.

---

# 2. High-Level Architecture

Initial target:

Flutter Application
↓
Presentation
↓
Application
↓
Domain
↓
Repository Abstractions
↓
Infrastructure

Infrastructure may include:

Local:
Drift / SQLite

Remote:
Supabase / PostgreSQL

Media:
Object Storage

---

# 3. Client

Primary client technology:

Flutter / Dart

Targets:

* iOS
* Android

Flutter provides a shared application and UI codebase while still allowing platform-specific integrations where necessary.

---

# 4. Presentation Layer

Responsibilities:

* screens
* widgets
* user interaction
* navigation
* presentation state
* family-tree rendering

Proposed state-management technology:

Riverpod

Presentation must not directly contain database queries or cloud-access logic.

---

# 5. Application Layer

Responsibilities may include:

* coordinating user actions
* orchestrating repositories
* application workflows
* synchronization orchestration later
* permission-aware operations, once permissions exist

Do not create a separate class for every trivial action merely to satisfy a theoretical architecture pattern.

Concretely for the local milestones: **Riverpod notifiers are the application
layer.** Do not introduce separate application classes until an operation
genuinely needs to orchestrate more than one repository or span a transaction.
With roughly nine V1 use cases, a dedicated application class per action
produces pass-through code and nothing else.

Permission-aware operations are deferred with FamilyMembership. Writing
permission checks against a current user that does not yet exist means writing
them twice.

---

# 6. Domain Layer

Contains:

* Family
* Person
* Relationship
* domain rules
* FamilyGraph
* domain validation (errors and warnings — see DOMAIN.md §9)

FamilyMembership is documented in DOMAIN.md §12.1 but is **not** part of the
local-only domain. It holds a `userId` and arrives with authentication.

The FamilyGraph for a family is built in memory in full (DOMAIN.md §13.2).
Relationship validation is a graph-level operation, not an entity constructor
check (DOMAIN.md §13.1).

Domain must be pure Dart.

It must not depend on:

* Flutter
* Riverpod
* Drift
* Supabase
* platform APIs

---

# 7. Repository Boundary

Application/domain code should depend on repository abstractions rather than infrastructure implementations.

Exact interfaces must emerge from actual use cases rather than being designed
exhaustively in advance. Naming three interfaces up front and anticipating three
implementation flavours for each would produce nine classes for a problem that
does not exist yet — precisely what §21 exists to prevent.

**For the local milestones: one repository.**

Through the local-only phase, every operation is either "load this family's
persons and relationships" or "write one row". A single `FamilyRepository`
covers it. Split it when a caller needs something the single interface makes
awkward, not before.

Remote and synchronization-aware implementations are introduced in their own
milestones, against interfaces that by then have real callers.

The repository layer — not the domain — owns `updatedAt` / `deletedAt` and
filters soft-deleted rows on read (DOMAIN.md §15.2).

---

# 8. Local Persistence

Proposed technology:

Drift + SQLite

Reasons:

* offline support
* relational data
* local query capability
* migrations
* Flutter/Dart ecosystem support

Initial development should prioritize local persistence before cloud synchronization.

The initial schema must already include the decisions that are expensive to
reverse once real data exists (see DOMAIN.md §18):

* partial dates stored as ISO-prefix text plus an `isApproximate` flag
* `updatedAt` and nullable `deletedAt` on every synchronizable table
* `ON DELETE CASCADE` from relationships to both person endpoints
* `UNIQUE (familyId, type, personAId, personBId)` on relationships, with
  canonically ordered ids for symmetric types
* UUID v7 primary keys, globally unique, never composite with `familyId`

None of these require synchronization to be designed. All of them are painful or
impossible to add after users have entered data.

---

# 9. Cloud

Proposed initial managed backend:

Supabase

Expected services:

* PostgreSQL
* Authentication
* Storage
* Row Level Security

The application should avoid unnecessary dependency on proprietary backend behavior where a standard PostgreSQL model is sufficient.

---

# 10. Authentication

Authentication will be introduced during the cloud phase.

Authentication identity must remain separate from Person.

Conceptually:

Supabase User
↓
FamilyMembership
↓
Family

Optional future association:

User ↔ Person

must not be required by the initial architecture.

---

# 11. Authorization

Authorization is family-based.

Initial roles:

* Owner
* Editor
* Viewer

Authorization must eventually be enforced server-side.

When Supabase is introduced, PostgreSQL Row Level Security should protect family data.

Client-side checks are for UX and must not be considered the security boundary.

Membership rules that become RLS policies — at least one owner per family, the
last owner cannot be removed, one membership row per user per family — are
specified in DOMAIN.md §12.1. An error there is a security hole, not a UI defect.

### 11.1 Known limitation: family-level granularity

Family is currently the only authorization unit. The near-certain next
requirement is **hiding living people from Viewers**, which family-level RLS
cannot express.

Nothing structural is built for this now, but two cheap hedges apply:

* The synchronization contract must be able to transmit a **subset** of a
  family, not "the whole family". A protocol that assumes whole-family payloads
  has to be rewritten to support per-person filtering.
* The client must not treat a received payload as authoritatively complete. In
  particular, "the server did not send Person X" must never be interpreted as
  "X was deleted".

Related open product question: `deathDate == null` is **not** a reliable
indicator that a person is living — many deceased ancestors have no recorded
death date. A deliberate living/deceased decision is needed before cloud
sharing, not before the local milestones.

---

# 12. Synchronization

Synchronization is intentionally deferred until local functionality is stable.

Desired eventual behavior:

Local SQLite
↕
Synchronization
↕
PostgreSQL

The system should favor delta synchronization over repeatedly downloading complete family datasets when practical.

The exact conflict-resolution model should not be implemented until editing and sharing requirements are better understood.

Three constraints are already known and constrain the eventual design:

**Ordering does not come from device clocks.** `updatedAt` is metadata. Conflict
ordering uses a server-assigned sequence or a hybrid logical clock. A device with
a wrong system date must not be able to win every conflict (DOMAIN.md §15.3).

**Deletions travel as tombstones.** This is why `deletedAt` exists from the
persistence milestone rather than this one — rows hard-deleted before tombstones
existed are re-proposed by any peer that still holds them (DOMAIN.md §15.2).

**Merging can produce ancestry cycles.** Two devices editing offline can each add
a valid parent-child edge that together form a cycle. Sync must detect and report
this for user resolution, and must never silently drop an edge to restore
acyclicity (DOMAIN.md §6.2).

---

# 13. Media Architecture

Media should be stored separately from relational records.

Conceptually:

Person
↓
Media metadata
↓
Object Storage

The client should eventually generate appropriate image sizes before or during upload.

Possible variants:

* thumbnail
* display-size image
* optional original

Storage architecture may be changed later if media cost becomes significant.

---

# 14. Tree Architecture

Tree rendering should be separated into stages:

Persons + Relationships
↓
FamilyGraph
↓
TreeLayoutEngine
↓
Layout result
↓
Flutter Renderer

FamilyGraph answers genealogical questions.

TreeLayoutEngine solves visual positioning.

Flutter renders the result.

This separation allows graph and layout logic to be unit-tested independently of Flutter UI.

### 14.1 Build a throwaway renderer before hardening the layout engine

The separation above is correct. The build order needs care.

Unit tests can assert that a node is at `(100, 50)`. They cannot assert that
nodes do not overlap, that spouses read as a pair, that connector lines do not
cross, or that the result looks like a family tree. A layout engine developed
with nothing to look at will pass its tests and still be wrong.

Therefore: produce a crude renderer — boxes and straight lines, no styling — as
soon as the layout engine emits its first coordinates, and develop the engine
against it. The engine stays free of Flutter; the renderer exists to close the
feedback loop.

---

# 15. Proposed Project Structure

Initial direction:

lib/
├── app/
├── core/
├── domain/
│   ├── family/
│   ├── person/
│   └── relationship/
├── features/
│   ├── family/
│   ├── person/
│   └── tree/
└── data/
├── database/
└── repositories/

test/
docs/

This structure is provisional.

Do not create directories or abstractions until actual code requires them.

---

# 16. Dependency Direction

Desired dependency direction:

Presentation
↓
Application
↓
Domain

Infrastructure
↓
Domain/repository contracts

Domain must not point outward toward infrastructure.

---

# 17. Backend Philosophy

Do not initially introduce a custom application server unless required.

Preferred initial cloud architecture:

Flutter
↓
Supabase APIs
↓
PostgreSQL

Potential server/edge functions may be introduced for operations that:

* require trusted credentials
* require server-side processing
* cannot safely execute on the client
* materially simplify the system

---

# 18. Cost Strategy

Optimize total cost of ownership.

Primary cost drivers to monitor:

* database usage
* media storage
* media bandwidth
* authentication usage
* backend execution
* developer maintenance time

For this application, media is expected to become a larger infrastructure cost than genealogical text/relationship data.

Optimize media before introducing complex database optimizations.

---

# 19. Scalability

Initial target:

small to medium private family groups.

The architecture should comfortably support family trees containing hundreds or thousands of people.

Do not design for millions of concurrent users unless actual usage requires it.

Prefer migration paths over premature scale infrastructure.

---

# 20. Observability

Initial development requires only practical diagnostics:

* structured application logging where useful
* Flutter errors
* synchronization diagnostics when sync is introduced

Production monitoring should be introduced proportionally to actual operational requirements.

---

# 21. Architectural Decision Rule

Before introducing new infrastructure or abstraction, ask:

1. What current problem does this solve?
2. Can the existing architecture solve it adequately?
3. What maintenance cost does it introduce?
4. What operating cost does it introduce?
5. How difficult is it to remove later?

If the problem is hypothetical, prefer not to introduce the complexity yet.
