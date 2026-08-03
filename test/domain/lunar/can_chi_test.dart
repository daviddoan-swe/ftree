import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/lunar/can_chi.dart';

import '../../support/lunar_reference.dart';

void main() {
  group('naming (PROVISIONAL reference)', () {
    test('matches years whose names are widely known', () {
      for (final entry in canChiNames.entries) {
        expect(
          CanChi.ofLunarYear(entry.key).toString(),
          entry.value,
          reason: 'lunar year ${entry.key}',
        );
      }
    });
  });

  group('cycle structure', () {
    test('repeats every sixty years', () {
      for (var year = 1900; year < 2000; year++) {
        expect(
          CanChi.ofLunarYear(year + sexagenaryCycle),
          CanChi.ofLunarYear(year),
          reason: 'year $year',
        );
      }
    });

    test('does not repeat sooner than sixty years', () {
      final start = CanChi.ofLunarYear(2000);
      for (var gap = 1; gap < sexagenaryCycle; gap++) {
        expect(
          CanChi.ofLunarYear(2000 + gap),
          isNot(start),
          reason: 'gap of $gap years',
        );
      }
    });

    test('produces exactly sixty distinct names in sixty years', () {
      final names = <CanChi>{
        for (var year = 2000; year < 2060; year++) CanChi.ofLunarYear(year),
      };
      expect(names.length, 60);
    });

    test('the stem advances every year and wraps every ten', () {
      for (var year = 1900; year < 2000; year++) {
        expect(
          CanChi.ofLunarYear(year + 10).stem,
          CanChi.ofLunarYear(year).stem,
        );
        expect(
          CanChi.ofLunarYear(year + 1).stem,
          isNot(CanChi.ofLunarYear(year).stem),
        );
      }
    });

    test('the branch wraps every twelve — the zodiac animal', () {
      for (var year = 1900; year < 2000; year++) {
        expect(
          CanChi.ofLunarYear(year + 12).branch,
          CanChi.ofLunarYear(year).branch,
        );
      }
    });

    test('half of the possible pairings never occur', () {
      // Ten stems and twelve branches suggest a hundred and twenty names, but
      // both advance together, so only the sixty of matching parity happen.
      var possible = 0;
      for (final stem in heavenlyStems) {
        for (final branch in earthlyBranches) {
          if (CanChi(stem, branch).isPossible) possible++;
        }
      }
      expect(possible, 60);
    });

    test('every generated name is a possible one', () {
      for (var year = 1800; year < 2100; year++) {
        expect(CanChi.ofLunarYear(year).isPossible, isTrue, reason: '$year');
      }
    });
  });

  group('parsing', () {
    test('round-trips a generated name', () {
      for (var year = 2000; year < 2060; year++) {
        final name = CanChi.ofLunarYear(year);
        expect(CanChi.parse(name.toString()), name);
      }
    });

    test('tolerates extra whitespace', () {
      expect(CanChi.parse('  Bính   Ngọ  '), const CanChi('Bính', 'Ngọ'));
    });

    test('rejects an unknown stem or branch', () {
      expect(() => CanChi.parse('Xxx Ngọ'), throwsArgumentError);
      expect(() => CanChi.parse('Bính Xxx'), throwsArgumentError);
    });

    test('rejects a pairing that cannot occur', () {
      // Giáp is at an even index, Sửu at an odd one, so they never meet.
      expect(() => CanChi.parse('Giáp Sửu'), throwsArgumentError);
    });

    test('rejects text that is not two words', () {
      for (final bad in <String>['', 'Bính', 'Bính Ngọ Thêm']) {
        expect(() => CanChi.parse(bad), throwsArgumentError, reason: bad);
      }
    });
  });

  group('lunarYearsNamed', () {
    test('finds every candidate in a range, sixty years apart', () {
      final years = lunarYearsNamed(
        CanChi.parse('Đinh Hợi'),
        from: 1800,
        to: 2000,
      );

      expect(years.length, greaterThan(1));
      for (var i = 1; i < years.length; i++) {
        expect(years[i] - years[i - 1], sexagenaryCycle);
      }
    });

    test('a century-wide range yields one or two candidates', () {
      // The ambiguity a source giving only a name leaves behind.
      for (var year = 1900; year < 2000; year++) {
        final candidates = lunarYearsNamed(
          CanChi.ofLunarYear(year),
          from: 1900,
          to: 1999,
        );
        expect(candidates.length, inInclusiveRange(1, 2));
        expect(candidates, contains(year));
      }
    });

    test('a range shorter than the cycle can be empty', () {
      final years = lunarYearsNamed(
        CanChi.ofLunarYear(2024),
        from: 2025,
        to: 2030,
      );
      expect(years, isEmpty);
    });

    test('rejects a reversed range', () {
      expect(
        () => lunarYearsNamed(CanChi.ofLunarYear(2024), from: 2030, to: 2020),
        throwsArgumentError,
      );
    });
  });
}
