/// Joining a family somebody invited you to (PRODUCT.md §5.1).
///
/// SQLite is real, so what these check is what ends up on the device — which
/// is the half that can lose somebody's work. The cloud is a stand-in: what
/// the server does with a code is `test/cloud/invitations.dart`.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/database/sharing_marks.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/join_family.dart';
import 'package:ftree/l10n/app_localizations.dart';

const familyId = 'f0000000-0000-7000-8000-000000000001';

String personId(int n) =>
    'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

final class StandInJoining implements JoiningCloud {
  StandInJoining({
    this.letsMeIn = true,
    this.acceptThrows,
    this.onServer,
    this.grants = 'editor',
  });

  bool letsMeIn;
  Object? acceptThrows;
  FamilySnapshot? onServer;

  /// What the code the stand-in accepts turns out to have granted.
  String? grants;

  final List<String> accepted = <String>[];
  int signInAttempts = 0;

  @override
  Future<bool> signIn(BuildContext context) async {
    signInAttempts++;
    return letsMeIn;
  }

  @override
  Future<String> accept(String code) async {
    final failure = acceptThrows;
    if (failure != null) throw failure;
    accepted.add(code);
    return familyId;
  }

  @override
  Future<FamilySnapshot?> download(String id) async => onServer;

  @override
  Future<String?> roleIn(String familyId) async => grants;
}

FamilySnapshot _up(List<Person> persons) => FamilySnapshot(
  family: const Family(id: familyId, name: 'Họ Nguyễn'),
  graph: FamilyGraph(persons: persons, relationships: const <Relationship>[]),
);

