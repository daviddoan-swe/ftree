import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/layout/tree_layout.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/person/person_profile_screen.dart';
import 'package:ftree/features/tree/tree_screen.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;

  const familyId = 'f0000000-0000-7000-8000-000000000000';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Future<void> seedPerson(
    int n,
    String name, {
    GenealogicalDate? birthDate,
  }) => repository.savePerson(
    Person(
      id: personId(n),
      familyId: familyId,
      displayName: name,
      birthDate: birthDate,
    ),
  );

  Future<void> link(int parent, int child) => repository.saveRelationship(
    Relationship.parentChild(
      id: 'r0000000-0000-7000-8000-${parent}0000000000$child',
      familyId: familyId,
      parent: personId(parent),
      child: personId(child),
    ),
  );

  Future<void> openTree(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: const TreeScreen(familyId: familyId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The chart's own painter, not the several a Material screen also paints.
  final chart = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is TreePainter,
  );

  TreeLayout drawnLayout(WidgetTester tester) =>
      (tester.widget<CustomPaint>(chart).painter! as TreePainter).layout;

  /// Three generations from one ancestor, plus a spouse.
  Future<void> seedFamily() async {
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    await seedPerson(1, 'Cụ Tổ', birthDate: GenealogicalDate(year: 1887));
    await seedPerson(2, 'Cụ Bà');
    await seedPerson(3, 'Con Cả');
    await seedPerson(4, 'Cháu');
    await repository.saveRelationship(
      Relationship.spouse(
        id: 'r0000000-0000-7000-8000-000000000099',
        familyId: familyId,
        personA: personId(1),
        personB: personId(2),
      ),
    );
    await link(1, 3);
    await link(2, 3);
    await link(3, 4);
  }

  testWidgets('says so plainly when there is nobody to draw', (tester) async {
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    await openTree(tester);

    expect(find.text('Nobody to draw yet'), findsOneWidget);
  });

  testWidgets('draws from the person with no recorded parents', (tester) async {
    await seedFamily();
    await openTree(tester);

    final layout = drawnLayout(tester);
    expect(layout.nodes.length, 4);
    expect(layout.nodeFor(personId(1))!.generation, 0);
    expect(layout.nodeFor(personId(3))!.generation, 1);
    expect(layout.nodeFor(personId(4))!.generation, 2);
  });

  testWidgets('says how many people the chart leaves out', (tester) async {
    await seedFamily();
    // No relationship to anybody, so a descendant chart cannot reach them.
    await seedPerson(5, 'Người Ngoài');
    await openTree(tester);

    expect(find.text('1 not on this branch'), findsOneWidget);
  });

  testWidgets('says nothing when everybody is on the chart', (tester) async {
    await seedFamily();
    await openTree(tester);

    expect(find.textContaining('not on this branch'), findsNothing);
  });

  group('selection', () {
    /// Taps the middle of a person's box, in chart coordinates.
    Future<void> tapPerson(WidgetTester tester, int n) async {
      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(n))!;
      final canvas = tester.getTopLeft(chart);

      await tester.tapAt(
        canvas +
            Offset(
              node.x + 40 + layout.metrics.nodeWidth / 2,
              node.y + 40 + layout.metrics.nodeHeight / 2,
            ),
      );
      // A single tap only resolves once the double-tap window closes: the
      // chart listens for both, and the gesture arena has to wait to know
      // which it was.
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
    }

    testWidgets('a tap on a box names the person', (tester) async {
      await seedFamily();
      await openTree(tester);
      await tapPerson(tester, 3);

      expect(find.widgetWithText(FilledButton, 'Profile'), findsOneWidget);
      expect(find.text('Con Cả'), findsOneWidget);
    });

    testWidgets('a tap on empty space selects nobody', (tester) async {
      await seedFamily();
      await openTree(tester);
      await tapPerson(tester, 3);
      expect(find.widgetWithText(FilledButton, 'Profile'), findsOneWidget);

      // The top-left corner of the canvas is padding, never a box.
      await tester.tapAt(tester.getTopLeft(chart) + const Offset(4, 4));
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Profile'), findsNothing);
    });

    testWidgets('the selected person opens their profile', (tester) async {
      await seedFamily();
      await openTree(tester);
      await tapPerson(tester, 3);

      await tester.tap(find.widgetWithText(FilledButton, 'Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonProfileScreen), findsOneWidget);
      // Their own relatives, so the profile really did build for this person
      // rather than merely appearing.
      expect(find.text('Parents'), findsOneWidget);
      expect(find.text('Children'), findsOneWidget);
    });

    testWidgets('redrawing from the selected person moves them to the top', (
      tester,
    ) async {
      await seedFamily();
      await openTree(tester);
      await tapPerson(tester, 3);

      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(3))!.generation, 0);
      // The ancestors are above this root, so a descendant chart drops them.
      expect(layout.nodeFor(personId(1)), isNull);
      expect(find.text('2 not on this branch'), findsOneWidget);
    });

    testWidgets('a double tap redraws from that person', (tester) async {
      await seedFamily();
      await openTree(tester);

      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(3))!;
      final at =
          tester.getTopLeft(chart) +
          Offset(
            node.x + 40 + layout.metrics.nodeWidth / 2,
            node.y + 40 + layout.metrics.nodeHeight / 2,
          );

      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(at);
      await tester.pumpAndSettle();

      expect(drawnLayout(tester).nodeFor(personId(3))!.generation, 0);
      expect(drawnLayout(tester).nodeFor(personId(1)), isNull);
    });

    testWidgets('a double tap on empty space redraws nothing', (tester) async {
      await seedFamily();
      await openTree(tester);
      final before = drawnLayout(tester).nodes.length;

      final at = tester.getTopLeft(chart) + const Offset(4, 4);
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(at);
      await tester.pumpAndSettle();

      expect(drawnLayout(tester).nodes, hasLength(before));
    });

    testWidgets('the root is not offered as a new root', (tester) async {
      await seedFamily();
      await openTree(tester);
      await tapPerson(tester, 1);

      expect(find.text('Draw from here'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Profile'), findsOneWidget);
    });
  });

  group('the opening view', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    /// The scale that would show the whole chart, never magnifying it.
    double wholeChartScale(WidgetTester tester) {
      final layout = drawnLayout(tester);
      final viewport = tester.getSize(find.byType(InteractiveViewer));
      return <double>[
        viewport.width / (layout.width + 80),
        viewport.height / (layout.height + 80),
        1,
      ].reduce((a, b) => a < b ? a : b);
    }

    testWidgets('shows a family whole when it is still readable that way', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      // Five children: wider than the viewport, but not so wide that fitting
      // makes it unreadable.
      for (var n = 2; n <= 6; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
      await openTree(tester);

      final whole = wholeChartScale(tester);
      expect(whole, inExclusiveRange(0.6, 1), reason: 'the case being tested');
      expect(scaleOf(tester), closeTo(whole, 0.01));
    });

    testWidgets('opens a large family readable rather than whole', (
      tester,
    ) async {
      // Eight generations measure some 2900 units across. Fitted to a phone
      // that is a scale of 0.13 — names under two pixels, which is not an
      // overview of anything.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      var next = 2;
      var generation = <int>[1];
      for (var depth = 0; depth < 7; depth++) {
        final born = <int>[];
        for (final parent in generation) {
          for (var child = 0; child < 2; child++) {
            await seedPerson(next, 'Đời ${depth + 2} · $next');
            await link(parent, next);
            born.add(next);
            next++;
          }
        }
        generation = born;
        if (next > 40) break;
      }

      await openTree(tester);

      expect(
        wholeChartScale(tester),
        lessThan(0.6),
        reason: 'the chart really is too wide to read when fitted',
      );
      expect(scaleOf(tester), greaterThanOrEqualTo(0.6));
    });

    testWidgets('the fit button then shows everything, however small', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= 30; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }

      await openTree(tester);
      expect(scaleOf(tester), greaterThanOrEqualTo(0.6));

      await tester.tap(find.byIcon(Icons.fit_screen_outlined));
      await tester.pumpAndSettle();

      expect(scaleOf(tester), closeTo(wholeChartScale(tester), 0.01));
    });
  });

  testWidgets('picks a new root when the chosen one is deleted', (
    tester,
  ) async {
    // Not the default root — a root the reader picked, which is the case the
    // guard in _body exists for. Deleting that person from their profile is a
    // few taps away, and the tree screen stays in the stack while it happens.
    await seedFamily();
    await openTree(tester);

    final layout = drawnLayout(tester);
    final node = layout.nodeFor(personId(3))!;
    await tester.tapAt(
      tester.getTopLeft(chart) +
          Offset(
            node.x + 40 + layout.metrics.nodeWidth / 2,
            node.y + 40 + layout.metrics.nodeHeight / 2,
          ),
    );
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
    await tester.pumpAndSettle();
    expect(drawnLayout(tester).nodeFor(personId(3))!.generation, 0);

    await repository.deletePerson(personId(3));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TreeScreen)),
    );
    await container.read(familySnapshotProvider(familyId).notifier).reload();
    await tester.pumpAndSettle();

    final after = drawnLayout(tester);
    expect(after.nodeFor(personId(3)), isNull);
    expect(after.nodes, isNotEmpty, reason: 'a chart is still drawn');
  });

  testWidgets('survives a graph with an ancestry loop in it', (tester) async {
    // Two devices editing offline can produce this (DOMAIN.md §6.2). It must
    // draw something rather than hang.
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    await seedPerson(1, 'A');
    await seedPerson(2, 'B');
    await seedPerson(3, 'C');
    await link(1, 2);
    await link(2, 3);
    await link(3, 1);

    await openTree(tester);

    expect(drawnLayout(tester).nodes.length, 3);
  });
}
