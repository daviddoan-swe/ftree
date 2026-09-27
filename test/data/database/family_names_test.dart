/// The name a shared family goes by on the server (PRODUCT.md §5.10).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_names.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyNames names;

  const one = 'f0000000-0000-7000-8000-000000000001';
  const two = 'f0000000-0000-7000-8000-000000000002';

  Future<String> nameOf(String id) async =>
      (await repository.loadFamily(id))!.family.name;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    names = FamilyNames(db);

    await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn'));
    await repository.saveFamily(const Family(id: two, name: 'Họ Trần'));
    // Nothing of this device's own is waiting; that case has its own test.
    await db.customStatement('UPDATE families SET unsent = 0');
  });

  tearDown(() async => db.close());

  test('a rename made elsewhere arrives', () async {
    expect(await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'}), <String>{
      one,
    });

    expect(await nameOf(one), 'Họ Nguyễn Phúc');
  });

  test('and the other family is left alone', () async {
    await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'});

    expect(await nameOf(two), 'Họ Trần');
  });

  test('the same name is not a change', () async {
    // It runs on every pull. Reporting a change every time would redraw the
    // list every time, and asking to be redrawn is asking to be run again.
    expect(await names.apply(<String, String>{one: 'Họ Nguyễn'}), isEmpty);
  });

  test('a family this device has not sent is held, not overwritten', () async {
    // The rule the rest of synchronisation follows, and the reason this
    // shortcut is safe to take: two devices renaming the same family is a
    // disagreement nothing here can settle, so this side does not enter it.
    // The local name stays and goes up on the next push.
    await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn Gia'));
    expect(
      await FamilyPush(db).pending(one),
      isNot(isEmpty),
      reason: 'the rename made here is waiting to go',
    );

    expect(await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'}), isEmpty);
    expect(await nameOf(one), 'Họ Nguyễn Gia');
  });

  test('a family deleted here is not brought back', () async {
    await repository.deleteFamily(one);
    await db.customStatement('UPDATE families SET unsent = 0');

    expect(await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'}), isEmpty);
    expect(await repository.loadFamily(one), isNull);
  });

  test(
    'a family the server names but this device does not is ignored',
    () async {
      // Somebody invited on another phone. Inventing a row would put a family on
      // the list that is not on it.
      final changed = await names.apply(<String, String>{
        'f0000000-0000-7000-8000-00000000000f': 'Họ Lê',
      });

      expect(changed, isEmpty);
      expect(await repository.listFamilies(), hasLength(2));
    },
  );

  test('what this device recorded about the copy is untouched', () async {
    // The server is told what the family is called. It is not told what this
    // device did with it — the role it arrived as, and whether it was shared
    // from here — and writing those away would hand out or take away rights.
    await FamilyRoles(db).remember(one, FamilyRole.viewer);
    await SharingMarks(db).markShared(one);
    await db.customStatement('UPDATE families SET unsent = 0');

    await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'});

    expect(await FamilyRoles(db).all(), containsPair(one, FamilyRole.viewer));
    expect(await SharingMarks(db).isShared(one), isTrue);
  });

  test('applying a name does not make the family look edited', () async {
    // updatedAt is what synchronisation orders by (§15.2), and `unsent` is what
    // decides whether a row is offered to the server. A name that came *from*
    // the server must not then be offered back to it.
    final before = (await db.select(db.families).get())
        .firstWhere((f) => f.id == one)
        .updatedAt;

    await names.apply(<String, String>{one: 'Họ Nguyễn Phúc'});

    final after = (await db.select(db.families).get()).firstWhere(
      (f) => f.id == one,
    );
    expect(after.updatedAt, before);
    expect(after.unsent, isFalse);
    expect(await FamilyPush(db).pending(one), isEmpty);
  });

  test('nothing to apply asks the database nothing', () async {
    expect(await names.apply(const <String, String>{}), isEmpty);
  });
}
