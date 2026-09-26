/// Asking somebody which version they want (ROADMAP M9, step 3b).
///
/// SQLite is real, so what these check is what the screen leaves behind: which
/// version ends up in the gia phả, and whether the question is cleared.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/sync/conflicts.dart';
import 'package:ftree/data/sync/family_pull.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/features/sync/conflicts_screen.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late FamilyPull pull;

  const familyId = 'f0000000-0000-7000-8000-000000000001';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Person person(int n, String name, {String? place}) => Person(
    id: personId(n),
    familyId: familyId,
    displayName: name,
    birthPlace: place,
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    pull = FamilyPull(db);

    await repository.saveAll(
      family: const Family(id: familyId, name: 'Họ Nguyễn'),
      persons: <Person>[person(1, 'Cụ Tổ')],
    );
    await db.customStatement('UPDATE persons SET unsent = 0');
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> disagree({required String mine, required String theirs}) async {
    await repository.savePerson(person(1, mine));
    await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 7, persons: <Person>[person(1, theirs)]),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: ConflictsScreen(familyId: familyId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> nameNow() async => (await repository.loadFamily(
    familyId,
  ))!.graph.personById(personId(1))!.displayName;

  /// Opened the way the banner opens it: pushed over the family, with
  /// somewhere to go back to. The [open] helper above makes it the root of a
  /// navigator, where there is nothing behind it to return to.
  Future<void> openOverAFamily(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showConflicts(context, familyId),
                  child: const Text('phía sau'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('phía sau'));
    await tester.pumpAndSettle();
  }

  testWidgets('answering the last question leaves the screen', (tester) async {
    // It exists for the questions. Answering the last one and being left on a
    // page that says there is nothing here makes somebody press back to leave
    // a screen that has already finished.
    await disagree(mine: 'tôi', theirs: 'họ');
    await openOverAFamily(tester);

    expect(find.text('Keep these'), findsOneWidget);

    await tester.tap(find.text('Keep these'));
    await tester.pumpAndSettle();

    expect(find.text('phía sau'), findsOneWidget, reason: 'back where we were');
    expect(find.text('Nothing left to decide'), findsNothing);
  });

  testWidgets('answering one of two stays, because one is left', (
    tester,
  ) async {
    // Both have to have been synchronised once, or there is no version the two
    // edits started from and the pull simply holds the second one instead of
    // finding a disagreement in it.
    await repository.savePerson(person(2, 'Bà Tổ'));
    await db.customStatement('UPDATE persons SET unsent = 0');

    await disagree(mine: 'tôi', theirs: 'họ');
    await repository.savePerson(person(2, 'Bà Tổ (tôi)'));
    await pull.apply(
      familyId,
      IncomingChanges(
        highestSeq: 9,
        persons: <Person>[person(2, 'Bà Tổ (họ)')],
      ),
    );
    expect(await Conflicts(db).countIn(familyId), 2);

    await openOverAFamily(tester);

    await tester.tap(find.text('Keep these').first);
    await tester.pumpAndSettle();

    expect(find.text('phía sau'), findsNothing);
    expect(find.text('Keep these'), findsOneWidget);
  });

  testWidgets('nothing waiting says so', (tester) async {
    await open(tester);

    expect(find.text('Nothing left to decide'), findsOneWidget);
  });

  testWidgets('both versions are shown, with what they started from', (
    tester,
  ) async {
    // Two values on their own do not say which way either side moved. The
    // version they began at does.
    await disagree(mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');

    await open(tester);

    // Twice for mine: once as the heading, which is how the person is named,
    // and once as the version on offer.
    expect(find.textContaining('Cụ Tổ (tôi)'), findsNWidgets(2));
    expect(find.textContaining('Cụ Tổ (họ)'), findsOneWidget);
    expect(find.textContaining('Before: Cụ Tổ'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
  });

  testWidgets('doing nothing keeps what this device holds', (tester) async {
    // A screen that defaulted to the server would settle disagreements for
    // anybody who pressed on through.
    await disagree(mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');
    await open(tester);

    await tester.tap(find.text('Keep these'));
    await tester.pumpAndSettle();

    expect(await nameNow(), 'Cụ Tổ (tôi)');
    expect(await Conflicts(db).countIn(familyId), 0);
  });

  testWidgets('and choosing theirs takes their value', (tester) async {
    await disagree(mine: 'Cụ Tổ (tôi)', theirs: 'Cụ Tổ (họ)');
    await open(tester);

    await tester.tap(find.text('The version on the server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep these'));
    await tester.pumpAndSettle();

    expect(await nameNow(), 'Cụ Tổ (họ)');
  });

  testWidgets('answering clears the question from the screen', (tester) async {
    await disagree(mine: 'tôi', theirs: 'họ');
    await open(tester);

    await tester.tap(find.text('Keep these'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing left to decide'), findsOneWidget);
  });

  testWidgets('the family screen stops saying one is waiting', (tester) async {
    // The banner is the only thing that says a decision is outstanding. Answered
    // on one screen and still announced on the other, somebody goes looking for
    // a question that is no longer there.
    await disagree(mine: 'tôi', theirs: 'họ');

    final container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(conflictCountProvider(familyId).future), 1);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: ConflictsScreen(familyId: familyId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep these'));
    await tester.pumpAndSettle();

    expect(await container.read(conflictCountProvider(familyId).future), 0);
  });

  testWidgets('an emptied field says so rather than showing nothing', (
    tester,
  ) async {
    // A blank row beside a filled one reads as the screen failing to load it,
    // when what it means is that somebody cleared the field on purpose.
    await repository.savePerson(person(1, 'Cụ Tổ', place: 'Nam Định'));
    await db.customStatement(
      'UPDATE persons SET unsent = 0, base_fields = NULL',
    );
    await repository.savePerson(person(1, 'Cụ Tổ'));
    await pull.apply(
      familyId,
      IncomingChanges(
        highestSeq: 7,
        persons: <Person>[person(1, 'Cụ Tổ', place: 'Ý Yên')],
      ),
    );

    await open(tester);

    expect(find.textContaining('left empty'), findsWidgets);
  });

  // ------------------------------------------- a removal against an edit ---

  Future<void> theyRemoved() async {
    await repository.savePerson(person(1, 'sửa ở máy này'));
    await pull.apply(
      familyId,
      IncomingChanges(highestSeq: 7, deletedPersons: <String>[personId(1)]),
    );
  }

  Future<void> iRemoved() async {
    await repository.savePerson(person(1, 'sửa ở máy này'));
    await db.customStatement('UPDATE persons SET unsent = 0');
    await repository.savePerson(person(1, 'sửa lần nữa'));
    await repository.deletePerson(personId(1));
    await pull.apply(
      familyId,
      IncomingChanges(
        highestSeq: 7,
        persons: <Person>[person(1, 'từ máy khác')],
      ),
    );
  }

  Future<bool> stillHere() async =>
      (await repository.loadFamily(familyId))!.graph.personById(personId(1)) !=
      null;

  testWidgets('their removal is asked as one question, not field by field', (
    tester,
  ) async {
    await theyRemoved();
    await open(tester);

    expect(find.textContaining('Removed on another device'), findsOneWidget);
    expect(find.text('Keep them in the gia phả'), findsOneWidget);
    expect(find.text('Remove them from the gia phả'), findsOneWidget);
    // No field rows: there is no version of a person both gone and corrected.
    expect(find.text('Display name'), findsNothing);
    expect(find.textContaining('Before:'), findsNothing);
  });

  testWidgets('doing nothing keeps somebody the server removed', (
    tester,
  ) async {
    // This device holds them alive, and pressing on through must not reverse a
    // removal on one side or an edit on the other by accident.
    await theyRemoved();
    await open(tester);

    await tester.tap(find.text('Save this decision'));
    await tester.pumpAndSettle();

    expect(await stillHere(), isTrue);
    expect(await Conflicts(db).countIn(familyId), 0);
  });

  testWidgets('and agreeing to it takes them away', (tester) async {
    await theyRemoved();
    await open(tester);

    await tester.tap(find.text('Remove them from the gia phả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this decision'));
    await tester.pumpAndSettle();

    expect(await stillHere(), isFalse);
  });

  testWidgets('doing nothing stands by a removal made here', (tester) async {
    await iRemoved();
    await open(tester);

    expect(find.textContaining('You removed them here'), findsOneWidget);

    await tester.tap(find.text('Save this decision'));
    await tester.pumpAndSettle();

    expect(await stillHere(), isFalse);
  });

  testWidgets('taking them back names the version that comes back', (
    tester,
  ) async {
    // Which copy returns is not obvious and is not the same in both
    // directions — here it is theirs, because taking back somebody who was
    // being corrected means taking the correction too.
    await iRemoved();
    await open(tester);

    expect(find.textContaining('từ máy khác'), findsOneWidget);

    await tester.tap(find.text('Keep them in the gia phả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save this decision'));
    await tester.pumpAndSettle();

    expect(await stillHere(), isTrue);
    expect(
      (await repository.loadFamily(
        familyId,
      ))!.graph.personById(personId(1))!.displayName,
      'từ máy khác',
    );
  });
}
