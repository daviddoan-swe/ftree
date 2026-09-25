/// Asking a real server what has changed (ROADMAP M9, step 1).
///
/// **Not part of the suite.** No `_test.dart` suffix: it needs Docker and a
/// running local Supabase. Run it deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/pull.dart
/// ```
///
/// What the device does with an answer is `test/data/sync/family_pull_test.dart`.
/// What is worth checking here is the answer itself: that `change_seq` moves
/// when it should, that a second ask returns only what is new, and that a
/// deletion comes back at all rather than simply going missing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ftree/data/cloud/cloud_session.dart';
import 'package:ftree/data/cloud/supabase_family_repository.dart';
import 'package:ftree/data/sync/cloud_changes.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  SupabaseClient client() => Supabase.instance.client;
  CloudChanges changes() => CloudChanges(client());
  SupabaseFamilyRepository repository() => SupabaseFamilyRepository(client());

  String anEmail() =>
      'pull-${DateTime.now().microsecondsSinceEpoch}@example.test';

  String aFamilyId() {
    final n = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return 'aaaaaaaa-1111-7000-8000-${n.substring(n.length - 12)}';
  }

  /// Unique per family *and* per person. Derived from the family's own tail
  /// rather than its head, which is the same eight characters every time — an
  /// earlier draft shared one id across every test in the file, and upserting
  /// it hit a row belonging to another account's family.
  String personIn(String family, int n) =>
      'bbbbbbbb-2222-7000-800$n-${family.substring(family.length - 12)}';

  Future<void> anAccount() =>
      signUp(email: anEmail(), password: 'correct horse battery');

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  tearDown(() async {
    if (isSignedIn) await signOut();
  });

  test('nothing seen yet means everything', () async {
    // Which is what makes the first download and every later pull one request
    // rather than two paths.
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(family, 1), familyId: family, displayName: 'Cụ Tổ'),
      ],
    );

    final answer = await changes().since(family, 0);

    expect(answer.family?.name, 'Họ Nguyễn');
    expect(answer.persons, hasLength(1));
    expect(answer.highestSeq, greaterThan(0));
  });

  test('asking again from where it stopped answers nothing', () async {
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
    );

    final first = await changes().since(family, 0);
    final second = await changes().since(family, first.highestSeq);

    expect(second.isEmpty, isTrue);
    expect(
      second.highestSeq,
      first.highestSeq,
      reason: 'an empty answer must not move the mark',
    );
  });

  test('and after a change, only the change', () async {
    // The point of the whole design: a family of a thousand people costs one
    // row to catch up on when one row moved.
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(family, 1), familyId: family, displayName: 'Cụ Tổ'),
        Person(id: personIn(family, 2), familyId: family, displayName: 'Bà Tổ'),
      ],
    );
    final caught = await changes().since(family, 0);

    await repository().savePerson(
      Person(
        id: personIn(family, 2),
        familyId: family,
        displayName: 'Bà Tổ Trần Thị',
      ),
    );

    final answer = await changes().since(family, caught.highestSeq);

    expect(answer.family, isNull, reason: 'the family itself did not move');
    expect(answer.persons, hasLength(1));
    expect(answer.persons.single.displayName, 'Bà Tổ Trần Thị');
    expect(answer.highestSeq, greaterThan(caught.highestSeq));
  });

  test('a deletion arrives as a deletion, not as an absence', () async {
    // Soft everywhere (§15.1), so it travels as an ordinary changed row. A
    // pull that only saw live rows would never learn anybody had gone.
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(family, 1), familyId: family, displayName: 'Cụ Tổ'),
      ],
    );
    final caught = await changes().since(family, 0);

    await repository().deletePerson(personIn(family, 1));

    final answer = await changes().since(family, caught.highestSeq);

    expect(answer.persons, isEmpty);
    expect(answer.deletedPersons, <String>[personIn(family, 1)]);
  });

  test('a relationship moves on its own number too', () async {
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(family, 1), familyId: family, displayName: 'Ông A'),
        Person(id: personIn(family, 2), familyId: family, displayName: 'Bà B'),
      ],
    );
    final caught = await changes().since(family, 0);

    await repository().saveRelationship(
      Relationship.spouse(
        id: 'cccccccc-3333-7000-8000-${family.substring(family.length - 12)}',
        familyId: family,
        personA: personIn(family, 1),
        personB: personIn(family, 2),
      ),
    );

    final answer = await changes().since(family, caught.highestSeq);

    expect(answer.relationships, hasLength(1));
    expect(answer.persons, isEmpty);
  });

  test('somebody else’s family answers nothing at all', () async {
    // Not a refusal — absence, as everywhere else. A pull against a family
    // this account has no part in is indistinguishable from one that is not
    // there, which is what makes a leak impossible rather than merely caught.
    await anAccount();
    final family = aFamilyId();
    await repository().saveAll(
      family: Family(id: family, name: 'Họ Nguyễn'),
      persons: <Person>[
        Person(id: personIn(family, 1), familyId: family, displayName: 'Cụ Tổ'),
      ],
    );
    await signOut();

    await anAccount();
    final answer = await changes().since(family, 0);

    expect(answer.isEmpty, isTrue);
    expect(answer.highestSeq, 0);
  });
}
