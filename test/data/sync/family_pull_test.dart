/// Taking a family's changes down (ROADMAP M9, step 1).
///
/// SQLite is real, because what a pull has to get right is what ends up on the
/// device. What the server would have answered is handed in: the request is
/// one `WHERE change_seq > ?`, and doubting Postgres's greater-than proves
/// nothing.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/family_pull.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyPull pull;

  const familyId = 'f0000000-0000-7000-8000-000000000001';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Person person(int n, String name) =>
      Person(id: personId(n), familyId: familyId, displayName: name);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    pull = FamilyPull(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person(1, 'Cụ Tổ')],
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Clears the flag every local write sets, as arriving from the server does.
  Future<void> asIfDownloaded() async {
    await db.customStatement('UPDATE families SET unsent = 0');
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE relationships SET unsent = 0');
  }

  group('where this device has got to', () {
    test('a family never pulled is at nothing', () async {
      expect(await pull.lastSeen(familyId), 0);
    });

    test('and a family not here at all is too', () async {
      expect(await pull.lastSeen('no-such-family'), 0);
    });

    test('the mark moves only when something is applied', () async {
      await asIfDownloaded();

      await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 12, persons: <Person>[person(2, 'Bà Tổ')]),
      );

      expect(await pull.lastSeen(familyId), 12);
    });

    test('an empty answer moves nothing', () async {
      // Nothing came, so nothing is recorded as having come. A mark moved on
      // an empty answer would be a claim the device cannot support.
      await pull.apply(familyId, const IncomingChanges(highestSeq: 99));

      expect(await pull.lastSeen(familyId), 0);
    });
  });

  group('what arrives', () {
    setUp(asIfDownloaded);

    test('a new person is written in', () async {
      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, persons: <Person>[person(2, 'Bà Tổ')]),
      );

      expect(result.applied, 1);
      final here = await repository.loadFamily(familyId);
      expect(here!.graph.persons.map((p) => p.displayName), contains('Bà Tổ'));
    });

    test('a change to somebody already here replaces them', () async {
      // Not add-only, which is the whole difference from importing a file.
      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'Cụ Tổ Nguyễn Phúc Thịnh')],
        ),
      );

      final here = await repository.loadFamily(familyId);
      expect(
        here!.graph.personById(personId(1))!.displayName,
        'Cụ Tổ Nguyễn Phúc Thịnh',
      );
    });

    test('a deletion arrives as a tombstone and takes effect', () async {
      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
      );

      expect(result.applied, 1);
      final here = await repository.loadFamily(familyId);
      expect(here!.graph.persons, isEmpty);
    });

    test('the family’s own name comes down too', () async {
      await pull.apply(
        familyId,
        const IncomingChanges(
          highestSeq: 7,
          family: Family(id: familyId, name: 'Họ Nguyễn – Phù Ninh'),
        ),
      );

      final here = await repository.loadFamily(familyId);
      expect(here!.family.name, 'Họ Nguyễn – Phù Ninh');
    });

    test('but not this device’s own notes about it', () async {
      // sharedAt, myRole and lastSeen say what this device did and may do.
      // The server has nothing to say about any of them (PRODUCT §4.2, §5.0).
      await db.customStatement(
        "UPDATE families SET shared_at = '2026-09-25T00:00:00Z', "
        "my_role = 'editor'",
      );

      await pull.apply(
        familyId,
        const IncomingChanges(
          highestSeq: 7,
          family: Family(id: familyId, name: 'Đổi tên'),
        ),
      );

      final row = (await db.select(db.families).get()).single;
      expect(row.name, 'Đổi tên');
      expect(row.sharedAt, isNotNull);
      expect(row.myRole, 'editor');
    });
  });

  group('two edits of the same person', () {
    setUp(asIfDownloaded);

    test('different fields fit together, and nobody is asked', () async {
      // The case the whole of step three is for: two relatives filling in
      // different halves of the same record.
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthPlace: 'Nam Định',
        ),
      );

      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[
            Person(
              id: personId(1),
              familyId: familyId,
              displayName: 'Cụ Tổ',
              biography: 'Làm nghề dạy học.',
            ),
          ],
        ),
      );

      expect(result.merged, 1);
      expect(result.conflicted, isEmpty);

      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.birthPlace, 'Nam Định', reason: 'mine survived');
      expect(here.biography, 'Làm nghề dạy học.', reason: 'and theirs came');
    });

    test('a merged row still has to go up', () async {
      // Half of it is this device's, and the server has never seen that half.
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthPlace: 'Nam Định',
        ),
      );

      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[
            Person(
              id: personId(1),
              familyId: familyId,
              displayName: 'Cụ Tổ',
              biography: 'Làm nghề dạy học.',
            ),
          ],
        ),
      );

      final row = (await db.select(db.persons).get()).firstWhere(
        (p) => p.id == personId(1),
      );
      expect(row.unsent, isTrue);
      expect(
        row.baseFields,
        isNotNull,
        reason: 'and the base has moved on to what they now hold',
      );
    });

    test('the same field, changed differently, is a conflict', () async {
      await repository.savePerson(person(1, 'Cụ Tổ — sửa ở máy này'));

      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'Cụ Tổ — sửa ở máy khác')],
        ),
      );

      expect(result.conflicted, <String>[personId(1)]);
      expect(result.applied, 0);
    });

    test('and nothing is decided for anybody', () async {
      // A later change_seq says which write reached the server second, not
      // which reading of a hundred-year-old record is right.
      await repository.savePerson(person(1, 'sửa ở máy này'));

      final reported = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'sửa ở máy khác')],
        ),
      );

      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.displayName, 'sửa ở máy này');
      expect(
        reported.conflicted,
        <String>[personId(1)],
        reason: 'it has to be reported as one, not quietly merged',
      );
      expect(reported.merged, 0);
    });

    test('two edits here still merge against what the server gave', () async {
      // The base is kept on the *first* edit after a synchronisation and not
      // touched again. Overwritten by the second, a merge would compare this
      // device's work against itself, find no change where there was one, and
      // hand the field back to the other side.
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthPlace: 'Nam Định',
        ),
      );
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthPlace: 'Nam Định, Ý Yên',
        ),
      );

      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[
            // They left the birthplace where the base had it — empty — and
            // only added a life. Had they set it too, that would be a real
            // disagreement about the birthplace, which is a different test.
            Person(
              id: personId(1),
              familyId: familyId,
              displayName: 'Cụ Tổ',
              biography: 'Làm nghề dạy học.',
            ),
          ],
        ),
      );

      expect(result.merged, 1);
      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(
        here.birthPlace,
        'Nam Định, Ý Yên',
        reason: 'both of my edits are still mine',
      );
      expect(here.biography, 'Làm nghề dạy học.');
    });

    test(
      'the other version is kept, so the question outlives the pull',
      () async {
        // `lastSeen` moves past the change either way. A conflict only reported
        // would never be offered again, and the disagreement would quietly
        // become this device's version winning.
        await repository.savePerson(person(1, 'sửa ở máy này'));

        await pull.apply(
          familyId,
          IncomingChanges(
            highestSeq: 7,
            persons: <Person>[person(1, 'sửa ở máy khác')],
          ),
        );

        final row = (await db.select(db.persons).get()).firstWhere(
          (p) => p.id == personId(1),
        );
        expect(row.theirsFields, isNotNull);
        expect(row.theirsFields, contains('sửa ở máy khác'));
      },
    );

    test('a conflict in one person does not stop another arriving', () async {
      await repository.savePerson(person(1, 'sửa ở máy này'));

      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'từ máy khác'), person(2, 'Bà Tổ')],
        ),
      );

      expect(result.conflicted, <String>[personId(1)]);
      expect(result.applied, 1);
      expect(
        (await repository.loadFamily(familyId))!.graph.persons,
        hasLength(2),
      );
    });
  });

  group('when there is no version to merge against', () {
    test('a person edited before anything was ever pulled is held', () async {
      // Nothing was downloaded, so there is no version the two started from.
      // Holding is all that can honestly be done.
      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'từ máy khác')],
        ),
      );

      expect(result.held, <String>[personId(1)]);
      expect(result.conflicted, isEmpty);
    });

    test('and a deletion over an edit becomes a question', () async {
      // Held would not do. The row stays live and unsent, so the next push
      // sends the person up alive and undoes the deletion for everybody — with
      // nobody told either that it happened or that it was reversed
      // (ROADMAP M9, step 4).
      await asIfDownloaded();
      await repository.savePerson(person(1, 'sửa ở máy này'));

      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
      );

      expect(result.conflicted, <String>[personId(1)]);
      expect(result.held, isEmpty);

      // Neither side's version is applied while the question stands.
      final here = await repository.loadFamily(familyId);
      expect(here!.graph.persons, hasLength(1));
      expect(here.graph.personById(personId(1))!.displayName, 'sửa ở máy này');
    });
  });

  group('when the family itself is renamed', () {
    setUp(asIfDownloaded);

    test('the rename is reported apart from the people', () async {
      // The list of families reads the repository rather than a snapshot, so
      // it is the one screen that cannot notice a rename on its own: without
      // this the gia phả was called one thing inside and another in the list.
      final result = await pull.apply(
        familyId,
        const IncomingChanges(
          highestSeq: 7,
          family: Family(id: familyId, name: 'Họ Nguyễn – Phù Ninh'),
        ),
      );

      expect(result.familyChanged, isTrue);
      expect(
        (await repository.loadFamily(familyId))!.family.name,
        'Họ Nguyễn – Phù Ninh',
      );
    });

    test('people arriving on their own do not claim one', () async {
      // Otherwise every pull that brought anything would re-read every family
      // to catch the rare case where one was renamed.
      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, persons: <Person>[person(2, 'Bà Tổ')]),
      );

      expect(result.applied, 1);
      expect(result.familyChanged, isFalse);
    });

    test('nor does one this device renamed and has not sent', () async {
      // Held, so nothing was applied and there is nothing for the list to
      // show that it is not showing already.
      await repository.saveFamily(
        const Family(id: familyId, name: 'đổi ở máy này'),
      );

      final result = await pull.apply(
        familyId,
        const IncomingChanges(
          highestSeq: 7,
          family: Family(id: familyId, name: 'đổi ở máy kia'),
        ),
      );

      expect(result.held, <String>[familyId]);
      expect(result.familyChanged, isFalse);
    });
  });

  group('when a removal meets an edit', () {
    setUp(asIfDownloaded);

    /// The row as SQLite holds it, tombstone and questions included. The
    /// repository filters tombstones out, which is exactly what these need to
    /// see.
    Future<PersonRow> rowFor(int n) => (db.select(
      db.persons,
    )..where((p) => p.id.equals(personId(n)))).getSingle();

    test('their removal is written down, not applied', () async {
      await repository.savePerson(person(1, 'sửa ở máy này'));

      await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
      );

      final row = await rowFor(1);
      expect(row.theirsDeleted, isTrue);
      expect(row.deletedAt, isNull, reason: 'the edit is not destroyed');
      expect(row.unsent, isTrue, reason: 'it has still not gone anywhere');
    });

    test('both sides removing is no disagreement', () async {
      // Nothing to ask. Asking anyway would put a question to somebody whose
      // only two answers mean the same thing.
      await repository.deletePerson(personId(1));

      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
      );

      expect(result.conflicted, isEmpty);
      expect(result.applied, 1);
      final row = await rowFor(1);
      expect(row.deletedAt, isNotNull);
      expect(row.unsent, isFalse, reason: 'the server already has it');
    });

    test('their edit does not bring back somebody removed here', () async {
      // The dangerous direction. A merge writes the row through `personToRow`,
      // which clears `deletedAt` because writing a row asserts it exists — so
      // merging here would quietly undo the deletion, locally, with nothing
      // said.
      await repository.savePerson(person(1, 'sửa rồi mới xoá'));
      await db.customStatement('UPDATE persons SET unsent = 0');
      await repository.savePerson(person(1, 'sửa lần nữa'));
      await repository.deletePerson(personId(1));

      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'từ máy khác')],
        ),
      );

      expect(result.conflicted, <String>[personId(1)]);
      expect(result.merged, 0);
      final row = await rowFor(1);
      expect(row.deletedAt, isNotNull, reason: 'still removed');
      expect(row.theirsFields, isNotNull, reason: 'their version is kept');
      expect(row.displayName, 'sửa lần nữa');
    });

    test('nor does a merge that would otherwise have gone through', () async {
      // The way the guard actually gets reached. Where the two sides changed
      // the *same* field the merge conflicts anyway, and a conflict writes only
      // `theirsFields`, so the tombstone survives by luck rather than by
      // design. It is the clean merge that is dangerous: it writes the whole
      // row through `personToRow`, which clears `deletedAt` because writing a
      // row asserts that it exists (§15.2) — and somebody removed here walks
      // back in with nothing said.
      await repository.savePerson(person(1, 'sửa ở máy này'));
      await repository.deletePerson(personId(1));

      // A different field, so there is nothing to disagree about.
      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[
            Person(
              id: personId(1),
              familyId: familyId,
              displayName: 'Cụ Tổ',
              biography: 'Làm nghề dạy học.',
            ),
          ],
        ),
      );

      expect(result.merged, 0, reason: 'a removal is not merged into');
      expect(result.conflicted, <String>[personId(1)]);
      final row = await rowFor(1);
      expect(row.deletedAt, isNotNull, reason: 'still removed');
      expect(row.biography, isNull, reason: 'their version is kept apart');
    });

    test('an edge is taken even where a person would be asked about', () async {
      // An edge carries no recorded detail, only which two people it joins, and
      // changing that makes it a different edge. There is nothing to lose and
      // so nothing to ask.
      await repository.saveAll(persons: <Person>[person(2, 'Bà Tổ')]);
      const edgeId = 'r0000000-0000-7000-8000-000000000001';
      await repository.saveRelationship(
        Relationship.spouse(
          id: edgeId,
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );

      final result = await pull.apply(
        familyId,
        const IncomingChanges(
          highestSeq: 7,
          deletedRelationships: <String>[edgeId],
        ),
      );

      expect(result.held, isEmpty);
      final here = await repository.loadFamily(familyId);
      expect(here!.graph.relationships, isEmpty);
    });
  });

  group('when the owner deletes the whole family', () {
    setUp(asIfDownloaded);

    test('it takes the family, its people and their edges', () async {
      await repository.saveAll(persons: <Person>[person(2, 'Bà Tổ')]);
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
      await asIfDownloaded();

      final result = await pull.apply(
        familyId,
        const IncomingChanges(highestSeq: 30, familyDeleted: true),
      );

      expect(result.familyDeleted, isTrue);
      expect(await repository.loadFamily(familyId), isNull);
      expect(await repository.listFamilies(), isEmpty);

      final people = await db.select(db.persons).get();
      expect(people.every((p) => p.deletedAt != null), isTrue);
      final edges = await db.select(db.relationships).get();
      expect(edges.every((r) => r.deletedAt != null), isTrue);
    });

    test('unsent work goes with it, and its questions too', () async {
      // Not a disagreement about one person that somebody could be asked
      // about — there would be nothing left to keep the answer in.
      await repository.savePerson(person(1, 'sửa chưa gửi'));

      await pull.apply(
        familyId,
        const IncomingChanges(highestSeq: 30, familyDeleted: true),
      );

      final row = await (db.select(
        db.persons,
      )..where((p) => p.id.equals(personId(1)))).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.unsent, isFalse, reason: 'there is nowhere for it to go');
      expect(row.baseFields, isNull);
      expect(row.theirsFields, isNull);
      expect(row.theirsDeleted, isFalse);
    });

    test('a rename arriving in the same answer does not survive it', () async {
      // Corrections have nothing left to correct. Applied first they would only
      // write rows the deletion is about to tombstone, and a person written
      // after it would be left alive in a family that is gone.
      final result = await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 30,
          familyDeleted: true,
          persons: <Person>[person(2, 'Bà Tổ')],
        ),
      );

      expect(result.familyDeleted, isTrue);
      expect(await repository.loadFamily(familyId), isNull);
      final people = await db.select(db.persons).get();
      expect(people.every((p) => p.deletedAt != null), isTrue);
    });

    test('the mark still moves, so it is not asked for again', () async {
      await pull.apply(
        familyId,
        const IncomingChanges(highestSeq: 30, familyDeleted: true),
      );

      expect(await pull.lastSeen(familyId), 30);
    });
  });

  group('what it writes for the next pull', () {
    setUp(asIfDownloaded);

    test('an applied row is no longer unsent', () async {
      // Otherwise the next pull would refuse to touch what it wrote itself,
      // and the family would freeze after one round.
      await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, persons: <Person>[person(2, 'Bà Tổ')]),
      );

      final rows = await db.select(db.persons).get();
      expect(rows.map((p) => p.unsent), everyElement(isFalse));
    });

    test('a relationship comes down and is marked the same way', () async {
      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(2, 'Bà Tổ')],
          relationships: <Relationship>[
            Relationship.spouse(
              id: 'r0000000-0000-7000-8000-000000000001',
              familyId: familyId,
              personA: personId(1),
              personB: personId(2),
            ),
          ],
        ),
      );

      final here = await repository.loadFamily(familyId);
      expect(here!.graph.relationships, hasLength(1));
      expect((await db.select(db.relationships).get()).single.unsent, isFalse);
    });
  });
}
