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

  Future<void> openTree(WidgetTester tester, {String family = familyId}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: TreeScreen(familyId: family),
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

  /// Turns the page until the chart runs the way this test is about.
  ///
  /// Which way a chart opens is measured from the family, so a test that means
  /// to check one orientation has to say so rather than hope the fixture picks
  /// it.
  Future<void> facing(WidgetTester tester, TreeOrientation orientation) async {
    for (var turn = 0; turn < 2; turn++) {
      if (drawnLayout(tester).metrics.orientation == orientation) return;
      await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw_outlined));
      await tester.pumpAndSettle();
    }
    expect(drawnLayout(tester).metrics.orientation, orientation);
  }

  /// Where a point in chart coordinates lands on the screen.
  Offset onScreen(WidgetTester tester, Offset chartPoint) {
    final viewer = find.byType(InteractiveViewer);
    final view = tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!;

    return tester.getTopLeft(viewer) +
        MatrixUtils.transformPoint(view.value, chartPoint);
  }

  /// A point that is inside the drawing but never on a box: the padding just
  /// left of the root's own box.
  ///
  /// The drawing is larger than the viewport and hangs off it on every side,
  /// so its own corner is no good — a tap there lands outside the viewer, is
  /// never delivered, and a test that expects nothing to happen then passes
  /// without having tested anything.
  Offset emptySpace(WidgetTester tester, int rootPerson) {
    final layout = drawnLayout(tester);
    final node = layout.nodeFor(personId(rootPerson))!;

    return onScreen(
      tester,
      Offset(node.x + 40 - 14, node.y + 40 + layout.metrics.nodeHeight / 2),
    );
  }

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
    // A single tap only resolves once the double-tap window closes: the chart
    // listens for both, and the gesture arena has to wait to know which it was.
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
  }

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

      await tester.tapAt(emptySpace(tester, 1));
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

      final at = emptySpace(tester, 1);
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

    /// Where the point the opening view anchors on lands on the screen.
    ///
    /// The leading edge along the generation axis, centred on the sibling
    /// axis — so the box's top middle upright, and its left middle sideways.
    /// Measuring a corner instead would drift with the zoom, because the
    /// distance from the corner to the anchor is in chart units.
    Offset anchorOnScreen(WidgetTester tester, String id) {
      final layout = drawnLayout(tester);
      final metrics = layout.metrics;
      final node = layout.nodeFor(id)!;

      return onScreen(
        tester,
        metrics.orientation.isTopDown
            ? Offset(node.x + 40 + metrics.nodeWidth / 2, node.y + 40)
            : Offset(node.x + 40, node.y + 40 + metrics.nodeHeight / 2),
      );
    }

    testWidgets('every family opens with its ancestor in the same place', (
      tester,
    ) async {
      // Two families that could hardly differ more in what they force the
      // chart to do: one opens at natural size, the other has to be zoomed
      // out to be read at all. They must still open looking alike, or moving
      // between families is a series of small jumps.
      const otherFamily = 'f0000000-0000-7000-8000-000000000001';
      String otherPerson(int n) =>
          'p0000000-0000-7000-8000-1${n.toString().padLeft(11, '0')}';

      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Nhỏ'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      await seedPerson(2, 'Con');
      await link(1, 2);

      await repository.saveFamily(
        const domain.Family(id: otherFamily, name: 'Lớn'),
      );
      await repository.savePerson(
        Person(
          id: otherPerson(1),
          familyId: otherFamily,
          displayName: 'Thuỷ Tổ',
        ),
      );
      for (var n = 2; n <= 13; n++) {
        await repository.savePerson(
          Person(
            id: otherPerson(n),
            familyId: otherFamily,
            displayName: 'Con $n',
          ),
        );
        await repository.saveRelationship(
          Relationship.parentChild(
            id: 'r0000000-0000-7000-8000-2${n.toString().padLeft(11, '0')}',
            familyId: otherFamily,
            parent: otherPerson(1),
            child: otherPerson(n),
          ),
        );
      }

      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      expect(scaleOf(tester), 1, reason: 'the case being tested');
      final small = anchorOnScreen(tester, personId(1));

      await openTree(tester, family: otherFamily);
      await facing(tester, TreeOrientation.leftToRight);
      expect(scaleOf(tester), lessThan(1), reason: 'the other case');

      final large = anchorOnScreen(tester, otherPerson(1));

      expect(large.dy, closeTo(small.dy, 0.5));
      expect(large.dx, closeTo(small.dx, 0.5));
    });

    testWidgets('the ancestor opens centred, not against an edge', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= 12; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final viewer = find.byType(InteractiveViewer);
      expect(
        anchorOnScreen(tester, personId(1)).dx - tester.getTopLeft(viewer).dx,
        closeTo(tester.getSize(viewer).width / 2, 0.5),
      );
    });

    testWidgets('turned sideways the ancestor is centred down instead', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= 12; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      // The sibling axis is vertical now, so that is the one the ancestor is
      // centred on — and the generation axis, running across, carries the
      // fixed inset instead.
      final viewer = find.byType(InteractiveViewer);
      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(1))!;
      final centre = onScreen(
        tester,
        Offset(node.x + 40, node.y + 40 + layout.metrics.nodeHeight / 2),
      );

      expect(
        centre.dy - tester.getTopLeft(viewer).dy,
        closeTo(tester.getSize(viewer).height / 2, 0.5),
      );
      expect(centre.dx - tester.getTopLeft(viewer).dx, closeTo(24, 0.5));
    });

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
      await facing(tester, TreeOrientation.topDown);

      final whole = wholeChartScale(tester);
      expect(whole, inExclusiveRange(0.6, 1), reason: 'the case being tested');
      expect(scaleOf(tester), closeTo(whole, 0.01));
    });

    testWidgets('opens a large family readable rather than whole', (
      tester,
    ) async {
      // Wide rather than deep, because depth alone no longer reaches the
      // viewport: a chart opens folded to three generations, so an eighth is
      // not drawn to be too small to read. Width within those three is what
      // still overflows, and it is the common shape — a gia phả widens toward
      // the present. Sixteen boxes in the last row measure some 2900 units,
      // which fitted to a phone is a scale of 0.13: names under two pixels.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      var next = 2;
      final children = <int>[];
      for (var n = 0; n < 8; n++) {
        await seedPerson(next, 'Con $next');
        await link(1, next);
        children.add(next);
        next++;
      }
      for (final parent in children) {
        for (var n = 0; n < 2; n++) {
          await seedPerson(next, 'Cháu $next');
          await link(parent, next);
          next++;
        }
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

  group('folding', () {
    /// A single line of descent [depth] people long: 1 is the ancestor of 2,
    /// 2 of 3, and so on. Narrow on purpose — what is being tested is depth.
    Future<void> seedLine(int depth) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Đời 1');
      for (var n = 2; n <= depth; n++) {
        await seedPerson(n, 'Đời $n');
        await link(n - 1, n);
      }
    }

    /// Taps the `+N` badge on a folded box, in chart coordinates.
    Future<void> tapBadge(WidgetTester tester, int n) async {
      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(n))!;
      final target = TreePainter.foldBadgeTarget(node, layout.metrics, 40);

      await tester.tapAt(tester.getTopLeft(chart) + target.center);
      await tester.pump(kDoubleTapTimeout);
      await tester.pumpAndSettle();
    }

    testWidgets('a chart opens three generations deep, however long the line', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(3)), isNotNull);
      expect(layout.nodeFor(personId(4)), isNull);
      expect(layout.generationCount, 3);
    });

    testWidgets('the last visible box says how many it stands in front of', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);

      // Three people are below the fold: Đời 4, 5 and 6.
      expect(drawnLayout(tester).nodeFor(personId(3))!.hiddenDescendantCount, 3);
    });

    testWidgets('tapping the badge reveals exactly one more generation', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);
      await tapBadge(tester, 3);

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(4)), isNotNull);
      expect(
        layout.nodeFor(personId(5)),
        isNull,
        reason: 'the fold below the one opened still holds',
      );
      expect(layout.nodeFor(personId(4))!.hiddenDescendantCount, 2);
    });

    testWidgets('the badge takes the tap, not the box under it', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);
      await tapBadge(tester, 3);

      expect(
        find.widgetWithText(FilledButton, 'Profile'),
        findsNothing,
        reason: 'opening a fold is not selecting the person in front of it',
      );
    });

    testWidgets('opening a fold leaves the view where the reader put it', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);

      final view = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final before = view.value.clone();

      await tapBadge(tester, 3);

      // Refitting here would throw the reader back to the root at the moment
      // they reached what they were looking for.
      expect(view.value, before);
    });

    testWidgets('a new root forgets the folds opened on the old chart', (
      tester,
    ) async {
      await seedLine(7);
      await openTree(tester);
      await tapBadge(tester, 3);
      await tapBadge(tester, 4);
      expect(drawnLayout(tester).nodeFor(personId(5)), isNotNull);

      // Redraw from Đời 2. Were the opened folds carried over, Đời 5
      // would still be unfolded and the new chart four generations deep.
      await tapPerson(tester, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(4)), isNotNull);
      expect(layout.nodeFor(personId(5)), isNull);
      expect(layout.generationCount, 3);
    });

    testWidgets('the off-branch notice does not lie over the chart', (
      tester,
    ) async {
      // It used to float on top, and what it covered was the top generation —
      // on a descendant chart that is the founding ancestor.
      await seedLine(6);
      await seedPerson(90, 'Ngoại tộc');
      await openTree(tester);

      final notice = find.text('1 not on this branch');
      expect(notice, findsOneWidget);

      expect(
        tester.getBottomLeft(notice).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(InteractiveViewer)).dy,
        ),
        reason: 'the strip ends before the drawing begins',
      );
    });

    testWidgets('folding does not inflate the off-branch notice', (
      tester,
    ) async {
      // Two separate lines, so somebody really is off this branch. The notice
      // counts them and nobody else: the folded are on this branch, and a tap
      // brings them back.
      await seedLine(6);
      await seedPerson(90, 'Ngoại tộc');
      await openTree(tester);

      expect(find.text('1 not on this branch'), findsOneWidget);
    });
  });

  group('which way the page is turned', () {
    TreeOrientation orientationOf(WidgetTester tester) =>
        drawnLayout(tester).metrics.orientation;

    Future<void> seedWide(int children) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= children + 1; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
    }

    Future<void> seedDeep(int depth) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Đời 1');
      for (var n = 2; n <= depth; n++) {
        await seedPerson(n, 'Đời $n');
        await link(n - 1, n);
      }
    }

    testWidgets('a generation of many opens sideways', (tester) async {
      // Twelve abreast is what an upright chart cannot show: it would be some
      // five screens across, and sideways it is one.
      await seedWide(12);
      await openTree(tester);

      expect(orientationOf(tester), TreeOrientation.leftToRight);
    });

    testWidgets('a long thin line opens upright', (tester) async {
      // More people than the wide family above, and the opposite answer —
      // which is why the measurement is of the chart and not of the census.
      await seedDeep(14);
      await openTree(tester);

      expect(orientationOf(tester), TreeOrientation.topDown);
    });

    testWidgets('the button turns it', (tester) async {
      await seedWide(12);
      await openTree(tester);
      final opened = orientationOf(tester);

      await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw_outlined));
      await tester.pumpAndSettle();

      expect(orientationOf(tester), isNot(opened));
    });

    testWidgets('a swipe from the edge turns it too', (tester) async {
      await seedWide(12);
      await openTree(tester);
      final opened = orientationOf(tester);

      // Starting hard against the left edge, where the strip is and where
      // panning cannot begin.
      final viewer = find.byType(InteractiveViewer);
      final from =
          tester.getTopLeft(viewer) +
          Offset(6, tester.getSize(viewer).height / 2);
      await tester.dragFrom(from, const Offset(120, 0));
      await tester.pumpAndSettle();

      expect(orientationOf(tester), isNot(opened));
    });

    testWidgets('adding a person does not turn the page', (tester) async {
      await seedWide(12);
      await openTree(tester);
      final opened = orientationOf(tester);

      await seedPerson(90, 'Con mới');
      await link(1, 90);
      await tester.pumpAndSettle();

      expect(orientationOf(tester), opened);
    });

    testWidgets('the reader\'s choice survives redrawing from somebody else', (
      tester,
    ) async {
      // A new root means a new measurement, and the measurement would turn
      // this chart back: a line of descent is narrower upright. Having been
      // told once which way the reader wants it, the screen stops asking.
      await seedDeep(14);
      await openTree(tester);
      expect(orientationOf(tester), TreeOrientation.topDown);

      await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw_outlined));
      await tester.pumpAndSettle();
      expect(orientationOf(tester), TreeOrientation.leftToRight);

      await tapPerson(tester, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      expect(
        drawnLayout(tester).nodeFor(personId(1)),
        isNull,
        reason: 'the root really did move',
      );
      expect(orientationOf(tester), TreeOrientation.leftToRight);
    });

    testWidgets('turning the page places the view again', (tester) async {
      await seedWide(12);
      await openTree(tester);

      final view = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final before = view.value.clone();

      await tester.tap(find.byIcon(Icons.rotate_90_degrees_cw_outlined));
      await tester.pumpAndSettle();

      // Unlike opening a fold, this is a different chart shape entirely, so
      // the old placement points at nothing.
      expect(view.value, isNot(before));
    });

    testWidgets('folding still works with the page turned', (tester) async {
      await seedDeep(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(3)), isNotNull);
      expect(layout.nodeFor(personId(4)), isNull);
      expect(layout.nodeFor(personId(3))!.hiddenDescendantCount, 3);
    });
  });
}
