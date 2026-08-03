import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/lunar/astronomy.dart';
import 'package:ftree/domain/lunar/lunar_conversion.dart';

import '../../support/lunar_reference.dart';

void main() {
  group('Tết reference dates (PROVISIONAL)', () {
    test('lunar new year matches the reference table', () {
      for (final entry in tetDates.entries) {
        final (day, month, year) = lunarNewYear(entry.key);
        expect(
          (day, month, year),
          (entry.value.$1, entry.value.$2, entry.key),
          reason: 'Tết ${entry.key}',
        );
      }
    });

    test('the day before Tết is the last day of the previous lunar year', () {
      for (final entry in tetDates.entries) {
        final tet = julianDayFromDate(
          entry.value.$1,
          entry.value.$2,
          entry.key,
        );
        final (day, month, year) = dateFromJulianDay(tet - 1);
        final lunar = solarToLunar(day, month, year);

        expect(lunar.month, 12, reason: 'eve of Tết ${entry.key}');
        expect(lunar.year, entry.key - 1);
      }
    });

    test('Tết itself converts back to lunar 1/1', () {
      for (final entry in tetDates.entries) {
        final lunar = solarToLunar(
          entry.value.$1,
          entry.value.$2,
          entry.key,
        );
        expect(lunar.day, 1, reason: 'Tết ${entry.key}');
        expect(lunar.month, 1);
        expect(lunar.year, entry.key);
      }
    });
  });

  group('round trip', () {
    test('every day across forty years survives both conversions', () {
      // Independent of the reference table: catches internal inconsistency
      // even if the calibration is off.
      final start = julianDayFromDate(1, 1, 1990);
      final end = julianDayFromDate(31, 12, 2030);

      for (var jd = start; jd <= end; jd++) {
        final (day, month, year) = dateFromJulianDay(jd);
        final lunar = solarToLunar(day, month, year);
        final back = lunarToSolar(
          lunar.day,
          lunar.month,
          lunar.year,
          isLeapMonth: lunar.isLeapMonth,
        );

        expect(
          back,
          (day, month, year),
          reason: '$year-$month-$day -> $lunar -> $back',
        );
      }
    });
  });

  group('structural properties', () {
    test('lunar day numbers stay within 1..30', () {
      final start = julianDayFromDate(1, 1, 1990);
      for (var offset = 0; offset < 15000; offset++) {
        final (day, month, year) = dateFromJulianDay(start + offset);
        final lunar = solarToLunar(day, month, year);

        expect(lunar.day, inInclusiveRange(1, 30));
        expect(lunar.month, inInclusiveRange(1, 12));
      }
    });

    test('a lunar year has twelve or thirteen months', () {
      for (var year = 1990; year <= 2030; year++) {
        final thisTet = julianDayFromDate(
          lunarNewYear(year).$1,
          lunarNewYear(year).$2,
          lunarNewYear(year).$3,
        );
        final nextTet = julianDayFromDate(
          lunarNewYear(year + 1).$1,
          lunarNewYear(year + 1).$2,
          lunarNewYear(year + 1).$3,
        );

        final length = nextTet - thisTet;
        final hasLeap = leapMonthOf(year) != null;

        if (hasLeap) {
          expect(length, inInclusiveRange(383, 385), reason: 'leap year $year');
        } else {
          expect(
            length,
            inInclusiveRange(353, 355),
            reason: 'ordinary year $year',
          );
        }
      }
    });

    test('lunar months run 29 or 30 days', () {
      for (var year = 2000; year <= 2030; year++) {
        for (var month = 1; month <= 12; month++) {
          final first = julianDayFromDate(
            lunarToSolar(1, month, year).$1,
            lunarToSolar(1, month, year).$2,
            lunarToSolar(1, month, year).$3,
          );
          final (nd, nm, ny) = month == 12
              ? lunarToSolar(1, 1, year + 1)
              : lunarToSolar(1, month + 1, year);
          final next = julianDayFromDate(nd, nm, ny);

          // A leap month sits between them when present, so allow for it.
          final gap = next - first;
          expect(
            gap,
            anyOf(29, 30, 58, 59, 60),
            reason: 'lunar $year-$month spanned $gap days',
          );
        }
      }
    });
  });

  group('leap months', () {
    test('are found in some years and not others', () {
      var leapYears = 0;
      for (var year = 1990; year <= 2030; year++) {
        if (leapMonthOf(year) != null) leapYears++;
      }
      // Seven leap years in every nineteen is the Metonic cycle.
      expect(leapYears, inInclusiveRange(13, 17));
    });

    test('a leap month converts and round-trips', () {
      // Reaches past 2030 on purpose: a leap month 11 is anchored to a
      // different month-11 window than months 1-10, and 2034 is the nearest
      // year that exercises it.
      for (var year = 1990; year <= 2040; year++) {
        final leap = leapMonthOf(year);
        if (leap == null) continue;

        final (day, month, gregorianYear) = lunarToSolar(
          1,
          leap,
          year,
          isLeapMonth: true,
        );
        final back = solarToLunar(day, month, gregorianYear);

        expect(back.isLeapMonth, isTrue, reason: 'leap month $leap of $year');
        expect(back.month, leap);
        expect(back.day, 1);
      }
    });

    test('an ordinary month and its leap twin are different days', () {
      // Reaches past 2030 on purpose: a leap month 11 is anchored to a
      // different month-11 window than months 1-10, and 2034 is the nearest
      // year that exercises it.
      for (var year = 1990; year <= 2040; year++) {
        final leap = leapMonthOf(year);
        if (leap == null) continue;

        final ordinary = lunarToSolar(1, leap, year);
        final intercalary = lunarToSolar(1, leap, year, isLeapMonth: true);

        expect(ordinary, isNot(intercalary), reason: 'year $year');
      }
    });

    test('asking for a leap month a year does not have is rejected', () {
      final ordinaryYear = <int>[
        for (var y = 1990; y <= 2030; y++)
          if (leapMonthOf(y) == null) y,
      ].first;

      expect(
        () => lunarToSolar(1, 3, ordinaryYear, isLeapMonth: true),
        throwsArgumentError,
      );
    });

    test('hasLeapMonth agrees with leapMonthOf', () {
      for (var year = 1990; year <= 2030; year++) {
        final leap = leapMonthOf(year);
        for (var month = 1; month <= 12; month++) {
          expect(hasLeapMonth(year, month), month == leap);
        }
      }
    });
  });

  group('time zone', () {
    test('UTC+7 and UTC+8 disagree on some dates', () {
      // The reason a Chinese implementation cannot be reused unchecked.
      var differences = 0;
      final start = julianDayFromDate(1, 1, 1990);

      for (var offset = 0; offset < 15000; offset++) {
        final (day, month, year) = dateFromJulianDay(start + offset);
        final vietnam = solarToLunar(day, month, year, timeZone: 7);
        final china = solarToLunar(day, month, year, timeZone: 8);
        if (vietnam != china) differences++;
      }

      expect(differences, greaterThan(0));
    });
  });
}
