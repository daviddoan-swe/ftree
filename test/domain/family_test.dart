import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/ids.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  final id = newId();

  group('validation', () {
    test('a named family is clean', () {
      final family = Family(id: id, name: 'Họ Nguyễn');
      expect(family.validate().hasIssues, isFalse);
    });

    test('an empty name is an error', () {
      final family = Family(id: id, name: '');
      final result = family.validate();

      expect(result.hasErrors, isTrue);
      expect(result.issues.single.code, IssueCode.familyNameEmpty);
    });

    test('a name of only whitespace is an error', () {
      for (final blank in <String>[' ', '   ', '\t', '\n', ' \t\n ']) {
        expect(
          Family(id: id, name: blank).validate().hasErrors,
          isTrue,
          reason: 'blank name ${blank.codeUnits}',
        );
      }
    });

    test('the issue names the family it concerns', () {
      final result = Family(id: id, name: '').validate();
      expect(result.issues.single.involvedIds, <String>[id]);
    });

    test('description is optional', () {
      expect(Family(id: id, name: 'Họ Trần').description, isNull);
      expect(
        Family(id: id, name: 'Họ Trần', description: 'Chi thứ hai')
            .validate()
            .hasIssues,
        isFalse,
      );
    });
  });

  group('name handling', () {
    test('surrounding whitespace does not make a real name invalid', () {
      expect(
        Family(id: id, name: '  Họ Nguyễn  ').validate().hasIssues,
        isFalse,
      );
    });

    test('the name is stored exactly as given, not trimmed', () {
      // Normalising in the constructor would mean the value read back differs
      // from the value written. That belongs to the UI, before submission.
      expect(Family(id: id, name: '  Họ Nguyễn  ').name, '  Họ Nguyễn  ');
    });
  });

  group('construction', () {
    test('an invalid family can still be built', () {
      // A half-filled form is a normal thing to hold in memory. Errors are
      // reported so the UI can show them, not thrown (DOMAIN.md §9).
      expect(() => Family(id: id, name: ''), returnsNormally);
    });

    test('the id is supplied, never generated internally', () {
      // Two families built with the same arguments must be identical, which
      // rules out an entity generating its own id.
      expect(
        Family(id: id, name: 'Họ Lê'),
        Family(id: id, name: 'Họ Lê'),
      );
    });
  });

  group('equality', () {
    test('compares every field, not just the id', () {
      // Id-only equality would let a persistence bug that drops the name pass
      // a round-trip test unnoticed.
      final original = Family(id: id, name: 'Họ Nguyễn');
      final renamed = Family(id: id, name: 'Họ Trần');

      expect(original, isNot(renamed));
    });

    test('differing description breaks equality', () {
      expect(
        Family(id: id, name: 'Họ Lê', description: 'a'),
        isNot(Family(id: id, name: 'Họ Lê', description: 'b')),
      );
    });

    test('identical fields mean equal families and equal hash codes', () {
      final a = Family(id: id, name: 'Họ Lê', description: 'Chi trưởng');
      final b = Family(id: id, name: 'Họ Lê', description: 'Chi trưởng');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different ids are different families', () {
      expect(
        Family(id: newId(), name: 'Họ Lê'),
        isNot(Family(id: newId(), name: 'Họ Lê')),
      );
    });

    test('the lunar calendar flag is part of equality', () {
      expect(
        Family(id: id, name: 'Họ Lê', usesLunarCalendar: true),
        isNot(Family(id: id, name: 'Họ Lê')),
      );
    });
  });

  group('lunar calendar', () {
    test('defaults to off, because the domain cannot read a locale', () {
      expect(Family(id: id, name: 'Smith').usesLunarCalendar, isFalse);
    });

    test('can be turned on', () {
      expect(
        Family(id: id, name: 'Họ Nguyễn', usesLunarCalendar: true)
            .usesLunarCalendar,
        isTrue,
      );
    });

    test('is not a validation concern either way', () {
      // It records how a family keeps its dates, not whether the data is
      // correct. Both settings are perfectly valid.
      expect(
        Family(id: id, name: 'Họ Nguyễn', usesLunarCalendar: true)
            .validate()
            .hasIssues,
        isFalse,
      );
      expect(
        Family(id: id, name: 'Smith').validate().hasIssues,
        isFalse,
      );
    });
  });
}
