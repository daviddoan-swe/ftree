/// Bringing a family in from a file, end to end (PRODUCT.md §9.1).
///
/// Everything below the interface has its own tests: the format in
/// `family_file_test`, the add-only merge in `family_import_test`, the
/// transaction in `drift_family_repository_test`. What is checked here is the
/// act as a reader meets it — a file goes in one end, rows come out the other,
/// and nothing is written until they have seen what will happen and said yes.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/transfer/family_file.dart';
import 'package:ftree/data/transfer/family_import.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/import_family.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;

  const familyId = 'f0000000-0000-7000-8000-000000000000';
  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const family = Family(id: familyId, name: 'Họ Nguyễn');

  Person personOf(int n, {String? name}) => Person(
    id: personId(n),
    familyId: familyId,
    displayName: name ?? 'Nguyễn Văn $n',
    birthDate: GenealogicalDate(year: 1880 + n),
  );

  Relationship childOf(int parent, int child) => Relationship.parentChild(
    id: 'r-$parent-$child',
    familyId: familyId,
    parent: personId(parent),
    child: personId(child),
  );

  /// A file holding three people in a line.
  String aFile({
    List<Person>? persons,
    List<Relationship>? relationships,
    DateTime? at,
  }) => encodeFamilyFile(
    family: family,
    at: at,
    persons: persons ?? <Person>[personOf(1), personOf(2), personOf(3)],
    relationships:
        relationships ?? <Relationship>[childOf(1, 2), childOf(2, 3)],
  );

  /// Runs the import against a screen that is really on the navigator.
  ///
  /// Through a real [MaterialApp], because the preview is a route and what is
  /// being tested includes what declining it does.
  Future<ImportPlan?> runImport(WidgetTester tester, String text) async {
    ImportPlan? outcome;
    var started = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              if (!started) {
                started = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  outcome = await importFamilyFromText(context, ref, text);
                });
              }
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return outcome;
  }

  Future<void> tapImport(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
  }

  group('nothing is written until the reader agrees', () {
    testWidgets('the preview appears before any row exists', (tester) async {
      await runImport(tester, aFile());

      expect(find.byType(ImportPreview), findsOneWidget);
      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.select(db.families).get(), isEmpty);
    });

    testWidgets('cancelling writes nothing at all', (tester) async {
      await runImport(tester, aFile());

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(await db.select(db.persons).get(), isEmpty);
      expect(await db.select(db.families).get(), isEmpty);
    });

    testWidgets('leaving by the back button writes nothing either', (
      tester,
    ) async {
      // A route popped without an answer must not be read as consent, the
      // same rule the warning prompt follows.
      await runImport(tester, aFile());

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(await db.select(db.persons).get(), isEmpty);
    });

    testWidgets('agreeing writes the family, its people, and their edges', (
      tester,
    ) async {
      await runImport(tester, aFile());
      await tapImport(tester);

      final stored = await repository.loadFamily(familyId);
      expect(stored, isNotNull);
      expect(stored!.family.name, 'Họ Nguyễn');
      expect(stored.graph.persons, hasLength(3));
      expect(stored.graph.relationships, hasLength(2));
    });

    testWidgets('and the dates survive the trip at their own precision', (
      tester,
    ) async {
      await runImport(tester, aFile());
      await tapImport(tester);

      final stored = await repository.loadFamily(familyId);
      final first = stored!.graph.personById(personId(1))!;
      expect(first.birthDate!.toIso(), '1881');
    });
  });

  group('the preview says what will happen', () {
    testWidgets('what arrives, counted', (tester) async {
      await runImport(tester, aFile());

      expect(find.text('Add 3 people'), findsOneWidget);
      expect(find.text('Add 2 relationships'), findsOneWidget);
    });

    testWidgets('a family not on the device is named as new', (tester) async {
      await runImport(tester, aFile());

      expect(find.text('This family is not on the device yet'), findsOneWidget);
    });

    testWidgets('what is already here is counted, not hidden', (tester) async {
      // Importing the same file twice must say "already here", not "done", or
      // a reader cannot tell whether the first time worked.
      await runImport(tester, aFile());
      await tapImport(tester);
      await runImport(tester, aFile());

      expect(find.text('3 people are already here'), findsOneWidget);
      expect(find.text('2 relationships are already here'), findsOneWidget);
    });

    testWidgets('with nothing new, the import button does nothing', (
      tester,
    ) async {
      await runImport(tester, aFile());
      await tapImport(tester);
      await runImport(tester, aFile());

      expect(
        find.text('There is nothing in this file that is not already here'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Import'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('the add-only limit is stated, not left to be discovered', (
      tester,
    ) async {
      // Required by PRODUCT §9.1 in as many words.
      await runImport(tester, aFile());

      expect(find.textContaining('Adds only'), findsOneWidget);
      expect(find.textContaining('does not travel'), findsOneWidget);
    });

    testWidgets('a refused relationship is named, with the reason', (
      tester,
    ) async {
      // The file brings an edge to somebody it did not bring. A count alone
      // would tell the reader their record lost something and not what.
      await runImport(
        tester,
        aFile(
          persons: <Person>[personOf(2, name: 'Nguyễn Văn Hai')],
          relationships: <Relationship>[childOf(1, 2)],
        ),
      );

      expect(find.text('1 relationship cannot be taken'), findsOneWidget);
      expect(find.textContaining('Nguyễn Văn Hai'), findsWidgets);
    });

    testWidgets('the day the file was written, when it says', (tester) async {
      await runImport(tester, aFile(at: DateTime.utc(2026, 9, 24, 10)));

      expect(find.textContaining('24/09/2026'), findsOneWidget);
    });
  });

  group('a file that cannot be read', () {
    testWidgets('is refused with the decoder’s own reason', (tester) async {
      // Not a generic "invalid file": the decoder knows which version it met,
      // and that is what tells somebody what to do about it.
      await runImport(
        tester,
        '{"format": "ftree.family", "version": 99}',
      );

      expect(find.text('The file could not be read'), findsOneWidget);
      expect(find.textContaining('99'), findsOneWidget);
    });

    testWidgets('and never reaches the preview', (tester) async {
      await runImport(tester, 'không phải JSON');

      expect(find.byType(ImportPreview), findsNothing);
      expect(await db.select(db.persons).get(), isEmpty);
    });
  });

  testWidgets('a file cannot rename the family already on the device', (
    tester,
  ) async {
    // The add-only rule covers the family's own record, not only its people.
    // A relative's export carries their spelling of the name and their
    // calendar setting; neither may land on top of what is here.
    await repository.saveFamily(family);

    await runImport(
      tester,
      encodeFamilyFile(
        family: const Family(
          id: familyId,
          name: 'Ho Nguyen (ban cua nguoi khac)',
          description: 'ghi chú của họ',
          usesLunarCalendar: true,
        ),
        persons: <Person>[personOf(1)],
        relationships: const <Relationship>[],
      ),
    );
    await tapImport(tester);

    final stored = await repository.loadFamily(familyId);
    expect(stored!.family.name, 'Họ Nguyễn');
    expect(stored.family.description, isNull);
    expect(stored.family.usesLunarCalendar, isFalse);
    expect(stored.graph.persons, hasLength(1), reason: 'the person still came');
  });

  testWidgets('a branch joins the family already on the device', (
    tester,
  ) async {
    // What exchanging files is for: a relative records a branch and sends it,
    // and it attaches to the tree already here rather than arriving separate.
    await repository.saveFamily(family);
    await repository.savePerson(personOf(1));

    await runImport(
      tester,
      aFile(
        persons: <Person>[personOf(1), personOf(2)],
        relationships: <Relationship>[childOf(1, 2)],
      ),
    );
    await tapImport(tester);

    final stored = await repository.loadFamily(familyId);
    expect(stored!.graph.persons, hasLength(2));
    expect(stored.graph.children(personId(1)), hasLength(1));
  });
}
