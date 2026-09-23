/// Measurements behind the M6 "profile tree rendering" task.
///
/// **This is not a test.** It asserts nothing, and its name has no `_test`
/// suffix, so `flutter test` does not pick it up. Run it deliberately:
///
/// ```sh
/// flutter test test/performance/tree_rendering.dart
/// ```
///
/// What it is for is deciding whether anything here needs optimising, and the
/// honest answer needs numbers rather than a reading of the code. Two costs
/// were suspected on inspection and are isolated below: `_barsByParent`, which
/// walks every edge on every paint, and the [TextPainter] each box builds from
/// scratch on every paint.
///
/// Read the absolute numbers with care. This runs in the Dart VM under JIT,
/// not AOT on a phone, and the canvas is a recording one rather than a GPU.
/// The *ratios* are what carry over: which of these dominates, and by how
/// much. Frame times on a device are a separate measurement, taken from
/// `lib/dev/main_dev.dart` in profile mode.
library;

import 'dart:ui' as ui;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/dev/synthetic_family.dart';
import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/layout/tree_layout.dart';
import 'package:ftree/features/person/person_style.dart';
import 'package:ftree/features/tree/tree_screen.dart';

/// How many times each measurement is repeated.
///
/// The median of these is reported rather than the mean: one run in twenty is
/// interrupted by the garbage collector, and a mean quietly carries that
/// interruption into every conclusion drawn from it.
const int _runs = 21;

/// Runs [work] [_runs] times and reports the median in microseconds.
///
/// [work] is run once before timing begins. The first call through any Dart
/// function is the slowest it will ever be — the JIT has not seen it yet — and
/// measuring that says more about the VM than about the code.
double _median(void Function() work) {
  work();

  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final clock = Stopwatch()..start();
    work();
    clock.stop();
    times.add(clock.elapsedMicroseconds);
  }
  times.sort();
  return times[times.length ~/ 2].toDouble();
}

/// The same, for work that has to be awaited.
Future<double> _medianAsync(Future<void> Function() work) async {
  await work();

  final times = <int>[];
  for (var i = 0; i < _runs; i++) {
    final clock = Stopwatch()..start();
    await work();
    clock.stop();
    times.add(clock.elapsedMicroseconds);
  }
  times.sort();
  return times[times.length ~/ 2].toDouble();
}

void _say(String what, double micros, {String? per}) {
  final ms = (micros / 1000).toStringAsFixed(3);
  // ignore: avoid_print
  print('  ${what.padRight(46)} ${ms.padLeft(9)} ms${per == null ? '' : "  $per"}');
}

