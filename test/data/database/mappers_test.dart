import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/mappers.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final updatedAt = DateTime.utc(2026, 8, 2);

  /// Writes an entity and reads it straight back through the real database, so
  /// a column that silently drops a value cannot pass.
  Future<Family> roundTripFamily(Family family) async {
    await db.into(db.families).insert(familyToRow(family, updatedAt: updatedAt));
    return familyFromRow(await db.select(db.families).getSingle());
  }

  Future<Person> roundTripPerson(Person person) async {
    await db
        .into(db.families)
        .insert(
          familyToRow(
            Family(id: person.familyId, name: 'Họ Nguyễn'),
            updatedAt: updatedAt,
          ),
        );
    await db.into(db.persons).insert(personToRow(person, updatedAt: updatedAt));
    return personFromRow(await db.select(db.persons).getSingle());
  }

  group('Family', () {
    test('survives a round trip with everything set', () async {
      const family = Family(
        id: 'f1',
        name: 'Họ Nguyễn',
        description: 'Chi trưởng',
        usesLunarCalendar: true,
      );

      expect(await roundTripFamily(family), family);
    });

    test('survives a round trip with only what is required', () async {
      const family = Family(id: 'f1', name: 'Smith');
      final restored = await roundTripFamily(family);

      expect(restored, family);
      expect(restored.description, isNull);
      expect(restored.usesLunarCalendar, isFalse);
    });
  });

  group('Person', () {
    test('survives a round trip with every field set', () async {
      final person = Person(
        id: 'p1',
        familyId: 'f1',
        displayName: 'Nguyễn Văn Bảy',
        givenName: 'Bảy',
        additionalNames: 'Văn',
        familyName: 'Nguyễn',
        birthFamilyName: 'Trần',
        sex: Sex.male,
        birthDate: GenealogicalDate(year: 1887, month: 3, day: 15),
        deathDate: GenealogicalDate(year: 1960, month: 4, day: 5),
        birthPlace: 'Hà Nội',
        deathPlace: 'Huế',
        biography: 'Cụ tổ chi trưởng',
        profileMediaRef: 'media-123',
      );

      expect(await roundTripPerson(person), person);
    });

    test('survives a round trip with only what is required', () async {
      const person = Person(
        id: 'p1',
        familyId: 'f1',
        displayName: 'Cụ Tổ',
      );
      final restored = await roundTripPerson(person);

      expect(restored, person);
      expect(restored.birthDate, isNull);
      expect(restored.deathDate, isNull);
      expect(restored.sex, Sex.unknown);
    });

    test('keeps each value of sex', () async {
      for (final sex in Sex.values) {
        final db2 = AppDatabase(NativeDatabase.memory());
        await db2
            .into(db2.families)
            .insert(
              familyToRow(
                const Family(id: 'f1', name: 'F'),
                updatedAt: updatedAt,
              ),
            );
        await db2
            .into(db2.persons)
            .insert(
              personToRow(
                Person(
                  id: 'p1',
                  familyId: 'f1',
                  displayName: 'X',
                  sex: sex,
                ),
                updatedAt: updatedAt,
              ),
            );

        expect(
          personFromRow(await db2.select(db2.persons).getSingle()).sex,
          sex,
          reason: sex.name,
        );
        await db2.close();
      }
    });
  });

  group('dates', () {
    /// The claim §4.2 rests on: precision entered is precision returned.
    Future<GenealogicalDate?> roundTripBirth(GenealogicalDate date) async {
      final restored = await roundTripPerson(
        Person(
          id: 'p1',
          familyId: 'f1',
          displayName: 'X',
          birthDate: date,
        ),
      );
      return restored.birthDate;
    }

    test('keep year-only precision', () async {
      final date = GenealogicalDate(year: 1887);
      final restored = await roundTripBirth(date);

      expect(restored, date);
      expect(restored!.precision, DatePrecision.year);
      expect(restored.month, isNull);
      expect(restored.day, isNull);
    });

    test('keep month precision', () async {
      // One round trip per test: each writes the family, and a second write
      // would collide on the primary key.
      final date = GenealogicalDate(year: 1887, month: 3);
      final restored = await roundTripBirth(date);

      expect(restored, date);
      expect(restored!.precision, DatePrecision.month);
      expect(restored.day, isNull);
    });

    test('keep day precision', () async {
      final date = GenealogicalDate(year: 1887, month: 3, day: 15);
      final restored = await roundTripBirth(date);

      expect(restored, date);
      expect(restored!.precision, DatePrecision.day);
    });

    test('never turn a year into the first of January', () async {
      // The loss §4.2 exists to prevent. Storing a plain date would make these
      // two indistinguishable forever.
      final yearOnly = await roundTripBirth(GenealogicalDate(year: 1887));
      final firstOfJanuary = GenealogicalDate(year: 1887, month: 1, day: 1);

      expect(yearOnly, isNot(firstOfJanuary));
      expect(yearOnly!.month, isNull);
    });

    test('keep the approximate flag', () async {
      final date = GenealogicalDate(year: 1887, isApproximate: true);
      final restored = await roundTripBirth(date);

      expect(restored!.isApproximate, isTrue);
      expect(restored, date);
    });

    test('keep a precise date precise', () async {
      final restored = await roundTripBirth(
        GenealogicalDate(year: 1887, month: 3, day: 15),
      );
      expect(restored!.isApproximate, isFalse);
    });

    test('keep 29 February in a leap year', () async {
      final date = GenealogicalDate(year: 1888, month: 2, day: 29);
      expect(await roundTripBirth(date), date);
    });

    test('birth and death do not bleed into one another', () async {
      final restored = await roundTripPerson(
        Person(
          id: 'p1',
          familyId: 'f1',
          displayName: 'X',
          birthDate: GenealogicalDate(year: 1887),
          deathDate: GenealogicalDate(year: 1960, month: 4, day: 5),
        ),
      );

      expect(restored.birthDate, GenealogicalDate(year: 1887));
      expect(
        restored.deathDate,
        GenealogicalDate(year: 1960, month: 4, day: 5),
      );
    });
  });

  group('lunar readings', () {
    Future<GenealogicalDate?> roundTripDeath(GenealogicalDate date) async {
      final restored = await roundTripPerson(
        Person(
          id: 'p1',
          familyId: 'f1',
          displayName: 'X',
          deathDate: date,
        ),
      );
      return restored.deathDate;
    }

    test('survive alongside the Gregorian date', () async {
      final date = GenealogicalDate(
        year: 1960,
        month: 4,
        day: 5,
        lunar: LunarDate(year: 1960, month: 3, day: 12),
      );

      expect(await roundTripDeath(date), date);
    });

    test('keep the intercalary flag', () async {
      final date = GenealogicalDate(
        year: 1960,
        month: 4,
        day: 5,
        lunar: LunarDate(year: 1960, month: 3, day: 12, isLeapMonth: true),
      );
      final restored = await roundTripDeath(date);

      expect(restored!.lunar!.isLeapMonth, isTrue);
      expect(restored, date);
    });

    test('keep partial lunar precision', () async {
      final date = GenealogicalDate(
        year: 1960,
        month: 4,
        day: 5,
        lunar: LunarDate(year: 1960),
      );
      final restored = await roundTripDeath(date);

      expect(restored!.lunar!.month, isNull);
      expect(restored.lunar!.day, isNull);
      expect(restored, date);
    });

    test('stay absent when none was recorded', () async {
      final date = GenealogicalDate(year: 1960, month: 4, day: 5);
      expect((await roundTripDeath(date))!.lunar, isNull);
    });

    test('do not change the Gregorian value', () async {
      // The lunar reading is an annotation; it must not alter what is compared.
      final withLunar = await roundTripDeath(
        GenealogicalDate(
          year: 1960,
          month: 4,
          day: 5,
          lunar: LunarDate(year: 1960, month: 3, day: 12),
        ),
      );

      expect(withLunar!.toIso(), '1960-04-05');
    });
  });

  group('Relationship', () {
    Future<Relationship> roundTrip(Relationship relationship) async {
      await db
          .into(db.families)
          .insert(
            familyToRow(
              Family(id: relationship.familyId, name: 'F'),
              updatedAt: updatedAt,
            ),
          );
      for (final id in <String>{
        relationship.personAId,
        relationship.personBId,
      }) {
        await db
            .into(db.persons)
            .insert(
              personToRow(
                Person(
                  id: id,
                  familyId: relationship.familyId,
                  displayName: id,
                ),
                updatedAt: updatedAt,
              ),
            );
      }
      await db
          .into(db.relationships)
          .insert(relationshipToRow(relationship, updatedAt: updatedAt));

      return relationshipFromRow(
        await db.select(db.relationships).getSingle(),
      );
    }

    test('keeps parent-child direction', () async {
      // The parent id sorts after the child's, so a mapper that re-sorted
      // every type would silently invert the generations here.
      final original = Relationship.parentChild(
        id: 'r1',
        familyId: 'f1',
        parent: 'zzz',
        child: 'aaa',
      );
      final restored = await roundTrip(original);

      expect(restored, original);
      expect(restored.parentId, 'zzz');
      expect(restored.childId, 'aaa');
    });

    test('keeps a spouse pair canonically ordered', () async {
      final original = Relationship.spouse(
        id: 'r1',
        familyId: 'f1',
        personA: 'zzz',
        personB: 'aaa',
      );
      final restored = await roundTrip(original);

      expect(restored, original);
      expect(restored.personAId, 'aaa');
      expect(restored.key, original.key);
    });

    test('rebuilds the same uniqueness key', () async {
      final original = Relationship.parentChild(
        id: 'r1',
        familyId: 'f1',
        parent: 'aaa',
        child: 'bbb',
      );

      expect((await roundTrip(original)).key, original.key);
    });
  });
}
