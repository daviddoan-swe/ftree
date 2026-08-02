import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/lunar/astronomy.dart';

void main() {
  group('julianDayFromDate', () {
    test('matches well-known Julian Day Numbers', () {
      // These are fixed points of the Julian day system, independent of any
      // calendar library, so they calibrate the conversion itself.
      expect(julianDayFromDate(1, 1, 2000), 2451545); // J2000.0
      expect(julianDayFromDate(1, 1, 1970), 2440588); // Unix epoch
      expect(julianDayFromDate(1, 1, 1900), 2415021); // lunar epoch used here
    });

    test('advances by exactly one per day', () {
      expect(
        julianDayFromDate(2, 1, 2000) - julianDayFromDate(1, 1, 2000),
        1,
      );
      expect(
        julianDayFromDate(1, 3, 2000) - julianDayFromDate(29, 2, 2000),
        1,
      );
    });

    test('accounts for leap years', () {
      // 2000 is a leap year, 1900 is not.
      expect(
        julianDayFromDate(1, 1, 2001) - julianDayFromDate(1, 1, 2000),
        366,
      );
      expect(
        julianDayFromDate(1, 1, 1901) - julianDayFromDate(1, 1, 1900),
        365,
      );
    });

    test('handles the Gregorian changeover of October 1582', () {
      // 4 October 1582 (Julian) was followed by 15 October (Gregorian); the
      // day numbers must stay consecutive across the gap.
      expect(
        julianDayFromDate(15, 10, 1582) - julianDayFromDate(4, 10, 1582),
        1,
      );
    });
  });

  group('dateFromJulianDay', () {
    test('inverts julianDayFromDate at known points', () {
      expect(dateFromJulianDay(2451545), (1, 1, 2000));
      expect(dateFromJulianDay(2440588), (1, 1, 1970));
      expect(dateFromJulianDay(2415021), (1, 1, 1900));
    });

    test('round-trips every day across several decades', () {
      // Walks day by day rather than sampling, so an off-by-one at a month or
      // year boundary cannot slip through.
      final start = julianDayFromDate(1, 1, 1890);
      final end = julianDayFromDate(31, 12, 2050);

      for (var jd = start; jd <= end; jd++) {
        final (day, month, year) = dateFromJulianDay(jd);
        expect(
          julianDayFromDate(day, month, year),
          jd,
          reason: 'round trip failed at $jd -> $year-$month-$day',
        );
      }
    });

    test('round-trips across the Gregorian changeover', () {
      final start = julianDayFromDate(1, 1, 1580);
      final end = julianDayFromDate(31, 12, 1584);

      for (var jd = start; jd <= end; jd++) {
        final (day, month, year) = dateFromJulianDay(jd);
        expect(julianDayFromDate(day, month, year), jd);
      }
    });
  });

  group('newMoonInstant', () {
    test('consecutive new moons are about a synodic month apart', () {
      // The mean is 29.53 days; individual intervals vary by roughly half a day
      // either side because the moon's orbit is not circular.
      for (var k = 0; k < 1500; k += 37) {
        final gap = newMoonInstant(k + 1) - newMoonInstant(k);
        expect(gap, greaterThan(29.2), reason: 'k=$k');
        expect(gap, lessThan(29.9), reason: 'k=$k');
      }
    });

    test('the long-run average matches the synodic month closely', () {
      const span = 1200;
      final average = (newMoonInstant(span) - newMoonInstant(0)) / span;
      expect(average, closeTo(synodicMonth, 0.0001));
    });

    test('increases monotonically', () {
      for (var k = 0; k < 500; k++) {
        expect(newMoonInstant(k + 1), greaterThan(newMoonInstant(k)));
      }
    });
  });

  group('newMoonDay', () {
    test('lands on consecutive lunar month starts 29 or 30 days apart', () {
      // A lunar month is always 29 or 30 whole days — never 28, never 31.
      for (var k = 1200; k < 1560; k++) {
        final length = newMoonDay(k + 1) - newMoonDay(k);
        expect(
          length,
          anyOf(29, 30),
          reason: 'new moon $k to ${k + 1} spanned $length days',
        );
      }
    });

    test('the time zone can move a new moon to a different day', () {
      // Not every new moon differs between UTC+7 and UTC+8, but some must —
      // that is exactly why the Vietnamese and Chinese calendars diverge.
      var differences = 0;
      for (var k = 1200; k < 1560; k++) {
        if (newMoonDay(k, timeZone: 7) != newMoonDay(k, timeZone: 8)) {
          differences++;
        }
      }
      expect(differences, greaterThan(0));
    });
  });

  group('newMoonIndexBefore', () {
    test('returns an index whose new moon is at or before the day', () {
      for (final year in <int>[1900, 1950, 2000, 2026, 2050]) {
        final jd = julianDayFromDate(1, 1, year);
        final k = newMoonIndexBefore(jd);

        expect(newMoonDay(k), lessThanOrEqualTo(jd + 1));
        expect(newMoonDay(k + 2), greaterThan(jd));
      }
    });
  });

  group('sunLongitudeSector', () {
    test('always yields one of twelve sectors', () {
      final start = julianDayFromDate(1, 1, 2000);
      for (var offset = 0; offset < 4000; offset += 7) {
        final sector = sunLongitudeSectorOnDay(start + offset);
        expect(sector, inInclusiveRange(0, 11));
      }
    });

    test('passes through all twelve sectors in a year', () {
      final start = julianDayFromDate(1, 1, 2026);
      final seen = <int>{};
      for (var offset = 0; offset < 366; offset++) {
        seen.add(sunLongitudeSectorOnDay(start + offset));
      }
      expect(seen.length, 12);
    });

    test('sector 9 begins at the December solstice', () {
      // Month 11 of the lunar year is defined as the one containing the winter
      // solstice, which is where sector 9 starts. The solstice falls on 21 or
      // 22 December.
      for (final year in <int>[2020, 2024, 2026, 2030]) {
        final before = sunLongitudeSectorOnDay(
          julianDayFromDate(20, 12, year),
        );
        final after = sunLongitudeSectorOnDay(julianDayFromDate(23, 12, year));

        expect(before, 8, reason: 'before solstice in $year');
        expect(after, 9, reason: 'after solstice in $year');
      }
    });

    test('advances through the year without going backwards', () {
      final start = julianDayFromDate(1, 1, 2026);
      var previous = sunLongitudeSectorOnDay(start);
      var wraps = 0;

      for (var offset = 1; offset < 365; offset++) {
        final sector = sunLongitudeSectorOnDay(start + offset);
        if (sector != previous) {
          if (sector == 0) {
            wraps++;
          } else {
            expect(sector, previous + 1, reason: 'jumped at day $offset');
          }
          previous = sector;
        }
      }
      expect(wraps, 1);
    });
  });
}
