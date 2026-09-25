/// A second entry point that runs the real application against generated data
/// (ROADMAP M6, T28).
///
/// ```sh
/// flutter run -t lib/dev/main_dev.dart
/// flutter run -t lib/dev/main_dev.dart \
///     --dart-define=GENERATIONS=25 --dart-define=PEOPLE=1000
/// flutter run -t lib/dev/main_dev.dart --dart-define=RESET=true
/// ```
///
/// **It writes into the real database**, `ftree`, so the generated family shows
/// up in the ordinary application beside any real one. Nothing is replaced: the
/// synthetic family is added, and the reader deletes it by swiping its row when
/// they are done with it.
///
/// The one hazard that creates is [_reset], which is scoped to the generated
/// family alone (see [eraseFamily]). There is no path here that touches a row
/// this file did not write.
///
/// Everything above the database is the shipping application — the same
/// providers, the same screens. That is the point: what appears here is what
/// three hundred people actually look like in the interface.
library;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app.dart';
import '../app/providers.dart';
import '../data/cloud/cloud_session.dart';
import '../data/database/app_database.dart';
import 'dev_database.dart';
import 'synthetic_family.dart';

/// How deep the generated tree runs. `--dart-define=GENERATIONS=25`
const int _generations = int.fromEnvironment('GENERATIONS', defaultValue: 12);

/// Roughly how many people it holds. `--dart-define=PEOPLE=1000`
const int _people = int.fromEnvironment('PEOPLE', defaultValue: 300);

/// Change it and every name, date and branch changes with it.
/// `--dart-define=SEED=99`
const int _seed = int.fromEnvironment('SEED', defaultValue: 20260805);

/// Erase the previously generated family before installing.
/// `--dart-define=RESET=true`
///
/// Needed to change the size while keeping the seed: without it the family
/// already installed under that seed is left alone. Only that family is
/// removed — never a real one.
const bool _reset = bool.fromEnvironment('RESET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // As `lib/main.dart` does, and for the reasons written there.
  await openCloud();

  final db = AppDatabase(driftDatabase(name: 'ftree'));

  final clock = Stopwatch()..start();
  final data = generateSyntheticFamily(
    generations: _generations,
    people: _people,
    seed: _seed,
    // The one input taken from the real clock. Who is still living has to move
    // as the years do, or the youngest generation would slowly fill with people
    // recorded as dead. It cannot reach the family's id, which is drawn first.
    currentYear: DateTime.now().year,
  );
  final built = clock.elapsedMilliseconds;

  // After generating, not before: the id being erased is the id about to be
  // written, which is what keeps the delete off every other family in the file.
  if (_reset) await eraseFamily(db, data.family.id);

  final present = await holdsFamily(db, data.family.id);
  if (!present) await installSyntheticFamily(db, data);
  final written = clock.elapsedMilliseconds - built;

  _report(data, builtMs: built, writtenMs: written, alreadyPresent: present);

  runApp(
    ProviderScope(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
      child: const FtreeApp(),
    ),
  );
}

/// Prints what was built, so the numbers behind a screenshot are on the record.
///
/// The two timings are the first thing the measurement task will want, and they
/// cost nothing to collect here.
void _report(
  SyntheticFamily data, {
  required int builtMs,
  required int writtenMs,
  required bool alreadyPresent,
}) {
  final (earliest, latest) = data.birthYearRange;

  debugPrint(
    'synthetic family: ${data.persons.length} people, '
    '${data.relationships.length} relationships, '
    '${data.depth} generations, born $earliest–$latest\n'
    '  widths per generation: ${data.widths.join(', ')}\n'
    '  seed $_seed, generated in ${builtMs}ms, '
    '${alreadyPresent ? 'already installed' : 'written in ${writtenMs}ms'}',
  );
}
