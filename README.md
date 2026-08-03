# Ftree

A private, offline-capable family tree application for iOS and Android.

Ftree lets a family record and explore its history across multiple generations,
with the data staying under the family's own control. It is not a social
network and has no public discovery features.

## Status

Pre-release. See [docs/ROADMAP.md](docs/ROADMAP.md) for the current milestone.

The local-only version comes first: domain model, family graph, local
persistence, and tree rendering. Cloud sync and sharing follow once the local
application is stable.

## Documentation

| Document | Contents |
| --- | --- |
| [docs/PRODUCT.md](docs/PRODUCT.md) | What the product is, who it's for, V1 scope |
| [docs/DOMAIN.md](docs/DOMAIN.md) | Domain model, invariants, and the decisions locked for V1 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layering, persistence, cloud, and cost strategy |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones M0–M12 |
| [CLAUDE.md](CLAUDE.md) | Working agreement for AI-assisted development |

Read DOMAIN.md §18 before changing the schema — it lists the decisions that are
expensive or impossible to reverse once real data exists.

## Technology

| Layer | Choice |
| --- | --- |
| Client | Flutter / Dart |
| State management | Riverpod |
| Local persistence | Drift / SQLite |
| Cloud (later) | Supabase — PostgreSQL, Auth, Storage |

Platform targets are iOS and Android. `web/` is kept as a development
convenience for inspecting graph and layout output quickly; it is not a
supported release target.

## Getting started

Requires the Flutter SDK on the stable channel.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

### Running on a physical iPhone

The simulator needs nothing. A real device has to be code-signed, and the
signing identity belongs to whoever is building rather than to the project:

```sh
cp ios/Flutter/Local.xcconfig.example ios/Flutter/Local.xcconfig
# then put your Apple Developer Team ID in it
```

`Local.xcconfig` is git-ignored — a Team ID identifies a person and this
repository is public. Nothing in it is secret; it is simply not the project's
to publish. The build works without the file, so a fresh clone still runs on
the simulator.

Sign in first at **Xcode → Settings → Accounts**. A free Apple ID is enough
for testing, with the caveat that it signs for seven days at a time and the
app must be reinstalled after that.

## Layering

```
Presentation  →  Application  →  Domain  →  Repository abstractions
                                              ↑
                                        Infrastructure
```

The domain layer is pure Dart and must not import Flutter, Riverpod, Drift,
SQLite, Supabase, or platform APIs. This is enforced by
`test/architecture/domain_purity_test.dart`, not by convention alone.
