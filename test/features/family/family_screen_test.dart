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
import 'package:ftree/features/family/family_screen.dart';
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

  Future<void> seedPerson(
    int n,
    String name, {
    GenealogicalDate? birthDate,
    GenealogicalDate? deathDate,
  }) => repository.savePerson(
    Person(
      id: 'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}',
      familyId: familyId,
      displayName: name,
      birthDate: birthDate,
      deathDate: deathDate,
    ),
  );

  Future<void> openFamily(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: const FamilyScreen(familyId: familyId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('builds only the rows on screen', (tester) async {
    // A gia phả runs to thousands of people. Laying every row out to show
    // eight of them is work nobody asked for, and it is paid on every rebuild
    // — including every keystroke in the search field.
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    for (var n = 1; n <= 60; n++) {
      await seedPerson(n, 'Người $n');
    }
    await openFamily(tester);

    final built = tester.widgetList(find.byType(ListTile)).length;
    expect(built, greaterThan(3), reason: 'the visible rows are there');
    expect(built, lessThan(60), reason: 'the other fifty are not');
  });

  group('searching by name', () {
    setUp(() async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      );
      await seedPerson(1, 'Nguyễn Văn Cả');
      await seedPerson(2, 'Trần Thị Mậu');
      await seedPerson(3, 'Lê Thị Hoà');
    });

    Future<void> type(WidgetTester tester, String query) async {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
    }

    testWidgets('everybody is listed before anything is typed', (tester) async {
      await openFamily(tester);

      expect(find.text('Nguyễn Văn Cả'), findsOneWidget);
      expect(find.text('Trần Thị Mậu'), findsOneWidget);
      expect(find.text('Lê Thị Hoà'), findsOneWidget);
    });

    testWidgets('a single letter narrows the list', (tester) async {
      await openFamily(tester);
      await type(tester, 'T');

      expect(find.text('Trần Thị Mậu'), findsOneWidget);
      expect(find.text('Lê Thị Hoà'), findsOneWidget, reason: 'Thị');
      expect(find.text('Nguyễn Văn Cả'), findsNothing);
    });

    testWidgets('finds a name typed without its tone marks', (tester) async {
      // PRODUCT.md §1.1: half the family will type from a phone keyboard
      // without the marks, and "no results" for a name plainly there reads as
      // the application being broken.
      await openFamily(tester);
      await type(tester, 'nguyen');

      expect(find.text('Nguyễn Văn Cả'), findsOneWidget);
      expect(find.text('Trần Thị Mậu'), findsNothing);
    });

    testWidgets('clearing the field puts everybody back', (tester) async {
      await openFamily(tester);
      await type(tester, 'nguyen');
      expect(find.text('Trần Thị Mậu'), findsNothing);

      await type(tester, '');

      expect(find.text('Nguyễn Văn Cả'), findsOneWidget);
      expect(find.text('Trần Thị Mậu'), findsOneWidget);
      expect(find.text('Lê Thị Hoà'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await openFamily(tester);
      await type(tester, 'zzz');

      expect(find.text('No name matches'), findsOneWidget);
      expect(find.text('Nguyễn Văn Cả'), findsNothing);
    });
  });

  group('the family header', () {
    setUp(
      () => repository.saveFamily(
        const domain.Family(
          id: familyId,
          name: 'Họ Nguyễn',
          description: 'Gia phả tám đời',
        ),
      ),
    );

    testWidgets('is an initial and a headcount, nothing repeated', (
      tester,
    ) async {
      await seedPerson(1, 'Nguyễn Văn Cả');
      await seedPerson(2, 'Trần Thị Mậu');
      await openFamily(tester);

      // "Họ Nguyễn" is N, not H: the leading word means "the family of" and
      // carries no identity.
      expect(find.text('N'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // The bar above already carries the name, and the notes were read on the
      // way in from the list.
      expect(find.text('Họ Nguyễn'), findsOneWidget, reason: 'the app bar');
      expect(find.text('Gia phả tám đời'), findsNothing);
    });

    testWidgets('the headcount is the family, not the filtered list', (
      tester,
    ) async {
      await seedPerson(1, 'Nguyễn Văn Cả');
      await seedPerson(2, 'Trần Thị Mậu');
      await seedPerson(3, 'Lê Thị Hoà');
      await openFamily(tester);

      await tester.enterText(find.byType(TextField), 'nguyen');
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget, reason: 'still three people');
      expect(find.text('1 person'), findsOneWidget, reason: 'one match');
    });
  });

  group('the lifespan under each name', () {
    setUp(
      () => repository.saveFamily(
        const domain.Family(id: familyId, name: 'Họ Nguyễn'),
      ),
    );

    testWidgets('is years only, whatever precision was recorded', (
      tester,
    ) async {
      // Found by looking at the screen: a year at one end and a month at the
      // other rendered as `1835–~1902-04`, which reads like two different
      // kinds of thing rather than a span.
      await seedPerson(
        1,
        'Nguyễn Văn Khiêm',
        birthDate: GenealogicalDate(year: 1835),
        deathDate: GenealogicalDate(year: 1902, month: 4, isApproximate: true),
      );
      await openFamily(tester);

      expect(find.text('1835–~1902'), findsOneWidget);
      expect(find.textContaining('1902-04'), findsNothing);
    });

    testWidgets('keeps "about" rather than presenting a guess as a fact', (
      tester,
    ) async {
      await seedPerson(
        1,
        'Nguyễn Phúc Thịnh',
        birthDate: GenealogicalDate(year: 1782, isApproximate: true),
        deathDate: GenealogicalDate(year: 1851),
      );
      await openFamily(tester);

      expect(find.text('~1782–1851'), findsOneWidget);
    });

    testWidgets('leaves the end that is unrecorded empty', (tester) async {
      await seedPerson(
        1,
        'Nguyễn Văn Hải',
        birthDate: GenealogicalDate(year: 1978),
      );
      await openFamily(tester);

      expect(find.text('1978–'), findsOneWidget);
    });

    testWidgets('is absent entirely when neither end is known', (tester) async {
      await seedPerson(1, 'Người Không Rõ');
      await openFamily(tester);

      expect(find.text('Người Không Rõ'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });
  });
}
