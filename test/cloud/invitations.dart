/// Letting a second person into a family (PRODUCT.md §5.1).
///
/// **Not part of the suite.** No `_test.dart` suffix: it needs Docker and a
/// running local Supabase. Run it deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/invitations.dart
/// ```
///
/// ## What is worth checking here
///
/// `accept_invitation` is a hole in the wall — SECURITY DEFINER, so nothing
/// inside it is protected by a policy and every check is one somebody wrote by
/// hand. Four of them are load-bearing, and a test for each is the only thing
/// standing between "the owner revoked it" and "the code still works".
///
/// The rest is the catch-22 the function exists for: the person the invitation
/// was written for cannot see it, cannot insert their own membership, and must
/// still get in.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ftree/data/cloud/cloud_session.dart';
import 'package:ftree/data/cloud/family_invitations.dart';
import 'package:ftree/data/cloud/supabase_family_repository.dart';
import 'package:ftree/domain/family.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // As in the other cloud files: the binding refuses every request so a unit
  // test cannot quietly reach the network. This one reaches it on purpose.
  HttpOverrides.global = null;

  SupabaseClient client() => Supabase.instance.client;
  FamilyInvitations invitations({DateTime Function()? now}) =>
      FamilyInvitations(client(), now: now);

  String anEmail() =>
      'inv-${DateTime.now().microsecondsSinceEpoch}@example.test';

  String aFamilyId() {
    final n = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return 'eeeeeeee-0000-7000-8000-${n.substring(n.length - 12)}';
  }

  const password = 'correct horse battery';

  /// A fresh account, signed in, and remembered well enough to come back to.
  Future<({String email, String id, String name})> anAccount({
    String name = 'Bác Minh',
  }) async {
    final email = anEmail();
    await signUp(email: email, password: password, name: name);
    return (email: email, id: signedInUserId!, name: name);
  }

  /// A family, shared, owned by whoever is signed in.
  Future<String> aFamily() async {
    final id = aFamilyId();
    await SupabaseFamilyRepository(client()).saveAll(
      family: Family(id: id, name: 'Họ Nguyễn'),
    );
    return id;
  }

  Future<String?> roleIn(String familyId) async {
    final rows = await client()
        .from('family_memberships')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', signedInUserId!)
        .isFilter('deleted_at', null);
    return rows.isEmpty ? null : rows.single['role'] as String;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  tearDown(() async {
    if (isSignedIn) await signOut();
  });

  group('only an owner hands one out', () {
    test('an owner can, and gets the code back exactly once', () async {
      await anAccount();
      final family = await aFamily();

      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );

      expect(invitation.code, isNotNull);
      expect(invitation.role, 'editor');
      expect(invitation.isLiveAt(DateTime.now().toUtc()), isTrue);
    });

    test('the plaintext is nowhere in the table', () async {
      // The whole point of hashing. A database that escapes must not escape
      // with anything that opens a family.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );

      final rows = await client()
          .from('family_invitations')
          .select()
          .eq('family_id', family);

      expect(rows.single.toString(), isNot(contains(invitation.code!)));
      expect(rows.single['token_hash'], invitationCodeHash(invitation.code!));
    });

    test('an editor cannot', () async {
      // An editor who could invite editors would widen the circle without the
      // owner ever seeing it happen.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      await anAccount();
      await invitations().accept(invitation.code!);

      expect(await roleIn(family), 'editor');
      await expectLater(
        invitations().create(familyId: family, role: 'viewer'),
        throwsA(isA<PostgrestException>()),
      );
      expect(owner.id, isNotEmpty);
    });
  });

  group('the catch-22 the function exists for', () {
    test(
      'the invitation is invisible to the person it was written for',
      () async {
        // Not forbidden — absent. This is why accepting cannot be a plain
        // SELECT and an INSERT from the client.
        await anAccount();
        final family = await aFamily();
        await invitations().create(familyId: family, role: 'editor');
        await signOut();

        await anAccount();

        expect(await invitations().forFamily(family), isEmpty);
      },
    );

    test('and they cannot add themselves', () async {
      await anAccount();
      final family = await aFamily();
      await signOut();

      final intruder = (await anAccount()).id;

      await expectLater(
        client().from('family_memberships').insert(<String, Object?>{
          'family_id': family,
          'user_id': intruder,
          'role': 'owner',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('but the code lets them in, with the role it names', () async {
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'viewer',
      );
      await signOut();

      await anAccount();
      final joined = await invitations().accept(invitation.code!);

      expect(joined, family);
      expect(await roleIn(family), 'viewer');
    });

    test('typed loosely, it still works', () async {
      // Read off one screen and typed into another. Refusing `k7p2 9xmr4t`
      // for a code issued as `K7P2-9XMR-4T` would be unexplainable.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      final mangled = invitation.code!.toLowerCase().replaceAll('-', ' ');
      await signOut();

      await anAccount();

      expect(await invitations().accept(mangled), family);
    });
  });

  group('the four checks inside the hole', () {
    Future<Invitation> invitationTo(
      String family, {
      String role = 'editor',
      DateTime Function()? now,
    }) => invitations(now: now).create(familyId: family, role: role);

    test('a code nobody issued is refused', () async {
      await anAccount();

      await expectLater(
        invitations().accept('ZZZZ-ZZZZ-ZZ'),
        throwsA(
          predicate<Object>(
            (e) => invitationRefusal(e) == InvitationRefusal.notFound,
          ),
        ),
      );
    });

    test('a used code is refused, and says so in those words', () async {
      // The sentence that makes a stolen code visible: the person it was meant
      // for is told somebody was here first.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitationTo(family);
      await signOut();

      await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await anAccount();
      await expectLater(
        invitations().accept(invitation.code!),
        throwsA(
          predicate<Object>(
            (e) => invitationRefusal(e) == InvitationRefusal.alreadyUsed,
          ),
        ),
      );
      expect(await roleIn(family), isNull, reason: 'and nothing was granted');
    });

    test('a revoked code is refused', () async {
      // Without this check the owner's Huỷ button means nothing.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitationTo(family);
      await invitations().revoke(invitation.id);
      await signOut();

      await anAccount();
      await expectLater(
        invitations().accept(invitation.code!),
        throwsA(
          predicate<Object>(
            (e) => invitationRefusal(e) == InvitationRefusal.revoked,
          ),
        ),
      );
      expect(await roleIn(family), isNull);
    });

    test('an expired code is refused', () async {
      // Made in 2020, so its seven days ran out long ago.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitationTo(
        family,
        now: () => DateTime.utc(2020),
      );
      await signOut();

      await anAccount();
      await expectLater(
        invitations().accept(invitation.code!),
        throwsA(
          predicate<Object>(
            (e) => invitationRefusal(e) == InvitationRefusal.expired,
          ),
        ),
      );
    });

    test('signed out, nobody may accept anything', () async {
      // anon holds no EXECUTE on the function at all, so this never reaches
      // the auth.uid() check inside it. Both are deliberate.
      expect(isSignedIn, isFalse);

      await expectLater(
        invitations().accept('ZZZZ-ZZZZ-ZZ'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('what revoking is, and is not', () {
    test('an invitation already used cannot be revoked', () async {
      // Revoking does not remove the person it let in; that is tombstoning a
      // membership, on another table. And the refusal is silent — a policy
      // that excludes a row by USING makes the UPDATE match nothing and report
      // success, which is why this reads the row back instead of the status.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      await invitations().revoke(invitation.id);

      final after = await invitations().forFamily(family);
      expect(after.single.isAccepted, isTrue);
      expect(
        after.single.isRevoked,
        isFalse,
        reason: 'the server refused it, quietly, as a refused UPDATE does',
      );
    });
  });

  group('handing a family back', () {
    test('an editor invited as owner is promoted, not refused', () async {
      // The way out of §4.3: whoever pressed Chia sẻ first owns the family,
      // and this is how they give the right person the same standing.
      await anAccount();
      final family = await aFamily();
      final asEditor = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      final asOwner = await invitations().create(
        familyId: family,
        role: 'owner',
      );
      await signOut();

      await anAccount();
      await invitations().accept(asEditor.code!);
      expect(await roleIn(family), 'editor');

      await invitations().accept(asOwner.code!);

      expect(await roleIn(family), 'owner');
    });
  });

  group('who is in the family', () {
    test('an owner sees everybody, by name and address', () async {
      // A list of uuids answers none of what §5.6 says the list is for.
      final owner = await anAccount(name: 'Bác Minh');
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final guest = await anAccount(name: 'Chú Hải');
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      final members = await invitations().members(family);

      expect(members, hasLength(2));
      expect(
        members.map((m) => m.email),
        containsAll(<String>[owner.email, guest.email]),
      );
      expect(members.map((m) => m.name), containsAll(<String>['Chú Hải']));
      expect(members.firstWhere((m) => m.userId == owner.id).role, 'owner');
    });

    test('an editor of the same family sees nothing', () async {
      // Reversed from what §5 first said. Managing the circle is the owner's
      // job, and the list is where somebody is demoted or put out — not a
      // thing to do in front of an audience.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      await anAccount();
      await invitations().accept(invitation.code!);

      expect(await roleIn(family), 'editor');
      expect(await invitations().members(family), isEmpty);
    });

    test('somebody outside sees nothing either', () async {
      // Indistinguishable from a family that does not exist.
      await anAccount();
      final family = await aFamily();
      await signOut();

      await anAccount();

      expect(await invitations().members(family), isEmpty);
    });

    test('an account with no name comes back without one', () async {
      // Nothing is invented from the address. The interface says so instead.
      await anAccount(name: '');
      final family = await aFamily();

      expect((await invitations().members(family)).single.name, isNull);
    });
  });

  group('changing what somebody may do', () {
    test('an owner can demote an editor to viewer', () async {
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final guest = await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      await invitations().changeRole(
        familyId: family,
        userId: guest.id,
        role: 'viewer',
      );

      expect(
        (await invitations().members(
          family,
        )).firstWhere((m) => m.userId == guest.id).role,
        'viewer',
      );
    });

    test('and promote one to owner', () async {
      // The way out of §4.3, done from the member list rather than by sending
      // a second code.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final guest = await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      await invitations().changeRole(
        familyId: family,
        userId: guest.id,
        role: 'owner',
      );
      await signOut();

      await signIn(email: guest.email, password: password);
      expect(await roleIn(family), 'owner');
    });

    test('the last owner cannot be demoted', () async {
      // keep_an_owner. A family nobody can manage is a family nobody can ever
      // be invited into.
      final owner = await anAccount();
      final family = await aFamily();

      await expectLater(
        invitations().changeRole(
          familyId: family,
          userId: owner.id,
          role: 'viewer',
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(await roleIn(family), 'owner');
    });

    test('an editor cannot promote themselves', () async {
      // The refusal is silent — a policy that excludes a row by USING makes
      // the UPDATE match nothing and report success — so this reads the role
      // back rather than trusting that nothing was raised.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final guest = await anAccount();
      await invitations().accept(invitation.code!);

      await invitations().changeRole(
        familyId: family,
        userId: guest.id,
        role: 'owner',
      );

      expect(await roleIn(family), 'editor');
    });
  });

  group('removing somebody', () {
    Future<void> remove(String family, String who) =>
        invitations().remove(familyId: family, userId: who);

    test('an owner can put somebody out again', () async {
      // The counterpart to letting anybody in without approval. A door that
      // opens and cannot close is worse than a slow lock.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final guest = await anAccount();
      await invitations().accept(invitation.code!);
      expect(await roleIn(family), 'editor');
      await signOut();

      await signIn(email: owner.email, password: password);
      await remove(family, guest.id);
      await signOut();

      await signIn(email: guest.email, password: password);
      expect(await roleIn(family), isNull);
      expect(
        await client().from('families').select('id'),
        isEmpty,
        reason: 'and the family goes back to being absent, not forbidden',
      );
    });

    test('the last owner cannot be put out', () async {
      // keep_an_owner, reached through the interface's own route rather than
      // through a direct DELETE. A family with nobody to manage it is a family
      // nobody can ever invite anybody into.
      final owner = await anAccount();
      final family = await aFamily();

      await expectLater(
        remove(family, owner.id),
        throwsA(isA<PostgrestException>()),
      );

      expect(await roleIn(family), 'owner');
    });
  });

  group('a family its owner deleted', () {
    // What happened on a real pair of phones. The owner made a code for a
    // family the server had already tombstoned, sent it, and the other device
    // accepted it: `accept_invitation` had nothing to say about the family
    // being gone, so the membership was written and the join *succeeded* —
    // and then the download that follows returned nothing, because reading a
    // family skips tombstones. The screen fell through to its catch-all and
    // said "It did not go through:" with nothing after the colon.

    test('cannot be invited into', () async {
      await anAccount();
      final family = await aFamily();
      await SupabaseFamilyRepository(client()).deleteFamily(family);

      await expectLater(
        invitations().create(familyId: family, role: 'editor'),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('and a code made before it refuses on use, by name', () async {
      // The order that matters: the code is older than the deletion, so no
      // check at the moment of making it could have caught this.
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await SupabaseFamilyRepository(client()).deleteFamily(family);
      await signOut();

      final guest = await anAccount();
      await expectLater(
        invitations().accept(invitation.code!),
        throwsA(
          predicate<Object>(
            (e) => invitationRefusal(e) == InvitationRefusal.familyDeleted,
            'refused as familyDeleted',
          ),
        ),
      );

      // Nothing left behind. A membership of a gia phả that does not exist is
      // something the application can neither show nor undo.
      expect(await roleIn(family), isNull, reason: 'guest ${guest.email}');
    });

    test('and the code is not spent by the refusal', () async {
      // There is nothing to protect it from: the family is gone. If its owner
      // brings it back, the code should still work.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await SupabaseFamilyRepository(client()).deleteFamily(family);
      await signOut();

      await anAccount();
      await expectLater(
        invitations().accept(invitation.code!),
        throwsA(isA<PostgrestException>()),
      );
      await signOut();

      await signIn(email: owner.email, password: password);
      final still = await invitations().forFamily(family);
      expect(still.single.isAccepted, isFalse);
      expect(still.single.isRevoked, isFalse);
    });
  });

  group('what the server says this account still holds', () {
    // One request answers two different questions, and the difference decides
    // whether a role survives (PRODUCT §5.10).

    test('a live family comes back with the role held there', () async {
      await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      await anAccount();
      await invitations().accept(invitation.code!);

      final answer = await invitations().myRoles();

      expect(answer.live, containsPair(family, 'editor'));
      expect(answer.deleted, isEmpty);
    });

    test('one the owner deleted comes back as deleted, not as gone', () async {
      // The case that cannot be seen from memberships alone:
      // `delete_family_deep` never touches them, so the editor's row stands and
      // a question about memberships alone says the family is still theirs.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'editor',
      );
      await signOut();

      final editor = await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      await SupabaseFamilyRepository(client()).deleteFamily(family);
      await signOut();

      await signIn(email: editor.email, password: password);
      final answer = await invitations().myRoles();

      expect(
        answer.deleted,
        contains(family),
        reason: 'the family is gone, and this device has to be told',
      );
      expect(
        answer.live,
        isNot(contains(family)),
        reason: 'naming it live would leave the copy sitting there',
      );
    });

    test('and the owner of a deleted family is told the same', () async {
      // Deleting on one device and reaching for the backup on another is the
      // one undo there is. The role has to survive it, which it does because
      // this answer never claims the owner was put out.
      await anAccount();
      final family = await aFamily();
      await SupabaseFamilyRepository(client()).deleteFamily(family);

      final answer = await invitations().myRoles();

      expect(answer.deleted, contains(family));
      expect(answer.live, isNot(contains(family)));
    });

    test('a membership the owner ended is named neither way', () async {
      // Put out of a family that still exists: nothing to report at all, which
      // is what turns into `removed` on the device.
      final owner = await anAccount();
      final family = await aFamily();
      final invitation = await invitations().create(
        familyId: family,
        role: 'viewer',
      );
      await signOut();

      final viewer = await anAccount();
      await invitations().accept(invitation.code!);
      await signOut();

      await signIn(email: owner.email, password: password);
      await invitations().remove(familyId: family, userId: viewer.id);
      await signOut();

      await signIn(email: viewer.email, password: password);
      final answer = await invitations().myRoles();

      expect(answer.live, isNot(contains(family)));
      expect(answer.deleted, isNot(contains(family)));
    });
  });
}
