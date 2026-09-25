/// Two devices holding one family, against the stack `supabase start` runs
/// (PRODUCT.md §4.2).
///
/// **Not part of the suite.** No `_test.dart` suffix, so `flutter test` leaves
/// it alone: it needs Docker and a running local Supabase. Run it
/// deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/claiming.dart
/// ```
///
/// ## What is worth checking here
///
/// The case is A building a gia phả, sending B a file, and both of them being
/// able to press Chia sẻ — because the file keeps the family's id, and each
/// device's `sharedAt` only records what that device did.
///
/// So the checks are about seeing past RLS without stepping through it: that
/// a family another account owns reads as claimed although it reads as absent,
/// that the refusal has a name, and — the one that matters most — that a
/// refused attempt takes nothing. An owner quietly replaced is the failure
/// this whole file exists to make impossible.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ftree/data/cloud/cloud_session.dart';
import 'package:ftree/data/cloud/family_claims.dart';
import 'package:ftree/data/cloud/supabase_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/share_family.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // As in auth.dart: the test binding refuses every request so a unit test
  // cannot quietly reach the network. This file reaches it on purpose.
  HttpOverrides.global = null;

  SupabaseClient client() => Supabase.instance.client;
  FamilyClaims claims() => FamilyClaims(client());
  SupabaseFamilyRepository repository() => SupabaseFamilyRepository(client());

  /// A fresh address per call, so a second run is not a second signup.
  String anEmail() =>
      'dev-${DateTime.now().microsecondsSinceEpoch}@example.test';

  /// A fresh family id per call, for the same reason.
  String aFamilyId() {
    final n = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return 'cccccccc-0000-7000-8000-${n.substring(n.length - 12)}';
  }

  Future<void> anAccount() async =>
      signUp(email: anEmail(), password: 'correct horse battery');

  /// What pressing Chia sẻ will do: the family, through the repository, by
  /// the path the button will take.
  Future<void> share(String id, {String name = 'Họ Nguyễn'}) async =>
      repository().saveAll(
        family: Family(id: id, name: name),
      );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  tearDown(() async {
    if (isSignedIn) await signOut();
  });

  group('what the device cannot know, the server can say', () {
    test('a family nobody has shared is not claimed', () async {
      await anAccount();

      expect(await claims().isClaimed(aFamilyId()), isFalse);
    });

    test('a family this account shared is claimed', () async {
      await anAccount();
      final id = aFamilyId();
      await share(id);

      expect(await claims().isClaimed(id), isTrue);
    });

    test(
      'a family another account shared is claimed, and unreadable',
      () async {
        // The whole reason the function exists. B has the same file, so B has
        // the same id — and reading `families` tells B nothing, because a row a
        // policy refuses is absent rather than forbidden.
        await anAccount();
        final id = aFamilyId();
        await share(id);
        await signOut();

        await anAccount();

        expect(await claims().isClaimed(id), isTrue);
        final visible = await client().from('families').select('id');
        expect(
          visible.map((r) => r['id']),
          isNot(contains(id)),
          reason: 'claimed is the only thing B is allowed to learn',
        );
      },
    );

    test('a deleted family is still claimed', () async {
      // The tombstone keeps the primary key, so an insert would still fail.
      // Calling it unclaimed would send the client into that very error.
      await anAccount();
      final id = aFamilyId();
      await share(id);

      await repository().deleteFamily(id);

      expect(await claims().isClaimed(id), isTrue);
    });

    test('signed out, nobody may ask', () async {
      // Granted to `authenticated` only. The answer is wanted in order to
      // decide whether to share, which needs an account anyway.
      expect(isSignedIn, isFalse);

      await expectLater(
        claims().isClaimed(aFamilyId()),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('the second device to press is refused', () {
    test('the refusal has a name, not a constraint', () async {
      await anAccount();
      final id = aFamilyId();
      await share(id);
      await signOut();

      await anAccount();

      await expectLater(
        share(id),
        throwsA(
          predicate<Object>(
            FamilyClaims.wasAlreadyClaimed,
            'is the server saying the family is already claimed',
          ),
        ),
      );
    });

    test('and takes nothing: the first owner keeps it, name and all', () async {
      // The failure this file exists for. B pressing Chia sẻ must not end
      // with B owning A's gia phả, and must not end with A's family wearing
      // B's copy of the name.
      final aEmail = anEmail();
      await signUp(email: aEmail, password: 'correct horse battery');
      final id = aFamilyId();
      await share(id, name: 'Họ Nguyễn');
      final aUser = signedInUserId;
      await signOut();

      await anAccount();
      await expectLater(share(id, name: 'Bản của B'), throwsA(anything));
      await signOut();

      await signIn(email: aEmail, password: 'correct horse battery');
      final family = await client()
          .from('families')
          .select('name')
          .eq('id', id)
          .single();
      final owners = await client()
          .from('family_memberships')
          .select('user_id, role')
          .eq('family_id', id);

      expect(family['name'], 'Họ Nguyễn');
      expect(owners, hasLength(1));
      expect(owners.single['user_id'], aUser);
      expect(owners.single['role'], 'owner');
    });
  });

  group('the composition the button actually runs', () {
    // `LiveSharingCloud` is four lines of delegation, and until now nothing had
    // executed any of them. The parts are checked above and in the repository
    // contract; this checks that they are wired to each other the right way
    // round — that `canSee` really answers membership and not existence, which
    // is the distinction the whole flow turns on.
    const cloud = LiveSharingCloud();

    Future<void> sendOne(String id, String name) => cloud.send(
      FamilySnapshot(
        family: Family(id: id, name: name),
        graph: FamilyGraph(
          persons: <Person>[
            Person(
              id: id.replaceFirst('cccccccc', 'dddddddd'),
              familyId: id,
              displayName: 'Cụ Tổ',
            ),
          ],
          relationships: const <Relationship>[],
        ),
      ),
    );

    test('sends a family, then finds it claimed and visible', () async {
      await anAccount();
      final id = aFamilyId();

      await sendOne(id, 'Họ Nguyễn');

      expect(await cloud.isClaimed(id), isTrue);
      expect(await cloud.canSee(id), isTrue);
    });

    test('another account finds it claimed and not visible', () async {
      // The two states the flow tells apart: this is case 3 — somebody else
      // pressed first — and it must not read as case 2, which would recover a
      // mark for a family this device does not hold.
      await anAccount();
      final id = aFamilyId();
      await sendOne(id, 'Họ Nguyễn');
      await signOut();

      await anAccount();

      expect(await cloud.isClaimed(id), isTrue);
      expect(await cloud.canSee(id), isFalse);
    });
  });
}