void _heading(String what) {
  // ignore: avoid_print
  print('\n$what');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  for (final people in <int>[300, 1000]) {
    test('$people people', () async {
      final data = generateSyntheticFamily(people: people);

      _heading('═══ ${data.persons.length} people, '
          '${data.relationships.length} relationships, '
          '${data.depth} generations ═══');

      // ── The graph ───────────────────────────────────────────────────────
      //
      // Built on every rebuild of the tree screen from the loaded snapshot,
      // so its cost is paid per frame that changes anything.
      _heading('Graph');
      _say(
        'FamilyGraph(...) — built per rebuild',
        _median(() {
          FamilyGraph(
            persons: data.persons,
            relationships: data.relationships,
          );
        }),
      );

      final graph = FamilyGraph(
        persons: data.persons,
        relationships: data.relationships,
      );
      final root = graph.foundingAncestor()!;

      // Cached behind `late final`, so this is the price of the first call on
      // a fresh graph — which, since the graph is rebuilt, is every rebuild.
      _say(
        'generations() — first call on a fresh graph',
        _median(() {
          FamilyGraph(
            persons: data.persons,
            relationships: data.relationships,
          ).generations();
        }),
      );
      _say('generations() — already cached', _median(graph.generations));
      _say(
        'foundingAncestor() — already cached',
        _median(graph.foundingAncestor),
      );

      // ── Layout ──────────────────────────────────────────────────────────
      _heading('Layout');
      for (final orientation in TreeOrientation.values) {
        // The depths the screen actually draws (tree_screen.dart), and then
        // the whole chart, which the reader can reach by opening folds.
        final depths = <int?>[
          orientation.isTopDown ? 5 : 3,
          null,
        ];
        for (final depth in depths) {
          final folded = depth == null
              ? const <String>{}
              : collapseToDepth(graph, root.id, visibleGenerations: depth);
          final metrics = LayoutMetrics(orientation: orientation);
          final drawn = layoutDescendants(
            graph,
            root.id,
            collapsed: folded,
            metrics: metrics,
          );

          _say(
            'layoutDescendants ${orientation.name} '
            '${depth == null ? 'whole' : '$depth deep'}',
            _median(() {
              layoutDescendants(
                graph,
                root.id,
                collapsed: folded,
                metrics: metrics,
              );
            }),
            per: '${drawn.nodes.length} boxes, ${drawn.edges.length} edges',
          );
        }
      }

      // ── Paint ───────────────────────────────────────────────────────────
      //
      // The question this exists to answer: is a frame dominated by painting,
      // and if so by which part of it.
      _heading('Paint');
      const colors = ColorScheme.light();

      for (final orientation in TreeOrientation.values) {
        final folded = collapseToDepth(
          graph,
          root.id,
          visibleGenerations: orientation.isTopDown ? 5 : 3,
        );
        final layout = layoutDescendants(
          graph,
          root.id,
          collapsed: folded,
          metrics: LayoutMetrics(orientation: orientation),
        );
        final painter = TreePainter(
          layout: layout,
          selectedId: null,
          colors: colors,
          padding: 24,
        );
        final size = Size(layout.width + 48, layout.height + 48);

        _say(
          'TreePainter.paint ${orientation.name} (as drawn)',
          _median(() {
            final recorder = ui.PictureRecorder();
            painter.paint(Canvas(recorder), size);
            recorder.endRecording().dispose();
          }),
          per: '${layout.nodes.length} boxes',
        );

        // The first suspect, isolated: the map of drop points is rebuilt from
        // every edge on every paint. This is the same walk, done here.
        _say(
          '  of which: rebuilding the drop points',
          _median(() {
            final anchors = <String, Set<double>>{};
            for (final edge in layout.edges) {
              if (edge.kind != LayoutEdgeKind.parentChild) continue;
              (anchors[edge.fromPersonId] ??= <double>{})
                  .add(edge.fromAnchorAlong);
            }
            for (final entry in anchors.entries) {
              entry.value.toList().sort();
            }
          }),
          per: '${layout.edges.length} edges',
        );

        // The second: every box builds and lays out a fresh TextPainter. This
        // is that work alone, with no drawing at all.
        _say(
          '  of which: laying out the labels',
          _median(() {
            for (final node in layout.nodes) {
              _labelOf(node, colors).layout(maxWidth: 160 - 12);
            }
          }),
          per: '${layout.nodes.length} labels',
        );
      }

      // ── Reading it back ─────────────────────────────────────────────────
      //
      // Once per screen rather than per frame, but it is what the reader waits
      // through before anything is drawn at all.
      _heading('Database');
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final FamilyRepository repository = DriftFamilyRepository(db);

      final writing = Stopwatch()..start();
      await repository.saveFamily(data.family);
      for (final person in data.persons) {
        await repository.savePerson(person);
      }
      for (final relationship in data.relationships) {
        await repository.saveRelationship(relationship);
      }
      writing.stop();
      _say(
        'writing the family in, row by row',
        writing.elapsedMicroseconds.toDouble(),
        per: '${data.persons.length + data.relationships.length} rows',
      );

      final indexedRead = await _medianAsync(() async {
        await repository.loadFamily(data.family.id);
      });
      _say('loadFamily — indexed, as shipped', indexedRead);

      // The other query the indexes were declared for: finding one person's
      // edges, from either end. A different shape entirely — a handful of rows
      // out of thousands, which is the case an index is supposed to win.
      //
      // Tombstoned rather than removed, so the row is still there to delete
      // again on the next run and every measurement does the same work.
      final victims = data.persons.map((p) => p.id).toList();
      var next = 0;
      Future<void> deleteOne() async {
        await repository.deletePerson(victims[next++ % victims.length]);
      }

      final indexedDelete = await _medianAsync(deleteOne);
      _say('deletePerson — indexed, as shipped', indexedDelete);

      // What the indexes are worth, which the schema review never measured.
      for (final index in <String>[
        'persons_by_family',
        'relationships_by_family',
        'relationships_by_person_a',
        'relationships_by_person_b',
      ]) {
        await db.customStatement('DROP INDEX IF EXISTS $index');
      }

      final scannedRead = await _medianAsync(() async {
        await repository.loadFamily(data.family.id);
      });
      _say(
        'loadFamily — indexes dropped',
        scannedRead,
        per: '${(scannedRead / indexedRead).toStringAsFixed(2)}× indexed',
      );

      final scannedDelete = await _medianAsync(deleteOne);
      _say(
        'deletePerson — indexes dropped',
        scannedDelete,
        per: '${(scannedDelete / indexedDelete).toStringAsFixed(2)}× indexed',
      );
    });
  }
}

/// The label a box carries, built exactly as [TreePainter] builds it.
///
/// Copied rather than shared because the painter's is private, and exposing it
/// to be measured would change the thing being measured.
TextPainter _labelOf(LayoutNode node, ColorScheme colors) {
  final years = lifeYears(node.person);
  final glyph = personIcon(node.person);

  return TextPainter(
    text: TextSpan(
      style: TextStyle(fontSize: 13, color: colors.onSurface),
      children: <InlineSpan>[
        TextSpan(
          text: '${String.fromCharCode(glyph.codePoint)} ',
          style: TextStyle(
            fontFamily: glyph.fontFamily,
            package: glyph.fontPackage,
            fontSize: 13,
            color: personColor(node.person),
          ),
        ),
        TextSpan(text: node.person.displayName),
        if (years != null)
          TextSpan(
            text: '\n$years',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
      ],
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 3,
    ellipsis: '…',
  );
}
