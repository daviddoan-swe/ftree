/// Sending this device's changes up (ROADMAP M9, step 2).
///
/// SQLite is real. What the server does with an upsert is `test/cloud/`; what
/// is worth checking here is which rows the device offers, which it holds
/// back, and — the one that would lose somebody's work — which it stops
/// retrying.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyPush push;

  const familyId = 'f0000000-0000-7000-8000-000000000001';
  const other = 'f0000000-0000-7000-8000-000000000002';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Person person(int n, String name, {String family = familyId}) =>
      Person(id: personId(n), familyId: family, displayName: name);

  /// Clears the flag every local write sets, as arriving from the server does.
  Future<void> asIfSynced() async {
    await db.customStatement('UPDATE families SET unsent = 0');
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE relationships SET unsent = 0');
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    push = FamilyPush(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person(1, 'Cụ Tổ'), person(2, 'Bà Tổ')],
    );
    await repository.saveFamily(const Family(id: other, name: 'Họ Trần'));
    await asIfSynced();
  });

  tearDown(() async {
    await db.close();
  });

  group('what is waiting', () {
    test('nothing, when nothing has been touched', () async {
      expect((await push.pending(familyId)).isEmpty, isTrue);
    });

    test('a person edited here is offered', () async {
      await repository.savePerson(person(1, 'Cụ Tổ Nguyễn Phúc Thịnh'));

      final outgoing = await push.pending(familyId);

      expect(outgoing.persons, hasLength(1));
      expect(outgoing.persons.single.displayName, 'Cụ Tổ Nguyễn Phúc Thịnh');
    });

    test(
      'and one deleted here is offered as a removal, not as a row',
      () async {
        // `save_family_all` clears `deleted_at` on everything it writes. A
        // tombstone sent through it would bring the person back to life on the
        // server, so the two have to leave by different doors.
        await repository.deletePerson(personId(1));

        final outgoing = await push.pending(familyId);

        expect(outgoing.deletedPersons, <String>[personId(1)]);
        expect(outgoing.persons.map((p) => p.id), isNot(contains(personId(1))));
      },
    );

    test('another family’s changes are not swept in', () async {
      await repository.savePerson(person(9, 'Ai đó', family: other));

      expect((await push.pending(familyId)).isEmpty, isTrue);
    });

    test('the whole batch carries one timestamp', () async {
      // It is what the read-back afterwards looks for. Stamped row by row, a
      // push could only ever confirm the last of them.
      await repository.savePerson(person(1, 'sửa'));
      await repository.savePerson(person(2, 'sửa nữa'));

      final outgoing = await push.pending(familyId);

      expect(outgoing.stampedAt, isNotNull);
      expect(outgoing.ids, hasLength(2));
    });
  });

  group('what has gone', () {
    test(
      'only the ids the server was seen to hold stop being offered',
      () async {
        // The trap this exists for: an UPDATE a policy forbids changes nothing
        // and reports success. Clearing the flag on silence would drop the work
        // and never try again.
        await repository.savePerson(person(1, 'sửa'));
        await repository.savePerson(person(2, 'sửa nữa'));

        await push.markSent(<String>{personId(1)});

        final still = await push.pending(familyId);
        expect(still.persons, hasLength(1));
        expect(still.persons.single.id, personId(2));
      },
    );

    test('an empty answer leaves everything to go again', () async {
      await repository.savePerson(person(1, 'sửa'));

      await push.markSent(const <String>{});

      expect((await push.pending(familyId)).persons, hasLength(1));
    });

    test('clearing the flag does not touch what the row says', () async {
      // Nor `updatedAt`, which synchronisation orders by. The change was
      // already made; this only records that it has gone.
      await repository.savePerson(person(1, 'sửa'));
      final before = (await db.select(db.persons).get()).firstWhere(
        (p) => p.id == personId(1),
      );

      await push.markSent(<String>{personId(1)});

      final after = (await db.select(db.persons).get()).firstWhere(
        (p) => p.id == personId(1),
      );
      expect(after.displayName, before.displayName);
      expect(after.updatedAt, before.updatedAt);
      expect(after.unsent, isFalse);
    });

    test('a relationship goes the same way', () async {
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );

      final outgoing = await push.pending(familyId);
      expect(outgoing.relationships, hasLength(1));

      await push.markSent(outgoing.ids);

      expect((await push.pending(familyId)).isEmpty, isTrue);
    });

    test('the family’s own name goes too', () async {
      await repository.saveFamily(
        const Family(id: familyId, name: 'Họ Nguyễn – Phù Ninh'),
      );

      final outgoing = await push.pending(familyId);
      expect(outgoing.family?.name, 'Họ Nguyễn – Phù Ninh');

      await push.markSent(outgoing.ids);

      expect((await push.pending(familyId)).isEmpty, isTrue);
    });
  });

  group('what it counts', () {
    test('nothing waiting reads as nothing', () async {
      expect(await push.waiting(familyId), 0);
    });

    test('and two changes read as two', () async {
      await repository.savePerson(person(1, 'sửa'));
      await repository.deletePerson(personId(2));

      expect(await push.waiting(familyId), 2);
    });
  });
}
