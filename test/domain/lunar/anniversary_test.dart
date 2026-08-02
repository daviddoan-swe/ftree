import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/lunar/anniversary.dart';
import 'package:ftree/domain/lunar/lunar_conversion.dart';

void main() {
  group('the ordinary case', () {
    test('lands on the recorded lunar date, unadjusted', () {
      for (var year = 2020; year <= 2035; year++) {
        final result = anniversaryIn(
          lunarDay: 12,
          lunarMonth: 3,
          isLeapMonth: false,
          inLunarYear: year,
        );

        expect(result.adjustment, AnniversaryAdjustment.none);

        final back = solarToLunar(result.day, result.month, result.year);
        expect(back.day, 12, reason: 'year $year');
        expect(back.month, 3);
        expect(back.isLeapMonth, isFalse);
      }
    });

    test('moves through the Gregorian calendar from year to year', () {
      // The whole point: a fixed lunar date is a moving Gregorian one.
      final dates = <(int, int)>{
        for (var year = 2020; year <= 2030; year++)
          () {
            final a = anniversaryIn(
              lunarDay: 12,
              lunarMonth: 3,
              isLeapMonth: false,
              inLunarYear: year,
            );
            return (a.day, a.month);
          }(),
      };

      expect(dates.length, greaterThan(5));
    });

    test('a late lunar month can fall in the next Gregorian year', () {
      // Lunar month 12 runs into January or February, so the anniversary of a
      // lunar year lands in the Gregorian year after it.
      final result = anniversaryIn(
        lunarDay: 20,
        lunarMonth: 12,
        isLeapMonth: false,
        inLunarYear: 2025,
      );

      expect(result.year, 2026);
      expect(result.adjustment, AnniversaryAdjustment.none);
    });
  });

  group('a year without the intercalary month', () {
    test('falls back to the ordinary month and says so', () {
      // Families keep the rite in the ordinary month when the leap one is
      // absent, so this is an adjustment rather than a failure.
      final leapYear = <int>[
        for (var y = 2015; y <= 2035; y++)
          if (leapMonthOf(y) != null) y,
      ].first;
      final leapMonth = leapMonthOf(leapYear)!;

      final plainYear = <int>[
        for (var y = 2015; y <= 2035; y++)
          if (leapMonthOf(y) != leapMonth) y,
      ].first;

      final result = anniversaryIn(
        lunarDay: 10,
        lunarMonth: leapMonth,
        isLeapMonth: true,
        inLunarYear: plainYear,
      );

      expect(result.adjustment, AnniversaryAdjustment.leapMonthUnavailable);

      final back = solarToLunar(result.day, result.month, result.year);
      expect(back.month, leapMonth);
      expect(back.isLeapMonth, isFalse);
    });

    test('uses the intercalary month when the year does have it', () {
      final leapYear = <int>[
        for (var y = 2015; y <= 2035; y++)
          if (leapMonthOf(y) != null) y,
      ].first;
      final leapMonth = leapMonthOf(leapYear)!;

      final result = anniversaryIn(
        lunarDay: 10,
        lunarMonth: leapMonth,
        isLeapMonth: true,
        inLunarYear: leapYear,
      );

      expect(result.adjustment, AnniversaryAdjustment.none);

      final back = solarToLunar(result.day, result.month, result.year);
      expect(back.isLeapMonth, isTrue);
      expect(back.month, leapMonth);
    });

    test('never throws for a leap month the year lacks', () {
      // lunarToSolar rejects that outright; the anniversary layer exists partly
      // to turn it into something a family can act on.
      for (var year = 2015; year <= 2035; year++) {
        for (var month = 1; month <= 12; month++) {
          expect(
            () => anniversaryIn(
              lunarDay: 1,
              lunarMonth: month,
              isLeapMonth: true,
              inLunarYear: year,
            ),
            returnsNormally,
            reason: 'leap month $month of $year',
          );
        }
      }
    });
  });

  group('a month with no thirtieth day', () {
    test('falls back to the twenty-ninth and says so', () {
      var adjusted = 0;
      var exact = 0;

      for (var year = 2015; year <= 2035; year++) {
        for (var month = 1; month <= 12; month++) {
          final result = anniversaryIn(
            lunarDay: 30,
            lunarMonth: month,
            isLeapMonth: false,
            inLunarYear: year,
          );

          final back = solarToLunar(result.day, result.month, result.year);
          expect(back.month, month, reason: 'lunar $year-$month');

          if (result.adjustment == AnniversaryAdjustment.monthTooShort) {
            expect(back.day, 29);
            adjusted++;
          } else {
            expect(back.day, 30);
            exact++;
          }
        }
      }

      // Roughly half of lunar months are short, so both branches must occur.
      expect(adjusted, greaterThan(0));
      expect(exact, greaterThan(0));
    });

    test('a day that always exists is never adjusted', () {
      for (var year = 2015; year <= 2035; year++) {
        for (var month = 1; month <= 12; month++) {
          final result = anniversaryIn(
            lunarDay: 15,
            lunarMonth: month,
            isLeapMonth: false,
            inLunarYear: year,
          );
          expect(result.adjustment, AnniversaryAdjustment.none);
        }
      }
    });
  });

  group('anniversaryOfDeath', () {
    test('the first anniversary of a death converts back to the same lunar '
        'date', () {
      final death = anniversaryOfDeath(
        deathDay: 5,
        deathMonth: 4,
        deathYear: 1960,
        inLunarYear: 1960,
      );
      final lunarOfDeath = solarToLunar(5, 4, 1960);

      final back = solarToLunar(death.day, death.month, death.year);
      expect(back.day, lunarOfDeath.day);
      expect(back.month, lunarOfDeath.month);
    });

    test('recurs on the same lunar date across many years', () {
      final lunarOfDeath = solarToLunar(5, 4, 1960);

      for (var year = 2020; year <= 2035; year++) {
        final result = anniversaryOfDeath(
          deathDay: 5,
          deathMonth: 4,
          deathYear: 1960,
          inLunarYear: year,
        );
        final back = solarToLunar(result.day, result.month, result.year);

        expect(back.month, lunarOfDeath.month, reason: 'year $year');
        if (result.adjustment == AnniversaryAdjustment.none) {
          expect(back.day, lunarOfDeath.day);
        }
      }
    });
  });

  group('argument checking', () {
    test('rejects impossible lunar days and months', () {
      expect(
        () => anniversaryIn(
          lunarDay: 31,
          lunarMonth: 3,
          isLeapMonth: false,
          inLunarYear: 2026,
        ),
        throwsArgumentError,
      );
      expect(
        () => anniversaryIn(
          lunarDay: 0,
          lunarMonth: 3,
          isLeapMonth: false,
          inLunarYear: 2026,
        ),
        throwsArgumentError,
      );
      expect(
        () => anniversaryIn(
          lunarDay: 12,
          lunarMonth: 13,
          isLeapMonth: false,
          inLunarYear: 2026,
        ),
        throwsArgumentError,
      );
    });
  });
}
