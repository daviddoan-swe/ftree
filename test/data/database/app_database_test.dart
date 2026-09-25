// drift and matcher both export `isNull`; the matcher is the one wanted here.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // A real SQLite engine, in memory. Constraints are enforced by SQLite
    // itself here, so these tests prove the schema rather than a stand-in.
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DateTime now() => DateTime.utc(2026, 8, 2);

  Future<void> insertFamily(String id) => db
      .into(db.families)
      .insert(
        FamiliesCompanion.insert(
          id: id,
          name: 'Họ Nguyễn',
          updatedAt: now(),
        ),
      );

  Future<void> insertPerson(String id, String familyId) => db
      .into(db.persons)
      .insert(
        PersonsCompanion.insert(
          id: id,
          familyId: familyId,
          displayName: 'Person $id',
          sex: Sex.unknown,
          updatedAt: now(),
        ),
      );

  Future<void> insertRelationship({
    required String id,
    required String familyId,
    required RelationshipType type,
    required String personAId,
    required String personBId,
  }) => db
      .into(db.relationships)
      .insert(
        RelationshipsCompanion.insert(
          id: id,
          familyId: familyId,
          type: type,
          personAId: personAId,
          personBId: personBId,
          updatedAt: now(),
        ),
      );

  group('schema', () {
    test('opens at version 6 and creates every table', () async {
      // Written down rather than read from the database, on purpose. A schema
      // version changes what runs on every installed device, so it may not
      // move without somebody editing this line and noticing why.
      expect(db.schemaVersion, 6);

      // Touching each table proves it exists.
      expect(await db.select(db.families).get(), isEmpty);
      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.select(db.relationships).get(), isEmpty);
      expect(await db.select(db.invitationCodes).get(), isEmpty);
    });

    test('foreign keys are switched on for the connection', () async {
      // SQLite ignores foreign keys unless asked, per connection. Without this
      // every CASCADE in the schema is decoration.
      final result = await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle();

      expect(result.data.values.first, 1);
    });
  });

  group('foreign keys', () {
    test('a person cannot belong to a family that does not exist', () async {
      expect(
        () => insertPerson('p1', 'no-such-family'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('a relationship cannot name a person that does not exist', () async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');

      expect(
        () => insertRelationship(
          id: 'r1',
          familyId: 'f1',
          type: RelationshipType.parentChild,
          personAId: 'p1',
          personBId: 'ghost',
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('cascade', () {
    test('deleting a person removes edges naming them at either end', () async {
      // Orphaned edges are the commonest corruption for this shape, and they
      // surface as blank nodes in the tree (§15.1).
      await insertFamily('f1');
      await insertPerson('parent', 'f1');
      await insertPerson('child', 'f1');
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.parentChild,
        personAId: 'parent',
        personBId: 'child',
      );

      await (db.delete(db.persons)
            ..where((p) => p.id.equals('child')))
          .go();

      expect(await db.select(db.relationships).get(), isEmpty);
    });

    test('deleting the first endpoint also clears the edge', () async {
      await insertFamily('f1');
      await insertPerson('parent', 'f1');
      await insertPerson('child', 'f1');
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.parentChild,
        personAId: 'parent',
        personBId: 'child',
      );

      await (db.delete(db.persons)
            ..where((p) => p.id.equals('parent')))
          .go();

      expect(await db.select(db.relationships).get(), isEmpty);
    });

    test('deleting a family clears its people and their edges', () async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');
      await insertPerson('p2', 'f1');
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.spouse,
        personAId: 'p1',
        personBId: 'p2',
      );

      await (db.delete(db.families)..where((f) => f.id.equals('f1'))).go();

      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.select(db.relationships).get(), isEmpty);
    });
  });

  group('unique relationship key', () {
    setUp(() async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');
      await insertPerson('p2', 'f1');
    });

    test('rejects the same pair twice for one type', () async {
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.parentChild,
        personAId: 'p1',
        personBId: 'p2',
      );

      expect(
        () => insertRelationship(
          id: 'r2',
          familyId: 'f1',
          type: RelationshipType.parentChild,
          personAId: 'p1',
          personBId: 'p2',
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('allows the same pair under a different type', () async {
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.parentChild,
        personAId: 'p1',
        personBId: 'p2',
      );

      expect(
        () => insertRelationship(
          id: 'r2',
          familyId: 'f1',
          type: RelationshipType.spouse,
          personAId: 'p1',
          personBId: 'p2',
        ),
        returnsNormally,
      );
    });

    test('allows the reversed pair, which canonical ordering prevents', () async {
      // The database cannot see that (p2, p1) is the same couple as (p1, p2).
      // Only the domain's canonical ordering makes the constraint effective,
      // which is why Relationship.spouse sorts the ids before they get here.
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.spouse,
        personAId: 'p1',
        personBId: 'p2',
      );

      expect(
        () => insertRelationship(
          id: 'r2',
          familyId: 'f1',
          type: RelationshipType.spouse,
          personAId: 'p2',
          personBId: 'p1',
        ),
        returnsNormally,
      );
    });
  });

  group('synchronisation columns', () {
    test('every table carries updatedAt and a nullable deletedAt', () async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');
      await insertRelationship(
        id: 'r1',
        familyId: 'f1',
        type: RelationshipType.parentChild,
        personAId: 'p1',
        personBId: 'p1',
      );

      final family = await db.select(db.families).getSingle();
      final person = await db.select(db.persons).getSingle();
      final relationship = await db.select(db.relationships).getSingle();

      expect(family.updatedAt, now());
      expect(family.deletedAt, isNull);
      expect(person.updatedAt, now());
      expect(person.deletedAt, isNull);
      expect(relationship.updatedAt, now());
      expect(relationship.deletedAt, isNull);
    });

    test('a tombstone can be set without removing the row', () async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');

      await (db.update(db.persons)..where((p) => p.id.equals('p1'))).write(
        PersonsCompanion(deletedAt: Value(now())),
      );

      final person = await db.select(db.persons).getSingle();
      expect(person.deletedAt, now());
      expect(person.displayName, 'Person p1', reason: 'row still present');
    });
  });

  group('date storage', () {
    test('keeps year-only and full dates apart', () async {
      // The whole point of ISO-prefix text: '1887' and '1887-01-01' are
      // different claims and must stay different in storage (§4.2).
      await insertFamily('f1');
      await db
          .into(db.persons)
          .insert(
            PersonsCompanion.insert(
              id: 'p1',
              familyId: 'f1',
              displayName: 'Cụ Bảy',
              sex: Sex.male,
              updatedAt: now(),
              birthDateIso: const Value('1887'),
              deathDateIso: const Value('1950-03-15'),
            ),
          );

      final person = await db.select(db.persons).getSingle();
      expect(person.birthDateIso, '1887');
      expect(person.deathDateIso, '1950-03-15');
    });

    test('holds a lunar reading in its own columns', () async {
      await insertFamily('f1');
      await db
          .into(db.persons)
          .insert(
            PersonsCompanion.insert(
              id: 'p1',
              familyId: 'f1',
              displayName: 'Cụ Bảy',
              sex: Sex.male,
              updatedAt: now(),
              deathDateIso: const Value('1960-04-05'),
              deathLunarYear: const Value(1960),
              deathLunarMonth: const Value(3),
              deathLunarDay: const Value(12),
            ),
          );

      final person = await db.select(db.persons).getSingle();
      expect(person.deathDateIso, '1960-04-05');
      expect(person.deathLunarYear, 1960);
      expect(person.deathLunarMonth, 3);
      expect(person.deathLunarDay, 12);
      expect(person.deathLunarIsLeapMonth, isFalse);
    });

    test('approximate defaults to false rather than null', () async {
      await insertFamily('f1');
      await insertPerson('p1', 'f1');

      final person = await db.select(db.persons).getSingle();
      expect(person.birthDateApproximate, isFalse);
      expect(person.deathDateApproximate, isFalse);
    });
  });

  group('enums', () {
    test('are stored by name, so the rows stay readable', () async {
      await insertFamily('f1');
      await db
          .into(db.persons)
          .insert(
            PersonsCompanion.insert(
              id: 'p1',
              familyId: 'f1',
              displayName: 'Bà Lan',
              sex: Sex.female,
              updatedAt: now(),
            ),
          );

      final raw = await db
          .customSelect('SELECT sex FROM persons WHERE id = ?', variables: [
            Variable<String>('p1'),
          ])
          .getSingle();

      expect(raw.data['sex'], 'female');
    });
  });
}
