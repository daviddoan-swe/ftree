/// Where a family stands with the server (ROADMAP M9, step 5).
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/sync_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/features/family/family_screen.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;

  const familyId = 'f0000000-0000-7000-8000-000000000001';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[
        const Person(
          id: 'p0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          displayName: 'Cụ Tổ',
        ),
      ],
    );
  });

  tearDown(() async => db.close());

  /// A real phone, not the 800-point test surface. The bar now carries two
  /// lines, and the wider surface is exactly what would hide it overflowing.
  Future<void> openOnAPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: FamilyScreen(familyId: familyId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a family never synchronised says so, under its name', (
    tester,
  ) async {
    await openOnAPhone(tester);

    // A family nobody ever put on a server has never synchronised, and saying
    // "a moment ago" about a server it has not touched is the one thing this
    // line must not do.
    expect(find.text('Họ Nguyễn'), findsOneWidget);
    expect(find.textContaining('Not synced'), findsOneWidget);
  });

  testWidgets('nothing waiting is said by there being no number', (
    tester,
  ) async {
    // A time already says it synchronised. Saying so again beside it was the
    // same words twice, and the absence of a count is the shortest way to say
    // there is nothing to send.
    await db.customStatement('UPDATE persons SET unsent = 0');
    await db.customStatement('UPDATE families SET unsent = 0');

    await openOnAPhone(tester);

    expect(find.textContaining('changes'), findsNothing);
    expect(find.textContaining('Not synced'), findsOneWidget);
  });

  testWidgets('work not yet sent is counted where somebody can see it', (
    tester,
  ) async {
    // The whole point of the line. A person added on one phone sat there for
    // a day with nothing anywhere to say so.
    await openOnAPhone(tester);

    expect(find.textContaining('· 2 changes'), findsOneWidget);
  });

  testWidgets('a time that has passed is said in hours, not minutes', (
    tester,
  ) async {
    // Somebody reading this wants to know whether what they are looking at is
    // recent. "Three hours and eleven minutes" answers that no better than
    // "three hours" and reads as a machine talking.
    await SyncMarks(
      db,
      now: () => DateTime.now().toUtc().subtract(const Duration(hours: 3)),
    ).mark(familyId);

    await openOnAPhone(tester);

    expect(find.textContaining('3 hours ago'), findsOneWidget);
  });
}
