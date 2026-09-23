import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/app.dart';
import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/generation_filter.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Boots the real application over an in-memory database.
  ///
  /// Everything below the widget is real — providers, repository, SQLite — so
  /// these tests exercise the whole stack rather than a mock of it.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const FtreeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openCreateSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Create family'));
    await tester.pumpAndSettle();
  }

  group('empty state', () {
    testWidgets('invites the first family to be created', (tester) async {
      await pumpApp(tester);

      expect(find.text('No families yet'), findsOneWidget);
      expect(find.byTooltip('Create family'), findsOneWidget);
    });
  });

  group('creating a family', () {
    testWidgets('a named family appears in the list and is stored',
        (tester) async {
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Họ Nguyễn',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Họ Nguyễn'), findsOneWidget);
      expect(find.text('No families yet'), findsNothing);

      // Really written, not just held in the widget tree.
      final rows = await db.select(db.families).get();
      expect(rows.single.name, 'Họ Nguyễn');
    });

    testWidgets('a blank name is refused and nothing is written',
        (tester) async {
      // The domain rule surfacing in the interface: an error blocks the save
      // rather than being silently corrected (DOMAIN.md §9).
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot save'), findsOneWidget);
      expect(find.textContaining('A family needs a name'), findsOneWidget);
      expect(await db.select(db.families).get(), isEmpty);
    });

    testWidgets('a whitespace-only name is refused too', (tester) async {
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        '   ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Cannot save'), findsOneWidget);
      expect(await db.select(db.families).get(), isEmpty);
    });

    testWidgets('the message clears once the name is typed', (tester) async {
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot save'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Smith',
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot save'), findsNothing);
    });

    testWidgets('the lunar setting is saved with the family', (tester) async {
      // It travels with the tree rather than following the viewer, so it has
      // to be stored, not remembered in the interface.
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Họ Trần',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.families).get();
      expect(rows.single.usesLunarCalendar, isTrue);
    });

    testWidgets('cancelling writes nothing', (tester) async {
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Abandoned',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Abandoned'), findsNothing);
      expect(await db.select(db.families).get(), isEmpty);
    });

    testWidgets('an empty description is stored as absent, not blank',
        (tester) async {
      await pumpApp(tester);
      await openCreateSheet(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Họ Lê',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.families).get();
      expect(rows.single.description, isNull);
    });
  });

  testWidgets('the sheet survives a negative keyboard inset', (tester) async {
    // Seen on an iPhone simulator: while the keyboard animates, iOS reports a
    // bottom inset below zero for a frame. Fed straight into EdgeInsets it
    // asserts, and the failure takes down the screen behind the sheet too.
    await pumpApp(tester);
    await openCreateSheet(tester);

    addTearDown(tester.view.reset);
    tester.view.viewInsets = const FakeViewPadding(bottom: -80);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Create family'), findsWidgets);
  });

  group('the swipe actions', () {
    Future<void> seedFamily({
      String id = 'f0000000-0000-7000-8000-000000000000',
      String name = 'Họ Nguyễn',
      bool lunar = false,
    }) => repository.saveFamily(
      domain.Family(id: id, name: name, usesLunarCalendar: lunar),
    );

    String personId(int n) =>
        'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

    /// Two people and their marriage, in the family seeded above.
    Future<void> seedHousehold() async {
      await seedFamily();
      for (final (n, name) in <(int, String)>[(1, 'Cha'), (2, 'Mẹ')]) {
        await repository.savePerson(
          Person(
            id: personId(n),
            familyId: 'f0000000-0000-7000-8000-000000000000',
            displayName: name,
          ),
        );
      }
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: 'f0000000-0000-7000-8000-000000000000',
          personA: personId(1),
          personB: personId(2),
        ),
      );
    }

    /// Drags from the row's leading edge.
    ///
    /// Not from its centre: with another row's pane already open, the centre of
    /// this one is not reliably the row itself, and the drag lands elsewhere.
    Future<void> swipeOpen(WidgetTester tester, String name) async {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(ListTile),
      );
      await tester.dragFrom(
        tester.getTopLeft(row) + const Offset(24, 24),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a swipe reveals editing and deleting', (tester) async {
      await seedFamily();
      await pumpApp(tester);

      expect(find.text('Edit'), findsNothing);
      await swipeOpen(tester, 'Họ Nguyễn');

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('a swipe on its own deletes nothing', (tester) async {
      // The gesture reveals; it is never the last step before losing a family.
      await seedHousehold();
      await pumpApp(tester);
      await swipeOpen(tester, 'Họ Nguyễn');

      expect(find.text('Họ Nguyễn'), findsOneWidget);
      expect(await db.select(db.families).get(), hasLength(1));
    });

    testWidgets('scrolling the list does not open a row', (tester) async {
      await seedFamily();
      await seedFamily(
        id: 'f0000000-0000-7000-8000-000000000001',
        name: 'Họ Trần',
      );
      await pumpApp(tester);

      await tester.drag(find.text('Họ Nguyễn'), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('opening one row closes another', (tester) async {
      await seedFamily();
      await seedFamily(
        id: 'f0000000-0000-7000-8000-000000000001',
        name: 'Họ Trần',
      );
      await pumpApp(tester);

      await swipeOpen(tester, 'Họ Nguyễn');
      expect(find.text('Delete'), findsOneWidget);

      await swipeOpen(tester, 'Họ Trần');
      expect(find.text('Delete'), findsOneWidget, reason: 'only one is open');

      // Both rows offer a button reading "Delete", so which one is open is
      // settled by using it: the confirmation names the family it belongs to.
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Họ Trần?'), findsOneWidget);
    });
  });

  group('editing a family', () {
    testWidgets('the sheet opens on what is already recorded', (tester) async {
      await repository.saveFamily(
        const domain.Family(
          id: 'f0000000-0000-7000-8000-000000000000',
          name: 'Họ Nguyễn',
          description: 'Gia phả tám đời',
          usesLunarCalendar: true,
        ),
      );
      await pumpApp(tester);
      await tester.drag(
        find.ancestor(
          of: find.text('Họ Nguyễn'),
          matching: find.byType(ListTile),
        ),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit family'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Họ Nguyễn'))
            .controller!
            .text,
        'Họ Nguyễn',
      );
      expect(find.text('Gia phả tám đời'), findsWidgets);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
    });

    testWidgets('renaming updates rather than adding another', (tester) async {
      await repository.saveFamily(
        const domain.Family(
          id: 'f0000000-0000-7000-8000-000000000000',
          name: 'Họ Nguyên',
        ),
      );
      await pumpApp(tester);
      await tester.drag(
        find.ancestor(
          of: find.text('Họ Nguyên'),
          matching: find.byType(ListTile),
        ),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Family name'),
        'Họ Nguyễn',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.families).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Họ Nguyễn');
      expect(find.text('Họ Nguyễn'), findsOneWidget);
    });

    testWidgets('turning the lunar calendar off keeps the readings', (
      tester,
    ) async {
      // The flag decides what is offered and shown, not what is stored
      // (DOMAIN.md §4.4). Anything that erased the recorded lunar reading here
      // would be destroying what the source actually said.
      const familyId = 'f0000000-0000-7000-8000-000000000000';
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn',
            usesLunarCalendar: true),
      );
      await repository.savePerson(
        Person(
          id: 'p0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          displayName: 'Cụ Tổ',
          deathDate: GenealogicalDate(
            year: 1960,
            month: 4,
            day: 5,
            lunar: LunarDate(year: 1960, month: 3, day: 10),
          ),
        ),
      );

      await pumpApp(tester);
      await tester.drag(
        find.ancestor(
          of: find.text('Họ Nguyễn'),
          matching: find.byType(ListTile),
        ),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final family = (await repository.loadFamily(familyId))!;
      expect(family.family.usesLunarCalendar, isFalse);
      expect(
        family.graph.persons.single.deathDate!.lunar,
        LunarDate(year: 1960, month: 3, day: 10),
      );
    });
  });

  group('deleting a family', () {
    const familyId = 'f0000000-0000-7000-8000-000000000000';

    Future<void> seedHousehold() async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      for (final (n, name) in <(int, String)>[(1, 'Cha'), (2, 'Mẹ')]) {
        await repository.savePerson(
          Person(
            id: 'p0000000-0000-7000-8000-00000000000$n',
            familyId: familyId,
            displayName: name,
          ),
        );
      }
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: 'p0000000-0000-7000-8000-000000000001',
          personB: 'p0000000-0000-7000-8000-000000000002',
        ),
      );
    }

    Future<void> openDelete(WidgetTester tester, String name) async {
      await tester.drag(
        find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('the confirmation counts what will go', (tester) async {
      await seedHousehold();
      await pumpApp(tester);
      await openDelete(tester, 'Họ Nguyễn');

      expect(find.text('Delete Họ Nguyễn?'), findsOneWidget);
      expect(find.textContaining('2 people and 1 relationship'), findsOneWidget);
    });

    testWidgets('the name has to be typed back exactly', (tester) async {
      await seedHousehold();
      await pumpApp(tester);
      await openDelete(tester, 'Họ Nguyễn');

      final confirm = find.widgetWithText(FilledButton, 'Delete');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Họ Nguyên');
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(confirm).onPressed,
        isNull,
        reason: 'a missing diacritic is a different family name',
      );

      await tester.enterText(find.byType(TextField), 'Họ Nguyễn');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    });

    testWidgets('deleting takes the people and relationships with it', (
      tester,
    ) async {
      await seedHousehold();
      await repository.saveFamily(
        const domain.Family(
          id: 'f0000000-0000-7000-8000-000000000009',
          name: 'Họ Trần',
        ),
      );
      await pumpApp(tester);
      await openDelete(tester, 'Họ Nguyễn');

      await tester.enterText(find.byType(TextField), 'Họ Nguyễn');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Họ Nguyễn'), findsNothing);
      expect(find.text('Họ Trần'), findsOneWidget);
      expect(await repository.loadFamily(familyId), isNull);

      // Tombstoned, not erased: a row deleted outright leaves no record of the
      // deletion to synchronise (DOMAIN.md §15.2).
      final people = await db.select(db.persons).get();
      expect(people, hasLength(2));
      expect(people.every((p) => p.deletedAt != null), isTrue);
      expect((await db.select(db.relationships).get()).single.deletedAt,
          isNotNull);
    });

    testWidgets('an empty family is deleted without typing anything', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await pumpApp(tester);
      await openDelete(tester, 'Họ Nguyễn');

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('nobody in it'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Họ Nguyễn'), findsNothing);
      expect(await repository.loadFamily(familyId), isNull);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await seedHousehold();
      await pumpApp(tester);
      await openDelete(tester, 'Họ Nguyễn');

      await tester.enterText(find.byType(TextField), 'Họ Nguyễn');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Họ Nguyễn'), findsOneWidget);
      final snapshot = await repository.loadFamily(familyId);
      expect(snapshot!.graph.persons, hasLength(2));
    });
  });

  group('one palette, read twice', () {
    testWidgets('a family glyph carries the application colour', (
      tester,
    ) async {
      await repository.saveFamily(
        const domain.Family(
          id: 'f0000000-0000-7000-8000-000000000000',
          name: 'Họ Nguyễn',
        ),
      );
      await pumpApp(tester);

      final row = tester.widget<RowIcon>(find.byType(RowIcon).last);
      final scheme = Theme.of(
        tester.element(find.byType(RowIcon).last),
      ).colorScheme;

      // Not compared against a literal: the point is that the glyph and the
      // scheme are the same decision, so a new seed moves both together.
      expect(row.color, scheme.primary);
    });

    testWidgets('and so does a chosen chip, from the same seed', (
      tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: GroupedColors.seed),
          ),
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return Scaffold(
                body: GenerationFilter(
                  counts: const <int?, int>{1: 3, 2: 7},
                  chosen: 2,
                  onChosen: (_) {},
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chosen = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .firstWhere((chip) => chip.selected);

      expect(chosen.selectedColor, scheme.primary);
    });
  });
}
