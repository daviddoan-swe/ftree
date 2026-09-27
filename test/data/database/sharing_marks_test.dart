/// The mark a device keeps of what it has shared (PRODUCT.md §4.2).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late SharingMarks marks;

  final clock = DateTime.utc(2026, 9, 24, 12);

  const one = 'f0000000-0000-7000-8000-000000000001';
  const two = 'f0000000-0000-7000-8000-000000000002';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    marks = SharingMarks(db, now: () => clock);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seed() async {
    await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn'));
    await repository.saveFamily(const Family(id: two, name: 'Họ Trần'));
  }

  test('nothing is shared until something is', () async {
    await seed();

    expect(await marks.shared(), isEmpty);
    expect(await marks.isShared(one), isFalse);
  });

  test('marking one leaves the other alone', () async {
    // The whole decision in one check: signing in is not a statement about
    // everything on the device, and a family nobody shared stays unknown to
    // the server.
    await seed();

    await marks.markShared(one);

    expect(await marks.shared(), <String>{one});
    expect(await marks.isShared(two), isFalse);
  });

  test('the mark survives an ordinary edit of the family', () async {
    // saveFamily writes every column it is given. If it wrote sharedAt too,
    // renaming a family would quietly un-share it.
    await seed();
    await marks.markShared(one);

    await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn (sửa)'));

    expect(await marks.isShared(one), isTrue);
  });

  test('marking does not move updatedAt', () async {
    // updatedAt is what synchronisation orders by (§15.2). A local note about
    // what this device did must not make the family look edited.
    await seed();
    final before = (await db.select(db.families).get())
        .firstWhere((f) => f.id == one)
        .updatedAt;

    await marks.markShared(one);

    final after = (await db.select(db.families).get())
        .firstWhere((f) => f.id == one)
        .updatedAt;
    expect(after, before);
  });

  test('a deleted family is still one this device shared', () async {
    // It used to be left out, and that was the rule behind a defect found on
    // a real pair of phones: machine 1 deleted a family, machine 2 went on
    // showing it, and the server never heard. The push asks this set before
    // sending anything, so a tombstone filtered out here is a deletion that
    // can never leave the device that made it.
    //
    // The mark says this device *put* the family on a server. Deleting it
    // does not make that untrue — and the deletion is the one thing left that
    // still has to reach that server.
    await seed();
    await marks.markShared(one);

    await repository.deleteFamily(one);

    expect(await marks.shared(), contains(one));
  });

  test('a family brought back keeps its mark', () async {
    // Deleting hides the mark; it does not erase it. Bringing the family back
    // must not offer to share it a second time — which is the case that would
    // put this device's copy on top of the shared one.
    await seed();
    await marks.markShared(one);
    await repository.deleteFamily(one);

    await repository.saveAll(
      family: const Family(id: one, name: 'Họ Nguyễn'),
      persons: const <Person>[],
    );

    expect(await marks.isShared(one), isTrue);
  });
}
