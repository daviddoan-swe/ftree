/// Walking from relative to relative, and getting back out.
///
/// Before this, reading a gia phả the way it is meant to be read — open a
/// person, open their father, open his brother — left the reader with a pile
/// of screens and one way out of it: press back once per person, with no way
/// to tell how many that was.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart' as domain;
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/family_screen.dart';
import 'package:ftree/features/person/person_trail.dart';
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

  /// A line of four: Cả, his son Hai, Hai's son Ba, Ba's son Tư.
  ///
  /// Given names are distinct from the family name on purpose — the trail
  /// shows the given name, and a row of four "Nguyễn" would prove nothing.
  Future<void> seedLine() async {
    await repository.saveFamily(
      const domain.Family(id: familyId, name: 'Họ Nguyễn'),
    );
    for (final (n, given) in <(int, String)>[
      (1, 'Cả'),
      (2, 'Hai'),
      (3, 'Ba'),
      (4, 'Tư'),
    ]) {
      await repository.savePerson(
        Person(
          id: personId(n),
          familyId: familyId,
          displayName: 'Nguyễn Văn $given',
          givenName: given,
        ),
      );
    }
    for (var n = 1; n < 4; n++) {
      await repository.saveRelationship(
        Relationship.parentChild(
          id: 'r$n',
          familyId: familyId,
          parent: personId(n),
          child: personId(n + 1),
        ),
      );
    }
  }

  Future<void> openList(WidgetTester tester) async {
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

  /// Opens [given]'s profile from whatever is on screen.
  Future<void> open(WidgetTester tester, String given) async {
    await tester.tap(find.text('Nguyễn Văn $given').last);
    await tester.pumpAndSettle();
  }

  /// Walks Cả → Hai → Ba, which is three profiles deep.
  Future<void> walkToBa(WidgetTester tester) async {
    await openList(tester);
    await open(tester, 'Cả');
    await open(tester, 'Hai');
    await open(tester, 'Ba');
  }

  /// Taps [name] in the trail, and nowhere else.
  ///
  /// Scoped, because the profile body also prints the subject's given name in
  /// its "Tên" row — a bare finder would be ambiguous exactly for the person
  /// being read, which is the one case worth testing.
  Future<void> tapTrail(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(PersonTrail),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The given names the trail is showing, in order.
  List<String> trailNames(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(PersonTrail),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .toList();

  group('the trail appears when there is a walk to show', () {
    testWidgets('one person deep shows their name, not a trail', (
      tester,
    ) async {
      // A walk of one needs no trail: the back button already says where it
      // goes, and a lone given name where a full name was is a loss.
      await seedLine();
      await openList(tester);
      await open(tester, 'Cả');

      expect(find.byType(PersonTrail), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Nguyễn Văn Cả'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('two deep, the path appears', (tester) async {
      await seedLine();
      await openList(tester);
      await open(tester, 'Cả');
      await open(tester, 'Hai');

      expect(trailNames(tester), <String>['Cả', 'Hai']);
    });

    testWidgets('it grows with the walk, in the order walked', (tester) async {
      await seedLine();
      await walkToBa(tester);

      expect(trailNames(tester), <String>['Cả', 'Hai', 'Ba']);
    });

    testWidgets('it shows given names, not the whole name', (tester) async {
      // A full Vietnamese name is some 100–140 points at title size, and the
      // title row has about 280 — two names, and no sense of a path.
      await seedLine();
      await walkToBa(tester);

      expect(trailNames(tester), isNot(contains('Nguyễn Văn Cả')));
    });
  });

  group('the trail takes the title’s place, and the name moves down', () {
    testWidgets('the bar carries the path, not the name', (tester) async {
      // In place of the title rather than under it, so the path costs no
      // height — which on a phone is the scarcest thing a screen has.
      await seedLine();
      await walkToBa(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PersonTrail),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Nguyễn Văn Ba'),
        ),
        findsNothing,
      );
    });

    testWidgets('the full name is under the portrait instead', (tester) async {
      await seedLine();
      await walkToBa(tester);

      expect(
        find.descendant(
          of: find.byType(AvatarHeader),
          matching: find.text('Nguyễn Văn Ba'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the trail fills the slot rather than sitting shrunk in it', (
      tester,
    ) async {
      // The theme centres titles, and a horizontal scroll view under loose
      // constraints sizes to its content — so without being told to fill,
      // a long path ends up in a box the width of a short one, centred, and
      // scrolling inside that.
      await seedLine();
      await walkToBa(tester);

      final bar = tester.getRect(find.byType(AppBar));
      final trail = tester.getRect(find.byType(PersonTrail));

      // Everything but the back button and the action opposite.
      expect(trail.width, greaterThan(bar.width * 0.7));
      expect(trail.center.dx, moreOrLessEquals(bar.center.dx, epsilon: 40));
    });

    testWidgets('and it is level with the bar, not below it', (tester) async {
      await seedLine();
      await walkToBa(tester);

      final back = tester.getRect(find.byIcon(Icons.chevron_left));
      final trail = tester.getRect(find.byType(PersonTrail));

      expect(
        trail.center.dy,
        moreOrLessEquals(back.center.dy, epsilon: 2),
        reason: 'the same row as the back button',
      );
    });
  });

  group('any point on the path is one tap away', () {
    testWidgets('tapping the first name drops the rest of the walk', (
      tester,
    ) async {
      await seedLine();
      await walkToBa(tester);

      await tapTrail(tester, 'Cả');

      // Back on Cả's own profile, which is one deep and so has no trail.
      expect(find.byType(PersonTrail), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Nguyễn Văn Cả'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping the middle drops only what came after it', (
      tester,
    ) async {
      await seedLine();
      await openList(tester);
      await open(tester, 'Cả');
      await open(tester, 'Hai');
      await open(tester, 'Ba');
      await open(tester, 'Tư');
      expect(trailNames(tester), <String>['Cả', 'Hai', 'Ba', 'Tư']);

      await tapTrail(tester, 'Hai');

      expect(trailNames(tester), <String>['Cả', 'Hai']);
    });

    testWidgets('tapping the one being read does nothing', (tester) async {
      // It is where the reader already is. Popping to it would be a tap that
      // looks like it moved and did not.
      await seedLine();
      await walkToBa(tester);

      await tapTrail(tester, 'Ba');

      expect(trailNames(tester), <String>['Cả', 'Hai', 'Ba']);
    });
  });

  group('the head of the trail leaves the walk entirely', () {
    testWidgets('a walk begun on the list goes back to the list', (
      tester,
    ) async {
      await seedLine();
      await walkToBa(tester);

      await tester.tap(find.byTooltip('Back to the list of people'));
      await tester.pumpAndSettle();

      expect(find.byType(FamilyScreen), findsOneWidget);
      expect(find.byType(PersonTrail), findsNothing);
    });

    testWidgets('however deep the walk went', (tester) async {
      await seedLine();
      await openList(tester);
      await open(tester, 'Cả');
      await open(tester, 'Hai');
      await open(tester, 'Ba');
      await open(tester, 'Tư');

      await tester.tap(find.byTooltip('Back to the list of people'));
      await tester.pumpAndSettle();

      expect(find.byType(FamilyScreen), findsOneWidget);
    });
  });

  group('shortName', () {
    Person named(String display, {String? given}) => Person(
      id: 'p1',
      familyId: familyId,
      displayName: display,
      givenName: given,
    );

    test('prefers the recorded given name', () {
      expect(shortName(named('Nguyễn Văn Cả', given: 'Cả')), 'Cả');
    });

    test('falls back to the last word, as the search ranking does', () {
      // The same rule `rankName` uses to decide what a query matched, so the
      // two cannot disagree about which word is the name.
      expect(shortName(named('Nguyễn Thị Hoà')), 'Hoà');
    });

    test('a one-word name is its own given name', () {
      expect(shortName(named('Cả')), 'Cả');
    });

    test('an empty recorded given name does not win over the display name', () {
      expect(shortName(named('Nguyễn Văn Cả', given: '   ')), 'Cả');
    });
  });
}
