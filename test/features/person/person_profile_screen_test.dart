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

  Future<void> seedFamily({bool lunar = false}) => repository.saveFamily(
    domain.Family(
      id: familyId,
      name: 'Họ Nguyễn',
      usesLunarCalendar: lunar,
    ),
  );

  Future<Person> seedPerson(
    int n,
    String name, {
    GenealogicalDate? birthDate,
    GenealogicalDate? deathDate,
    String? birthPlace,
  }) async {
    final person = Person(
      id: personId(n),
      familyId: familyId,
      displayName: name,
      birthDate: birthDate,
      deathDate: deathDate,
      birthPlace: birthPlace,
    );
    await repository.savePerson(person);
    return person;
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

  testWidgets('shows what is recorded and leaves out what is not', (
    tester,
  ) async {
    await seedFamily();
    await seedPerson(
      1,
      'Nguyễn Văn A',
      birthDate: GenealogicalDate(year: 1887),
      birthPlace: 'Nam Định',
    );
    await openProfile(tester, 1);

    expect(find.text('Nguyễn Văn A'), findsWidgets);
    expect(find.text('1887'), findsOneWidget);
    expect(find.text('Nam Định'), findsOneWidget);

    // No death date was recorded, so there is no empty row claiming one.
    expect(find.text('Died'), findsNothing);
    expect(find.text('Place of death'), findsNothing);
  });

  testWidgets('names a recorded sex but stays quiet about an unknown one', (
    tester,
  ) async {
    await seedFamily();
    await repository.savePerson(
      Person(
        id: personId(1),
        familyId: familyId,
        displayName: 'Nguyễn Văn A',
        sex: Sex.male,
      ),
    );
    await seedPerson(2, 'Người Không Rõ');

    await openProfile(tester, 1);
    expect(find.text('Male'), findsOneWidget);

    await openProfile(tester, 2);
    expect(find.text('Sex'), findsNothing);
  });

  testWidgets('shows a year-only date as a year, not an invented January', (
    tester,
  ) async {
    await seedFamily();
    await seedPerson(1, 'Nguyễn Văn A', birthDate: GenealogicalDate(year: 1887));
    await openProfile(tester, 1);

    expect(find.text('1887'), findsOneWidget);
    expect(find.textContaining('1887-01'), findsNothing);
  });

  testWidgets('marks an approximate date as approximate', (tester) async {
    await seedFamily();
    await seedPerson(
      1,
      'Nguyễn Văn A',
      birthDate: GenealogicalDate(year: 1887, isApproximate: true),
    );
    await openProfile(tester, 1);

    expect(find.text('about 1887'), findsOneWidget);
  });

  group('the lunar reading', () {
    testWidgets('appears beside a full date when the family keeps one', (
      tester,
    ) async {
      await seedFamily(lunar: true);
      // 5 April 1960 is 10-3 in the lunar calendar.
      await seedPerson(
        1,
        'Nguyễn Văn A',
        birthDate: GenealogicalDate(year: 1960, month: 4, day: 5),
      );
      await openProfile(tester, 1);

      expect(find.text('1960-04-05'), findsOneWidget);
      expect(find.text('1960-03-10 lunar'), findsOneWidget);
    });

    testWidgets('stays away when the family does not keep one', (tester) async {
      await seedFamily();
      await seedPerson(
        1,
        'Nguyễn Văn A',
        birthDate: GenealogicalDate(year: 1960, month: 4, day: 5),
      );
      await openProfile(tester, 1);

      expect(find.text('1960-04-05'), findsOneWidget);
      expect(find.textContaining('lunar'), findsNothing);
    });

    testWidgets('is absent for a year-only date, which has none', (
      tester,
    ) async {
      await seedFamily(lunar: true);
      await seedPerson(
        1,
        'Nguyễn Văn A',
        birthDate: GenealogicalDate(year: 1887),
      );
      await openProfile(tester, 1);

      expect(find.textContaining('lunar'), findsNothing);
    });
  });

  group('relatives', () {
    /// A father, a mother, their two children, and the father's spouse edge.
    Future<void> seedHousehold() async {
      await seedFamily();
      await seedPerson(1, 'Cha');
      await seedPerson(2, 'Mẹ');
      await seedPerson(3, 'Con Cả');
      await seedPerson(4, 'Con Thứ');

      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
      for (final (index, child) in <int>[3, 4].indexed) {
        for (final parent in <int>[1, 2]) {
          await repository.saveRelationship(
            Relationship.parentChild(
              id: 'r0000000-0000-7000-8000-1$index${parent}0000000',
              familyId: familyId,
              parent: personId(parent),
              child: personId(child),
            ),
          );
        }
      }
    }

    testWidgets('says so plainly when there are none', (tester) async {
      await seedFamily();
      await seedPerson(1, 'Nguyễn Văn A');
      await openProfile(tester, 1);

      expect(find.text('Not connected to anybody yet'), findsOneWidget);
      expect(find.text('Parents'), findsNothing);
    });

    testWidgets('lists each kind under its own heading', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);

      expect(find.text('Parents'), findsOneWidget);
      expect(find.text('Cha'), findsOneWidget);
      expect(find.text('Mẹ'), findsOneWidget);
      expect(find.text('Siblings'), findsOneWidget);
      expect(find.text('Con Thứ'), findsOneWidget);
      expect(find.text('Not connected to anybody yet'), findsNothing);
    });

    testWidgets('reports how many parents a sibling shares', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);

      expect(find.text('2 parents in common'), findsOneWidget);
    });

    testWidgets('navigates through to a relative', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);

      await tester.tap(find.text('Cha'));
      await tester.pumpAndSettle();

      // The father's own profile: his children, not his parents.
      expect(find.text('Children'), findsOneWidget);
      expect(find.text('Con Cả'), findsOneWidget);
      expect(find.text('Spouses'), findsOneWidget);
    });
  });

  testWidgets('shows nothing rather than crashing for an absent person', (
    tester,
  ) async {
    await seedFamily();
    await openProfile(tester, 9);

    expect(find.byType(PersonProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
