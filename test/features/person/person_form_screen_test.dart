import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/app.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/features/person/partial_date_field.dart';
import 'package:ftree/domain/lunar/lunar_conversion.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  /// Boots the app, creates a family, and opens the person form.
  ///
  /// Everything below the widget is real, so what these tests check is that a
  /// domain rule survives the journey through the interface.
  Future<void> openPersonForm(
    WidgetTester tester, {
    bool lunar = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const FtreeApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create family'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Family name'),
      'Họ Nguyễn',
    );
    if (lunar) {
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Họ Nguyễn'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
  }

  Future<void> typeDate(
    WidgetTester tester, {
    required String section,
    String? year,
    String? month,
    String? day,
  }) async {
    // The form is longer than the screen and a ListView only builds what is
    // visible, so the section has to be scrolled to before it can be typed in.
    await tester.scrollUntilVisible(
      find.text(section),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // By position, not by walking up from the label: the death section's
    // title now sits on the switch that reveals it, in a different subtree
    // from the boxes themselves. Birth is the first date field on the form and
    // death, once revealed, the second.
    final fields = find.byType(PartialDateField);
    final field = section == 'Died' ? fields.last : fields.first;
    Finder box(String label) => find.descendant(
      of: field,
      matching: find.widgetWithText(TextField, label),
    );

    if (year != null) await tester.enterText(box('Year'), year);
    if (month != null) await tester.enterText(box('Month'), month);
    if (day != null) await tester.enterText(box('Day'), day);
    await tester.pumpAndSettle();
  }

  /// Reveals the death fields, which start folded away.
  Future<void> markAsDied(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Died'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('adding a person', () {
    testWidgets('a display name alone is enough', (tester) async {
      await openPersonForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Tổ',
      );
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.single.displayName, 'Cụ Tổ');
      expect(rows.single.birthDateIso, isNull);
    });

    testWidgets('a blank display name blocks the save', (tester) async {
      await openPersonForm(tester);
      await save(tester);

      expect(find.text('Cannot save'), findsOneWidget);
      expect(await db.select(db.persons).get(), isEmpty);
    });
  });

  group('partial dates', () {
    testWidgets('a year on its own is stored as a year', (tester) async {
      // The loss §4.2 exists to prevent: forcing a full date would turn this
      // into an invented 1 January that nothing could later undo.
      await openPersonForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Bảy',
      );
      await typeDate(tester, section: 'Born', year: '1887');
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.single.birthDateIso, '1887');
    });

    testWidgets('a full date keeps its day', (tester) async {
      await openPersonForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Bảy',
      );
      await typeDate(
        tester,
        section: 'Born',
        year: '1887',
        month: '3',
        day: '15',
      );
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.single.birthDateIso, '1887-03-15');
    });

    testWidgets('an impossible date is refused and nothing is written',
        (tester) async {
      await openPersonForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Bảy',
      );
      await typeDate(
        tester,
        section: 'Born',
        year: '1887',
        month: '2',
        day: '30',
      );

      expect(find.text('No such date'), findsOneWidget);

      await save(tester);
      expect(await db.select(db.persons).get(), isEmpty);
    });

    testWidgets('a day without a month is refused', (tester) async {
      await openPersonForm(tester);
      await typeDate(tester, section: 'Born', year: '1887', day: '15');

      expect(find.text('A day needs a month'), findsOneWidget);
    });
  });

  group('the death switch', () {
    Future<void> nameThem(WidgetTester tester) => tester.enterText(
      find.widgetWithText(TextField, 'Display name'),
      'Cụ Bảy',
    );

    testWidgets('starts off, with the death fields folded away', (
      tester,
    ) async {
      // Most people in a gia phả are dead; most records carry no death date.
      // Starting folded keeps the form short for the common case.
      await openPersonForm(tester);
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        120,
        scrollable: find.byType(Scrollable).first,
      );

      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);
      // Right beside the switch, so if the section were open this would be
      // built and on screen.
      expect(find.widgetWithText(TextField, 'Place of death'), findsNothing);
    });

    testWidgets('turning it on reveals the date and the place', (tester) async {
      await openPersonForm(tester);
      await markAsDied(tester);

      expect(find.byType(PartialDateField), findsNWidgets(2));
      expect(
        find.widgetWithText(TextField, 'Place of death'),
        findsOneWidget,
      );
    });

    testWidgets('on with nothing recorded is refused', (tester) async {
      // The domain reads a death off the fields themselves, so a claim with
      // nothing behind it would simply vanish on save.
      await openPersonForm(tester);
      await nameThem(tester);
      await markAsDied(tester);
      await save(tester);

      // The banner sits at the head of the form, which is off screen by now.
      await tester.scrollUntilVisible(
        find.text('Cannot save'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('A date or a place of death is needed'),
        findsOneWidget,
      );
      expect(await db.select(db.persons).get(), isEmpty);
    });

    testWidgets('a place of death alone is enough', (tester) async {
      await openPersonForm(tester);
      await nameThem(tester);
      await markAsDied(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Place of death'),
        'Phù Ninh',
      );
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.single.deathPlace, 'Phù Ninh');
      expect(rows.single.deathDateIso, isNull);
    });

    testWidgets('switching it off discards what was typed', (tester) async {
      await openPersonForm(tester);
      await nameThem(tester);
      await markAsDied(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Place of death'),
        'Phù Ninh',
      );
      await markAsDied(tester);
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.single.deathPlace, isNull);
      expect(rows.single.deathDateIso, isNull);
    });

    testWidgets('opens on for somebody already recorded as dead', (
      tester,
    ) async {
      await openPersonForm(tester);
      await nameThem(tester);
      await markAsDied(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Place of death'),
        'Phù Ninh',
      );
      await save(tester);

      await tester.tap(find.text('Cụ Bảy'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      // A place and no date still means dead, so the section opens.
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue);
      expect(
        find.widgetWithText(TextField, 'Place of death'),
        findsOneWidget,
      );
    });
  });

  group('warnings are the user’s to overrule', () {
    Future<void> enterContradictoryDates(WidgetTester tester) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Bảy',
      );
      await typeDate(
        tester,
        section: 'Born',
        year: '1900',
        month: '1',
        day: '1',
      );
      await markAsDied(tester);
      await typeDate(
        tester,
        section: 'Died',
        year: '1890',
        month: '1',
        day: '1',
      );
    }

    testWidgets('a death before a birth asks rather than refuses',
        (tester) async {
      await openPersonForm(tester);
      await enterContradictoryDates(tester);
      await save(tester);

      expect(find.text('Worth checking'), findsOneWidget);
      expect(find.textContaining('Died before being born'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save anyway'), findsOneWidget);
    });

    testWidgets('saving anyway writes the record', (tester) async {
      // Real records contain entries like this. Refusing them would make the
      // application unusable on genuine documents (DOMAIN.md §9).
      await openPersonForm(tester);
      await enterContradictoryDates(tester);
      await save(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save anyway'));
      await tester.pumpAndSettle();

      final rows = await db.select(db.persons).get();
      expect(rows.single.birthDateIso, '1900-01-01');
      expect(rows.single.deathDateIso, '1890-01-01');
    });

    testWidgets('choosing to review writes nothing', (tester) async {
      await openPersonForm(tester);
      await enterContradictoryDates(tester);
      await save(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Review'));
      await tester.pumpAndSettle();

      expect(await db.select(db.persons).get(), isEmpty);
    });
  });

  group('the lunar calendar', () {
    testWidgets('is not offered to a family that does not use it',
        (tester) async {
      await openPersonForm(tester);
      expect(find.text('Lunar'), findsNothing);
    });

    testWidgets('is offered to a family that does', (tester) async {
      await openPersonForm(tester, lunar: true);
      expect(find.text('Lunar'), findsWidgets);
    });

    testWidgets('a lunar date is converted and both readings are stored',
        (tester) async {
      await openPersonForm(tester, lunar: true);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Cụ Bảy',
      );

      // Switch the birth field to lunar, then type a lunar date.
      final bornSection = find
          .ancestor(of: find.text('Born'), matching: find.byType(Column))
          .first;
      await tester.tap(
        find.descendant(of: bornSection, matching: find.text('Lunar')),
      );
      await tester.pumpAndSettle();

      await typeDate(
        tester,
        section: 'Born',
        year: '1960',
        month: '3',
        day: '12',
      );
      await save(tester);

      final row = (await db.select(db.persons).get()).single;

      // The lunar reading is kept exactly as typed.
      expect(row.birthLunarYear, 1960);
      expect(row.birthLunarMonth, 3);
      expect(row.birthLunarDay, 12);

      // And the Gregorian value really is that lunar day.
      final expected = lunarToSolar(12, 3, 1960);
      expect(
        row.birthDateIso,
        '${expected.$3}-'
        '${expected.$2.toString().padLeft(2, '0')}-'
        '${expected.$1.toString().padLeft(2, '0')}',
      );
    });
  });

  group('editing', () {
    testWidgets('changes the person rather than adding another',
        (tester) async {
      await openPersonForm(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'Old name',
      );
      await save(tester);

      // Through the profile: the list opens what a person is, and editing is
      // one tap further in.
      await tester.tap(find.text('Old name'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Display name'),
        'New name',
      );
      await save(tester);

      final rows = await db.select(db.persons).get();
      expect(rows.length, 1);
      expect(rows.single.displayName, 'New name');
    });
  });
}
