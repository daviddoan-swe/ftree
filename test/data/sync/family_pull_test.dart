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

    test('and a deletion still does not take an edited person', () async {
      await asIfDownloaded();
      await repository.savePerson(person(1, 'sửa ở máy này'));

      final result = await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
      );

      expect(result.held, <String>[personId(1)]);
      final here = await repository.loadFamily(familyId);
      expect(here!.graph.persons, hasLength(1));
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
