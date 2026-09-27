/// The paths behind the signed-in guard (ROADMAP M9).
///
/// These could not be written before. `pushFamily` and `pullFamily` opened
/// with the global `isSignedIn`, which reads `Supabase.instance` and throws in
/// a process that never called `openCloud` — so the guard short-circuited and
/// every test of the code behind it passed whether that code was right or
/// wrong. Three defects fixed in one day had no cover for exactly that reason:
/// the order a synchronisation runs in, sending on the way out of a family,
/// and asking again what this account may do.
///
/// `cloudSessionProvider` and `rolesSourceProvider` are what let a test answer
/// for the cloud instead.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/database/sync_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/cloud_changes.dart';
import 'package:ftree/data/sync/cloud_push.dart';
import 'package:ftree/data/sync/family_pull.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';

/// Answers yes, without a cloud behind it.
final class SignedIn implements CloudSession {
  const SignedIn({this.isSignedIn = true});

  @override
  final bool isSignedIn;
}

/// Says what the server says this account may do.
final class StandInRoles implements RolesSource {
  StandInRoles(this.answer, {this.deleted = const <String>{}});

  Map<String, String> answer;

  /// Families this account is still a member of, and which no longer exist.
  Set<String> deleted;

  int asked = 0;

  @override
  Future<({Map<String, String> live, Set<String> deleted})> myRoles() async {
    asked++;
    return (live: answer, deleted: deleted);
  }
}

/// Watches what was sent, and answers for what the server then held.
final class WatchingSink implements ChangeSink {
  final List<Outgoing> sent = <Outgoing>[];

  /// Answers as a policy that refused in silence does: success, and none of
  /// the rows actually held.
  bool keepNothing = false;

  @override
  Future<Set<String>> send(String familyId, Outgoing outgoing) async {
    sent.add(outgoing);
    return keepNothing ? const <String>{} : outgoing.ids;
  }
}

/// Hands down whatever a test says the server has.
final class StandInSource implements ChangeSource {
  StandInSource(this.answer);

  IncomingChanges answer;
  int asked = 0;

  /// Out of reach, the way a server behind no network is.
  bool throws = false;

