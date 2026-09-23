import 'dart:typed_data';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/grouped_list.dart';
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

  /// A phone, which is where these rules have to earn their keep: the default
  /// test window is wide enough that a folded chart fits on it whichever way
  /// round it is drawn, and so exercises only half of them.
  void onAPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 756);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

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

  double scaleOf(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!
      .value
      .getMaxScaleOnAxis();

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
  Offset emptySpaceInChart(WidgetTester tester, int rootPerson) {
    final layout = drawnLayout(tester);
    final node = layout.nodeFor(personId(rootPerson))!;

    return Offset(node.x + 40 - 14, node.y + 40 + layout.metrics.nodeHeight / 2);
  }

  /// Taps a point given in chart coordinates, panning to it if it is off
  /// screen.
  ///
  /// The drawing is larger than the viewport and the view does not follow it
  /// as folds are opened, so a box that was in sight can leave it. A reader
  /// drags the chart until they can see what they want to press; so does this.
  /// Without the drag a tap simply lands outside the viewer, is never
  /// delivered, and the test that expected nothing to happen passes for the
  /// wrong reason.
  Future<void> tapInChart(WidgetTester tester, Offset chartPoint) async {
    final viewer = find.byType(InteractiveViewer);
    var target = onScreen(tester, chartPoint);

    if (!tester.getRect(viewer).contains(target)) {
      await tester.drag(viewer, tester.getRect(viewer).center - target);
      await tester.pumpAndSettle();
      target = onScreen(tester, chartPoint);
    }

    await tester.tapAt(target);
    // A single tap only resolves once the double-tap window closes: the chart
    // listens for both, and the gesture arena has to wait to know which it was.
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
  }

  /// Taps the middle of a person's box.
  Future<void> tapPerson(WidgetTester tester, int n) async {
    final layout = drawnLayout(tester);
    final node = layout.nodeFor(personId(n))!;

    await tapInChart(
      tester,
      Offset(
        node.x + 40 + layout.metrics.nodeWidth / 2,
        node.y + 40 + layout.metrics.nodeHeight / 2,
      ),
    );
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

      await tapInChart(tester, emptySpaceInChart(tester, 1));
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

      final at = onScreen(tester, emptySpaceInChart(tester, 1));
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

    /// Where the middle of the whole drawing lands, relative to the viewport.
    Offset chartCentreIn(WidgetTester tester) {
      final layout = drawnLayout(tester);
      return onScreen(
            tester,
            Offset((layout.width + 80) / 2, (layout.height + 80) / 2),
          ) -
          tester.getTopLeft(find.byType(InteractiveViewer));
    }

    /// How far the drawing runs along each axis on the screen.
    Size chartExtentOn(WidgetTester tester) {
      final layout = drawnLayout(tester);
      final scale = scaleOf(tester);
      return Size((layout.width + 80) * scale, (layout.height + 80) * scale);
    }

    testWidgets('a chart that fits opens centred', (tester) async {
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      await seedPerson(2, 'Con');
      await link(1, 2);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final viewport = tester.getSize(find.byType(InteractiveViewer));
      final extent = chartExtentOn(tester);
      expect(extent.width, lessThan(viewport.width), reason: 'the case tested');
      expect(extent.height, lessThan(viewport.height), reason: 'the case tested');

      final centre = chartCentreIn(tester);
      expect(centre.dx, closeTo(viewport.width / 2, 0.5));
      expect(centre.dy, closeTo(viewport.height / 2, 0.5));
    });

    testWidgets('a chart too long for the screen opens on its ancestor', (
      tester,
    ) async {
      onAPhone(tester);
      // Three generations turned sideways are wider than a phone. Centring
      // that would put the founding ancestor off the left edge, and a gia phả
      // opened at some middle generation is a gia phả nobody can place.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Đời 1');
      for (var n = 2; n <= 6; n++) {
        await seedPerson(n, 'Đời $n');
        await link(n - 1, n);
      }
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final viewport = tester.getSize(find.byType(InteractiveViewer));
      final extent = chartExtentOn(tester);
      expect(extent.width, greaterThan(viewport.width), reason: 'the case tested');
      expect(extent.height, lessThan(viewport.height), reason: 'the other axis');

      final root =
          anchorOnScreen(tester, personId(1)) -
          tester.getTopLeft(find.byType(InteractiveViewer));

      expect(root.dx, closeTo(24, 0.5), reason: 'a fixed inset along the line');
      expect(
        chartCentreIn(tester).dy,
        closeTo(viewport.height / 2, 0.5),
        reason: 'and centred on the axis that does fit',
      );
    });

    testWidgets('an overflowing chart leaves no gap at the leading edge', (
      tester,
    ) async {
      // The ancestor sits a fixed inset in, but never so far that the drawing
      // pulls away from an edge it is overflowing past — which would waste
      // room at one end while hiding the other.
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Đời 1');
      for (var n = 2; n <= 6; n++) {
        await seedPerson(n, 'Đời $n');
        await link(n - 1, n);
      }
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final viewer = find.byType(InteractiveViewer);
      expect(
        chartExtentOn(tester).width,
        greaterThan(tester.getSize(viewer).width),
        reason: 'the case tested',
      );

      final corner = onScreen(tester, Offset.zero) - tester.getTopLeft(viewer);
      expect(corner.dx, lessThanOrEqualTo(0.5));
    });

    testWidgets('the fit button does not move a chart that already fits', (
      tester,
    ) async {
      // The complaint this answers: the chart opened against the top and
      // moved to the middle the moment the button was pressed, because
      // opening and fitting were two different rules. They are one now, so
      // for a chart that already fits there is nothing left for the button to
      // do and it does nothing at all.
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      await seedPerson(2, 'Con');
      await link(1, 2);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final view = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final before = view.value.clone();

      await tester.tap(find.byIcon(Icons.fit_screen_outlined));
      await tester.pumpAndSettle();

      expect(view.value, before);
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

    /// Taps the `+N` badge on a folded box.
    Future<void> tapBadge(WidgetTester tester, int n) async {
      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(n))!;

      await tapInChart(
        tester,
        TreePainter.foldBadgeTarget(node, layout.metrics, 40).center,
      );
    }

    testWidgets('a chart opens three generations deep, however long the line', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

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
      await facing(tester, TreeOrientation.leftToRight);

      // Three people are below the fold: Đời 4, 5 and 6.
      expect(drawnLayout(tester).nodeFor(personId(3))!.hiddenDescendantCount, 3);
    });

    testWidgets('tapping the badge reveals exactly one more generation', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
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

    /// The box of a drawn person, in the viewport's own coordinates.
    Rect? boxIn(WidgetTester tester, int n) {
      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(n));
      if (node == null) return null;

      final origin = tester.getTopLeft(find.byType(InteractiveViewer));
      final metrics = layout.metrics;

      return Rect.fromPoints(
        onScreen(tester, Offset(node.x + 40, node.y + 40)) - origin,
        onScreen(
              tester,
              Offset(
                node.x + 40 + metrics.nodeWidth,
                node.y + 40 + metrics.nodeHeight,
              ),
            ) -
            origin,
      );
    }

    bool inSight(WidgetTester tester, int n) {
      final box = boxIn(tester, n);
      if (box == null) return false;
      return (Offset.zero & tester.getSize(find.byType(InteractiveViewer)))
          .contains(box.topLeft) &&
          (Offset.zero & tester.getSize(find.byType(InteractiveViewer)))
              .contains(box.bottomRight);
    }

    testWidgets('opening a fold brings the new generation into sight', (
      tester,
    ) async {
      onAPhone(tester);
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      // The first opening lands inside the screen on its own; the second does
      // not, and is the one worth testing.
      await tapBadge(tester, 3);
      expect(inSight(tester, 4), isTrue, reason: 'the easy case');

      await tapBadge(tester, 4);

      expect(drawnLayout(tester).nodeFor(personId(5)), isNotNull);
      expect(inSight(tester, 5), isTrue);
    });

    testWidgets('and moves no further than it has to', (tester) async {
      // Brought to the edge, not to the middle. Centring on what was revealed
      // would throw away the part of the chart the reader was reading.
      onAPhone(tester);
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      await tapBadge(tester, 3);
      await tapBadge(tester, 4);

      // Across, because with the generations as columns a new one arrives to
      // the right rather than below, and the pan that fetches it is sideways.
      final viewport = tester.getSize(find.byType(InteractiveViewer));
      final box = boxIn(tester, 5)!;

      expect(box.right, closeTo(viewport.width - 16, 1));
    });

    testWidgets('it slides there rather than jumping', (tester) async {
      onAPhone(tester);
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      await tapBadge(tester, 3);

      final view = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final before = view.value.clone();

      // Tapped by hand rather than through the helper, which settles every
      // animation and would leave nothing to observe.
      final layout = drawnLayout(tester);
      await tester.tapAt(
        onScreen(
          tester,
          TreePainter.foldBadgeTarget(
            layout.nodeFor(personId(4))!,
            layout.metrics,
            40,
          ).center,
        ),
      );
      await tester.pump(kDoubleTapTimeout);
      // One more: the tap resolves during that pump but the rebuild it causes
      // lands in the next frame, and the slide starts at the end of that one.
      // Sampling any earlier reads the view before it has set off.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final midway = view.value.clone();
      await tester.pumpAndSettle();
      final arrived = view.value.clone();

      expect(midway, isNot(before), reason: 'it had set off');
      expect(midway, isNot(arrived), reason: 'and had not got there yet');
    });

    testWidgets('a hand on the chart stops the slide', (tester) async {
      // Left running it would write to the same controller as the drag, and
      // the chart would pull against the hand moving it.
      //
      // Tested with the finger still down. Lifting it ends the interaction,
      // and a chart that fits an axis settles back to the middle of it when
      // that happens — movement that is correct but would be indistinguishable
      // here from a slide that never stopped.
      onAPhone(tester);
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      await tapBadge(tester, 3);

      final viewer = find.byType(InteractiveViewer);
      final view = tester
          .widget<InteractiveViewer>(viewer)
          .transformationController!;

      final layout = drawnLayout(tester);
      await tester.tapAt(
        onScreen(
          tester,
          TreePainter.foldBadgeTarget(
            layout.nodeFor(personId(4))!,
            layout.metrics,
            40,
          ).center,
        ),
      );
      await tester.pump(kDoubleTapTimeout);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      final gesture = await tester.startGesture(
        tester.getRect(viewer).center,
      );
      // Past kTouchSlop, or the tap recogniser keeps the arena and the pan —
      // and with it the interaction the screen listens for — never begins.
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      final underTheFinger = view.value.clone();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        view.value,
        underTheFinger,
        reason: 'the slide did not carry on beneath the hand',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the zoom is left alone while doing it', (tester) async {
      onAPhone(tester);
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      final before = scaleOf(tester);

      await tapBadge(tester, 3);
      await tapBadge(tester, 4);

      // Panning, not refitting. A chart that resized under the reader would
      // be the jump this whole rule exists to avoid.
      expect(scaleOf(tester), before);
    });

    testWidgets('nothing moves when the new generation is already in sight', (
      tester,
    ) async {
      // Movement nobody asked for is what made the chart feel unsteady, so
      // where there is nothing to bring in, the view must not twitch.
      //
      // Room enough that the new column lands on screen unaided. On a phone
      // the chart already runs past the right-hand edge, so every column
      // opened arrives outside it and there is no such case to test.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final view = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      final before = view.value.clone();

      await tapBadge(tester, 3);

      expect(inSight(tester, 4), isTrue, reason: 'it arrived on screen anyway');
      expect(view.value, before);
    });

    testWidgets('the badge is painted red, to be seen', (tester) async {
      // The colour is read back off the pixels rather than off the source.
      // An earlier attempt at this changed one of the two badges and was
      // reported as having changed both, because nothing checked.
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final layout = drawnLayout(tester);
      final folded = layout.nodes.firstWhere((n) => n.hidesDescendants);
      final target = TreePainter.foldBadgeTarget(folded, layout.metrics, 40);

      // Inside the pill but clear of the digits, which are drawn white on it.
      final sampleAt = Offset(
        target.center.dx - (target.width - 8) / 2 + 3,
        target.center.dy,
      );

      final painter =
          tester.widget<CustomPaint>(chart).painter! as TreePainter;
      final recorder = PictureRecorder();
      painter.paint(
        Canvas(recorder),
        Size(layout.width + 80, layout.height + 80),
      );
      final picture = recorder.endRecording();

      late ByteData pixels;
      await tester.runAsync(() async {
        final image = await picture.toImage(
          (layout.width + 80).ceil(),
          (layout.height + 80).ceil(),
        );
        pixels = (await image.toByteData())!;
      });

      final at =
          ((sampleAt.dy.round() * (layout.width + 80).ceil()) +
              sampleAt.dx.round()) *
          4;
      final painted = Color.fromARGB(
        pixels.getUint8(at + 3),
        pixels.getUint8(at),
        pixels.getUint8(at + 1),
        pixels.getUint8(at + 2),
      );

      expect(painted, GroupedColors.red);
    });

    testWidgets('the badge takes the tap, not the box under it', (
      tester,
    ) async {
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      await tapBadge(tester, 3);

      expect(
        find.widgetWithText(FilledButton, 'Profile'),
        findsNothing,
        reason: 'opening a fold is not selecting the person in front of it',
      );
    });

    testWidgets('a new root forgets the folds opened on the old chart', (
      tester,
    ) async {
      await seedLine(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
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

    testWidgets('names each generation on the chart', (tester) async {
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      // Three drawn, counted from the thuỷ tổ.
      expect(find.text('Generation 1'), findsOneWidget);
      expect(find.text('Generation 2'), findsOneWidget);
      expect(find.text('Generation 3'), findsOneWidget);
      expect(find.text('Generation 4'), findsNothing);
    });

    testWidgets('says how many of each đời this branch holds', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= 4; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      expect(find.bySemanticsLabel('1 person'), findsOneWidget);
      expect(find.bySemanticsLabel('3 people'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('counts the branch on screen, not the whole family', (
      tester,
    ) async {
      // The fault this replaces: redrawn from somebody in the fifth đời the
      // chart held two people and the label said twenty, because it was
      // counting the family rather than the branch. A number beside a column
      // that does not match the boxes in it describes nothing the reader can
      // see.
      final semantics = tester.ensureSemantics();
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      // Six in the second đời, but only one of them has children.
      for (var n = 2; n <= 7; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
      await seedPerson(8, 'Cháu');
      await link(2, 8);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      expect(find.bySemanticsLabel('6 people'), findsOneWidget);

      // Redraw from the one with a child: this branch holds one at that đời.
      await tapPerson(tester, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('6 people'), findsNothing);
      expect(find.bySemanticsLabel('1 person'), findsNWidgets(2));

      semantics.dispose();
    });

    testWidgets('counts from the thuỷ tổ, not from the chart root', (
      tester,
    ) async {
      // The point of the whole thing. Đời thứ năm is a fact about a person;
      // redrawing from somebody lower down must not renumber everybody.
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      expect(find.text('Generation 1'), findsOneWidget);

      await tapPerson(tester, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      expect(
        find.text('Generation 1'),
        findsNothing,
        reason: 'Đời 2 is not suddenly Đời 1 for being at the top',
      );
      expect(find.text('Generation 2'), findsOneWidget);
      expect(find.text('Generation 4'), findsOneWidget);
    });

    testWidgets('a married-in spouse does not start a line of her own', (
      tester,
    ) async {
      // Every spouse who married in is parentless, so the founder cannot be
      // "the first person without parents". Entered first, she would have
      // opened the chart on herself.
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Bà Cả');
      await seedPerson(2, 'Thuỷ Tổ');
      await seedPerson(3, 'Con');
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000077',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
      await link(2, 3);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      // Her generation cannot tell the two apart — she is the root's spouse
      // either way, and a spouse shares their partner's generation. Which of
      // them the chart is rooted at can: the root is the one person not
      // offered as a new root.
      await tapPerson(tester, 1);
      expect(
        find.widgetWithText(TextButton, 'Draw from here'),
        findsOneWidget,
        reason: 'the wife is on the chart, but the line is not hers',
      );

      await tapPerson(tester, 2);
      expect(
        find.widgetWithText(TextButton, 'Draw from here'),
        findsNothing,
        reason: 'the husband is where the family is counted from',
      );
    });

    testWidgets('the labels never sit on top of each other', (tester) async {
      // The fault this replaces: every generation that had scrolled past the
      // leading edge kept its label there, so they piled into one corner and
      // read as nonsense.
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      // Sideways, where the generations run across and the chart overflows:
      // upright it fits, and a chart that fits is settled back to the middle
      // the moment the hand lets go, so the drag below would be undone and
      // nothing would ever leave the edge.
      await facing(tester, TreeOrientation.leftToRight);

      await tester.drag(
        find.byType(InteractiveViewer),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      final labels = <Rect>[
        for (var n = 1; n <= 6; n++)
          if (find.text('Generation $n').evaluate().isNotEmpty)
            tester.getRect(find.text('Generation $n')),
      ];

      for (var i = 0; i < labels.length; i++) {
        for (var j = i + 1; j < labels.length; j++) {
          expect(
            labels[i].overlaps(labels[j]),
            isFalse,
            reason: 'two đời labels are on the same spot',
          );
        }
      }
    });

    testWidgets('the labels stand beside the drawing, not over it', (
      tester,
    ) async {
      // Laid on top, a label covered the boxes at the near edge of its own
      // generation — on a descendant chart, the eldest of them.
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final viewer = tester.getRect(find.byType(InteractiveViewer));
      for (final label in <String>['Generation 1', 'Generation 2']) {
        expect(
          viewer.overlaps(tester.getRect(find.text(label))),
          isFalse,
          reason: '$label lies over the chart',
        );
      }
    });

    testWidgets('the labels do not swallow a tap meant for a box', (
      tester,
    ) async {
      onAPhone(tester);
      await seedLine(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      // The first label sits at the leading edge, over the ancestor's corner.
      await tapPerson(tester, 1);

      expect(find.widgetWithText(FilledButton, 'Profile'), findsOneWidget);
    });
  });

  group('finding the way back', () {
    Future<void> seedDescent(int depth) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Doi 1');
      for (var n = 2; n <= depth; n++) {
        await seedPerson(n, 'Doi $n');
        await link(n - 1, n);
      }
    }

    Future<void> drawFrom(WidgetTester tester, int n) async {
      await tapPerson(tester, n);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();
    }

    testWidgets('is not offered before there is anywhere to go', (
      tester,
    ) async {
      onAPhone(tester);
      await seedDescent(6);
      await openTree(tester);

      expect(find.byIcon(Icons.undo), findsNothing);
    });

    testWidgets('sits between the way out and the title', (tester) async {
      // Two ways back, in the order they undo things: the outer one leaves
      // the chart, the inner one steps back through the branches within it.
      onAPhone(tester);
      await seedDescent(6);

      // Pushed rather than opened as the first screen, because the way out of
      // the chart only exists when there is something to go back to — and
      // that is the button this one has to sit beside.
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            initialRoute: '/tree',
            routes: <String, WidgetBuilder>{
              '/': (_) => const Scaffold(),
              '/tree': (_) => const TreeScreen(familyId: familyId),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await drawFrom(tester, 2);

      final out = tester.getRect(find.byIcon(Icons.chevron_left));
      final back = tester.getRect(find.byIcon(Icons.undo));
      final title = tester.getRect(find.text('Family tree'));

      expect(back.left, greaterThan(out.right));
      expect(back.right, lessThan(title.left));

      // And spaced as the pair on the right are. The leading slot does not
      // give its children the tap target an action button carries, so without
      // putting it back by hand the two sides sit differently.
      final turn = tester.getRect(
        find.byIcon(Icons.rotate_90_degrees_cw_outlined),
      );
      final fit = tester.getRect(find.byIcon(Icons.fit_screen_outlined));

      expect(back.left - out.right, closeTo(fit.left - turn.right, 0.5));
    });

    testWidgets('returns to the branch drawn before', (tester) async {
      onAPhone(tester);
      await seedDescent(6);
      await openTree(tester);
      expect(drawnLayout(tester).nodeFor(personId(1)), isNotNull);

      await drawFrom(tester, 2);
      expect(drawnLayout(tester).nodeFor(personId(1)), isNull);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      expect(drawnLayout(tester).nodeFor(personId(1)), isNotNull);
    });

    testWidgets('goes back one branch at a time', (tester) async {
      onAPhone(tester);
      await seedDescent(8);
      await openTree(tester);
      await drawFrom(tester, 2);
      await drawFrom(tester, 3);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(
        drawnLayout(tester).nodeFor(personId(2)),
        isNotNull,
        reason: 'the branch before last, not all the way home',
      );

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(drawnLayout(tester).nodeFor(personId(1)), isNotNull);
      expect(
        find.byIcon(Icons.undo),
        findsNothing,
        reason: 'and stops being offered once there is nowhere left',
      );
    });

    testWidgets('a double tap on a box is what it undoes', (tester) async {
      // The gesture that made the button necessary: it moves the chart
      // somewhere else with no obvious way of moving back.
      onAPhone(tester);
      await seedDescent(6);
      await openTree(tester);

      final layout = drawnLayout(tester);
      final node = layout.nodeFor(personId(2))!;
      final at = onScreen(
        tester,
        Offset(
          node.x + 40 + layout.metrics.nodeWidth / 2,
          node.y + 40 + layout.metrics.nodeHeight / 2,
        ),
      );
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(drawnLayout(tester).nodeFor(personId(1)), isNull);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();

      expect(drawnLayout(tester).nodeFor(personId(1)), isNotNull);
    });
  });

  group('not letting the chart get lost', () {
    Future<void> seedWide(WidgetTester tester, int children) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      for (var n = 2; n <= children + 1; n++) {
        await seedPerson(n, 'Con $n');
        await link(1, n);
      }
    }

    double minScaleOf(WidgetTester tester) =>
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).minScale;

    Offset offsetOf(WidgetTester tester) {
      final at = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value
          .getTranslation();
      return Offset(at.x, at.y);
    }

    testWidgets('zooming out stops where the whole chart is visible', (
      tester,
    ) async {
      onAPhone(tester);
      await seedWide(tester, 12);
      await openTree(tester);

      // Past this there is nothing further to see, only a smaller drawing in
      // a larger emptiness.
      expect(minScaleOf(tester), closeTo(wholeChartScale(tester), 0.001));
      expect(minScaleOf(tester), lessThan(1), reason: 'the case being tested');
    });

    testWidgets('a chart that already fits cannot be zoomed out at all', (
      tester,
    ) async {
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      await seedPerson(2, 'Con');
      await link(1, 2);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      expect(minScaleOf(tester), 1);
    });

    testWidgets('a chart shoved aside settles back to the middle', (
      tester,
    ) async {
      onAPhone(tester);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Thuỷ Tổ');
      await seedPerson(2, 'Con');
      await link(1, 2);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final settled = offsetOf(tester);
      await tester.drag(find.byType(InteractiveViewer), const Offset(-60, -40));
      await tester.pumpAndSettle();

      expect(offsetOf(tester), settled);
    });

    testWidgets('a chart bigger than the screen is left where it was put', (
      tester,
    ) async {
      // There is more of it to look at in every direction, so pulling the
      // reader back would be taking the chart away from them.
      onAPhone(tester);
      await seedWide(tester, 12);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final before = offsetOf(tester);
      await tester.drag(find.byType(InteractiveViewer), const Offset(-60, 0));
      await tester.pumpAndSettle();

      final after = offsetOf(tester);
      expect(after.dx, lessThan(before.dx), reason: 'the drag took effect');
      expect(
        after.dx,
        isNot(closeTo(before.dx, 0.5)),
        reason: 'and was not undone the moment the hand let go',
      );
    });

    testWidgets('a tap settles nothing, having moved nothing', (tester) async {
      // A tap ends an interaction like any other gesture. Sliding the chart
      // because somebody touched it is the unasked-for movement this screen
      // has been getting rid of.
      onAPhone(tester);
      await seedWide(tester, 12);
      await openTree(tester);

      await tester.drag(find.byType(InteractiveViewer), const Offset(-60, 0));
      await tester.pumpAndSettle();
      final shoved = offsetOf(tester);

      await tapPerson(tester, 1);

      expect(offsetOf(tester), shoved);
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

    testWidgets('a chart keeps its bearing as the reader moves about', (
      tester,
    ) async {
      // Twelve abreast opens sideways. Redraw from one of them and that
      // branch is a single person, which measured on its own would be drawn
      // upright — and the page would turn under the reader between one
      // generation and the next.
      await seedWide(12);
      await openTree(tester);
      expect(orientationOf(tester), TreeOrientation.leftToRight);

      await tapPerson(tester, 2);
      await tester.tap(find.widgetWithText(TextButton, 'Draw from here'));
      await tester.pumpAndSettle();

      expect(drawnLayout(tester).nodeFor(personId(1)), isNull);
      expect(orientationOf(tester), TreeOrientation.leftToRight);
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

    testWidgets('with the generations as rows it opens five deep', (
      tester,
    ) async {
      // Deeper than the columns, because rows are read along their length and
      // five of them is a stretch of the line. What the extra two cost is
      // recorded on `_visibleGenerationsDown`: a thousand people come to
      // sixty-one screens across rather than twenty-six.
      await seedDeep(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.topDown);

      final layout = drawnLayout(tester);
      for (var n = 1; n <= 5; n++) {
        expect(layout.nodeFor(personId(n)), isNotNull, reason: 'Đời $n');
      }
      expect(layout.nodeFor(personId(6)), isNull);
      expect(layout.nodeFor(personId(5))!.hiddenDescendantCount, 2);
    });

    testWidgets('with the generations as columns it opens three deep', (
      tester,
    ) async {
      // The two no longer fold alike, and this is the half that does.
      await seedDeep(6);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);

      final layout = drawnLayout(tester);
      expect(layout.nodeFor(personId(3)), isNotNull);
      expect(layout.nodeFor(personId(4)), isNull);
      expect(layout.nodeFor(personId(3))!.hiddenDescendantCount, 3);
    });

    testWidgets('turning the page opens what was folded, and back', (
      tester,
    ) async {
      // Đời 5 is the probe: past the columns' three, within the rows' five.
      await seedDeep(7);
      await openTree(tester);
      await facing(tester, TreeOrientation.leftToRight);
      expect(drawnLayout(tester).nodeFor(personId(5)), isNull);

      await facing(tester, TreeOrientation.topDown);
      expect(drawnLayout(tester).nodeFor(personId(5)), isNotNull);

      await facing(tester, TreeOrientation.leftToRight);
      expect(
        drawnLayout(tester).nodeFor(personId(5)),
        isNull,
        reason: 'the shallower fold comes back with the columns',
      );
    });

    testWidgets('neither way shows a generation past its own fold', (
      tester,
    ) async {
      // Đời 7 is past both, so turning the page does not reach it; the reader
      // opens a fold or redraws from further down.
      await seedDeep(7);
      await openTree(tester);

      for (final orientation in TreeOrientation.values) {
        await facing(tester, orientation);
        expect(
          drawnLayout(tester).nodeFor(personId(7)),
          isNull,
          reason: orientation.name,
        );
      }
    });
  });
}
