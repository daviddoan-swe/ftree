# Family Tree App — Claude Code Instructions

## 1. Project Overview

This project is a private, cross-platform family tree application for iOS and Android.

The application is intended primarily for families, relatives, and invited friends.

Primary engineering goals:

1. Maintainable architecture
2. Low long-term operational cost
3. Strong privacy and access control
4. Good offline capability
5. Simple infrastructure
6. Cross-platform development from a shared codebase
7. Ability to evolve without unnecessary early complexity

This is not intended to be a social network.

---

## 2. Technology Direction

Initial technology choices:

* Mobile: Flutter / Dart
* State management: Riverpod
* Local persistence: Drift / SQLite
* Cloud backend: Supabase
* Cloud database: PostgreSQL
* Authentication: Supabase Auth
* Media storage: Object storage, initially Supabase Storage
* Source control: Git
* Development environment: VS Code
* AI-assisted development: Claude Code

These choices may be reconsidered if there is a strong technical or economic reason.

Do not replace a technology merely because another technology is more popular.

---

## 3. Architecture Principles

Preferred dependency direction:

Presentation
↓
Application
↓
Domain
↓
Repository abstractions

Infrastructure implements repository abstractions.

Possible infrastructure:

* SQLite / Drift
* Supabase
* Object storage

The domain layer must remain independent from:

* Flutter
* Riverpod
* Drift
* SQLite
* Supabase
* HTTP clients
* platform-specific APIs

Do not introduce additional architectural layers unless they solve an actual problem.

---

## 4. Domain Principles

Core domain concepts initially include:

* Family
* Person
* Relationship

FamilyMembership is an access-control concept, specified in DOMAIN.md §12.1.
It is deliberately NOT part of the local-only domain: it holds a `userId`, and
until authentication exists there is no user id to hold. It arrives with
authentication.

Relationships between people must be modeled independently from Person.

Do NOT place the following fields directly inside Person:

* fatherId
* motherId
* spouseId

The initial relationship types are:

* parent-child
* spouse

The design must not assume that every person has:

* two known parents
* at most two parents
* one spouse
* one marriage
* complete birth information
* complete death information

Nor that a date is complete. Partial dates ("1887", "March 1887", "about 1890")
are part of V1, not a future feature — see DOMAIN.md §4. Storing a plain exact
date loses precision permanently at the moment of data entry.

Validation distinguishes blocking errors from non-blocking warnings
(DOMAIN.md §9). Genealogical records contain implausible but genuine entries;
refusing them makes the application unusable on real data.

The model should allow future support for additional relationship types without requiring a major redesign.

---

## 5. Development Rules

Before implementing a significant task:

1. Read relevant project documentation.
2. Inspect the existing implementation.
3. Understand existing conventions.
4. Propose a plan when architectural decisions are involved.
5. Do not modify files until the requested scope is understood.

During implementation:

* Make small, focused changes.
* Do not modify unrelated files.
* Do not silently change architecture.
* Do not add dependencies without justification.
* Prefer existing project conventions.
* Avoid speculative abstractions.
* Avoid premature optimization.
* Avoid premature generalization.
* Keep domain logic testable without Flutter.

After implementation:

* Run relevant tests.
* Run static analysis.
* Report failures.
* Do not hide warnings or failing tests.
* Summarize important changes.

---

## 6. Testing

Domain rules should have unit tests.

Important relationship logic must be tested, including:

* duplicate relationships
* self relationships
* invalid parent-child cycles
* traversal over a graph that already contains a cycle — it must terminate,
  not hang (cycles can arrive via synchronization; see DOMAIN.md §6.2)
* ancestor/descendant traversal
* spouse relationships, including reversed-argument duplicates
* multiple generations
* half siblings
* partial-date comparison, including indeterminate cases
* warnings are non-blocking; errors are blocking

Infrastructure code should have repository/persistence tests where appropriate.

Do not create tests that only verify implementation details.

---

## 7. Data and Synchronization Principles

The application should eventually support offline use.

The local database should be capable of functioning as a local source of application data.

Cloud synchronization will be introduced after the core local application works correctly.

Do not introduce a complex synchronization architecture before requirements justify it.

Records that may participate in synchronization should generally support appropriate identifiers and modification metadata.

Conflict-resolution strategy should be designed when synchronization requirements become concrete.

Two exceptions are deliberately NOT deferred, because they are schema decisions
whose cost cannot be paid later (DOMAIN.md §15):

* `updatedAt` and nullable `deletedAt` exist on every synchronizable table from
  the persistence milestone. Rows hard-deleted before tombstones exist come back
  on first sync, and the intent cannot be recovered.
* Identifiers are UUID v7, globally unique, and never composite with `familyId`.

`updatedAt` is metadata only. It must never decide which side wins a conflict —
device clocks are not comparable.

---

## 8. Privacy and Security

Family data is private by default.

Cloud access must eventually be protected by explicit authorization rules.

Expected family roles:

* Owner
* Editor
* Viewer

Do not rely only on client-side authorization.

When Supabase is introduced, Row Level Security must be considered part of the security model.

Never:

* commit secrets
* hard-code private API keys
* expose service-role credentials to mobile clients
* disable authorization merely to simplify development

---

## 9. Operational Cost Philosophy

Optimize total cost of ownership rather than trying to force infrastructure cost to zero.

Consider:

* hosting cost
* database cost
* storage cost
* bandwidth
* maintenance effort
* development complexity
* migration cost
* vendor lock-in

Prefer simple managed infrastructure while the application is small.

Do not introduce infrastructure such as the following without demonstrated need:

* Kubernetes
* microservices
* Redis
* message queues
* dedicated search clusters
* custom authentication servers
* multiple backend services

A simpler system with a small monthly cost may be preferable to a zero-cost system that requires significant maintenance.

---

## 10. Media

Photos must not be stored directly inside relational database rows.

Media should use object storage.

Before upload, the client should eventually support appropriate:

* resizing
* compression
* thumbnail generation

Do not assume original-resolution media must always be stored.

Video is outside the initial scope unless explicitly added later.

---

## 11. AI

Claude Code is a development tool for this project.

Claude API is NOT currently part of the production architecture.

Do not introduce AI runtime dependencies unless an actual product feature requires them.

Potential future AI features should remain optional.

---

## 12. Scope Discipline

Always distinguish between:

* required now
* likely required soon
* possible future requirement

Do not implement a possible future requirement unless it materially affects a current architectural decision.

When uncertain, prefer the smallest design that preserves a reasonable migration path.

---

## 13. Git Discipline

Prefer one logical change per commit.

Before considering a task complete:

* inspect git diff
* run tests
* run static analysis
* verify unrelated files were not modified

Do not automatically commit or push unless explicitly requested.

---

## 14. Working With the Developer

The developer is responsible for final architectural decisions.

Claude should:

* challenge questionable assumptions
* identify trade-offs
* point out architectural risks
* suggest simpler alternatives
* distinguish facts from recommendations

Do not agree with an architectural decision merely because it was suggested by the developer.

When there is a meaningful trade-off, explain it before implementation.