  @override
  Future<IncomingChanges> since(String familyId, int lastSeen) async {
    asked++;
    if (throws) throw const SocketException('no route to host');
    return answer;
  }
}

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late WatchingSink sink;
  late StandInSource source;
  late StandInRoles roles;

  const familyId = 'f0000000-0000-7000-8000-000000000001';
  const personId = 'p0000000-0000-7000-8000-000000000001';

  Person person(String name) =>
      Person(id: personId, familyId: familyId, displayName: name);

  Future<ProviderContainer> aDevice({
    bool signedIn = true,
    String role = 'owner',
  }) async {
    roles = StandInRoles(<String, String>{familyId: role});
    sink = WatchingSink();
    source = StandInSource(const IncomingChanges(highestSeq: 0));

    final container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        cloudSessionProvider.overrideWithValue(SignedIn(isSignedIn: signedIn)),
        rolesSourceProvider.overrideWithValue(roles),
        changeSinkProvider.overrideWithValue(sink),
        changeSourceProvider.overrideWithValue(source),
      ],
    );
    addTearDown(container.dispose);

    // Shared, or there is nothing on a server to talk to.
    //
    // The provider is deliberately **not** warmed here. It used to be, and
    // that hid a defect: the push read it with `valueOrNull`, which is null
    // while the answer is still coming, and read that as "never shared". At
    // start-up — the one moment stuck deletions are swept — nothing was ever
    // sent, and every test passed because every test had warmed it first.
    await SharingMarks(db).markShared(familyId);
    return container;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person('Cụ Tổ')],
    );
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE families SET unsent = 0');
  });

  tearDown(() async => db.close());

  group('the signed-in guard', () {
    test('nothing is sent when there is no session', () async {
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice(signedIn: false);

      await syncFamily(device, familyId);

      expect(sink.sent, isEmpty);
      expect(source.asked, 0);
    });

    test('and it is sent when there is one', () async {
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice();

      await syncFamily(device, familyId);

      expect(sink.sent.single.persons.single.displayName, 'sửa ở máy này');
    });
  });

  group('which way round a synchronisation runs', () {
    test('what came down is merged before anything goes up', () async {
      // The defect this is written for. Sending first cleared the base along
      // with the flag, so the pull behind it had two versions where a merge
      // needs three: it landed the server's row and this device's work went
      // with it, unasked and unrecorded.
      await repository.savePerson(person('Cụ Tổ (tôi)'));
      final device = await aDevice();
      source.answer = IncomingChanges(
        highestSeq: 9,
        persons: <Person>[person('Cụ Tổ (họ)')],
      );

      await syncFamily(device, familyId);

      // A disagreement was found, so the row was held back from the send.
      expect(sink.sent, isEmpty);
      expect(
        (await repository.loadFamily(
          familyId,
        ))!.graph.personById(personId)!.displayName,
        'Cụ Tổ (tôi)',
      );
    });

    test('and what fits together goes up merged', () async {
      await repository.savePerson(person('Cụ Tổ (tôi)'));
      final device = await aDevice();
      source.answer = IncomingChanges(
        highestSeq: 9,
        persons: <Person>[
          Person(
            id: personId,
            familyId: familyId,
            displayName: 'Cụ Tổ',
            biography: 'Làm nghề dạy học.',
          ),
        ],
      );

      await syncFamily(device, familyId);

      final gone = sink.sent.single.persons.single;
      expect(gone.displayName, 'Cụ Tổ (tôi)', reason: 'this device kept its');
      expect(gone.biography, 'Làm nghề dạy học.', reason: 'and took theirs');
    });
  });

  group('asking again what this account may do', () {
    test('a demotion arriving stops the sending', () async {
      // The interface used to go on offering an editor's controls until the
      // application was restarted, because the answer was cached for the life
      // of the process.
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice(role: 'viewer');

      await syncFamily(device, familyId);

      expect(roles.asked, greaterThan(0), reason: 'the server was asked');
      expect(sink.sent, isEmpty, reason: 'a viewer has nothing to send');
      expect((await FamilyRoles(db).all())[familyId], FamilyRole.viewer);
    });

    test('and a promotion arriving starts it', () async {
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice(role: 'editor');

      await syncFamily(device, familyId);

      expect(sink.sent, hasLength(1));
      expect((await FamilyRoles(db).all())[familyId], FamilyRole.editor);
    });
  });

  group('what it reports, and what it writes down', () {
    test('a quiet run says so rather than saying nothing', () async {
      // Somebody pulled the gia phả down and is owed an answer. "Nothing new"
      // is one; a wheel that stops is not, because it looks exactly the same
      // when the server could not be reached.
      final device = await aDevice();

      final result = await syncFamily(device, familyId);

      expect(result.isQuiet, isTrue);
      expect(result.trouble, isNull);
    });

    test('and counts what actually moved', () async {
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice();
      source.answer = IncomingChanges(
        highestSeq: 9,
        persons: <Person>[
          Person(
            id: 'p0000000-0000-7000-8000-000000000002',
            familyId: familyId,
            displayName: 'Bà Tổ',
          ),
        ],
      );

      final result = await syncFamily(device, familyId);

      expect(result.broughtDown, 1);
      expect(result.sentUp, 1);
      expect(result.isQuiet, isFalse);
    });

    test('a run that worked is written down', () async {
      final device = await aDevice();

      await syncFamily(device, familyId);

      expect(await SyncMarks(db).forFamily(familyId), isNotNull);
    });

    test('one that could not reach the server is not', () async {
      // The line has to mean the last time it worked. Marked on a failure it
      // would read "a moment ago" at the one moment somebody is looking at it
      // to find out whether to worry.
      final device = await aDevice();
      source.throws = true;

      final result = await syncFamily(device, familyId);

      expect(result.trouble, SyncTrouble.offline);
      expect(await SyncMarks(db).forFamily(familyId), isNull);
    });

    test('a silent refusal is named, not counted as sent', () async {
      // The shape the read-back exists for: an UPDATE a policy forbids
      // changes nothing and reports success. Fewer ids back than went is the
      // only sign, and without this somebody would watch the number waiting
      // never go down and never learn why.
      await repository.savePerson(person('sửa ở máy này'));
      final device = await aDevice();
      sink.keepNothing = true;

      final result = await syncFamily(device, familyId);

      expect(result.trouble, SyncTrouble.refused);
      expect(result.waiting, greaterThan(0));
      expect(await SyncMarks(db).forFamily(familyId), isNull);
    });
  });

  group('deleting a family for everybody', () {
    test('the tombstone is offered to the server', () async {
      // The path nothing joined. Deleting is done from the *list*, and a
      // synchronisation runs when a family is opened or left — so the one
      // family that can never be opened again was the one whose deletion
      // could never be sent. Found on a real pair of phones: machine 1 had
      // deleted it, the server still held it, machine 2 still showed it.
      await SyncMarks(db).mark(familyId);
      await repository.deleteFamily(familyId);
      final device = await aDevice();

      await pushFamily(device, familyId);

      expect(sink.sent.single.deletedFamily, familyId);
    });

    test('a family it has deleted still counts as one it shared', () async {
      // The other half, and either alone is fatal. The mark says this device
      // put the family on a server; a local tombstone does not make that
      // untrue, and filtering tombstones out of the set made the push decide
      // there was nothing up there to tell.
      await SharingMarks(db).markShared(familyId);
      await repository.deleteFamily(familyId);

      expect(await SharingMarks(db).shared(), contains(familyId));
    });

    test('one that failed to send is picked up later', () async {
      // The hole in the first fix. Sending happens at the moment of deleting,
      // and deleting is most often done while tidying up offline — so the
      // push that carries the tombstone is exactly the one most likely to
      // fail, and nothing could try it again: the family is gone from the
      // list and cannot be opened, and opening is what synchronises.
      await SharingMarks(db).markShared(familyId);
      await repository.deleteFamily(familyId);
      final device = await aDevice();

      await pushStuckDeletions(device);

      expect(sink.sent.single.deletedFamily, familyId);
    });

    test('and a family still here is left alone by the sweep', () async {
      // It can be opened, and opening is what sends it. Sweeping it here
      // would send every unsent family on the device every time the list is
      // drawn.
      // Renamed, not edited: it is the *family* row that has to be unsent
      // and alive, which is what the sweep must step over. Saving a person
      // leaves the family row untouched, so a weaker version of this test
      // passed against a sweep that took everything.
      final device = await aDevice();
      await repository.saveFamily(
        const Family(id: familyId, name: 'Họ Nguyễn – Phù Ninh'),
      );

      await pushStuckDeletions(device);

      expect(sink.sent, isEmpty);
    });

    test('and one never shared is still not offered', () async {
      await db.customStatement('UPDATE families SET shared_at = NULL');

      expect(await SharingMarks(db).shared(), isEmpty);
    });
  });

  group('being put out of a family', () {
    test('takes the copy on this device with it', () async {
      // Decided the other way round from how it started: the copy used to
      // stay, readable and unchangeable, with a line saying so (PRODUCT §5.0).
      await SharingMarks(db).markShared(familyId);
      final device = await aDevice();

      // Named once, so the device writes down what it is. `reconcile` only
      // takes a role away from a family that had one — a family with no role
      // is one nobody else has a claim on, and the server never naming it
      // says nothing about it.
      await refreshedRoles(device);
      expect(await repository.listFamilies(), hasLength(1));

      roles.answer = const <String, String>{}; // now the server names nobody
      await refreshedRoles(device);

      expect(await repository.listFamilies(), isEmpty);
    });

    test('and a family still named is left where it is', () async {
      await SharingMarks(db).markShared(familyId);
      final device = await aDevice(role: 'viewer');

      await refreshedRoles(device);

      expect(await repository.listFamilies(), hasLength(1));
    });
  });
}