void main() {
  late AppDatabase db;
  late DriftFamilyRepository repository;
  late SharingMarks marks;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFamilyRepository(db);
    marks = SharingMarks(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(WidgetTester tester, StandInJoining cloud) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          joiningCloudProvider.overrideWithValue(cloud),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: JoinFamilyScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.widgetWithText(FilledButton, 'Join the family'));
    await tester.pumpAndSettle();
  }

  /// Agrees to what the preview offers.
  Future<void> agree(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();
  }

  group('nothing is asked for nothing', () {
    testWidgets('an empty box asks the server nothing', (
      WidgetTester tester,
    ) async {
      final cloud = StandInJoining();
      await open(tester, cloud);

      await tester.tap(find.widgetWithText(FilledButton, 'Join the family'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the code'), findsOneWidget);
      expect(cloud.signInAttempts, 0);
      expect(cloud.accepted, isEmpty);
    });

    testWidgets('backing out of signing in redeems nothing', (
      WidgetTester tester,
    ) async {
      // The code is typed first and the account asked for second, so that
      // nobody is signed up before they have shown they have something to
      // join with. Declining there must not spend the code.
      final cloud = StandInJoining(letsMeIn: false);
      await open(tester, cloud);

      await enter(tester, 'K7P2-9XMR-4T');

      expect(cloud.accepted, isEmpty);
    });
  });

  group('arriving', () {
    testWidgets('the family lands on the device, and is marked shared', (
      WidgetTester tester,
    ) async {
      // Marked because it *is* shared: without it the list would offer Chia sẻ
      // on a family already on the server (PRODUCT §4.2).
      final cloud = StandInJoining(
        onServer: _up(<Person>[
          Person(id: personId(1), familyId: familyId, displayName: 'Cụ Tổ'),
        ]),
      );
      await open(tester, cloud);

      await enter(tester, 'K7P2-9XMR-4T');
      await agree(tester);

      expect(cloud.accepted, <String>['K7P2-9XMR-4T']);
      final snapshot = await repository.loadFamily(familyId);
      expect(snapshot!.graph.persons, hasLength(1));
      expect(await marks.isShared(familyId), isTrue);
    });

    testWidgets('the role the code granted is kept, so the interface knows', (
      WidgetTester tester,
    ) async {
      // Without it every invited copy would look like one nobody has a claim
      // on, and a viewer would be offered Export, Delete and the rest
      // (PRODUCT §5.0).
      final cloud = StandInJoining(
        grants: 'viewer',
        onServer: _up(<Person>[
          Person(id: personId(1), familyId: familyId, displayName: 'Cụ Tổ'),
        ]),
      );
      await open(tester, cloud);

      await enter(tester, 'K7P2-9XMR-4T');
      await agree(tester);

      expect(await FamilyRoles(db).all(), <String, FamilyRole>{
        familyId: FamilyRole.viewer,
      });
    });

    testWidgets('it does not land on top of work already here', (
      WidgetTester tester,
    ) async {
      // The case that loses data. Somebody was sent the exported file first,
      // imported it, and added their own branch; then the invitation arrived.
      // The file and the server carry the same family id, so an overwrite
      // would land on their branch and take it.
      await repository.saveAll(
        family: const Family(id: familyId, name: 'Họ Nguyễn'),
        persons: <Person>[
          Person(
            id: personId(9),
            familyId: familyId,
            displayName: 'Nhánh nhà tôi',
          ),
        ],
      );

      final cloud = StandInJoining(
        onServer: _up(<Person>[
          Person(id: personId(1), familyId: familyId, displayName: 'Cụ Tổ'),
        ]),
      );
      await open(tester, cloud);

      await enter(tester, 'K7P2-9XMR-4T');
      await agree(tester);

      final snapshot = await repository.loadFamily(familyId);
      expect(
        snapshot!.graph.persons.map((p) => p.displayName),
        containsAll(<String>['Nhánh nhà tôi', 'Cụ Tổ']),
        reason: 'add-only: what was here stays, what is new arrives',
      );
    });

    testWidgets('the whole message can be pasted, not just the code', (
      WidgetTester tester,
    ) async {
      // What the phone's Copy button actually gives you. Somebody moving a
      // code between two phones will paste the sentence around it, and so
      // will anybody forwarding the message they were sent.
      final cloud = StandInJoining(
        onServer: _up(<Person>[
          Person(id: personId(1), familyId: familyId, displayName: 'Cụ Tổ'),
        ]),
      );
      await open(tester, cloud);

      await enter(
        tester,
        'Your code for the Họ Nguyễn family tree: 6E54-7LNH-MR'
        '\n\nIt works once, and expires in seven days.',
      );
      await agree(tester);

      expect(cloud.accepted, <String>['6E54-7LNH-MR']);
    });

    testWidgets('declining the preview writes nothing', (
      WidgetTester tester,
    ) async {
      final cloud = StandInJoining(
        onServer: _up(<Person>[
          Person(id: personId(1), familyId: familyId, displayName: 'Cụ Tổ'),
        ]),
      );
      await open(tester, cloud);

      await enter(tester, 'K7P2-9XMR-4T');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(await repository.loadFamily(familyId), isNull);
      expect(await marks.shared(), isEmpty);
    });
  });

  group('what the server says no with', () {
    Future<void> refused(WidgetTester tester, String word) async {
      await open(
        tester,
        StandInJoining(acceptThrows: PostgrestException(message: word)),
      );
      await enter(tester, 'K7P2-9XMR-4T');
    }

    testWidgets('a code nobody issued', (WidgetTester tester) async {
      await refused(tester, 'invitation_not_found');

      expect(find.textContaining('There is no such code'), findsOneWidget);
    });

    testWidgets('a code somebody else got to first', (
      WidgetTester tester,
    ) async {
      // The sentence that makes a stolen code visible. Whoever was meant to
      // have it is told somebody was here already, and tells the owner.
      await refused(tester, 'invitation_already_used');

      expect(find.textContaining('has already been used'), findsOneWidget);
    });

    testWidgets('a code the owner called back', (WidgetTester tester) async {
      await refused(tester, 'invitation_revoked');

      expect(find.textContaining('was revoked'), findsOneWidget);
    });

    testWidgets('a code that ran out of days', (WidgetTester tester) async {
      await refused(tester, 'invitation_expired');

      expect(find.textContaining('has expired'), findsOneWidget);
    });

    testWidgets('and something that is not any of those, in its own words', (
      WidgetTester tester,
    ) async {
      await refused(tester, 'mạng mất rồi');

      expect(find.textContaining('mạng mất rồi'), findsOneWidget);
    });
  });
}
