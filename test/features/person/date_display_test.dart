/// What a reader is shown of a date that is only partly known (DOMAIN.md §4).
///
/// The domain's half of this — comparing partial dates, refusing to order what
/// cannot be ordered — has been tested since M2. This is the other half, and
/// the one a reader actually sees. A date stored to the year and displayed as
/// `1887-01-01` would be a loss of precision nobody would ever notice: the
/// record would still be right and the screen would still be wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/features/person/date_display.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  /// Runs [read] inside a built application, so the localisations are real.
  ///
  /// These functions take a [BuildContext] because the wording is translated,
  /// and a fake context would test a different function than the one that
  /// ships.
  Future<String?> shown(
    WidgetTester tester,
    String? Function(BuildContext context) read,
  ) async {
    String? answer;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        home: Builder(
          builder: (context) {
            answer = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return answer;
  }

  group('the Gregorian reading', () {
    testWidgets('a year and nothing more is shown as a year', (tester) async {
      // The whole point of the type. A formatter handed this date would have
      // to invent a month and a day to render it at all.
      expect(
        await shown(
          tester,
          (c) => formatDate(c, GenealogicalDate(year: 1887)),
        ),
        '1887',
      );
    });

    testWidgets('a year and a month stop at the month', (tester) async {
      expect(
        await shown(
          tester,
          (c) => formatDate(c, GenealogicalDate(year: 1887, month: 3)),
        ),
        '1887-03',
      );
    });

    testWidgets('a full date is shown in full', (tester) async {
      expect(
        await shown(
          tester,
          (c) => formatDate(
            c,
            GenealogicalDate(year: 1887, month: 3, day: 5),
          ),
        ),
        '1887-03-05',
      );
    });

    testWidgets('an approximate date says so', (tester) async {
      // "about 1890" is a different claim from "1890", and the record kept
      // them apart. Dropping the word on the way to the screen would quietly
      // upgrade a guess into a fact.
      expect(
        await shown(
          tester,
          (c) => formatDate(
            c,
            GenealogicalDate(year: 1890, isApproximate: true),
          ),
        ),
        'about 1890',
      );
    });

    testWidgets('an unknown date is named rather than left blank', (
      tester,
    ) async {
      // Blank would read as a field somebody forgot to fill in. "Unknown" is
      // what the record says, and often all it will ever say.
      expect(await shown(tester, (c) => formatDate(c, null)), 'Unknown');
    });

    testWidgets('an early year keeps four digits', (tester) async {
      // A gia phả reaches back past the year a thousand. `987` sorts before
      // `1000` as text only if it is written `0987`.
      expect(
        await shown(
          tester,
          (c) => formatDate(c, GenealogicalDate(year: 987)),
        ),
        '0987',
      );
    });
  });

  group('the lunar reading beside it', () {
    /// A day-precision date, which is the only kind that can be converted.
    final exact = GenealogicalDate(year: 1887, month: 3, day: 5);

    testWidgets('is absent for a family that does not keep the calendar', (
      tester,
    ) async {
      // The setting travels with the tree, so a relative reading in another
      // language sees the same thing (DOMAIN.md §4.4).
      expect(
        await shown(
          tester,
          (c) => formatLunar(c, exact, usesLunarCalendar: false),
        ),
        isNull,
      );
    });

    testWidgets('is absent for a date with no day', (tester) async {
      // A conversion needs a day. Showing a lunar year derived from a solar
      // year alone would be arithmetic the record does not support.
      expect(
        await shown(
          tester,
          (c) => formatLunar(
            c,
            GenealogicalDate(year: 1887, month: 3),
            usesLunarCalendar: true,
          ),
        ),
        isNull,
      );
    });

    testWidgets('is absent when there is no date at all', (tester) async {
      expect(
        await shown(
          tester,
          (c) => formatLunar(c, null, usesLunarCalendar: true),
        ),
        isNull,
      );
    });

    testWidgets('converts a day-precision date and marks it lunar', (
      tester,
    ) async {
      // The suffix is the whole safety of the feature: two calendars on one
      // screen, and a number that does not say which it belongs to is a
      // number that will be read as the wrong one.
      final reading = await shown(
        tester,
        (c) => formatLunar(c, exact, usesLunarCalendar: true),
      );

      expect(reading, endsWith(' lunar'));
      expect(reading, startsWith('1887-02-11'));
    });

    testWidgets('a recorded lunar date is shown rather than recomputed', (
      tester,
    ) async {
      // What the family wrote down beats what the converter would derive.
      // A giỗ is kept by the lunar date, and the solar one beside it is the
      // derived half, not the authority.
      expect(
        await shown(
          tester,
          (c) => formatLunar(
            c,
            GenealogicalDate(
              year: 1887,
              month: 3,
              day: 5,
              lunar: LunarDate(year: 1886, month: 12, day: 30),
            ),
            usesLunarCalendar: true,
          ),
        ),
        '1886-12-30 lunar',
      );
    });

    testWidgets('a leap month is marked', (tester) async {
      // Without the mark, the fourth month and the leap fourth month of the
      // same year read as the same date — and a giỗ kept in one would be
      // observed a month out.
      expect(
        await shown(
          tester,
          (c) => formatLunar(
            c,
            GenealogicalDate(
              year: 1887,
              month: 3,
              day: 5,
              lunar: LunarDate(
                year: 1887,
                month: 4,
                day: 2,
                isLeapMonth: true,
              ),
            ),
            usesLunarCalendar: true,
          ),
        ),
        '1887-04N-02 lunar',
      );
    });

    testWidgets('a lunar date known only to the month stops there', (
      tester,
    ) async {
      expect(
        await shown(
          tester,
          (c) => formatLunar(
            c,
            GenealogicalDate(
              year: 1887,
              lunar: LunarDate(year: 1887, month: 4),
            ),
            usesLunarCalendar: true,
          ),
        ),
        '1887-04 lunar',
      );
    });

    testWidgets('a lunar date known only to the year stops there', (
      tester,
    ) async {
      expect(
        await shown(
          tester,
          (c) => formatLunar(
            c,
            GenealogicalDate(
              year: 1887,
              lunar: LunarDate(year: 1887),
            ),
            usesLunarCalendar: true,
          ),
        ),
        '1887 lunar',
      );
    });
  });
}
