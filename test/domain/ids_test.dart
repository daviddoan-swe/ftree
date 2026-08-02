import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/ids.dart';

/// A stand-in for [Random] that returns the same byte every time, so a
/// generated id is fully determined by the timestamp passed in.
class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

void main() {
  group('format', () {
    test('is canonical 8-4-4-4-12 lowercase hexadecimal', () {
      final id = newId();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(id.length, 36);
    });

    test('declares version 7', () {
      // The first nibble of the third group. Getting this wrong would produce
      // ids that other tooling reads as a different UUID version.
      for (var i = 0; i < 50; i++) {
        expect(newId()[14], '7');
      }
    });

    test('declares the RFC 9562 variant', () {
      // The first nibble of the fourth group must have its top two bits 0b10,
      // which restricts it to 8, 9, a, or b.
      for (var i = 0; i < 50; i++) {
        expect('89ab', contains(newId()[19]));
      }
    });

    test('accepts its own output', () {
      for (var i = 0; i < 50; i++) {
        expect(isValidId(newId()), isTrue);
      }
    });
  });

  group('isValidId', () {
    test('rejects malformed strings', () {
      for (final bad in <String>[
        '',
        'not-a-uuid',
        '0189d6f0-1a2b-7c3d-8e4f',
        '0189d6f0-1a2b-7c3d-8e4f-5a6b7c8d9e0',
        '0189d6f01a2b7c3d8e4f5a6b7c8d9e0f',
      ]) {
        expect(isValidId(bad), isFalse, reason: bad);
      }
    });

    test('rejects uppercase — canonical form is lowercase', () {
      expect(isValidId('0189D6F0-1A2B-7C3D-8E4F-5A6B7C8D9E0F'), isFalse);
    });

    test('rejects a well-formed UUID of another version', () {
      // Shape is right, version nibble says 4.
      expect(isValidId('0189d6f0-1a2b-4c3d-8e4f-5a6b7c8d9e0f'), isFalse);
    });

    test('rejects a wrong variant', () {
      // Fourth group starts with c: top bits 0b11, not 0b10.
      expect(isValidId('0189d6f0-1a2b-7c3d-ce4f-5a6b7c8d9e0f'), isFalse);
    });
  });

  group('timestamp', () {
    test('is written into the leading 48 bits', () {
      final at = DateTime.utc(2026, 8, 2, 12, 0, 0);
      final id = newId(at: at, random: _FixedRandom(0));

      final leading = id.substring(0, 8) + id.substring(9, 13);
      expect(int.parse(leading, radix: 16), at.millisecondsSinceEpoch);
    });

    test('rejects times before the Unix epoch', () {
      expect(
        () => newId(at: DateTime.utc(1969)),
        throwsArgumentError,
      );
    });
  });

  group('ordering', () {
    test('later timestamps produce lexicographically larger ids', () {
      // The whole reason for choosing v7 over v4: index locality depends on
      // creation order surviving into the string form.
      final times = <DateTime>[
        DateTime.utc(2020, 1, 1),
        DateTime.utc(2024, 6, 15),
        DateTime.utc(2026, 8, 2),
        DateTime.utc(2030, 12, 31),
      ];
      final ids = times
          .map((t) => newId(at: t, random: _FixedRandom(0)))
          .toList();

      final sorted = List<String>.from(ids)..sort();
      expect(sorted, ids);
    });

    test('ordering holds one millisecond apart', () {
      final first = newId(at: DateTime.utc(2026, 8, 2, 0, 0, 0, 500));
      final second = newId(at: DateTime.utc(2026, 8, 2, 0, 0, 0, 501));
      expect(first.compareTo(second), lessThan(0));
    });
  });

  group('uniqueness', () {
    test('ten thousand ids are all distinct', () {
      final ids = <String>{};
      for (var i = 0; i < 10000; i++) {
        ids.add(newId());
      }
      expect(ids.length, 10000);
    });

    test('the same millisecond still yields different ids', () {
      // Randomness, not the clock, carries uniqueness within a millisecond.
      final at = DateTime.utc(2026, 8, 2, 12, 0, 0);
      final ids = <String>{};
      for (var i = 0; i < 1000; i++) {
        ids.add(newId(at: at));
      }
      expect(ids.length, 1000);
    });
  });

  group('determinism', () {
    test('pinning both the clock and the random source pins the id', () {
      final at = DateTime.utc(2026, 8, 2, 12, 0, 0);
      final first = newId(at: at, random: _FixedRandom(0xAB));
      final second = newId(at: at, random: _FixedRandom(0xAB));

      expect(first, second);
    });

    test('the random source affects everything after the timestamp', () {
      final at = DateTime.utc(2026, 8, 2, 12, 0, 0);
      final a = newId(at: at, random: _FixedRandom(0x11));
      final b = newId(at: at, random: _FixedRandom(0x22));

      expect(a, isNot(b));
      // Timestamp portion is identical; only the tail differs.
      expect(a.substring(0, 13), b.substring(0, 13));
    });
  });
}
