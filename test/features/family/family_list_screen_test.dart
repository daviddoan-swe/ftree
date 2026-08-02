import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/app.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
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
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Create family'));
    await tester.pumpAndSettle();
  }

  group('empty state', () {
    testWidgets('invites the first family to be created', (tester) async {
      await pumpApp(tester);

      expect(find.text('No families yet'), findsOneWidget);
      expect(
        find.widgetWithText(FloatingActionButton, 'Create family'),
        findsOneWidget,
      );
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
}
