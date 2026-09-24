/// Where the controls that qualify a date sit (DOMAIN.md §4).
///
/// The boxes themselves are exercised through the person form. What is checked
/// here is the arrangement, because it carries meaning: everything that says
/// *what kind of date this is* — approximate, and which calendar — belongs
/// above the boxes, since both change what the numbers below them mean.
///
/// A reader who types 1887 and only then finds the calendar switch has already
/// entered the wrong date once.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/features/person/partial_date_field.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  Future<void> show(WidgetTester tester, {bool allowLunar = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PartialDateField(
              allowLunar: allowLunar,
              onChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect approximate(WidgetTester tester) => tester.getRect(
    find.ancestor(of: find.text('About'), matching: find.byType(Row)).first,
  );

  Rect calendar(WidgetTester tester) =>
      tester.getRect(find.byType(SegmentedButton<bool>));

  Rect yearBox(WidgetTester tester) =>
      tester.getRect(find.widgetWithText(TextField, 'Year'));

  group('what qualifies the date sits above it', () {
    testWidgets('“About” is above the boxes, not below them', (tester) async {
      // It used to sit underneath, where it read as an afterthought to a date
      // already typed rather than as part of describing one.
      await show(tester);

      expect(approximate(tester).bottom, lessThan(yearBox(tester).top));
    });

    testWidgets('the calendar switch is above them too', (tester) async {
      await show(tester);

      expect(calendar(tester).bottom, lessThan(yearBox(tester).top));
    });

    testWidgets('and the two share one row', (tester) async {
      await show(tester);

      expect(
        approximate(tester).center.dy,
        moreOrLessEquals(calendar(tester).center.dy, epsilon: 4),
      );
    });
  });

  group('one goes left, the other right', () {
    testWidgets('“About” stays on the left', (tester) async {
      await show(tester);

      // Against the same edge the boxes below start at, so the column of
      // things being read reads as a column.
      expect(
        approximate(tester).left,
        lessThanOrEqualTo(yearBox(tester).left + 1),
      );
    });

    testWidgets('the calendar switch is pushed to the right', (tester) async {
      // Its own edge, because it changes what every box below it means — that
      // is worth more than a place in a queue.
      await show(tester);

      final field = tester.getRect(find.byType(PartialDateField));

      expect(calendar(tester).right, moreOrLessEquals(field.right, epsilon: 1));
      expect(calendar(tester).left, greaterThan(approximate(tester).right));
    });

    testWidgets('without the lunar calendar, “About” is still on the left', (
      tester,
    ) async {
      await show(tester, allowLunar: false);

      expect(find.byType(SegmentedButton<bool>), findsNothing);
      expect(
        approximate(tester).left,
        lessThanOrEqualTo(yearBox(tester).left + 1),
      );
      expect(approximate(tester).bottom, lessThan(yearBox(tester).top));
    });
  });

  group('the leap month is a different kind of thing', () {
    testWidgets('it is absent until the lunar calendar is chosen', (
      tester,
    ) async {
      // It qualifies the month box rather than the date as a whole, and in the
      // Gregorian calendar it means nothing at all.
      await show(tester);

      expect(find.text('Leap'), findsNothing);
    });

    testWidgets('and it stays below the boxes, where the month is', (
      tester,
    ) async {
      await show(tester);

      await tester.tap(find.text('Lunar'));
      await tester.pumpAndSettle();

      expect(find.text('Leap'), findsOneWidget);
      expect(
        tester.getRect(find.text('Leap')).top,
        greaterThan(yearBox(tester).bottom),
      );
    });
  });

  // There is no test here for a narrow screen, deliberately. The test
  // environment renders every glyph as a square of the font size, so
  // "Gregorian | Lunar" comes to some 292 points where a real device draws it
  // in about 200 — the switch alone overflows a 320-point screen here and fits
  // comfortably there. A test of that measures the test font, not the layout.
  // The word beside the tick is free to shrink, and the fit is checked on a
  // simulator instead.
}
