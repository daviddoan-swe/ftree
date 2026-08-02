import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/person/person_profile_screen.dart';
import 'package:ftree/l10n/app_localizations.dart';

/// Everything below the widget is real, so what these check is that a
/// relationship rule survives the journey through the interface.
void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;

  const familyId = 'f0000000-0000-7000-8000-000000000000';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  Future<void> seedPerson(
    int n,
    String name, {
    GenealogicalDate? birthDate,
  }) => repository.savePerson(
    Person(
      id: personId(n),
      familyId: familyId,
      displayName: name,
      birthDate: birthDate,
    ),
  );

  Future<void> seed() async {
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    await seedPerson(1, 'Ông A');
    await seedPerson(2, 'Bà B');
  }

  Future<void> openProfile(WidgetTester tester, int n) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: PersonProfileScreen(
            familyId: familyId,
            personId: personId(n),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Runs the whole flow: the button, the role, and the person.
  Future<void> addRelative(
    WidgetTester tester, {
    required String role,
    required String name,
  }) async {
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add relationship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(role));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<List<RelationshipRow>> storedRelationships() =>
      (db.select(db.relationships)..where((r) => r.deletedAt.isNull())).get();

  group('adding', () {
    testWidgets('a parent points from the person picked to the subject', (
      tester,
    ) async {
      await seed();
      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      final stored = await storedRelationships();
      expect(stored.length, 1);
      expect(stored.single.type, RelationshipType.parentChild);
      expect(stored.single.personAId, personId(2));
      expect(stored.single.personBId, personId(1));

      expect(find.text('Parents'), findsOneWidget);
    });

    testWidgets('a child points the other way from the same screen', (
      tester,
    ) async {
      await seed();
      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a child', name: 'Bà B');

      final stored = await storedRelationships();
      expect(stored.single.personAId, personId(1));
      expect(stored.single.personBId, personId(2));
      expect(find.text('Children'), findsOneWidget);
    });

    testWidgets('a spouse is stored in canonical id order', (tester) async {
      await seed();
      // Opened on the person with the higher id, so a naive implementation
      // storing subject-then-other would get the order wrong (DOMAIN.md §5.1).
      await openProfile(tester, 2);
      await addRelative(tester, role: 'Add a spouse', name: 'Ông A');

      final stored = await storedRelationships();
      expect(stored.single.type, RelationshipType.spouse);
      expect(stored.single.personAId, personId(1));
      expect(stored.single.personBId, personId(2));
    });

    testWidgets('the subject is not offered as their own relative', (
      tester,
    ) async {
      await seed();
      await openProfile(tester, 1);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add relationship'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a parent'));
      await tester.pumpAndSettle();

      expect(find.text('Bà B'), findsOneWidget);
      expect(find.text('Ông A'), findsNothing);
    });

    testWidgets('the list can be narrowed by name', (tester) async {
      await seed();
      await seedPerson(3, 'Cụ C');
      await openProfile(tester, 1);
      await tester.tap(
        find.widgetWithText(FloatingActionButton, 'Add relationship'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a parent'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Cụ');
      await tester.pumpAndSettle();

      expect(find.text('Cụ C'), findsOneWidget);
      expect(find.text('Bà B'), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('refuses a link that would close an ancestry loop', (
      tester,
    ) async {
      await seed();
      await repository.saveRelationship(
        Relationship.parentChild(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          parent: personId(1),
          child: personId(2),
        ),
      );

      await openProfile(tester, 1);
      // A's child is B, so making B A's parent would make A their own ancestor.
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      expect(
        find.textContaining('This would make someone their own ancestor'),
        findsOneWidget,
      );
      expect((await storedRelationships()).length, 1);
    });

    testWidgets('refuses a duplicate of an existing link', (tester) async {
      await seed();
      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      expect(
        find.textContaining('This relationship already exists'),
        findsOneWidget,
      );
      expect((await storedRelationships()).length, 1);
    });

    testWidgets('lets the user overrule a warning', (tester) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Ông A', birthDate: GenealogicalDate(year: 1800));
      // Recorded as born a century after the child. Implausible but the kind of
      // thing a real gia phả contains, so it must be possible to record it.
      await seedPerson(2, 'Bà B', birthDate: GenealogicalDate(year: 1900));

      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      expect(find.text('Save anyway'), findsOneWidget);
      await tester.tap(find.text('Save anyway'));
      await tester.pumpAndSettle();

      expect((await storedRelationships()).length, 1);
    });

    testWidgets('a warning declined leaves nothing behind', (tester) async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Ông A', birthDate: GenealogicalDate(year: 1800));
      await seedPerson(2, 'Bà B', birthDate: GenealogicalDate(year: 1900));

      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      expect(await storedRelationships(), isEmpty);
    });
  });

  group('removing', () {
    testWidgets('unmakes the link and keeps both people', (tester) async {
      await seed();
      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(await storedRelationships(), isEmpty);
      expect(find.text('Not connected to anybody yet'), findsOneWidget);

      final people = await (db.select(
        db.persons,
      )..where((p) => p.deletedAt.isNull())).get();
      expect(people.length, 2);
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await seed();
      await openProfile(tester, 1);
      await addRelative(tester, role: 'Add a parent', name: 'Bà B');

      await tester.tap(find.byIcon(Icons.link_off));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect((await storedRelationships()).length, 1);
    });

    testWidgets('is not offered for a sibling, which is not an edge', (
      tester,
    ) async {
      await seed();
      await seedPerson(3, 'Con C');
      await seedPerson(4, 'Con D');
      for (final (index, child) in <int>[3, 4].indexed) {
        await repository.saveRelationship(
          Relationship.parentChild(
            id: 'r0000000-0000-7000-8000-00000000000$index',
            familyId: familyId,
            parent: personId(1),
            child: personId(child),
          ),
        );
      }

      await openProfile(tester, 3);

      expect(find.text('Siblings'), findsOneWidget);
      expect(find.text('Con D'), findsOneWidget);
      // One unlink button: the parent. The sibling row has none.
      expect(find.byIcon(Icons.link_off), findsOneWidget);
    });
  });
}
