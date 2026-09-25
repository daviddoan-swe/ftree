/// Putting this device's changes on a real server (ROADMAP M9, step 2).
///
/// **Not part of the suite.** No `_test.dart` suffix: it needs Docker and a
/// running local Supabase. Run it deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/push.dart
/// ```
///
/// What is worth checking here is the confirmation. A policy that refuses an
/// UPDATE changes nothing and reports success, so a push has to *read back*
/// what the server is holding rather than trust the absence of an error — and
/// the case that proves it is a viewer, whose writes vanish quietly.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ftree/data/cloud/cloud_session.dart';
import 'package:ftree/data/cloud/family_invitations.dart';
import 'package:ftree/data/cloud/supabase_family_repository.dart';
import 'package:ftree/data/sync/cloud_changes.dart';
import 'package:ftree/data/sync/cloud_push.dart';
import 'package:ftree/data/sync/family_push.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  SupabaseClient client() => Supabase.instance.client;
  CloudPush sink() => CloudPush(client());
  SupabaseFamilyRepository repository() => SupabaseFamilyRepository(client());

  const password = 'correct horse battery';

  String anEmail() =>
      'push-${DateTime.now().microsecondsSinceEpoch}@example.test';

  String aFamilyId() {
    final n = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return 'aaaaaaaa-4444-7000-8000-${n.substring(n.length - 12)}';
  }

  /// Unique per family and per person — the head of a family id is the same
  /// eight characters every time, so the tail is what distinguishes them.
  String personIn(String family, int n) =>
      'bbbbbbbb-4444-7000-800$n-${family.substring(family.length - 12)}';

  Future<({String email})> anAccount() async {
    final email = anEmail();
    await signUp(email: email, password: password);
    return (email: email);
  }

  /// A family on the server, owned by whoever is signed in.
  Future<String> aFamily() async {
    final id = aFamilyId();
    await repository().saveAll(
      family: Family(id: id, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(id, 1), familyId: id, displayName: 'Cụ Tổ'),
      ],
    );
    return id;
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  tearDown(() async {
    if (isSignedIn) await signOut();
  });

  test('an owner’s changes land, and are confirmed', () async {
    await anAccount();
    final family = await aFamily();
    final at = DateTime.now().toUtc();

    final held = await sink().send(
      family,
      Outgoing(
        stampedAt: at,
        persons: <Person>[
          Person(
            id: personIn(family, 2),
            familyId: family,
            displayName: 'Bà Tổ',
          ),
        ],
      ),
    );

    expect(held, <String>{personIn(family, 2)});
    final answer = await CloudChanges(client()).since(family, 0);
    expect(answer.persons.map((p) => p.displayName), contains('Bà Tổ'));
  });

  test('a removal travels as a removal, not as a resurrection', () async {
    // `save_family_all` clears `deleted_at` on everything it writes. Sent
    // through it, a tombstone would bring the person back to life.
    await anAccount();
    final family = await aFamily();

    final held = await sink().send(
      family,
      Outgoing(
        stampedAt: DateTime.now().toUtc(),
        deletedPersons: <String>[personIn(family, 1)],
      ),
    );

    expect(held, contains(personIn(family, 1)));
    final answer = await CloudChanges(client()).since(family, 0);
    expect(answer.persons, isEmpty);
    expect(answer.deletedPersons, contains(personIn(family, 1)));
  });

  test('a viewer pushing a person is refused loudly', () async {
    // Not the silent shape, and worth knowing which is which.
    // `save_family_all` reaches `persons` through an INSERT, so
    // `persons_insert` refuses it with 42501 rather than matching nothing.
    // The push therefore throws, the caller leaves everything flagged, and the
    // read-back never runs — which is the right outcome by a different route.
    final owner = await anAccount();
    final family = await aFamily();
    final invitation = await FamilyInvitations(
      client(),
    ).create(familyId: family, role: 'viewer');
    await signOut();

    await anAccount();
    await FamilyInvitations(client()).accept(invitation.code!);

    await expectLater(
      sink().send(
        family,
        Outgoing(
          stampedAt: DateTime.now().toUtc(),
          persons: <Person>[
            Person(
              id: personIn(family, 1),
              familyId: family,
              displayName: 'viewer đổi tên',
            ),
          ],
        ),
      ),
      throwsA(isA<PostgrestException>()),
    );

    await signOut();
    await signIn(email: owner.email, password: password);
    final answer = await CloudChanges(client()).since(family, 0);
    expect(answer.persons.single.displayName, 'Cụ Tổ');
  });

  test('and a viewer removing a relationship is refused in silence', () async {
    // This is the shape the confirmation exists for. Removing an edge is a
    // plain UPDATE, and a policy that excludes a row by USING makes the
    // statement match nothing, change nothing and raise nothing — HTTP 204.
    // A push that read the absence of an error as agreement would clear the
    // flag on work the server never took.
    final owner = await anAccount();
    final family = await aFamily();
    final edge =
        'cccccccc-4444-7000-8000-'
        '${family.substring(family.length - 12)}';
    await repository().saveAll(
      persons: <Person>[
        Person(id: personIn(family, 2), familyId: family, displayName: 'Bà Tổ'),
      ],
      relationships: <Relationship>[
        Relationship.spouse(
          id: edge,
          familyId: family,
          personA: personIn(family, 1),
          personB: personIn(family, 2),
        ),
      ],
    );
    final invitation = await FamilyInvitations(
      client(),
    ).create(familyId: family, role: 'viewer');
    await signOut();

    await anAccount();
    await FamilyInvitations(client()).accept(invitation.code!);

    final held = await sink().send(
      family,
      Outgoing(
        stampedAt: DateTime.now().toUtc(),
        deletedRelationships: <String>[edge],
      ),
    );

    expect(held, isEmpty, reason: 'it raised nothing, and it also did nothing');

    await signOut();
    await signIn(email: owner.email, password: password);
    final answer = await CloudChanges(client()).since(family, 0);
    expect(answer.relationships, hasLength(1));
    expect(answer.deletedRelationships, isEmpty);
  });

  test('an editor’s push does land', () async {
    // The other side of the same check: the confirmation must not be so strict
    // that it refuses work the server took.
    final owner = await anAccount();
    final family = await aFamily();
    final invitation = await FamilyInvitations(
      client(),
    ).create(familyId: family, role: 'editor');
    await signOut();

    await anAccount();
    await FamilyInvitations(client()).accept(invitation.code!);

    final held = await sink().send(
      family,
      Outgoing(
        stampedAt: DateTime.now().toUtc(),
        persons: <Person>[
          Person(
            id: personIn(family, 1),
            familyId: family,
            displayName: 'editor đổi tên',
          ),
        ],
      ),
    );

    expect(held, <String>{personIn(family, 1)});
    expect(owner.email, isNotEmpty);
  });

  test('nothing to send sends nothing', () async {
    await anAccount();
    final family = await aFamily();

    final held = await sink().send(
      family,
      Outgoing(stampedAt: DateTime.now().toUtc()),
    );

    expect(held, isEmpty);
  });
}
