/// The account, and the way out of it (PRODUCT.md §5.9).
///
/// SQLite is real, because what signing out has to get right is what it leaves
/// on the device. The session is a stand-in: whether Supabase can end one is
/// their code, and doubting it proves nothing.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/invitation_codes.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/features/account/account_screen.dart';
import 'package:ftree/l10n/app_localizations.dart';

final class StandInSession implements AccountSession {
  StandInSession({this.name = 'Bác Minh', this.email = 'minh@example.test'});

  @override
  String? name;

  @override
  String? email;

  int signedOut = 0;

  @override
  Future<void> signOut() async => signedOut++;
}

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late SharingMarks marks;
  late InvitationCodeStore codes;

  const familyId = 'f0000000-0000-7000-8000-000000000001';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    marks = SharingMarks(db);
    codes = InvitationCodeStore(db);

    await repository.saveFamily(const Family(id: familyId, name: 'Họ Nguyễn'));
    await marks.markShared(familyId);
    await codes.remember(id: 'inv-1', familyId: familyId, code: 'K7P2-9XMR-4T');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(WidgetTester tester, StandInSession session) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          accountSessionProvider.overrideWithValue(session),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pressSignOut(WidgetTester tester) async {
    await tester.tap(find.text('Sign out').first);
    await tester.pumpAndSettle();
  }

  group('who you are here', () {
    testWidgets('the name and the address', (WidgetTester tester) async {
      await open(tester, StandInSession());

      expect(find.text('Bác Minh'), findsOneWidget);
      expect(find.text('minh@example.test'), findsOneWidget);
    });

    testWidgets('an account with no name says so', (WidgetTester tester) async {
      // Nothing is invented from the address, here or on the member list.
      await open(tester, StandInSession(name: null));

      expect(find.text('No name given'), findsOneWidget);
    });

    testWidgets('what signing out costs is on the screen, not only in the '
        'dialog', (WidgetTester tester) async {
      // Somebody deciding whether to press it should not have to press it to
      // find out.
      await open(tester, StandInSession());

      expect(
        find.textContaining('cannot be sent from this device again'),
        findsWidgets,
      );
    });
  });

  group('signing out', () {
    testWidgets('asks first, and declining changes nothing', (
      WidgetTester tester,
    ) async {
      final session = StandInSession();
      await open(tester, session);

      await pressSignOut(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(session.signedOut, 0);
      expect(await marks.isShared(familyId), isTrue);
      expect(await codes.forFamily(familyId), hasLength(1));
    });

    testWidgets('takes the marks and the codes with it', (
      WidgetTester tester,
    ) async {
      // Both belong to the account that is leaving rather than to the device.
      // Left behind, the marks would lie to whoever signs in next and the
      // codes would be handed to them.
      final session = StandInSession();
      await open(tester, session);

      await pressSignOut(tester);
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      expect(session.signedOut, 1);
      expect(await marks.shared(), isEmpty);
      expect(await codes.forFamily(familyId), isEmpty);
    });

    testWidgets('and leaves the gia phả alone', (WidgetTester tester) async {
      // Clearing a mark is not deleting a family. The record is the point of
      // the application; the mark is a note about what this device did.
      await open(tester, StandInSession());

      await pressSignOut(tester);
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      final here = await repository.loadFamily(familyId);
      expect(here, isNotNull);
      expect(here!.family.name, 'Họ Nguyễn');
    });

    testWidgets('the mark goes without the family looking edited', (
      WidgetTester tester,
    ) async {
      // updatedAt is what synchronisation orders by (§15.2). Clearing a local
      // note must not make every family look changed.
      final before = (await db.select(db.families).get()).single.updatedAt;
      await open(tester, StandInSession());

      await pressSignOut(tester);
      await tester.tap(find.text('Sign out').last);
      await tester.pumpAndSettle();

      expect((await db.select(db.families).get()).single.updatedAt, before);
    });
  });
}
