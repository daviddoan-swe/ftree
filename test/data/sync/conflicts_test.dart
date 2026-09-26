/// The disagreements waiting for somebody to settle them
/// (ROADMAP M9, step 3b).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/conflicts.dart';
import 'package:ftree/data/sync/family_pull.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyPull pull;
  late Conflicts conflicts;

  const familyId = 'f0000000-0000-7000-8000-000000000001';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Person person(int n, String name, {String? place, String? life}) => Person(
    id: personId(n),
    familyId: familyId,
    displayName: name,
    birthPlace: place,
    biography: life,
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    pull = FamilyPull(db);
    conflicts = Conflicts(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person(1, 'Cụ Tổ'), person(2, 'Bà Tổ')],
    );
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE families SET unsent = 0');
  });

  tearDown(() async {
    await db.close();
  });

  /// Two devices editing the same field differently, which is what leaves a
  /// question behind.
  Future<void> disagreeAbout(
    int n, {
    required String mine,
    required String theirs,
  }) async {
    await repository.savePerson(person(n, mine));
    await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 7, persons: <Person>[person(n, theirs)]),
    );
  }

  group('what is waiting', () {
    test('nothing, when the two sides agree', () async {
      expect(await conflicts.countIn(familyId), 0);
      expect(await conflicts.inFamily(familyId), isEmpty);
    });

    test('a disagreement is listed with both versions and the field', () async {
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');

      final waiting = await conflicts.inFamily(familyId);

      expect(waiting, hasLength(1));
      expect(waiting.single.mine.displayName, 'Cụ Tổ (tôi)');
      expect(waiting.single.theirs!.displayName, 'Cụ Tổ (họ)');
      expect(waiting.single.fields.single.field, 'displayName');
    });

    test('a clean merge leaves nothing to ask about', () async {
      // Different fields fit together on their own; nobody is called on.
      await repository.savePerson(person(1, 'Cụ Tổ', place: 'Nam Định'));
      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(1, 'Cụ Tổ', life: 'Làm nghề dạy học.')],
        ),
      );

      expect(await conflicts.countIn(familyId), 0);
    });

    test(
      'one person disagreeing does not put the others in the list',
      () async {
        await disagreeAbout(1, mine: 'tôi', theirs: 'họ');

        expect(await conflicts.countIn(familyId), 1);
        expect(
          (await conflicts.inFamily(familyId)).single.mine.id,
          personId(1),
        );
      },
    );
  });

  group('settling it', () {
    test('keeping mine clears the question and leaves the value', () async {
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');

      await conflicts.settle(personId(1), const <String, Object?>{});

      expect(await conflicts.countIn(familyId), 0);
      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.displayName, 'Cụ Tổ (tôi)');
    });

    test('taking theirs writes their value in', () async {
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');

      await conflicts.settle(personId(1), const <String, Object?>{
        'displayName': 'Cụ Tổ (họ)',
      });

      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.displayName, 'Cụ Tổ (họ)');
      expect(await conflicts.countIn(familyId), 0);
    });

    test('a decision survives their version arriving again', () async {
      // The answer goes up, but until the server takes it the next pull still
      // carries their version. It must not quietly undo the decision: what the
      // two sides are now agreed to have started from is what the server held,
      // not what this device chose. Keep the wrong base and the rejected value
      // walks back in on the very next pull.
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');
      await conflicts.settle(personId(1), const <String, Object?>{});

      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 9,
          persons: <Person>[person(1, 'Cụ Tổ (họ)')],
        ),
      );

      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.displayName, 'Cụ Tổ (tôi)');
      expect(await conflicts.countIn(familyId), 0);
    });

    test('a settled row still has to go up', () async {
      // A decision is a change, and the other device has not seen it.
      await disagreeAbout(1, mine: 'tôi', theirs: 'họ');

      await conflicts.settle(personId(1), const <String, Object?>{});

      final row = (await db.select(db.persons).get()).firstWhere(
        (p) => p.id == personId(1),
      );
      expect(row.unsent, isTrue);
      expect(row.theirsFields, isNull);
    });

    test('and it goes, where before it was held back', () async {
      // A row in conflict is deliberately not pushed. Once answered it must
      // be, or the decision never reaches anybody.
      await disagreeAbout(1, mine: 'tôi', theirs: 'họ');
      expect((await FamilyPush(db).pending(familyId)).persons, isEmpty);

      await conflicts.settle(personId(1), const <String, Object?>{});

      expect((await FamilyPush(db).pending(familyId)).persons, hasLength(1));
    });

    test('answering one leaves another waiting', () async {
      await disagreeAbout(1, mine: 'tôi', theirs: 'họ');
      await disagreeAbout(2, mine: 'tôi 2', theirs: 'họ 2');
      expect(await conflicts.countIn(familyId), 2);

      await conflicts.settle(personId(1), const <String, Object?>{});

      expect(await conflicts.countIn(familyId), 1);
    });

    test('settling something nobody disagrees about does nothing', () async {
      await conflicts.settle(personId(1), const <String, Object?>{
        'displayName': 'không ai hỏi',
      });

      final here = (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!;
      expect(here.displayName, 'Cụ Tổ');
    });
  });

  group('when the field in dispute is a date', () {
    test('it is asked about by its pieces, not as a whole', () async {
      // Somebody adding a lunar reading has changed one field; somebody
      // correcting the year has changed another. Kept whole they would read
      // as one disagreement about the birth.
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Cụ Tổ',
          birthDate: GenealogicalDate.parseIso('1887'),
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
              birthDate: GenealogicalDate.parseIso('1888'),
            ),
          ],
        ),
      );

      final waiting = await conflicts.inFamily(familyId);

      expect(waiting.single.fields.single.field, 'birthDateIso');
      expect(waiting.single.fields.single.mine, '1887');
      expect(waiting.single.fields.single.theirs, '1888');
    });
  });

  group('a removal against an edit', () {
    Future<PersonRow> rowFor(int n) => (db.select(
      db.persons,
    )..where((p) => p.id.equals(personId(n)))).getSingle();

    /// They removed somebody this device has been editing.
    Future<void> theyRemoved(int n) async {
      await repository.savePerson(person(n, 'sửa ở máy này'));
      await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(n)]),
      );
    }

    /// This device removed somebody the server was changing.
    Future<void> iRemoved(int n) async {
      await repository.savePerson(person(n, 'sửa ở máy này'));
      await db.customStatement('UPDATE persons SET unsent = 0');
      await repository.savePerson(person(n, 'sửa lần nữa'));
      await repository.deletePerson(personId(n));
      await pull.apply(
        familyId,
        IncomingChanges(
          highestSeq: 7,
          persons: <Person>[person(n, 'từ máy khác')],
        ),
      );
    }

    test(
      'their removal is a question about the person, not the fields',
      () async {
        await theyRemoved(1);

        final one = (await conflicts.inFamily(familyId)).single;

        expect(one.kind, Dispute.theyRemoved);
        expect(one.theirs, isNull, reason: 'they have no version to show');
        expect(one.fields, isEmpty);
        expect(await conflicts.countIn(familyId), 1);
      },
    );

    test('and so is mine, the other way round', () async {
      await iRemoved(1);

      final one = (await conflicts.inFamily(familyId)).single;

      expect(one.kind, Dispute.iRemoved);
      expect(one.mine.displayName, 'sửa lần nữa');
      expect(one.theirs!.displayName, 'từ máy khác');
      expect(one.fields, isEmpty);
    });

    test('keeping somebody they removed sends them back up', () async {
      // Reviving them for everybody is exactly what was asked for, so the row
      // has to go — the server holds a tombstone and does not know otherwise.
      await theyRemoved(1);

      await conflicts.settleRemoval(personId(1), remove: false);

      final row = await rowFor(1);
      expect(row.deletedAt, isNull);
      expect(row.displayName, 'sửa ở máy này');
      expect(row.unsent, isTrue);
      expect(await conflicts.countIn(familyId), 0);
    });

    test('agreeing to their removal sends nothing', () async {
      // The server already holds the tombstone. Pushing would be a write with
      // nothing in it.
      await theyRemoved(1);

      await conflicts.settleRemoval(personId(1), remove: true);

      final row = await rowFor(1);
      expect(row.deletedAt, isNotNull);
      expect(row.unsent, isFalse);
      expect(await repository.loadFamily(familyId), isNotNull);
      expect(
        (await repository.loadFamily(familyId))!.graph.personById(personId(1)),
        isNull,
      );
    });

    test('standing by my removal sends the tombstone up', () async {
      await iRemoved(1);

      await conflicts.settleRemoval(personId(1), remove: true);

      final row = await rowFor(1);
      expect(row.deletedAt, isNotNull);
      expect(row.unsent, isTrue, reason: 'the server still has them');
      expect(row.theirsFields, isNull);
      expect(await conflicts.countIn(familyId), 0);
    });

    test('taking them back takes their version, not mine', () async {
      // Keeping somebody the other side was correcting means keeping the
      // correction. Reviving this device's copy instead would quietly discard
      // work that was never in dispute.
      await iRemoved(1);

      await conflicts.settleRemoval(personId(1), remove: false);

      final row = await rowFor(1);
      expect(row.deletedAt, isNull);
      expect(row.displayName, 'từ máy khác');
      expect(row.unsent, isFalse, reason: 'that is what the server holds');
    });

    test('a removal outranks a disagreement about a field', () async {
      // One pull finds the two sides disagreeing about a name; the next brings
      // word that the person has been removed. Settling the name first would
      // put a question to somebody about a birthplace belonging to a person the
      // other side has taken out.
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');
      await pull.apply(
        familyId,
        IncomingChanges(highestSeq: 9, deletedPersons: <String>[personId(1)]),
      );

      final one = (await conflicts.inFamily(familyId)).single;
      expect(one.kind, Dispute.theyRemoved);

      // And the field-by-field answer is refused, so nothing settles it by
      // accident while the larger question stands.
      await conflicts.settle(personId(1), const <String, Object?>{});
      expect(await conflicts.countIn(familyId), 1);
    });

    test('settling a removal nobody asked about does nothing', () async {
      await disagreeAbout(1, mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');

      await conflicts.settleRemoval(personId(1), remove: true);

      final row = await rowFor(1);
      expect(row.deletedAt, isNull);
      expect(await conflicts.countIn(familyId), 1);
    });
  });
}
