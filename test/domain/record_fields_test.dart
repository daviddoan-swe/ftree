/// A record flattened to named fields, and put back together
/// (ROADMAP M9, step 3).
///
/// The round trip is what matters. A merge takes a record apart, decides field
/// by field, and builds one again — so anything the taking-apart loses is
/// something a merge would silently erase from a gia phả.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/record_fields.dart';

void main() {
  const id = 'p0000000-0000-7000-8000-000000000001';
  const familyId = 'f0000000-0000-7000-8000-000000000001';

  Person rebuilt(Person person) =>
      personFromFields(person, personFields(person));

  group('the round trip keeps everything', () {
    test('a person with nothing but a name', () {
      const person = Person(id: id, familyId: familyId, displayName: 'Cụ Tổ');

      expect(rebuilt(person), person);
    });

    test('and one with every field filled in', () {
      final person = Person(
        id: id,
        familyId: familyId,
        displayName: 'Nguyễn Văn A',
        givenName: 'A',
        additionalNames: 'Văn',
        familyName: 'Nguyễn',
        birthFamilyName: 'Trần',
        sex: Sex.male,
        birthDate: GenealogicalDate.parseIso('1887-03-12'),
        deathDate: GenealogicalDate.parseIso('1950'),
        birthPlace: 'Nam Định',
        deathPlace: 'Hà Nội',
        biography: 'Làm nghề dạy học.',
        profileMediaRef: 'media/1',
      );

      expect(rebuilt(person), person);
    });

    test('a partial date keeps its precision', () {
      // A year-only date is not a full one with holes (§4). Losing that in the
      // round trip would invent a day nobody recorded.
      final person = Person(
        id: id,
        familyId: familyId,
        displayName: 'Cụ Tổ',
        birthDate: GenealogicalDate.parseIso('1887'),
      );

      expect(rebuilt(person).birthDate!.toIso(), '1887');
      expect(rebuilt(person).birthDate!.month, isNull);
    });

    test('an approximate date stays approximate', () {
      final person = Person(
        id: id,
        familyId: familyId,
        displayName: 'Cụ Tổ',
        birthDate: GenealogicalDate.parseIso('1890', isApproximate: true),
      );

      expect(rebuilt(person).birthDate!.isApproximate, isTrue);
    });

    test('a lunar reading survives, leap month and all', () {
      final person = Person(
        id: id,
        familyId: familyId,
        displayName: 'Cụ Tổ',
        birthDate: GenealogicalDate.parseIso(
          '1887-03-12',
          lunar: LunarDate(year: 1887, month: 2, day: 18, isLeapMonth: true),
        ),
      );

      final lunar = rebuilt(person).birthDate!.lunar!;
      expect(lunar.year, 1887);
      expect(lunar.month, 2);
      expect(lunar.day, 18);
      expect(lunar.isLeapMonth, isTrue);
    });
  });

  group('what is left out, and why', () {
    test('the identifiers are not fields to merge', () {
      // They say which record this is. Merging them would be merging two
      // different people into one, which is not a disagreement but a mistake.
      final fields = personFields(
        const Person(id: id, familyId: familyId, displayName: 'Cụ Tổ'),
      );

      expect(fields.containsKey('id'), isFalse);
      expect(fields.containsKey('familyId'), isFalse);
    });

    test('and rebuilding takes them from the record it is given', () {
      const mine = Person(id: id, familyId: familyId, displayName: 'Cụ Tổ');

      final other = personFromFields(mine, <String, Object?>{
        'displayName': 'Cụ Tổ (họ sửa)',
      });

      expect(other.id, id);
      expect(other.familyId, familyId);
      expect(other.displayName, 'Cụ Tổ (họ sửa)');
    });
  });

  group('dates come apart into the pieces people edit', () {
    test('a lunar reading added to an unchanged date is one field moving', () {
      // Somebody filling in the lunar date of a birth whose Gregorian reading
      // is already right has changed one field, not the date as a whole. Kept
      // whole, a merge would call that a disagreement about the birth.
      final before = personFields(
        Person(
          id: id,
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthDate: GenealogicalDate.parseIso('1887-03-12'),
        ),
      );
      final after = personFields(
        Person(
          id: id,
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthDate: GenealogicalDate.parseIso(
            '1887-03-12',
            lunar: LunarDate(year: 1887, month: 2, day: 18),
          ),
        ),
      );

      final moved = <String>[
        for (final key in after.keys)
          if (before[key] != after[key]) key,
      ];

      expect(moved, isNot(contains('birthDateIso')));
      expect(moved, contains('birthLunarYear'));
    });
  });
}
