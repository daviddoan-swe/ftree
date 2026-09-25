/// Signing in, against the stack `supabase start` runs (ROADMAP M7).
///
/// **Not part of the suite.** No `_test.dart` suffix, so `flutter test` leaves
/// it alone. It needs Docker and a running local Supabase, and a test that
/// fails on a machine without them says nothing about the code. Run it
/// deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/auth.dart
/// ```
///
/// Same arrangement as `test/performance/tree_rendering.dart`, and for the
/// same reason: the suite has to stay runnable anywhere.
///
/// ## What is worth checking here
///
/// Not that Supabase can sign somebody in — that is their code, and doubting
/// it proves nothing.
///
/// What matters is the link every policy rests on: that the id this client
/// believes it has is the id the server judges by. So the checks go through
/// the real tables rather than through a function added to answer them. A
/// family created while signed in, read back while signed in, and gone the
/// moment the session ends, exercises `auth.uid()`, `my_role()`, the
/// owner-on-create trigger and the read policy in one line each — and adds
/// nothing to the schema that only a test would want.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/cloud/cloud_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test binding installs an HttpClient that refuses every request, so
  // that a unit test cannot quietly depend on the network. This file depends
  // on the network on purpose — it is checking a server — so it puts the real
  // one back.
  HttpOverrides.global = null;

  SupabaseClient client() => Supabase.instance.client;

  /// A fresh address per call, so a second run of this file is not a second
  /// signup of somebody who already exists.
  String anEmail() =>
      'dev-${DateTime.now().microsecondsSinceEpoch}@example.test';

  /// A fresh family id per call, for the same reason.
  String aFamilyId() {
    final n = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return 'aaaaaaaa-0000-4000-8000-${n.substring(n.length - 12)}';
  }

  Future<String> createFamily() async {
    final id = aFamilyId();
    await client().from('families').insert(<String, Object?>{
      'id': id,
      'name': 'Họ Nguyễn',
    });
    return id;
  }

  setUpAll(() async {
    // supabase_flutter keeps its session, and its PKCE state, in shared
    // preferences — which has no implementation in a test process. The mock
    // is the plugin's own answer for this, and it starts empty, so each run
    // begins signed out.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  tearDown(() async {
    if (isSignedIn) await signOut();
  });

  group('the id this client holds is the id the server judges by', () {
    test('signed in, a family created is a family owned', () async {
      // Four things at once, and all of them the server's: auth.uid() reads
      // the token, the trigger writes a membership from it, my_role finds
      // that membership, and the read policy lets it through.
      await signUp(email: anEmail(), password: 'correct horse battery');
      final id = await createFamily();

      final families = await client().from('families').select('id');
      final membership = await client()
          .from('family_memberships')
          .select('user_id, role')
          .eq('family_id', id)
          .single();

      expect(families.map((r) => r['id']), contains(id));
      expect(membership['role'], 'owner');
      expect(
        membership['user_id'],
        signedInUserId,
        reason: 'the server made the owner from the token, not from the body',
      );
    });

    test('signed out, the same family is not there at all', () async {
      // Not "forbidden" — *absent*. A row a policy refuses is a row the query
      // never sees, which is what makes a leak impossible rather than merely
      // caught.
      await signUp(email: anEmail(), password: 'correct horse battery');
      final id = await createFamily();

      await signOut();
      final families = await client().from('families').select('id');

      expect(families, isEmpty);
      expect(families.map((r) => r['id']), isNot(contains(id)));
    });

    test('another account cannot see it either', () async {
      // Signed out is the easy case. This is the one that matters: a real
      // session, a real token, and still nothing.
      await signUp(email: anEmail(), password: 'correct horse battery');
      final id = await createFamily();
      await signOut();

      await signUp(email: anEmail(), password: 'correct horse battery');
      final families = await client().from('families').select('id');

      expect(families.map((r) => r['id']), isNot(contains(id)));
    });

    test('and cannot write into it', () async {
      await signUp(email: anEmail(), password: 'correct horse battery');
      final id = await createFamily();
      await signOut();
      await signUp(email: anEmail(), password: 'correct horse battery');

      await expectLater(
        client().from('persons').insert(<String, Object?>{
          'id': aFamilyId(),
          'family_id': id,
          'display_name': 'kẻ lạ',
          'sex': 'unknown',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('the interface hears about it', () {
    test('signing in and out both reach signedInProvider', () async {
      // The bug this exists for: asked as a future, the answer was computed
      // once and kept. It survived a sign-out only because that path
      // invalidated it by hand, and it never noticed a sign-in at all —
      // the screen that signs somebody in holds no `ref`.
      //
      // Checked here rather than in a widget test, because a widget test has
      // to override the provider to control it, and overriding the thing that
      // was broken proves nothing. This one runs the real provider against a
      // real auth server.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final seen = <bool>[];
      final listener = container.listen<AsyncValue<bool>>(signedInProvider, (
        _,
        next,
      ) {
        final value = next.valueOrNull;
        if (value != null) seen.add(value);
      }, fireImmediately: true);
      addTearDown(listener.close);

      await signUp(email: anEmail(), password: 'correct horse battery');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(seen.last, isTrue, reason: 'signing in has to reach it');

      await signOut();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(seen.last, isFalse, reason: 'and so does signing out');

      await signIn(email: anEmail(), password: 'x').catchError((_) {});
      await signUp(email: anEmail(), password: 'correct horse battery');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        seen.last,
        isTrue,
        reason: 'and signing in again, which is what nobody was told about',
      );
    });
  });

  group('an account survives being left', () {
    test('signing in again reaches the same user, and their family', () async {
      // An id that changed on each sign-in would make every family a person
      // owned unreachable the moment they logged back in.
      final email = anEmail();
      await signUp(email: email, password: 'correct horse battery');
      final id = await createFamily();
      final first = signedInUserId;
      await signOut();

      await signIn(email: email, password: 'correct horse battery');

      expect(signedInUserId, first);
      final families = await client().from('families').select('id');
      expect(families.map((r) => r['id']), contains(id));
    });

    test('the wrong password is refused, in the server’s own words', () async {
      final email = anEmail();
      await signUp(email: email, password: 'correct horse battery');
      await signOut();

      await expectLater(
        signIn(email: email, password: 'wrong'),
        throwsA(isA<AuthException>()),
      );
      expect(isSignedIn, isFalse);
    });

    test('a password below the minimum is refused', () async {
      await expectLater(
        signUp(email: anEmail(), password: 'x'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
