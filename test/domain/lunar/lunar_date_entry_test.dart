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
