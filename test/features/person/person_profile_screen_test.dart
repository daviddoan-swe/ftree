import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/features/tree/tree_screen.dart';
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
    domain.Family(id: familyId, name: 'Họ Nguyễn', usesLunarCalendar: lunar),
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
          home: PersonProfileScreen(familyId: familyId, personId: personId(n)),
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

  testWidgets('shows sex as a glyph on the portrait, not as a row', (
    tester,
  ) async {
    // One of three states does not need a label and a value; and `unknown` is
    // a recorded answer rather than a blank (DOMAIN.md §3.2), so it gets a
    // glyph too instead of quietly vanishing.
    await seedFamily();
    await repository.savePerson(
      Person(
        id: personId(1),
        familyId: familyId,
        displayName: 'Nguyễn Văn A',
        sex: Sex.male,
      ),
    );
    await repository.savePerson(
      Person(
        id: personId(2),
        familyId: familyId,
        displayName: 'Nguyễn Thị B',
        sex: Sex.female,
      ),
    );
    await seedPerson(3, 'Người Không Rõ');

    await openProfile(tester, 1);
    expect(find.byIcon(Icons.man), findsOneWidget);
    expect(find.text('Sex'), findsNothing);
    expect(find.text('Male'), findsNothing);

    await openProfile(tester, 2);
    expect(find.byIcon(Icons.woman), findsOneWidget);

    // The same figure the family list uses, so one person is not drawn two
    // ways on two screens.
    await openProfile(tester, 3);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  group('the age under the portrait', () {
    testWidgets('is the life span when the person died', (tester) async {
      await seedFamily();
      await seedPerson(
        1,
        'Nguyễn Văn A',
        birthDate: GenealogicalDate(year: 1808),
        deathDate: GenealogicalDate(year: 1874),
      );
      await openProfile(tester, 1);

      expect(find.text('66 years old'), findsOneWidget);
    });

    testWidgets('is absent when there is no birth to count from', (
      tester,
    ) async {
      await seedFamily();
      await seedPerson(
        1,
        'Nguyễn Văn A',
        deathDate: GenealogicalDate(year: 1874),
      );
      await openProfile(tester, 1);

      expect(find.textContaining('years old'), findsNothing);
    });

    testWidgets('is absent when it would be an impossible age today', (
      tester,
    ) async {
      // No death date does not mean living (ARCHITECTURE §11.1). Somebody born
      // in 1782 is not two hundred and something; nothing is better.
      await seedFamily();
      await seedPerson(1, 'Cụ Tổ', birthDate: GenealogicalDate(year: 1782));
      await openProfile(tester, 1);

      expect(find.textContaining('years old'), findsNothing);
    });
  });

  group('somebody who has died', () {
    testWidgets('is drawn back in grey, on the portrait and in a list', (
      tester,
    ) async {
      await seedFamily();
      await seedPerson(
        1,
        'Người Đã Mất',
        birthDate: GenealogicalDate(year: 1912),
        deathDate: GenealogicalDate(year: 1988),
      );
      await openProfile(tester, 1);

      final avatar = tester.widget<AvatarHeader>(find.byType(AvatarHeader));
      expect(avatar.color, GroupedColors.grey);
    });

    testWidgets('a living person keeps the colour of their sex', (
      tester,
    ) async {
      await seedFamily();
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Người Còn Sống',
          sex: Sex.female,
          birthDate: GenealogicalDate(year: 1982),
        ),
      );
      await openProfile(tester, 1);

      final avatar = tester.widget<AvatarHeader>(find.byType(AvatarHeader));
      expect(avatar.color, GroupedColors.pink);
    });
  });

  testWidgets('shows a year-only date as a year, not an invented January', (
    tester,
  ) async {
    await seedFamily();
    await seedPerson(
      1,
      'Nguyễn Văn A',
      birthDate: GenealogicalDate(year: 1887),
    );
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

  group('deleting a person', () {
    /// A father, a mother, and their child.
    Future<void> seedHousehold() async {
      await seedFamily();
      await seedPerson(1, 'Cha');
      await seedPerson(2, 'Mẹ');
      await seedPerson(3, 'Con');

      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
      for (final parent in <int>[1, 2]) {
        await repository.saveRelationship(
          Relationship.parentChild(
            id:
                'r0000000-0000-7000-8000-00000000000$parent'
                '0',
            familyId: familyId,
            parent: personId(parent),
            child: personId(3),
          ),
        );
      }
    }

    /// Reaches the button, which is deliberately below everything recorded.
    Future<void> tapDelete(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Delete this person'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete this person'));
      await tester.pumpAndSettle();
    }

    testWidgets('says how many relationships go with them', (tester) async {
      await seedHousehold();
      await openProfile(tester, 1);
      await tapDelete(tester);

      expect(find.text('Delete Cha?'), findsOneWidget);
      expect(
        find.textContaining('Removes 2 relationships as well'),
        findsOneWidget,
      );
    });

    testWidgets('tombstones the row rather than erasing it', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);
      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // The row survives, carrying its tombstone: a row erased outright leaves
      // no record of the deletion to synchronise (DOMAIN.md §15.2).
      final rows = await db.select(db.persons).get();
      expect(rows.length, 3);
      expect(rows.singleWhere((r) => r.id == personId(3)).deletedAt, isNotNull);

      final snapshot = await repository.loadFamily(familyId);
      expect(snapshot!.graph.personById(personId(3)), isNull);
    });

    testWidgets('takes their relationships with them', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);
      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // Nobody is left holding an edge to somebody who is gone.
      final snapshot = await repository.loadFamily(familyId);
      expect(snapshot!.graph.children(personId(1)), isEmpty);
      expect(snapshot.graph.relationships.length, 1, reason: 'the marriage');
    });

    testWidgets('cancelling changes nothing', (tester) async {
      await seedHousehold();
      await openProfile(tester, 3);
      await tapDelete(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final snapshot = await repository.loadFamily(familyId);
      expect(snapshot!.graph.persons.length, 3);
      expect(snapshot.graph.relationships.length, 3);
    });

    testWidgets('does not pop away the only page there is', (tester) async {
      // Found the hard way, from a preview harness that opened a profile as
      // the root route: the delete worked, the pop emptied the navigator, and
      // a blank window reads exactly like a crash.
      await seedHousehold();
      await openProfile(tester, 3);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(PersonProfileScreen),
        findsOneWidget,
        reason: 'still something on screen',
      );
      // The person really did go, even though the screen stayed.
      expect(
        (await repository.loadFamily(familyId))!.graph.persons,
        hasLength(2),
      );
    });

    testWidgets('leaves the profile once the person is gone', (tester) async {
      await seedHousehold();
      // Pushed onto a route, so there is somewhere to go back to.
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPersonProfile(
                    context,
                    familyId: familyId,
                    personId: personId(3),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(PersonProfileScreen), findsOneWidget);

      await tapDelete(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(PersonProfileScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
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

  group('the chart from this person', () {
    Future<void> link(int parent, int child) => repository.saveRelationship(
      Relationship.parentChild(
        id:
            'r0000000-0000-7000-8000-${parent.toString().padLeft(6, '0')}'
            '${child.toString().padLeft(6, '0')}',
        familyId: familyId,
        parent: personId(parent),
        child: personId(child),
      ),
    );

    Future<void> seedLine() async {
      await seedFamily();
      await seedPerson(1, 'Thuy To');
      await seedPerson(2, 'Con Ca');
      await seedPerson(3, 'Chau Dich');
      await link(1, 2);
      await link(2, 3);
    }

    testWidgets('is offered from the corner, as the family list offers it', (
      tester,
    ) async {
      await seedLine();
      await openProfile(tester, 2);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.account_tree_rounded), findsOneWidget);
    });

    testWidgets('starts from this person, not from the thuy to', (
      tester,
    ) async {
      // Standing on somebody's page the question is what came of them, not
      // what the whole family looks like.
      await seedLine();
      await openProfile(tester, 2);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final layout =
          (tester
                      .widget<CustomPaint>(
                        find.byWidgetPredicate(
                          (w) => w is CustomPaint && w.painter is TreePainter,
                        ),
                      )
                      .painter!
                  as TreePainter)
              .layout;

      expect(layout.nodeFor(personId(2)), isNotNull);
      expect(layout.nodeFor(personId(3)), isNotNull, reason: 'his descendant');
      expect(
        layout.nodeFor(personId(1)),
        isNull,
        reason: 'his father is above the root, so the chart drops him',
      );
    });

    testWidgets('still counts doi from the thuy to', (tester) async {
      // The chart starts here; the numbering does not. Doi thu hai is a fact
      // about this person, not about where the drawing happens to begin.
      await seedLine();
      await openProfile(tester, 2);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Gen 2'), findsOneWidget);
      expect(find.text('Gen 1'), findsNothing);
    });
  });

  group('what a role is offered on a profile', () {
    testWidgets('a copy nobody else has a claim on shows everything', (
      tester,
    ) async {
      await seedFamily();
      await seedPerson(1, 'Cụ Tổ');
      await openProfile(tester, 1);

      expect(find.text('Edit person'), findsOneWidget);
      expect(find.text('Delete this person'), findsOneWidget);
    });

    testWidgets('an editor keeps them', (tester) async {
      // persons_insert and persons_update both take owner or editor, and
      // deleting is soft, so it is an update and an editor may do it.
      await seedFamily();
      await seedPerson(1, 'Cụ Tổ');
      await FamilyRoles(db).remember(familyId, FamilyRole.editor);

      await openProfile(tester, 1);

      expect(find.text('Edit person'), findsOneWidget);
      expect(find.text('Delete this person'), findsOneWidget);
    });

    testWidgets('a viewer is offered neither, nor a way to add a relative', (
      tester,
    ) async {
      // Every one of these is refused by a policy, so offering it would be
      // offering work that cannot land (PRODUCT §5.0).
      await seedFamily();
      await seedPerson(1, 'Cụ Tổ');
      await FamilyRoles(db).remember(familyId, FamilyRole.viewer);

      await openProfile(tester, 1);

      expect(find.text('Edit person'), findsNothing);
      expect(find.text('Delete this person'), findsNothing);
      expect(find.byTooltip('Add a relative'), findsNothing);
    });

    testWidgets('but a viewer still reads who is related to whom', (
      tester,
    ) async {
      // What goes is the link that breaks a relationship, not the list of
      // them. A viewer reads the gia phả; that is the whole of the role.
      await seedFamily();
      await seedPerson(1, 'Ông A');
      await seedPerson(2, 'Bà B');
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r0000000-0000-7000-8000-000000000001',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
      await FamilyRoles(db).remember(familyId, FamilyRole.viewer);

      await openProfile(tester, 1);

      expect(find.text('Bà B'), findsOneWidget);
      expect(find.byIcon(Icons.link_off), findsNothing);
    });
  });

  group('a copy somebody was put out of', () {
    testWidgets('reads, and does nothing else', (tester) async {
      // The server has already done everything it can — the family is
      // invisible to them and every write is refused. What it cannot reach is
      // the copy on this phone, so the interface is the whole of it.
      await seedFamily();
      await seedPerson(1, 'Cụ Tổ');
      await FamilyRoles(db).remember(familyId, FamilyRole.removed);

      await openProfile(tester, 1);

      expect(find.text('Cụ Tổ'), findsWidgets, reason: 'it still reads');
      expect(find.text('Edit person'), findsNothing);
      expect(find.text('Delete this person'), findsNothing);
      expect(find.byTooltip('Add a relative'), findsNothing);
    });
  });
}
