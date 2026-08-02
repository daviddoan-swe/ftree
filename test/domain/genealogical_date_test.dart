import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/genealogical_date.dart';

void main() {
  group('construction', () {
    test('accepts a year on its own — the common genealogical case', () {
      final date = GenealogicalDate(year: 1887);
      expect(date.year, 1887);
      expect(date.month, isNull);
      expect(date.day, isNull);
      expect(date.isApproximate, isFalse);
    });

    test('accepts year and month', () {
      final date = GenealogicalDate(year: 1887, month: 3);
      expect(date.month, 3);
      expect(date.day, isNull);
    });

    test('accepts a full date', () {
      final date = GenealogicalDate(year: 1887, month: 3, day: 15);
      expect(date.day, 15);
    });

    test('rejects a day without a month', () {
      // "the 15th of an unknown month" describes nothing.
      expect(
        () => GenealogicalDate(year: 1887, day: 15),
        throwsArgumentError,
      );
    });

    test('rejects months outside 1-12', () {
      expect(() => GenealogicalDate(year: 1887, month: 0), throwsArgumentError);
      expect(() => GenealogicalDate(year: 1887, month: 13), throwsArgumentError);
    });

    test('rejects days beyond the length of the month', () {
      expect(
        () => GenealogicalDate(year: 1887, month: 4, day: 31),
        throwsArgumentError,
      );
      expect(
        () => GenealogicalDate(year: 1887, month: 1, day: 32),
        throwsArgumentError,
      );
      expect(
        () => GenealogicalDate(year: 1887, month: 1, day: 0),
        throwsArgumentError,
      );
    });

    test('applies the Gregorian leap year rule to 29 February', () {
      expect(GenealogicalDate(year: 1888, month: 2, day: 29).day, 29);
      expect(GenealogicalDate(year: 2000, month: 2, day: 29).day, 29);
      expect(
        () => GenealogicalDate(year: 1887, month: 2, day: 29),
        throwsArgumentError,
      );
      // 1900 is divisible by 4 but not a leap year.
      expect(
        () => GenealogicalDate(year: 1900, month: 2, day: 29),
        throwsArgumentError,
      );
    });

    test('rejects non-positive years — BC is out of scope', () {
      expect(() => GenealogicalDate(year: 0), throwsArgumentError);
      expect(() => GenealogicalDate(year: -44), throwsArgumentError);
    });
  });

  group('precision', () {
    test('is derived from the components present', () {
      expect(GenealogicalDate(year: 1887).precision, DatePrecision.year);
      expect(
        GenealogicalDate(year: 1887, month: 3).precision,
        DatePrecision.month,
      );
      expect(
        GenealogicalDate(year: 1887, month: 3, day: 15).precision,
        DatePrecision.day,
      );
    });
  });

  group('interval bounds', () {
    test('a year spans the whole year', () {
      final date = GenealogicalDate(year: 1887);
      expect(date.earliest, DateTime.utc(1887, 1, 1));
      expect(date.latest, DateTime.utc(1887, 12, 31));
    });

    test('a month spans that month', () {
      final date = GenealogicalDate(year: 1887, month: 3);
      expect(date.earliest, DateTime.utc(1887, 3, 1));
      expect(date.latest, DateTime.utc(1887, 3, 31));
    });

    test('a month of 30 days ends on the 30th', () {
      expect(
        GenealogicalDate(year: 1887, month: 4).latest,
        DateTime.utc(1887, 4, 30),
      );
    });

    test('February ends on the 28th or 29th according to the year', () {
      expect(
        GenealogicalDate(year: 1887, month: 2).latest,
        DateTime.utc(1887, 2, 28),
      );
      expect(
        GenealogicalDate(year: 1888, month: 2).latest,
        DateTime.utc(1888, 2, 29),
      );
    });

    test('a full date is a single instant', () {
      final date = GenealogicalDate(year: 1887, month: 3, day: 15);
      expect(date.earliest, date.latest);
    });

    test('bounds are UTC, so no timezone can shift a comparison', () {
      expect(GenealogicalDate(year: 1887).earliest.isUtc, isTrue);
      expect(GenealogicalDate(year: 1887).latest.isUtc, isTrue);
    });
  });

  group('comparison', () {
    test('non-overlapping years are ordered', () {
      final earlier = GenealogicalDate(year: 1887);
      final later = GenealogicalDate(year: 1889);

      expect(earlier.definitelyBefore(later), isTrue);
      expect(later.definitelyAfter(earlier), isTrue);
      expect(earlier.definitelyAfter(later), isFalse);
    });

    test('a year and a date inside it are indeterminate both ways', () {
      // The heart of §4.3: 1887 may fall before, after, or on 15 March 1887.
      final year = GenealogicalDate(year: 1887);
      final exact = GenealogicalDate(year: 1887, month: 3, day: 15);

      expect(year.definitelyBefore(exact), isFalse);
      expect(year.definitelyAfter(exact), isFalse);
      expect(exact.definitelyBefore(year), isFalse);
      expect(exact.definitelyAfter(year), isFalse);
      expect(year.isIndeterminateAgainst(exact), isTrue);
    });

    test('identical exact dates are neither before nor after', () {
      final a = GenealogicalDate(year: 1887, month: 3, day: 15);
      final b = GenealogicalDate(year: 1887, month: 3, day: 15);

      expect(a.definitelyBefore(b), isFalse);
      expect(a.definitelyAfter(b), isFalse);
      expect(a.isIndeterminateAgainst(b), isTrue);
    });

    test('adjacent exact dates are ordered', () {
      final first = GenealogicalDate(year: 1887, month: 3, day: 15);
      final second = GenealogicalDate(year: 1887, month: 3, day: 16);

      expect(first.definitelyBefore(second), isTrue);
      expect(first.isIndeterminateAgainst(second), isFalse);
    });

    test('approximate dates compare exactly like precise ones', () {
      // Decided in §4.3: "about" records doubt about the value, not permission
      // to ignore the contradictions it produces.
      final approximate = GenealogicalDate(year: 1887, isApproximate: true);
      final later = GenealogicalDate(year: 1889);

      expect(approximate.definitelyBefore(later), isTrue);
      expect(approximate.earliest, GenealogicalDate(year: 1887).earliest);
      expect(approximate.latest, GenealogicalDate(year: 1887).latest);
    });
  });

  group('spanTo', () {
    test('between two exact dates the range collapses to one value', () {
      final birth = GenealogicalDate(year: 1900, month: 1, day: 1);
      final death = GenealogicalDate(year: 1901, month: 1, day: 1);

      final span = birth.spanTo(death);
      expect(span.minimumDays, 365);
      expect(span.maximumDays, 365);
      expect(span.minimumYears, closeTo(1.0, 0.01));
    });

    test('between two years the gap is genuinely a range', () {
      // 1887 to 1888 could be one day (31 Dec to 1 Jan) or nearly two years.
      final from = GenealogicalDate(year: 1887);
      final to = GenealogicalDate(year: 1888);

      final span = from.spanTo(to);
      expect(span.minimumDays, 1);
      expect(span.maximumDays, 730);
    });

    test('is negative when the end may precede the start', () {
      final later = GenealogicalDate(year: 1900, month: 6, day: 1);
      final earlier = GenealogicalDate(year: 1890, month: 6, day: 1);

      expect(later.spanTo(earlier).maximumDays, lessThan(0));
    });

    test('supports the thresholds the warning rules need', () {
      final birth = GenealogicalDate(year: 1800);
      final death = GenealogicalDate(year: 1950);

      // Even at its shortest this lifespan exceeds 120 years.
      expect(birth.spanTo(death).minimumYears, greaterThan(120));

      final parentBirth = GenealogicalDate(year: 1910);
      final childBirth = GenealogicalDate(year: 1918);
      // Even at its longest the parent was under 12.
      expect(parentBirth.spanTo(childBirth).maximumYears, lessThan(12));
    });

    test('a year-precision gap stays indeterminate against a threshold', () {
      final parentDeath = GenealogicalDate(year: 1900);
      final childBirth = GenealogicalDate(year: 1901);

      final span = parentDeath.spanTo(childBirth);
      // Could be days, could be two years: a rule must not conclude either way.
      expect(span.minimumYears, lessThan(1));
      expect(span.maximumYears, greaterThan(1));
    });
  });

  group('ISO-prefix form', () {
    test('writes exactly the precision that is known', () {
      expect(GenealogicalDate(year: 1887).toIso(), '1887');
      expect(GenealogicalDate(year: 1887, month: 3).toIso(), '1887-03');
      expect(
        GenealogicalDate(year: 1887, month: 3, day: 15).toIso(),
        '1887-03-15',
      );
    });

    test('pads single-digit components', () {
      expect(GenealogicalDate(year: 887, month: 1, day: 2).toIso(), '0887-01-02');
    });

    test('sorts correctly as plain text', () {
      final texts = <String>[
        GenealogicalDate(year: 1890, month: 2).toIso(),
        GenealogicalDate(year: 1887).toIso(),
        GenealogicalDate(year: 1887, month: 12, day: 31).toIso(),
      ]..sort();
      expect(texts, <String>['1887', '1887-12-31', '1890-02']);
    });

    test('round-trips at every precision without losing information', () {
      // The proof that the representation is lossless — the entire point of
      // §4.2.
      final dates = <GenealogicalDate>[
        GenealogicalDate(year: 1887),
        GenealogicalDate(year: 1887, month: 3),
        GenealogicalDate(year: 1887, month: 3, day: 15),
        GenealogicalDate(year: 1888, month: 2, day: 29),
        GenealogicalDate(year: 2026, month: 12, day: 31),
      ];

      for (final date in dates) {
        expect(GenealogicalDate.parseIso(date.toIso()), date, reason: '$date');
      }
    });

    test('carries isApproximate alongside the string, not inside it', () {
      final date = GenealogicalDate(year: 1887, isApproximate: true);
      expect(date.toIso(), '1887');

      final restored = GenealogicalDate.parseIso(
        date.toIso(),
        isApproximate: true,
      );
      expect(restored, date);
    });

    test('rejects text that is not one of the three forms', () {
      for (final bad in <String>['', '18', '1887-3', '1887/03/15', 'abcd']) {
        expect(
          () => GenealogicalDate.parseIso(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });

    test('rejects text that parses but describes no real date', () {
      expect(
        () => GenealogicalDate.parseIso('1887-02-30'),
        throwsArgumentError,
      );
    });
  });

  group('value semantics', () {
    test('equal components mean equal dates', () {
      expect(
        GenealogicalDate(year: 1887, month: 3),
        GenealogicalDate(year: 1887, month: 3),
      );
      expect(
        GenealogicalDate(year: 1887, month: 3).hashCode,
        GenealogicalDate(year: 1887, month: 3).hashCode,
      );
    });

    test('differing precision is not equality', () {
      // "1887" and "1 January 1887" are different claims about the world.
      expect(
        GenealogicalDate(year: 1887),
        isNot(GenealogicalDate(year: 1887, month: 1, day: 1)),
      );
    });

    test('approximate and precise are not equal', () {
      expect(
        GenealogicalDate(year: 1887, isApproximate: true),
        isNot(GenealogicalDate(year: 1887)),
      );
    });
  });

  group('design', () {
    test('is deliberately not Comparable', () {
      // A compareTo would have to return -1, 0, or 1 for 1887 vs 1887-03-15,
      // inventing an answer where none exists.
      expect(GenealogicalDate(year: 1887), isNot(isA<Comparable<Object>>()));
    });
  });
}
