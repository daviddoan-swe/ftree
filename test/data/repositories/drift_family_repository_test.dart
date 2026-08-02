import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late FamilyRepository repository;

  final clock = DateTime.utc(2026, 8, 2, 12);

  setUpAll(() {
    // Drift warns when a database class is built twice, because two live
    // instances over one executor can corrupt each other. These tests do build
    // several, but each has its own executor and the file-based pair is strictly
    // sequential — the second opens only after the first has closed.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db, now: () => clock);
  });

  tearDown(() async {
    await db.close();
  });

  const familyId = 'f1';
  const aliceId = 'aaaa';
  const bobId = 'bbbb';
  const carolId = 'cccc';

  Person personOf(String id) =>
      Person(id: id, familyId: familyId, displayName: 'Person $id');

  Future<void> seedThreeGenerations() async {
    await repository.saveFamily(
      const Family(id: familyId, name: 'Họ Nguyễn'),
    );
    for (final id in <String>[aliceId, bobId, carolId]) {
      await repository.savePerson(personOf(id));
    }
    await repository.saveRelationship(
      Relationship.parentChild(
        id: 'r-ab',
        familyId: familyId,
        parent: aliceId,
        child: bobId,
      ),
    );
    await repository.saveRelationship(
      Relationship.parentChild(
        id: 'r-bc',
        familyId: familyId,
        parent: bobId,
        child: carolId,
      ),
    );
  }

  group('round trip through storage', () {
    test('a family written can be read back', () async {
      const family = Family(
        id: familyId,
        name: 'Họ Nguyễn',
        description: 'Chi trưởng',
        usesLunarCalendar: true,
      );
      await repository.saveFamily(family);

      final loaded = await repository.loadFamily(familyId);
      expect(loaded!.family, family);
    });

    test('people and relationships come back as a queryable graph', () async {
      await seedThreeGenerations();

      final graph = (await repository.loadFamily(familyId))!.graph;

      expect(graph.persons.length, 3);
      expect(graph.parents(bobId).single.id, aliceId);
      expect(
        graph.ancestors(carolId).map((p) => p.id),
        <String>[bobId, aliceId],
      );
    });

    test('a person keeps partial dates and a lunar reading', () async {
      await repository.saveFamily(const Family(id: familyId, name: 'F'));
      final person = Person(
        id: aliceId,
        familyId: familyId,
        displayName: 'Cụ Bảy',
        birthDate: GenealogicalDate(year: 1887),
        deathDate: GenealogicalDate(
          year: 1960,
          month: 4,
          day: 5,
          lunar: LunarDate(year: 1960, month: 3, day: 12),
        ),
      );
      await repository.savePerson(person);

      final loaded = (await repository.loadFamily(familyId))!.graph
          .personById(aliceId);

      expect(loaded, person);
      expect(loaded!.birthDate!.month, isNull, reason: 'year-only stays so');
      expect(loaded.deathDate!.lunar!.day, 12);
    });

    test('an unknown family is null rather than an error', () async {
      expect(await repository.loadFamily('no-such-family'), isNull);
    });

    test('listFamilies returns what was saved', () async {
      await repository.saveFamily(const Family(id: 'f1', name: 'Họ Nguyễn'));
      await repository.saveFamily(const Family(id: 'f2', name: 'Smith'));

      final names = (await repository.listFamilies())
          .map((f) => f.name)
          .toList();
      expect(names, containsAll(<String>['Họ Nguyễn', 'Smith']));
    });
  });

  group('reopening the database', () {
    test('data survives closing the database and opening the file again',
        () async {
      // The M3 exit criterion, and it needs a real file: an in-memory database
      // dies with its connection, so nothing short of this proves the data was
      // written rather than merely remembered.
      final directory = await Directory.systemTemp.createTemp('ftree_test');
      final file = File('${directory.path}/ftree.sqlite');

      try {
        final firstDb = AppDatabase(NativeDatabase(file));
        final firstRepo = DriftFamilyRepository(firstDb, now: () => clock);
        await firstRepo.saveFamily(const Family(id: familyId, name: 'Họ Lê'));
        await firstRepo.savePerson(personOf(aliceId));
        await firstRepo.savePerson(personOf(bobId));
        await firstRepo.saveRelationship(
          Relationship.parentChild(
            id: 'r1',
            familyId: familyId,
            parent: aliceId,
            child: bobId,
          ),
        );
        await firstDb.close();

        expect(await file.exists(), isTrue, reason: 'written to disk');

        final secondDb = AppDatabase(NativeDatabase(file));
        final secondRepo = DriftFamilyRepository(secondDb, now: () => clock);
        final reopened = await secondRepo.loadFamily(familyId);

        expect(reopened!.family.name, 'Họ Lê');
        expect(reopened.graph.persons.map((p) => p.id), <String>[
          aliceId,
          bobId,
        ]);
        expect(reopened.graph.parents(bobId).single.id, aliceId);
        await secondDb.close();
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('a relationship refused on write is refused after reopening too',
        () async {
      // Foreign keys are enabled per connection, so a second connection that
      // forgot to switch them on would quietly accept an orphan.
      final directory = await Directory.systemTemp.createTemp('ftree_test');
      final file = File('${directory.path}/ftree.sqlite');

      try {
        final firstDb = AppDatabase(NativeDatabase(file));
        await DriftFamilyRepository(firstDb, now: () => clock)
            .saveFamily(const Family(id: familyId, name: 'F'));
        await firstDb.close();

        final secondDb = AppDatabase(NativeDatabase(file));
        final secondRepo = DriftFamilyRepository(secondDb, now: () => clock);

        await expectLater(
          secondRepo.saveRelationship(
            Relationship.parentChild(
              id: 'r1',
              familyId: familyId,
              parent: 'ghost-a',
              child: 'ghost-b',
            ),
          ),
          throwsA(anything),
        );
        await secondDb.close();
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('saving the same id twice updates rather than duplicating', () async {
      await repository.saveFamily(const Family(id: familyId, name: 'Old'));
      await repository.saveFamily(const Family(id: familyId, name: 'New'));

      final families = await repository.listFamilies();
      expect(families.length, 1);
      expect(families.single.name, 'New');
    });

    test('editing a person overwrites the previous values', () async {
      await repository.saveFamily(const Family(id: familyId, name: 'F'));
      await repository.savePerson(personOf(aliceId));
      await repository.savePerson(
        Person(
          id: aliceId,
          familyId: familyId,
          displayName: 'Renamed',
          birthDate: GenealogicalDate(year: 1900),
        ),
      );

      final loaded = (await repository.loadFamily(familyId))!.graph
          .personById(aliceId);
      expect(loaded!.displayName, 'Renamed');
      expect(loaded.birthDate, GenealogicalDate(year: 1900));
    });
  });

  group('deletion leaves a tombstone', () {
    test('a deleted person disappears from reads but not from the table',
        () async {
      await seedThreeGenerations();
      await repository.deletePerson(bobId);

      final graph = (await repository.loadFamily(familyId))!.graph;
      expect(graph.personById(bobId), isNull);

      // Still on disk, carrying the tombstone that synchronisation will need.
      final row = await (db.select(db.persons)
            ..where((p) => p.id.equals(bobId)))
          .getSingle();
      expect(row.deletedAt, clock);
      expect(row.displayName, 'Person $bobId');
    });

    test('deleting a person also tombstones their relationships', () async {
      // The schema cascade cannot do this: it only fires on a physical delete,
      // and nothing here performs one. Left live, these edges would sync as
      // real relationships pointing at somebody the family no longer has.
      await seedThreeGenerations();
      await repository.deletePerson(bobId);

      final graph = (await repository.loadFamily(familyId))!.graph;
      expect(graph.relationships, isEmpty);

      final rows = await db.select(db.relationships).get();
      expect(rows.length, 2, reason: 'rows kept');
      expect(rows.every((r) => r.deletedAt == clock), isTrue);
    });

    test('a deleted person leaves no orphaned edge behind', () async {
      // The M3 exit criterion, checked from the graph's point of view.
      await seedThreeGenerations();
      await repository.deletePerson(bobId);

      final graph = (await repository.loadFamily(familyId))!.graph;
      for (final relationship in graph.relationships) {
        expect(graph.personById(relationship.personAId), isNotNull);
        expect(graph.personById(relationship.personBId), isNotNull);
      }
    });

    test('deleting one relationship leaves both people alone', () async {
      await seedThreeGenerations();
      await repository.deleteRelationship('r-ab');

      final graph = (await repository.loadFamily(familyId))!.graph;
      expect(graph.persons.length, 3);
      expect(graph.relationships.length, 1);
      expect(graph.parents(bobId), isEmpty);
      expect(graph.parents(carolId).single.id, bobId);
    });

    test('deleting a family hides it and everything in it', () async {
      await seedThreeGenerations();
      await repository.deleteFamily(familyId);

      expect(await repository.loadFamily(familyId), isNull);
      expect(await repository.listFamilies(), isEmpty);

      final persons = await db.select(db.persons).get();
      final relationships = await db.select(db.relationships).get();
      expect(persons.every((p) => p.deletedAt == clock), isTrue);
      expect(relationships.every((r) => r.deletedAt == clock), isTrue);
    });

    test('one family being deleted does not touch another', () async {
      await seedThreeGenerations();
      await repository.saveFamily(const Family(id: 'f2', name: 'Smith'));
      await repository.savePerson(
        const Person(id: 'other', familyId: 'f2', displayName: 'Other'),
      );

      await repository.deleteFamily(familyId);

      final survivor = await repository.loadFamily('f2');
      expect(survivor!.graph.persons.single.id, 'other');
    });
  });

  group('timestamps', () {
    test('every write records updatedAt in UTC', () async {
      await repository.saveFamily(const Family(id: familyId, name: 'F'));
      await repository.savePerson(personOf(aliceId));

      final family = await db.select(db.families).getSingle();
      final person = await db.select(db.persons).getSingle();

      expect(family.updatedAt, clock);
      expect(family.updatedAt.isUtc, isTrue);
      expect(person.updatedAt.isUtc, isTrue);
    });

    test('a local clock is still stored as UTC', () async {
      // The schema keeps ISO-8601 UTC text; writing a local DateTime unchanged
      // would attach the wrong zone to the value.
      final localClock = DateTime(2026, 8, 2, 12);
      final localRepo = DriftFamilyRepository(db, now: () => localClock);
      await localRepo.saveFamily(const Family(id: familyId, name: 'F'));

      final row = await db.select(db.families).getSingle();
      expect(row.updatedAt.isUtc, isTrue);
      expect(row.updatedAt, localClock.toUtc());
    });

    test('deleting stamps updatedAt as well as deletedAt', () async {
      // A tombstone that did not move updatedAt would look older than the row
      // it replaces, and synchronisation orders by change.
      await seedThreeGenerations();
      await repository.deletePerson(bobId);

      final row = await (db.select(db.persons)
            ..where((p) => p.id.equals(bobId)))
          .getSingle();
      expect(row.updatedAt, clock);
      expect(row.deletedAt, clock);
    });
  });
}
