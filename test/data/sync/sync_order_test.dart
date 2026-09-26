/// Which way round a synchronisation runs (ROADMAP M9).
///
/// A device that has edited something holds three versions between them: what
/// it typed, what the server last gave it, and — once a pull has run — what
/// the other side typed. The merge needs all three.
///
/// Sending first throws the third one away before it is ever asked for.
/// `markSent` clears `unsent` and `baseFields` together, because once the
/// server holds this version there is no longer an earlier one the two sides
/// started from. That is right on its own terms, and it means a pull that
/// comes *after* a push has nothing left to merge against: it lands the
/// server's row outright.
///
/// So these check the order as a property of the pieces, which is where it can
/// be checked. `syncFamily` is the one place that decides it, and it cannot be
/// tested directly — it opens with `isSignedIn`, which reads
/// `Supabase.instance` and throws in a test process.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/conflicts.dart';
import 'package:ftree/data/sync/family_pull.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyPull pull;
  late FamilyPush push;

  const familyId = 'f0000000-0000-7000-8000-000000000001';
  const personId = 'p0000000-0000-7000-8000-000000000001';

  Person person(String name) =>
      Person(id: personId, familyId: familyId, displayName: name);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    pull = FamilyPull(db);
    push = FamilyPush(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person('Cụ Tổ')],
    );
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE families SET unsent = 0');

    // This device's own edit, not yet anywhere else.
    await repository.savePerson(person('Cụ Tổ (tôi)'));
  });

  tearDown(() async => db.close());

  Future<String> nameHere() async => (await repository.loadFamily(
    familyId,
  ))!.graph.personById(personId)!.displayName;

  test('pulling first finds the disagreement', () async {
    final result = await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 9, persons: <Person>[person('Cụ Tổ (họ)')]),
    );

    expect(result.conflicted, <String>[personId]);
    expect(await Conflicts(db).countIn(familyId), 1);
    expect(await nameHere(), 'Cụ Tổ (tôi)', reason: 'nothing is chosen yet');
  });

  test('and the disagreement is then held back from the next push', () async {
    await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 9, persons: <Person>[person('Cụ Tổ (họ)')]),
    );

    expect(
      (await push.pending(familyId)).persons,
      isEmpty,
      reason: 'sending it would settle it with nobody asked',
    );
  });

  test('a send with no pull in front of it overwrites the other side', () async {
    // The same defect at the other boundary. Leaving the screen sends what was
    // written, and sending alone takes whatever arrived while the screen was
    // open and writes over it — the server stores what it is given. The device
    // that wrote the other version has already cleared its flag, so nothing
    // will ever send it again.
    final outgoing = await push.pending(familyId);

    expect(
      outgoing.persons.single.displayName,
      'Cụ Tổ (tôi)',
      reason: 'this is what would land on top of theirs, unasked',
    );

    // Pulled first instead, the same row is held back from the send entirely.
    await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 9, persons: <Person>[person('Cụ Tổ (họ)')]),
    );

    expect((await push.pending(familyId)).persons, isEmpty);
  });

  test('sending first leaves nothing to merge against', () async {
    // The reason the order is not a matter of taste. `markSent` clears the
    // base along with the flag, so the pull that follows has two versions
    // where it needs three — and two versions cannot tell an edit from an
    // absence of one.
    final outgoing = await push.pending(familyId);
    expect(outgoing.persons.single.displayName, 'Cụ Tổ (tôi)');
    await push.markSent(outgoing.ids);

    final result = await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 9, persons: <Person>[person('Cụ Tổ (họ)')]),
    );

    expect(result.conflicted, isEmpty, reason: 'nobody is asked');
    expect(result.applied, 1);
    expect(
      await nameHere(),
      'Cụ Tổ (họ)',
      reason: 'this device’s edit is gone, and nothing said so',
    );
  });
}
