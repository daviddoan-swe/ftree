/// Sending one family to the cloud (PRODUCT.md §4.2, §4.3).
///
/// The device half is real — a live SQLite database, the real repository, the
/// real mark. The cloud is a stand-in, because the three answers that matter
/// are *states of the server*, and two of them cannot be produced by asking a
/// real one politely: a family this account can see but has no mark for, and a
/// second device winning the race between the question and the send.
///
/// The server's own behaviour under those states is `test/cloud/claiming.dart`,
/// where it is a real Postgres with real policies.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/share_family.dart';
import 'package:ftree/l10n/app_localizations.dart';

/// A server in whichever of the three states is being examined.
final class StandInCloud implements SharingCloud {
  StandInCloud({
    this.letsMeIn = true,
    this.claimed = false,
    this.visibleToMe = false,
    this.sendThrows,
  });

  bool letsMeIn;
  bool claimed;
  bool visibleToMe;
  Object? sendThrows;

  int signInAttempts = 0;
  final List<FamilySnapshot> sent = <FamilySnapshot>[];

  @override
  Future<bool> signIn(BuildContext context) async {
    signInAttempts++;
    return letsMeIn;
  }

  @override
  Future<bool> isClaimed(String familyId) async => claimed;

  @override
  Future<bool> canSee(String familyId) async => visibleToMe;

  @override
  Future<void> send(FamilySnapshot snapshot) async {
    final failure = sendThrows;
    if (failure != null) throw failure;
    sent.add(snapshot);
  }
}

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late SharingMarks marks;

  /// What [shareFamily] answered, or null while it is still waiting on a
  /// dialog — which it does, on the paths that end in one.
  bool? outcome;

  const familyId = 'f0000000-0000-7000-8000-000000000000';
  const family = Family(id: familyId, name: 'Họ Nguyễn');

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  setUp(() async {
    outcome = null;
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    marks = SharingMarks(db);

    await repository.saveAll(
      family: family,
      persons: <Person>[
        Person(id: personId(1), familyId: familyId, displayName: 'Ông A'),
        Person(id: personId(2), familyId: familyId, displayName: 'Bà B'),
      ],
      relationships: <Relationship>[
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Presses the button, then answers the confirmation.
  Future<void> share(
    WidgetTester tester,
    StandInCloud cloud, {
    bool agreeing = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          sharingCloudProvider.overrideWithValue(cloud),
        ],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  ElevatedButton(
                    onPressed: () async {
                      outcome = await shareFamily(context, ref, family);
                    },
                    child: const Text('bắt đầu'),
                  ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('bắt đầu'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(agreeing ? 'Share' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  /// Closes a failure dialog, letting the call finish.
  Future<void> readTheBadNews(WidgetTester tester) async {
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }

  group('nothing leaves without being asked for', () {
    testWidgets('declining the confirmation does not even sign in', (
      WidgetTester tester,
    ) async {
      // Asked before signing in on purpose: creating an account somebody did
      // not want is its own thing that cannot be undone.
      final cloud = StandInCloud();

      await share(tester, cloud, agreeing: false);

      expect(outcome, isFalse);
      expect(cloud.signInAttempts, 0);
      expect(cloud.sent, isEmpty);
      expect(await marks.shared(), isEmpty);
    });

    testWidgets('backing out of signing in sends nothing', (
      WidgetTester tester,
    ) async {
      final cloud = StandInCloud(letsMeIn: false);

      await share(tester, cloud);

      expect(outcome, isFalse);
      expect(cloud.sent, isEmpty);
      expect(await marks.shared(), isEmpty);
    });
  });

  group('when nobody holds it', () {
    testWidgets('the whole family goes, and the device remembers', (
      WidgetTester tester,
    ) async {
      final cloud = StandInCloud();

      await share(tester, cloud);

      expect(outcome, isTrue);
      expect(cloud.sent, hasLength(1));
      expect(cloud.sent.single.family.name, 'Họ Nguyễn');
      expect(cloud.sent.single.graph.persons, hasLength(2));
      expect(
        cloud.sent.single.graph.relationships,
        hasLength(1),
        reason: 'people without their edges is not a gia phả',
      );
      expect(await marks.isShared(familyId), isTrue);
      expect(find.text('Họ Nguyễn has been shared'), findsOneWidget);
    });

    testWidgets('a send that fails leaves no mark behind', (
      WidgetTester tester,
    ) async {
      // The mark decides whether the button is offered again. Written before
      // the send, a failure would hide the only way to retry.
      final cloud = StandInCloud(sendThrows: Exception('mạng mất rồi'));

      await share(tester, cloud);

      expect(find.text('It could not be shared'), findsOneWidget);
      expect(find.textContaining('mạng mất rồi'), findsOneWidget);

      await readTheBadNews(tester);

      expect(outcome, isFalse);
      expect(await marks.shared(), isEmpty);
    });

    testWidgets('losing the race reads as somebody else having it', (
      WidgetTester tester,
    ) async {
      // Asking and sending are two requests. A second device that pressed in
      // between is not a fault to show raw — it is the same news as finding it
      // claimed, arriving a moment later.
      final cloud = StandInCloud(
        sendThrows: const PostgrestException(
          message: 'family_already_claimed',
          code: 'P0001',
        ),
      );

      await share(tester, cloud);

      expect(find.textContaining('Ask them to invite you'), findsOneWidget);

      await readTheBadNews(tester);

      expect(outcome, isFalse);
      expect(await marks.shared(), isEmpty);
    });
  });

  group('when it is already up there', () {
    testWidgets('and this account can see it, the mark is recovered', (
      WidgetTester tester,
    ) async {
      // A reinstall, or a restore from an exported file: the family is ours and
      // the mark was lost with the old database. Re-sending would put this copy
      // on top of the shared one, so nothing is sent — the mark is rebuilt from
      // what the server already knows, and the button stops being offered.
      final cloud = StandInCloud(claimed: true, visibleToMe: true);

      await share(tester, cloud);

      expect(cloud.sent, isEmpty, reason: 'my copy must not win (§15.3)');
      expect(await marks.isShared(familyId), isTrue);
      expect(find.text('Họ Nguyễn is already shared'), findsOneWidget);
      expect(outcome, isFalse, reason: 'nothing was shared by this press');
    });

    testWidgets('and it cannot, the way in is an invitation', (
      WidgetTester tester,
    ) async {
      // Somebody else pressed first — the ordinary consequence of having sent
      // them a file, since the file keeps the family's id (§4.3).
      final cloud = StandInCloud(claimed: true, visibleToMe: false);

      await share(tester, cloud);

      expect(outcome, isFalse);
      expect(cloud.sent, isEmpty);
      expect(find.textContaining('Ask them to invite you'), findsOneWidget);
      expect(
        await marks.shared(),
        isEmpty,
        reason: 'this device shared nothing, and a mark would say it had',
      );
    });
  });
}
