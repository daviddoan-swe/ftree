import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/age.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/ids.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  final id = newId();
  final familyId = newId();

  Person person({
    String? displayName,
    GenealogicalDate? birthDate,
    GenealogicalDate? deathDate,
    Sex? sex,
  }) => Person(
    id: id,
    familyId: familyId,
    displayName: displayName ?? 'Nguyễn Văn Bảy',
    birthDate: birthDate,
    deathDate: deathDate,
    sex: sex ?? Sex.unknown,
  );

  group('minimal person', () {
    test('needs only an id, a family, and a display name', () {
      final minimal = Person(
        id: id,
        familyId: familyId,
        displayName: 'Cụ Tổ',
      );
      expect(minimal.validate().hasIssues, isFalse);
    });

    test('leaves every biographical field optional', () {
      final minimal = Person(
        id: id,
        familyId: familyId,
        displayName: 'Cụ Tổ',
      );

      expect(minimal.givenName, isNull);
      expect(minimal.additionalNames, isNull);
      expect(minimal.familyName, isNull);
      expect(minimal.birthFamilyName, isNull);
      expect(minimal.birthDate, isNull);
      expect(minimal.deathDate, isNull);
      expect(minimal.birthPlace, isNull);
      expect(minimal.deathPlace, isNull);
      expect(minimal.biography, isNull);
      expect(minimal.profileMediaRef, isNull);
    });

    test('records a maiden name separately from the current family name', () {
      final married = Person(
        id: id,
        familyId: familyId,
        displayName: 'Trần Thị Lan',
        familyName: 'Trần',
        birthFamilyName: 'Nguyễn',
      );

      expect(married.familyName, 'Trần');
      expect(married.birthFamilyName, 'Nguyễn');
    });
  });

  group('displayName', () {
    test('empty is an error', () {
      final result = person(displayName: '').validate();
      expect(result.hasErrors, isTrue);
      expect(result.issues.single.code, IssueCode.displayNameEmpty);
    });

    test('whitespace only is an error', () {
      for (final blank in <String>[' ', '\t', '\n', '   ']) {
        expect(person(displayName: blank).validate().hasErrors, isTrue);
      }
    });

    test('surrounding whitespace does not invalidate a real name', () {
      expect(person(displayName: '  Cụ Bảy  ').validate().hasIssues, isFalse);
    });

    test('is stored exactly as given', () {
      expect(person(displayName: '  Cụ Bảy  ').displayName, '  Cụ Bảy  ');
    });

    test('the issue names the person it concerns', () {
      final result = person(displayName: '').validate();
      expect(result.issues.single.involvedIds, <String>[id]);
    });
  });

  group('sex', () {
    test('defaults to unknown rather than being absent', () {
      expect(
        Person(id: id, familyId: familyId, displayName: 'Cụ Tổ').sex,
        Sex.unknown,
      );
    });

    test('holds the three documented values', () {
      expect(Sex.values, <Sex>[Sex.male, Sex.female, Sex.unknown]);
    });

    test('an unknown sex is not a validation problem', () {
      expect(person(sex: Sex.unknown).validate().hasIssues, isFalse);
    });
  });

  group('deathBeforeBirth', () {
    test('warns when the dates cannot overlap', () {
      final result = person(
        birthDate: GenealogicalDate(year: 1850),
        deathDate: GenealogicalDate(year: 1849, month: 6),
      ).validate();

      expect(result.issues.single.code, IssueCode.deathBeforeBirth);
    });

    test('is a warning, never an error — the record may still be saved', () {
      final result = person(
        birthDate: GenealogicalDate(year: 1850, month: 1, day: 1),
        deathDate: GenealogicalDate(year: 1840, month: 1, day: 1),
      ).validate();

      expect(result.hasIssues, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('stays silent when the dates overlap', () {
      // June 1850 sits inside the year 1850. Someone born in March and dead in
      // June is not a contradiction, so there is nothing to report (§4.3).
      final result = person(
        birthDate: GenealogicalDate(year: 1850),
        deathDate: GenealogicalDate(year: 1850, month: 6),
      ).validate();

      expect(result.hasIssues, isFalse);
    });

    test('needs both dates', () {
      expect(
        person(birthDate: GenealogicalDate(year: 1850)).validate().hasIssues,
        isFalse,
      );
      expect(
        person(deathDate: GenealogicalDate(year: 1850)).validate().hasIssues,
        isFalse,
      );
    });
  });

  group('implausibleLifespan', () {
    test('warns when even the shortest possible lifespan is too long', () {
      // Against the threshold rather than a fixed pair of years, so the rule
      // survives the threshold being retuned.
      final result = person(
        birthDate: GenealogicalDate(year: 1800),
        deathDate: GenealogicalDate(
          year: 1800 + maximumPlausibleLifespanYears + 2,
        ),
      ).validate();

      expect(result.issues.single.code, IssueCode.implausibleLifespan);
      expect(result.hasErrors, isFalse);
    });

    test('stays silent at a long but possible age', () {
      final result = person(
        birthDate: GenealogicalDate(year: 1800, month: 1, day: 1),
        deathDate: GenealogicalDate(
          year: 1800 + maximumPlausibleLifespanYears - 1,
          month: 1,
          day: 1,
        ),
      ).validate();

      expect(result.hasIssues, isFalse);
    });

    test('uses the minimum span, so an uncertain limit stays silent', () {
      // Year-only dates exactly the threshold apart span anything from one
      // less to one more. Judging by the maximum would flag a lifespan that
      // may well be ordinary.
      final result = person(
        birthDate: GenealogicalDate(year: 1800),
        deathDate: GenealogicalDate(
          year: 1800 + maximumPlausibleLifespanYears,
        ),
      ).validate();

      expect(result.hasIssues, isFalse);
    });

    test('is not reported when the death already precedes the birth', () {
      // One contradiction, one message: a negative lifespan is the
      // death-before-birth problem, not an implausibly long life.
      final result = person(
        birthDate: GenealogicalDate(year: 1950),
        deathDate: GenealogicalDate(year: 1800),
      ).validate();

      expect(result.issues.single.code, IssueCode.deathBeforeBirth);
    });
  });

  group('combined results', () {
    test('reports an error and a warning together', () {
      final result = Person(
        id: id,
        familyId: familyId,
        displayName: '',
        birthDate: GenealogicalDate(year: 1850, month: 1, day: 1),
        deathDate: GenealogicalDate(year: 1840, month: 1, day: 1),
      ).validate();

      expect(result.issues.length, 2);
      expect(result.hasErrors, isTrue);
      expect(
        result.errors.single.code,
        IssueCode.displayNameEmpty,
      );
      expect(
        result.warnings.single.code,
        IssueCode.deathBeforeBirth,
      );
    });
  });

  group('construction and equality', () {
    test('an invalid person can still be built', () {
      expect(
        () => Person(id: id, familyId: familyId, displayName: ''),
        returnsNormally,
      );
    });

    test('compares every field', () {
      expect(person(), person());
      expect(person().hashCode, person().hashCode);
      expect(person(), isNot(person(displayName: 'Khác')));
      expect(person(), isNot(person(sex: Sex.male)));
      expect(
        person(),
        isNot(person(birthDate: GenealogicalDate(year: 1900))),
      );
    });

    test('a lunar annotation on a date is part of the person', () {
      final withLunar = person(
        birthDate: GenealogicalDate(
          year: 1887,
          month: 4,
          day: 5,
          lunar: LunarDate(year: 1887, month: 3, day: 12),
        ),
      );
      final withoutLunar = person(
        birthDate: GenealogicalDate(year: 1887, month: 4, day: 5),
      );

      expect(withLunar, isNot(withoutLunar));
    });
  });
}
