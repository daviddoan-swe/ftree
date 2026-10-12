# Ftree

[![ci](https://github.com/daviddoan-swe/ftree/actions/workflows/ci.yml/badge.svg)](https://github.com/daviddoan-swe/ftree/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A private, offline-capable family tree application for iOS and Android.

Ftree lets a family record and explore its history across multiple generations,
with the data staying under the family's own control. It is not a social
network and has no public discovery features.

## Status

Pre-release. See [docs/ROADMAP.md](docs/ROADMAP.md) for the current milestone.

The local-only version comes first: domain model, family graph, local
persistence, and tree rendering. Cloud sync and sharing follow once the local
application is stable.

The cloud schema, authentication and access policies exist and are checked
against a Postgres running on the developer's own machine — but **no screen
uses them**. The application reads and writes SQLite exactly as it did, and
will until synchronisation gives the two copies something to say to each
other. A family leaves the device today as a file, not over a network.

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
| Cloud | Supabase — PostgreSQL, Auth, Storage |

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

Running on a physical device needs a signing identity, and the day-to-day
development loop — generated test data, resetting the database, the pre-commit
hook, running the cloud locally, changing either schema — is in
[CONTRIBUTING.md](CONTRIBUTING.md).

## Vietnamese terms

The documentation keeps the Vietnamese words for the things it is about, because
each names something English describes only loosely. Interface labels are in
English and Vietnamese both — these are the terms the *documentation* uses.

| Term | Meaning |
| --- | --- |
| **gia phả** | A Vietnamese family record: the book a lineage is written down in, kept and added to across generations |
| **giỗ** | The death anniversary, observed on the lunar date rather than the Gregorian one |
| **đời** | Generation, counted from the founding ancestor — a fact about a person, not about the chart on screen |
| **thuỷ tổ** | The founding ancestor the generations are counted from |
| **Con Cả** / **Con Thứ** | The eldest child / a younger child. A gia phả is read from Con Cả down |
| **can chi** | The sixty-year cycle that names years — Giáp Tý, Đinh Hợi. Repeats every 60 years, so a source giving only the name needs a century from the reader |
| **tháng nhuận** | The intercalary month of the lunar calendar: a year with one has two months of the same number |
| **Tết** | Lunar new year, where the lunar year changes mid-Gregorian-year |

## Layering

```
Presentation  →  Application  →  Domain  →  Repository abstractions
                                              ↑
                                        Infrastructure
```

The domain layer is pure Dart and must not import Flutter, Riverpod, Drift,
SQLite, Supabase, or platform APIs. This is enforced by
`test/architecture/domain_purity_test.dart`, not by convention alone.

## Continuous integration

Every push runs `flutter analyze --fatal-infos` and the full test suite
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) — the same two gates
the pre-commit hook expects before a commit, run somewhere other than the
author's laptop. The Flutter version is pinned, so a red badge means this code
changed rather than that the SDK moved.

## License

MIT — see [LICENSE](LICENSE).
