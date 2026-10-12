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

## Developing

Everything below is the day-to-day loop: generated data to work against, how to
get a change onto the simulator, and what to run before committing it.

### Working against a large family

The interface is hard to judge against the three people a manual test creates.
A second entry point generates a family and runs the ordinary application
against it:

```sh
flutter run -t lib/dev/main_dev.dart
flutter run -t lib/dev/main_dev.dart \
    --dart-define=GENERATIONS=25 --dart-define=PEOPLE=1000
```

Twelve generations and three hundred people by default. The data is
deterministic — the same seed gives the same family every time — and carries no
validation issue of any severity, so nothing on screen is an artefact of bad
input. `lib/dev/` is unreachable from `lib/main.dart` and so is absent from a
release build.

It writes into the **normal** database, alongside any real family. Delete the
generated one by swiping its row when you are done.

### Resetting the generated family

`RESET` removes the family that seed produced and installs it again. It is
scoped to that one family by id, so any real family in the database is left
alone:

```sh
flutter run -t lib/dev/main_dev.dart --dart-define=RESET=true
```

Needed whenever you change `GENERATIONS` or `PEOPLE` while keeping the seed:
without it the family already installed under that seed is recognised and
nothing is rewritten.

### Emptying the database

The application keeps everything in one SQLite file, `ftree.sqlite`, in the
platform's documents directory. Deleting it wipes **every** family on that
device, generated and real alike, and the next launch starts from an empty
schema.

```sh
rm "$(xcrun simctl get_app_container booted com.newstar247.ftree data)/Documents/ftree.sqlite"
```

This is also how to reach the file with a SQLite browser when a migration or a
query needs inspecting rather than deleting.

### Reinstalling on the simulator

Three levels, cheapest first. Reach for the next one only when the one before
it did not explain what you are seeing.

**Hot reload, and hot restart.** With `flutter run` attached, `r` reloads the
changed code into the running app and `R` restarts it from `main`. Editing a
file does nothing on its own — a running app does not notice, which is the
usual reason a fix appears not to have worked.

**A clean rebuild.** Keeps the database:

```sh
flutter clean && flutter pub get
flutter run -t lib/dev/main_dev.dart -d "iPhone 17 Pro"
```

**A full reinstall.** Removes the app and everything it stored:

```sh
xcrun simctl uninstall booted com.newstar247.ftree
flutter run -t lib/dev/main_dev.dart -d "iPhone 17 Pro"
```

> The uninstall destroys the database with the app. Any family typed in by hand
> on that simulator is gone and cannot be recovered. The generated family comes
> back on the next launch because it is derived from its seed; nothing else
> does.

### Driving the simulator

```sh
flutter devices                       # what -d will accept
xcrun simctl list devices available   # every simulator, booted or not
xcrun simctl boot "iPhone 17 Pro"; open -a Simulator
xcrun simctl io booted screenshot shot.png
```

`booted` works in place of a device id in every `simctl` command above when
exactly one simulator is running.

### Before a commit

```sh
flutter analyze
flutter test
git diff
```

All three, in that order. The project treats a failing test or a new analyser
warning as a broken build rather than as a note for later, and the diff is
where an unrelated file that drifted into the change shows up.

To run one file, or one test by name:

```sh
flutter test test/domain/layout/tree_layout_test.dart
flutter test --plain-name "folds the last visible generation"
```

### The pre-commit hook

One command in a fresh clone, and git will refuse to commit anything that
belongs to the machine rather than to the project:

```sh
git config core.hooksPath .githooks
```

It is not installed automatically — git will not run a hook from a clone
without being told to, and that is a protection rather than an inconvenience.

It checks what is **staged**, and it looks for two kinds of thing: paths that
are never the project's to publish (signing material, `.env` files,
`Local.xcconfig`, editor droppings), and values that have leaked into a file
which does belong here — private keys, cloud credentials, and above all
`DEVELOPMENT_TEAM` in `project.pbxproj`.

That last one is why the hook exists. Xcode writes the Team ID back into the
project file after a build on a physical device, silently undoing commit
`a36d87d`, and a Team ID names a person in a public repository. It will happen
again on the next device build, so it is caught here rather than remembered.

Every pattern in it is one that would be wrong in *this* repository. It
deliberately does not build or test — it runs on every commit, and a hook that
is slow or cries wolf is one people learn to bypass:

```sh
git commit --no-verify    # when you are certain it is a false alarm
```

### The cloud, on your own machine

The cloud half of the project — PostgreSQL, authentication, and the policies
that decide who may read what — runs locally. Nothing needs a Supabase account
to develop against.

```sh
brew install supabase/tap/supabase   # once; 2.117.0 at the time of writing
supabase start                       # needs Docker Desktop running
```

The first start pulls a few images and takes several minutes. It prints the
addresses and keys; `supabase status -o env` prints them again later. The
database sits on port 54322, the API on 54321, and a web console on 54323.

Migrations in `supabase/migrations/` are applied automatically on start, and
by hand afterwards:

```sh
supabase migration up --local        # apply what is new
supabase db reset --local            # throw it away and replay from the top
```

`[analytics]` is off in `supabase/config.toml`. It runs a log shipper — the
`vector` container — that nothing here reads, and it is the one piece of the
local stack that fails to come up.

### Running the checks that need the cloud

They are **not** part of `flutter test`, and deliberately have no `_test.dart`
suffix: they need Docker and a running stack, and a check that fails on a
machine without one says nothing about the code.

```sh
flutter test test/cloud/auth.dart                 # signing in, and who the server thinks you are
flutter test test/cloud/repository_contract.dart  # Postgres answering the repository contract
```

The second is the one worth understanding. `test/support/repository_contract.dart`
holds sixteen checks written against `FamilyRepository` rather than against
either store; SQLite answers them in the ordinary suite and Postgres answers
the same ones here, unchanged. If a change makes the two disagree, that file
is where it shows.

`test/performance/tree_rendering.dart` is arranged the same way, for the same
reason: the suite has to stay runnable anywhere.

### Changing the cloud schema

```sh
supabase migration new <name>        # creates a timestamped, empty file
# write it, then:
supabase db reset --local            # replay everything, including yours
```

Read ARCHITECTURE.md §8.2 first. **A migration that has been applied anywhere
but a local scratch database is never edited** — the file is the shipped
history, and every environment has to run the same sequence. Editing one is
allowed only while it has never been committed, and `supabase db reset` is
what proves it still works from scratch.

Two traps the existing migrations have comments about, worth knowing before
writing a new one:

* **Enable row-level security in the same file that creates the table.**
  PostgREST serves every table through the publishable key, which ships inside
  the application. A table without RLS is a public table, and nothing warns
  about it.
* **A policy on a table that reads that same table recurses for ever.** The
  way out is a `SECURITY DEFINER` function, which runs outside RLS — see
  `my_role` in `20260924000002_memberships.sql`. Every such function is a hole
  in the wall, so there are two of them and both say why where they are
  written.

### Changing the local schema

SQLite, on the device. Drift generates the table code, and the schema history
has to be captured
before the migration can be tested against it:

```sh
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/data/database/schema_versions/
flutter test test/data/database/migration_test.dart
```

Read DOMAIN.md §18 and ARCHITECTURE.md §8.2 first. A schema mistake costs a
migration on every installed device, and the migration tests exist to replay
the real shipped schema rather than an approximation of it.

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
