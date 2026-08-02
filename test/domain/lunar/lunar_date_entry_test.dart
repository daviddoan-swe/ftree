import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/lunar/lunar_conversion.dart';
import 'package:ftree/domain/lunar/lunar_date_entry.dart';

void main() {
  group('a complete lunar date', () {
    test('converts exactly and keeps day precision', () {
      final lunar = LunarDate(year: 1960, month: 3, day: 12);
      final result = gregorianFromLunarEntry(lunar);

      expect(result.precision, DatePrecision.day);
      expect(result.isApproximate, isFalse);

      // The stored Gregorian value really is that lunar day.
      final back = solarToLunar(result.day!, result.month!, result.year);
      expect(back.day, 12);
      expect(back.month, 3);
      expect(back.year, 1960);
    });

    test('keeps the caller’s approximate flag', () {
      final result = gregorianFromLunarEntry(
        LunarDate(year: 1960, month: 3, day: 12),
        isApproximate: true,
      );
      expect(result.isApproximate, isTrue);
    });
  });

  group('a lunar year and month', () {
    test('lands in the Gregorian month that lunar month begins in', () {
      final result = gregorianFromLunarEntry(LunarDate(year: 1960, month: 3));
      final firstOfMonth = lunarToSolar(1, 3, 1960);

      expect(result.year, firstOfMonth.$3);
      expect(result.month, firstOfMonth.$2);
      expect(result.precision, DatePrecision.month);
    });

    test('is marked approximate, because the day is unknown', () {
      final result = gregorianFromLunarEntry(LunarDate(year: 1960, month: 3));
      expect(result.isApproximate, isTrue);
    });
  });

  group('a lunar year alone', () {
    test('becomes the Gregorian year its Tết falls in', () {
      // The common case in an old gia phả: năm Đinh Hợi and nothing more.
      for (final year in <int>[1887, 1960, 2024]) {
        final result = gregorianFromLunarEntry(LunarDate(year: year));
        expect(result.year, lunarNewYear(year).$3, reason: '$year');
        expect(result.precision, DatePrecision.year);
      }
    });

    test('is marked approximate, because a lunar year spans two', () {
      final result = gregorianFromLunarEntry(LunarDate(year: 1887));
      expect(result.isApproximate, isTrue);
    });
  });

  group('lunarReadingOf', () {
    test('prefers what the source recorded over anything computed', () {
      // A recorded reading says what the document said. Even a deliberately
      // wrong one must not be quietly replaced by a conversion.
      final recorded = LunarDate(year: 1200, month: 1, day: 1);
      final date = GenealogicalDate(
        year: 1960,
        month: 4,
        day: 5,
        lunar: recorded,
      );

      expect(lunarReadingOf(date), recorded);
    });

    test('derives one from a complete Gregorian date', () {
      final date = GenealogicalDate(year: 1960, month: 4, day: 5);
      final reading = lunarReadingOf(date)!;
      final expected = solarToLunar(5, 4, 1960);

      expect(reading.year, expected.year);
      expect(reading.month, expected.month);
      expect(reading.day, expected.day);
    });

    test('has nothing to show for a partial date', () {
      // Converting would mean inventing the missing parts, the same mistake as
      // storing a year-only date as 1 January.
      expect(lunarReadingOf(GenealogicalDate(year: 1960)), isNull);
      expect(lunarReadingOf(GenealogicalDate(year: 1960, month: 4)), isNull);
    });

    test('round-trips a date that was entered as lunar', () {
      final entered = LunarDate(year: 1960, month: 3, day: 12);
      final stored = gregorianFromLunarEntry(entered);

      expect(lunarReadingOf(stored), entered);
    });
  });

  group('the lunar reading', () {
    test('is carried through untouched at every precision', () {
      // It records what the source said. Nothing derived may overwrite it.
      final dates = <LunarDate>[
        LunarDate(year: 1887),
        LunarDate(year: 1887, month: 3),
        LunarDate(year: 1887, month: 3, day: 12),
      ];

      for (final lunar in dates) {
        expect(gregorianFromLunarEntry(lunar).lunar, lunar, reason: '$lunar');
      }
    });

    test('keeps an intercalary month even when the year has one', () {
      final leapYear = <int>[
        for (var y = 2015; y <= 2035; y++)
          if (leapMonthOf(y) != null) y,
      ].first;
      final leapMonth = leapMonthOf(leapYear)!;

      final lunar = LunarDate(
        year: leapYear,
        month: leapMonth,
        day: 5,
        isLeapMonth: true,
      );
      final result = gregorianFromLunarEntry(lunar);

      expect(result.lunar, lunar);
      expect(solarToLunar(result.day!, result.month!, result.year).isLeapMonth,
          isTrue);
    });

    test('survives a leap month the year does not have', () {
      // lunarToSolar refuses that outright. Falling back to the ordinary month
      // matches what families do, and the annotation still says what was typed.
      final plainYear = <int>[
        for (var y = 2015; y <= 2035; y++)
          if (leapMonthOf(y) == null) y,
      ].first;

      final lunar = LunarDate(
        year: plainYear,
        month: 3,
        day: 5,
        isLeapMonth: true,
      );

      expect(() => gregorianFromLunarEntry(lunar), returnsNormally);
      expect(gregorianFromLunarEntry(lunar).lunar, lunar);
    });
  });
}
