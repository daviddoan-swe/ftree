/// Families whose copy on this device has to go (PRODUCT.md §5.0, §5.10).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/database/removed_families.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late RemovedFamilies removed;

  const one = 'f0000000-0000-7000-8000-000000000001';
  const two = 'f0000000-0000-7000-8000-000000000002';

  Person someone(String family, int n) => Person(
    id: 'p0000000-0000-7000-800$n-000000000001',
    familyId: family,
    displayName: 'Cụ Tổ $n',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    removed = RemovedFamilies(db);

    await repository.saveAll(
      family: const Family(id: one, name: 'Họ Nguyễn'),
      persons: <Person>[someone(one, 1)],
    );
    await repository.saveAll(
      family: const Family(id: two, name: 'Họ Trần'),
      persons: <Person>[someone(two, 2)],
    );
    await SharingMarks(db).markShared(one);
    await db.customStatement('UPDATE families SET unsent = 0');
    await db.customStatement('UPDATE persons SET unsent = 0');
  });

  tearDown(() async => db.close());

  test('a family this account was put out of goes', () async {
    await FamilyRoles(db).remember(one, FamilyRole.removed);

    expect(await removed.drop(), <String, String>{one: 'Họ Nguyễn'});
    expect((await repository.listFamilies()).map((f) => f.id), <String>[two]);
  });

  test('and its people go with it', () async {
    await FamilyRoles(db).remember(one, FamilyRole.removed);

    await removed.drop();

    final rows = await db
        .customSelect("SELECT deleted_at FROM persons WHERE family_id = '$one'")
        .get();
    expect(rows.single.data['deleted_at'], isNotNull);
  });

  test('every other family is left alone', () async {
    // Being put out of one says nothing about the others, and a device holds
    // families it made itself beside ones it was invited into.
    await FamilyRoles(db).remember(one, FamilyRole.removed);
    await FamilyRoles(db).remember(two, FamilyRole.editor);

    await removed.drop();

    expect((await repository.listFamilies()).single.id, two);
  });

  test('what it drops is not then offered to the server', () async {
    // The part that is easy to miss. `deleteFamily` leaves its tombstones
    // unsent, because an owner deleting a family means everybody should lose
    // it. This is the opposite: the family stays, and this device loses its
    // copy. Left unsent, the sweep for stuck deletions would offer to delete
    // for everybody a gia phả this account has no say over — and the server
    // would refuse it in silence, for ever.
    await FamilyRoles(db).remember(one, FamilyRole.removed);

    await removed.drop();

    expect(await FamilyPush(db).deletedAndUnsent(), isEmpty);
  });

  test('running it twice changes nothing the second time', () async {
    // It runs on every refresh, not only when something changed — a drop
    // interrupted half way would otherwise leave a family marked removed and
    // still sitting there, with nothing that ever looks again.
    await FamilyRoles(db).remember(one, FamilyRole.removed);

    expect(await removed.drop(), <String, String>{one: 'Họ Nguyễn'});
    expect(await removed.drop(), isEmpty);
  });

  test('nothing marked removed means nothing to do', () async {
    expect(await removed.drop(), isEmpty);
    expect(await repository.listFamilies(), hasLength(2));
  });

  test('the name is read before the copy goes', () async {
    // The whole reason this returns names rather than ids. By the time anybody
    // wants to say which family disappeared, the row is a tombstone and
    // nothing draws it any more.
    await FamilyRoles(db).remember(one, FamilyRole.removed);

    expect((await removed.drop())[one], 'Họ Nguyễn');
  });

  group('a family somebody deleted', () {
    test('goes too, though this account was never put out', () async {
      // The other way in (PRODUCT §5.10). The membership survives
      // `delete_family_deep`, so nothing marks this family removed — the
      // server is asked about the family itself, and the answer arrives here.
      await FamilyRoles(db).remember(one, FamilyRole.editor);

      expect(await removed.drop(alsoGone: <String>{one}), <String, String>{
        one: 'Họ Nguyễn',
      });
      expect((await repository.listFamilies()).single.id, two);
    });

    test('keeps the role it had', () async {
      // An owner deleting on one device and reaching for their backup on
      // another is the one undo there is, and the role is what permits it. Drop
      // the copy, keep the claim.
      await FamilyRoles(db).remember(one, FamilyRole.owner);

      await removed.drop(alsoGone: <String>{one});

      expect(await FamilyRoles(db).all(), containsPair(one, FamilyRole.owner));
    });

    test('is not then offered to the server either', () async {
      // The deletion already happened up there. Offering it again spends a
      // request to be told what this device was just told.
      await FamilyRoles(db).remember(one, FamilyRole.editor);

      await removed.drop(alsoGone: <String>{one});

      expect(await FamilyPush(db).deletedAndUnsent(), isEmpty);
    });

    test('an empty set is not a predicate that drops everything', () async {
      // `id IN ()` is not SQL SQLite will take, and the obvious way of writing
      // this builds exactly that on every refresh where nothing is gone.
      await FamilyRoles(db).remember(one, FamilyRole.editor);

      expect(await removed.drop(alsoGone: const <String>{}), isEmpty);
      expect(await repository.listFamilies(), hasLength(2));
    });
  });
}
