import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/family_screen.dart';
import 'package:ftree/features/family/generation_filter.dart';
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
      // Scoped to the header: the đời chips carry counts of their own, and a
      // bare finder for the number cannot tell one badge from another.
      expect(
        find.descendant(
          of: find.byType(AvatarHeader),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

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

      expect(
        find.descendant(
          of: find.byType(AvatarHeader),
          matching: find.text('3'),
        ),
        findsOneWidget,
        reason: 'the header counts the family, not what is left of the list',
      );
      expect(find.text('Nguyễn Văn Cả'), findsOneWidget, reason: 'the match');
      expect(find.text('Trần Thị Mậu'), findsNothing);
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

      expect(find.text('1835 – ~1902'), findsOneWidget);
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

      expect(find.text('~1782 – 1851'), findsOneWidget);
    });

    testWidgets('is the birth year alone when no death is recorded', (
      tester,
    ) async {
      await seedPerson(
        1,
        'Nguyễn Văn Hải',
        birthDate: GenealogicalDate(year: 1978),
      );
      await openFamily(tester);

      // Not `1978–`, which claims the person is still living — a missing
      // death date is far more often a death nobody wrote down.
      expect(find.text('1978'), findsOneWidget);
    });

    testWidgets('is absent entirely when neither end is known', (tester) async {
      await seedPerson(1, 'Người Không Rõ');
      await openFamily(tester);

      expect(find.text('Người Không Rõ'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });
  });

  group('filtering by doi', () {
    String personId(int n) =>
        'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

    Future<void> link(int parent, int child) =>
        repository.saveRelationship(
          Relationship.parentChild(
            id: 'r0000000-0000-7000-8000-${parent.toString().padLeft(6, '0')}'
                '${child.toString().padLeft(6, '0')}',
            familyId: familyId,
            parent: personId(parent),
            child: personId(child),
          ),
        );

    /// A founder, two children, and one grandchild.
    Future<void> seedLine() async {
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Thuy To');
      await seedPerson(2, 'Con Ca');
      await seedPerson(3, 'Con Thu');
      await seedPerson(4, 'Chau');
      await link(1, 2);
      await link(1, 3);
      await link(2, 4);
    }

    testWidgets('shows a chip for each doi the family occupies', (
      tester,
    ) async {
      await seedLine();
      await openFamily(tester);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Generation 1'), findsOneWidget);
      expect(find.text('Generation 2'), findsOneWidget);
      expect(find.text('Generation 3'), findsOneWidget);
      expect(find.text('Generation 4'), findsNothing);
    });

    testWidgets('the All chip counts everybody, and the parts add up', (
      tester,
    ) async {
      await seedLine();
      await openFamily(tester);

      // Four people across three doi: one, two, one. The chips are a set of
      // parts and their whole, so a reader can check the one against the
      // others without counting rows.
      //
      // Scoped to the row, because the header carries a headcount of its own
      // and a bare finder for a number cannot tell the two apart.
      Finder inRow(String n) => find.descendant(
        of: find.byType(GenerationFilter),
        matching: find.text(n),
      );

      expect(inRow('4'), findsOneWidget);
      expect(inRow('2'), findsOneWidget);
      expect(inRow('1'), findsNWidgets(2));
    });

    testWidgets('brings the chosen doi to the middle of the row', (
      tester,
    ) async {
      // On a family of twelve the chip chosen can be off the right-hand end,
      // and a reader would see a shortened list with no sign of why. A phone,
      // because the default test window is wide enough to hold the whole row
      // and so never exercises this.
      tester.view.physicalSize = const Size(402, 756);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Doi 1');
      for (var n = 2; n <= 12; n++) {
        await seedPerson(n, 'Doi $n');
        await link(n - 1, n);
      }
      await openFamily(tester);

      final row = tester.getRect(find.byType(GenerationFilter));

      // Built but off the end — every chip is laid out, which is what makes
      // one reachable at all, but only some of them are on screen.
      expect(
        tester.getRect(find.text('Generation 9')).left,
        greaterThan(row.right),
        reason: 'the case tested: it starts beyond the right-hand edge',
      );

      final scroller = find
          .ancestor(
            of: find.byType(GenerationFilter),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(find.text('Generation 9'), 200,
          scrollable: scroller);
      await tester.tap(find.text('Generation 9'));
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.text('Generation 9')).center.dx,
        closeTo(row.center.dx, 40),
      );
    });

    testWidgets('the row stays under the bar once scrolled past', (
      tester,
    ) async {
      // On three hundred names a reader is deep in the list by the time they
      // know which đời they wanted, and a filter they must scroll back to the
      // top to reach is one they will not use.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Doi 1');
      for (var n = 2; n <= 30; n++) {
        await seedPerson(n, 'Nguoi $n');
        await link(1, n);
      }
      await openFamily(tester);

      expect(find.byType(AvatarHeader), findsOneWidget);
      final before = tester.getRect(find.byType(GenerationFilter));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(
        find.byType(AvatarHeader),
        findsNothing,
        reason: 'the portrait scrolls away, as it should',
      );
      expect(
        find.byType(GenerationFilter),
        findsOneWidget,
        reason: 'the row does not',
      );
      expect(
        tester.getRect(find.byType(GenerationFilter)).top,
        lessThan(before.top),
        reason: 'it rose with the list until it met the bar',
      );
    });

    testWidgets('choosing a doi keeps the place already scrolled to', (
      tester,
    ) async {
      // The shorter list clamps the scroll position, and without keeping it
      // the reader is put back at the top with the portrait in their face.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Doi 1');
      for (var n = 2; n <= 40; n++) {
        await seedPerson(n, 'Nguoi $n');
        await link(1, n);
      }
      await openFamily(tester);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarHeader), findsNothing, reason: 'scrolled past');

      await tester.tap(find.text('Generation 2'));
      await tester.pumpAndSettle();

      expect(
        find.byType(AvatarHeader),
        findsNothing,
        reason: 'still scrolled past it, not thrown back to the top',
      );
      expect(find.byType(GenerationFilter), findsOneWidget);
    });

    testWidgets('narrows the list to the doi chosen', (tester) async {
      await seedLine();
      await openFamily(tester);
      expect(find.text('Thuy To'), findsOneWidget);

      await tester.tap(find.text('Generation 2'));
      await tester.pumpAndSettle();

      expect(find.text('Con Ca'), findsOneWidget);
      expect(find.text('Con Thu'), findsOneWidget);
      expect(find.text('Thuy To'), findsNothing);
      expect(find.text('Chau'), findsNothing);
    });

    testWidgets('choosing the same doi again puts everybody back', (
      tester,
    ) async {
      await seedLine();
      await openFamily(tester);

      await tester.tap(find.text('Generation 2'));
      await tester.pumpAndSettle();
      expect(find.text('Thuy To'), findsNothing);

      await tester.tap(find.text('Generation 2'));
      await tester.pumpAndSettle();

      expect(find.text('Thuy To'), findsOneWidget);
    });

    testWidgets('doi and name narrow together', (tester) async {
      // Either alone may be hundreds of people in a real gia pha.
      await seedLine();
      await openFamily(tester);

      await tester.tap(find.text('Generation 2'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'ca');
      await tester.pumpAndSettle();

      expect(find.text('Con Ca'), findsOneWidget);
      expect(find.text('Con Thu'), findsNothing);
    });

    testWidgets('a family of one doi is offered no choice', (tester) async {
      // A row of a single chip is furniture.
      await repository.saveFamily(
        const domain.Family(id: familyId, name: 'Ho Nguyen'),
      );
      await seedPerson(1, 'Mot Nguoi');
      await openFamily(tester);

      expect(find.text('All'), findsNothing);
    });

    testWidgets('somebody outside the founder line is still reachable', (
      tester,
    ) async {
      // They belong to no doi in this family's counting, so every numbered
      // chip filters them out. Without one of their own they would be
      // findable by no chip at all.
      // Wide enough for every chip at once: what is being tested is that the
      // unnumbered have a chip of their own, not that the row scrolls.
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await seedLine();
      await seedPerson(9, 'Ngoai Toc');
      await openFamily(tester);

      await tester.tap(find.text('Generation unknown'));
      await tester.pumpAndSettle();

      expect(find.text('Ngoai Toc'), findsOneWidget);
      expect(find.text('Thuy To'), findsNothing);
    });
  });
}
