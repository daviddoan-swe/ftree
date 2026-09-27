/// Who is in a family, and who has been asked (PRODUCT.md §5.1).
///
/// The device half is real — SQLite, the real code store — and the cloud is a
/// stand-in, because what is worth checking here is the screen's judgement:
/// which buttons it offers to whom, what it keeps, and what it forgets.
///
/// The server's own rules are `test/cloud/invitations.dart`, against a real
/// Postgres with real policies.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/cloud/family_invitations.dart';
import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/invitation_codes.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/features/family/invite_family.dart';
import 'package:ftree/l10n/app_localizations.dart';

const me = 'u-me';
const other = 'u-other';

final class StandInCircle implements FamilyCircle {
  StandInCircle({
    this.myRole = 'owner',
    this.letsMeIn = true,
    List<Invitation>? invitations,
    this.removeThrows,
    this.crowd = const <Member>[],
  }) : _invitations = invitations ?? <Invitation>[];

  /// Extra members, for the screens a hundred relatives make.
  final List<Member> crowd;

  String myRole;
  bool namesThem = true;
  bool letsMeIn;
  Object? removeThrows;

  List<Invitation> _invitations;
  final List<({String familyId, String role})> invited =
      <({String familyId, String role})>[];
  final List<String> revoked = <String>[];
  final List<String> removed = <String>[];

  int _next = 0;

  @override
  String? get meId => me;

  @override
  Future<bool> signIn(BuildContext context) async => letsMeIn;

  final List<({String userId, String role})> roleChanges =
      <({String userId, String role})>[];

  @override
  Future<String?> myRoleIn(String familyId) async => myRole;

  @override
  Future<List<Member>> members(String familyId) async => <Member>[
    Member(
      userId: me,
      role: myRole,
      email: 'toi@example.test',
      name: namesThem ? 'Bác Minh' : null,
      joinedAt: DateTime.utc(2026, 3, 2, 12),
    ),
    Member(
      userId: other,
      role: 'editor',
      email: 'em@example.test',
      name: namesThem ? 'Chú Hải' : null,
      joinedAt: DateTime.utc(2026, 9, 14, 12),
    ),
    ...crowd,
  ];

  @override
  Future<void> changeRole({
    required String familyId,
    required String userId,
    required String role,
  }) async {
    final failure = removeThrows;
    if (failure != null) throw failure;
    roleChanges.add((userId: userId, role: role));
  }

  @override
  Future<void> remove({
    required String familyId,
    required String userId,
  }) async {
    final failure = removeThrows;
    if (failure != null) throw failure;
    removed.add(userId);
  }

  @override
  Future<List<Invitation>> invitations(String familyId) async => _invitations;

  @override
  Future<Invitation> invite({
    required String familyId,
    required String role,
  }) async {
    invited.add((familyId: familyId, role: role));
    final made = Invitation(
      id: 'inv-${_next++}',
      familyId: familyId,
      role: role,
      createdAt: DateTime.utc(2026, 9, 25),
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
      code: 'K7P2-9XMR-4T',
    );
    _invitations = <Invitation>[..._invitations, made];
    return made;
  }

  @override
  Future<void> revoke(String invitationId) async {
    revoked.add(invitationId);
    _invitations = <Invitation>[
      for (final one in _invitations)
        if (one.id == invitationId)
          Invitation(
            id: one.id,
            familyId: one.familyId,
            role: one.role,
            createdAt: one.createdAt,
            expiresAt: one.expiresAt,
            revokedAt: DateTime.now().toUtc(),
          )
        else
          one,
    ];
  }
}

/// Midday UTC throughout, not midnight. The screen shows these in the reader's
/// own zone, which is right — "joined" is read beside a clock on a wall — and a
/// date written at midnight lands on the day before for every reader west of
/// Greenwich, including the machine these run on.
///
/// One somebody walked through, with the address of who it was.
Invitation _used(String id, {String role = 'editor'}) => Invitation(
  id: id,
  familyId: 'f-1',
  role: role,
  createdAt: DateTime.utc(2026, 9, 20, 12),
  expiresAt: DateTime.utc(2026, 9, 27, 12),
  acceptedAt: DateTime.utc(2026, 9, 22, 12),
  acceptedByEmail: 'chuhai@example.test',
  invitedByName: 'Bác Minh',
  invitedByEmail: 'toi@example.test',
);

/// One the owner closed before anybody used it.
Invitation _revoked(String id) => Invitation(
  id: id,
  familyId: 'f-1',
  role: 'viewer',
  createdAt: DateTime.utc(2026, 9, 18, 12),
  expiresAt: DateTime.utc(2026, 9, 25, 12),
  revokedAt: DateTime.utc(2026, 9, 19, 12),
  invitedByName: 'Bác Minh',
  invitedByEmail: 'toi@example.test',
);

/// One that simply ran out: nobody used it, nobody closed it.
Invitation _expired(String id) => Invitation(
  id: id,
  familyId: 'f-1',
  role: 'viewer',
  createdAt: DateTime.utc(2026, 9, 10, 12),
  expiresAt: DateTime.utc(2026, 9, 17, 12),
);

Invitation _live(String id, {String role = 'editor'}) => Invitation(
  id: id,
  familyId: 'f-1',
  role: role,
  createdAt: DateTime.utc(2026, 9, 25, 12),
  expiresAt: DateTime.now().toUtc().add(const Duration(days: 6)),
);

void main() {
  late AppDatabase db;
  late InvitationCodeStore store;

  const family = Family(id: 'f-1', name: 'Họ Nguyễn');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InvitationCodeStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> open(WidgetTester tester, StandInCircle circle) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          familyCircleProvider.overrideWithValue(circle),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: InvitationsScreen(family: family),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Reveals the actions on one member's row, as on the family list.
  Future<void> swipeMember(WidgetTester tester, String name) async {
    await tester.drag(
      find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
  }

  group('who is in the family', () {
    testWidgets('a row is a name, an address and a role — and nothing to '
        'press', (WidgetTester tester) async {
      await open(tester, StandInCircle());

      expect(find.text('Chú Hải'), findsOneWidget);
      expect(find.text('em@example.test'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(
        find.byType(IconButton),
        findsNothing,
        reason: 'a row is for reading; the actions are behind a swipe',
      );
    });

    testWidgets('an account with no name says so rather than wearing its '
        'address', (WidgetTester tester) async {
      // An account made before names were asked for. Showing the address with
      // its domain cut off would be the screen telling a lie.
      final circle = StandInCircle()..namesThem = false;
      await open(tester, circle);

      expect(find.text('No name given'), findsWidgets);
    });

    testWidgets('an editor is told whose job this is', (
      WidgetTester tester,
    ) async {
      // Only an owner manages the circle (§5.6), and the server answers an
      // editor with nothing — so the screen has to say why it is empty rather
      // than look broken.
      await open(tester, StandInCircle(myRole: 'editor'));

      expect(
        find.textContaining('Only the owner of a family manages'),
        findsOneWidget,
      );
      expect(find.text('New invitation'), findsNothing);
      expect(find.text('Chú Hải'), findsNothing);
    });

    testWidgets('swiping a member reveals Edit and Delete', (
      WidgetTester tester,
    ) async {
      await open(tester, StandInCircle());

      await swipeMember(tester, 'Chú Hải');

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('your own row has nothing behind it', (
      WidgetTester tester,
    ) async {
      // Leaving a family is a different act from running one, and this screen
      // is reached by whoever runs it.
      await open(tester, StandInCircle());

      await swipeMember(tester, 'Bác Minh (you)');

      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('Edit changes the role', (WidgetTester tester) async {
      final circle = StandInCircle();
      await open(tester, circle);
      await swipeMember(tester, 'Chú Hải');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Viewer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(circle.roleChanges.single.userId, other);
      expect(circle.roleChanges.single.role, 'viewer');
    });

    testWidgets('promoting somebody to owner asks first', (
      WidgetTester tester,
    ) async {
      // The same warning an owner invitation gets, for the same reason: there
      // is no walking it back.
      final circle = StandInCircle();
      await open(tester, circle);
      await swipeMember(tester, 'Chú Hải');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Owner'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Invite them as an owner?'), findsOneWidget);
      expect(circle.roleChanges, isEmpty);
    });

    testWidgets('Delete asks first, and says so to the server', (
      WidgetTester tester,
    ) async {
      final circle = StandInCircle();
      await open(tester, circle);
      await swipeMember(tester, 'Chú Hải');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the family').last);
      await tester.pumpAndSettle();

      expect(circle.removed, <String>[other]);
    });

    testWidgets('the last owner is refused in the server’s own terms', (
      WidgetTester tester,
    ) async {
      // keep_an_owner raising, arriving at a person. "It did not go through:
      // PostgrestException" would tell them nothing about what to do.
      final circle = StandInCircle(
        removeThrows: const PostgrestException(
          message: 'a family must always have at least one owner',
        ),
      );
      await open(tester, circle);
      await swipeMember(tester, 'Chú Hải');

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the family').last);
      await tester.pumpAndSettle();

      expect(
        find.text('A family must always have at least one owner'),
        findsOneWidget,
      );
    });
  });

  group('making one', () {
    Future<void> chooseRole(WidgetTester tester, String role) async {
      await tester.tap(find.text('New invitation'));
      await tester.pumpAndSettle();
      // By its row in the sheet: the same word is also a member's role in the
      // list above, so plain text finds two.
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(role),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an editor invitation is made without being argued about', (
      WidgetTester tester,
    ) async {
      final circle = StandInCircle();
      await open(tester, circle);

      await chooseRole(tester, 'Editor');

      expect(circle.invited.single.role, 'editor');
    });

    testWidgets('the code is kept on this device, before anything else', (
      WidgetTester tester,
    ) async {
      // The code exists in exactly one other place — the message about to be
      // sent — and a message is easy to close by accident.
      final circle = StandInCircle();
      await open(tester, circle);

      await chooseRole(tester, 'Editor');

      expect(await store.forFamily('f-1'), <String, String>{
        'inv-0': 'K7P2-9XMR-4T',
      });
    });

    testWidgets('inviting an owner asks first', (WidgetTester tester) async {
      // The only role that does. An owner can delete the family and can make
      // further owners, and there is no walking either back (§5.1).
      final circle = StandInCircle();
      await open(tester, circle);

      await chooseRole(tester, 'Owner');

      expect(find.text('Invite them as an owner?'), findsOneWidget);
      expect(
        find.textContaining('delete the whole family'),
        findsOneWidget,
        reason: 'the warning has to say what they will be able to do',
      );
      expect(
        circle.invited,
        isEmpty,
        reason: 'nothing made until it is agreed',
      );
    });

    testWidgets('and declining that makes nothing', (
      WidgetTester tester,
    ) async {
      final circle = StandInCircle();
      await open(tester, circle);
      await chooseRole(tester, 'Owner');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(circle.invited, isEmpty);
      expect(await store.forFamily('f-1'), isEmpty);
    });
  });

  group('a family with a hundred relatives in it', () {
    /// Enough viewers to make a screen nobody can read down.
    List<Member> viewers(int many) => <Member>[
      for (var n = 0; n < many; n++)
        Member(
          userId: 'u-$n',
          role: n.isEven ? 'viewer' : 'editor',
          email: 'nguoi$n@example.test',
          name: n == 7 ? 'Cô Hải' : 'Người $n',
          joinedAt: DateTime.utc(2026, 5, 1, 12),
        ),
    ];

    testWidgets('a short list is left alone', (WidgetTester tester) async {
      // Two members and a search field is a box asking a question nobody has.
      await open(tester, StandInCircle());

      expect(find.text('Name or address'), findsNothing);
      expect(find.textContaining('All'), findsNothing);
    });

    testWidgets('a long one is given something to search with', (
      WidgetTester tester,
    ) async {
      await open(tester, StandInCircle(crowd: viewers(20)));

      expect(find.text('Name or address'), findsOneWidget);
    });

    testWidgets('typing narrows it, diacritics and all', (
      WidgetTester tester,
    ) async {
      // `hai` finds Hải. Half a gia phả's names carry marks and nobody
      // switches keyboards to search.
      await open(tester, StandInCircle(crowd: viewers(20)));

      await tester.enterText(find.byType(TextField), 'hai');
      await tester.pumpAndSettle();

      expect(find.text('Cô Hải'), findsOneWidget);
      expect(find.text('Người 8'), findsNothing);
    });

    testWidgets('and an address is searchable too', (
      WidgetTester tester,
    ) async {
      // Half the accounts have no name — they signed up before names were
      // asked for — so an address is the only thing there is to type.
      await open(tester, StandInCircle(crowd: viewers(20)));

      await tester.enterText(find.byType(TextField), 'nguoi11@');
      await tester.pumpAndSettle();

      expect(find.text('Người 11'), findsOneWidget);
      expect(find.text('Người 12'), findsNothing);
    });

    testWidgets('a role can be asked for on its own', (
      WidgetTester tester,
    ) async {
      // The question a hundred members raises is rarely "where is Hải" — it
      // is "who are all the viewers", and that is not something to type.
      await open(tester, StandInCircle(crowd: viewers(20)));

      await tester.tap(
        find.descendant(
          of: find.byType(ChoiceChip),
          matching: find.textContaining('Viewer'),
        ),
      );
      await tester.pumpAndSettle();

      // Every remaining row is a viewer: the editors are gone, and so is the
      // owner who is not one either.
      expect(find.text('Người 1'), findsNothing, reason: 'an editor');
      expect(find.text('Người 2'), findsOneWidget, reason: 'a viewer');
    });

    testWidgets('matching nobody says so rather than showing a blank', (
      WidgetTester tester,
    ) async {
      await open(tester, StandInCircle(crowd: viewers(20)));

      await tester.enterText(find.byType(TextField), 'khong-co-ai');
      await tester.pumpAndSettle();

      expect(find.text('Nobody here matches that'), findsOneWidget);
    });
  });

  /// Taps one of the invitation chips.
  ///
  /// The list opens on the live ones, because those are the only rows that
  /// can still be acted on. Everything else is a record and is one chip away.
  Future<void> showState(WidgetTester tester, String label) async {
    final chip = find.descendant(
      of: find.byType(ChoiceChip),
      matching: find.textContaining(label),
    );

    // Scrolled to first. The default test surface is 800 points tall and the
    // chips sit below the members and the button, so a tap without this lands
    // on nothing, warns, and leaves the filter where it was — which reads as
    // the filter not working rather than as the test not reaching it.
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  group('a list of invitations that has grown long', () {
    testWidgets('it opens on the ones that can still be used', (
      WidgetTester tester,
    ) async {
      // Of seventy-three invitations on a real family, twelve were live. The
      // rest are a record, not a list of things to do, and a screen that
      // opens on the record buries the twelve worth acting on.
      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[
            _live('inv-9'),
            _used('inv-1'),
            _revoked('inv-2'),
          ],
        ),
      );

      expect(find.textContaining('K7P2-9XMR-4T'), findsOneWidget);
      expect(find.textContaining('Used · '), findsNothing);
      expect(find.textContaining('Revoked · '), findsNothing);
    });

    testWidgets('and the chips are there to reach the rest', (
      WidgetTester tester,
    ) async {
      // Shown whatever the length, unlike the search field. They are the only
      // way to a used code, so hiding them would hide rows with nothing on
      // the screen to say they exist.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_used('inv-1')]),
      );

      await showState(tester, 'Used');

      expect(find.textContaining('Used · 22/09/2026'), findsOneWidget);
    });

    testWidgets('an address finds the invitation somebody came in on', (
      WidgetTester tester,
    ) async {
      // Not "which code was that" — nobody remembers a code — but "who came
      // in, and on whose invitation".
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[
            for (var n = 0; n < 10; n++) _used('inv-$n'),
            _revoked('inv-r'),
          ],
        ),
      );
      await showState(tester, 'Used');

      await tester.enterText(find.byType(TextField), 'chuhai');
      await tester.pumpAndSettle();

      expect(find.textContaining('chuhai@example.test'), findsWidgets);
    });

    testWidgets('a used one names who let them in', (
      WidgetTester tester,
    ) async {
      // The one fact this row has that the member list has not. Without it a
      // used invitation only repeats what the membership already says.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_used('inv-1')]),
      );
      await showState(tester, 'Used');

      expect(find.text('Bác Minh'), findsOneWidget);
    });

    testWidgets('one nobody came in on names nobody', (
      WidgetTester tester,
    ) async {
      // A revoked code has an inviter too, and naming them would say nothing
      // that happened. This line is the record of who admitted whom, not of
      // who wrote a code that went nowhere.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_revoked('inv-2')]),
      );
      await showState(tester, 'Revoked');

      expect(find.text('Bác Minh'), findsNothing);
      expect(find.textContaining('Revoked · '), findsOneWidget);
    });
  });

  group('what each row says', () {
    testWidgets('a member shows when they came in, over what they may do', (
      WidgetTester tester,
    ) async {
      // Running a family is deciding who is in it, and "since when" is half of
      // what that decision is made on.
      await open(tester, StandInCircle());

      expect(find.text('14/09/2026'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
    });

    testWidgets('a used invitation names who used it, and when', (
      WidgetTester tester,
    ) async {
      // The record of who let whom in. Without the address it answers "was it
      // used?" and not "by whom?", which is the question an owner has.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_used('inv-1')]),
      );
      await showState(tester, 'Used');

      expect(find.textContaining('chuhai@example.test'), findsOneWidget);
      expect(find.textContaining('Used · 22/09/2026'), findsOneWidget);
    });

    testWidgets('each state wears its own colour, on the icon and the word', (
      WidgetTester tester,
    ) async {
      // Four states in one list. Colour reinforces the word rather than
      // replacing it, so what matters is that the four differ — and that the
      // icon and the word agree, because a green dot beside a red word would
      // be worse than no colour at all.
      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[
            _live('inv-9'),
            _used('inv-1'),
            _revoked('inv-2'),
            _expired('inv-3'),
          ],
        ),
      );
      await showState(tester, 'All');

      Color colourOf(String word) =>
          tester.widget<Text>(find.text(word)).style!.color!;

      final used = colourOf('Used · 22/09/2026');
      final revoked = colourOf('Revoked · 19/09/2026');
      final expired = colourOf('Expired');

      expect(<Color>{used, revoked, expired}, hasLength(3));

      // And the icon beside each says the same thing. `RowIcon` paints the
      // colour as the tile behind a white glyph, so the tile is what carries
      // it. The live one has no word — its corner holds two buttons — so its
      // icon is what states its colour at all.
      final icons = tester
          .widgetList<RowIcon>(find.byType(RowIcon))
          .where((r) => r.icon == Icons.mail_outline)
          .map((r) => r.color)
          .toList();

      expect(icons, hasLength(4));
      expect(icons.toSet(), hasLength(4), reason: 'one colour per state');
      expect(icons, contains(used));
      expect(icons, contains(revoked));
      expect(icons, contains(expired));
    });

    testWidgets('one that ran out says so, and shows no day', (
      WidgetTester tester,
    ) async {
      // A seven-day code cannot be watched expiring by hand, so this is the
      // only place the state is checked at all.
      //
      // No date, unlike used and revoked: nothing happened to it. Nobody
      // pressed anything and nobody walked through it — a day simply passed,
      // and putting one on the row would be inventing a moment.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_expired('inv-3')]),
      );
      await showState(tester, 'Expired');

      expect(find.textContaining('Expired'), findsWidgets);
      expect(find.text('Nobody used it'), findsOneWidget);
      expect(find.textContaining('17/09/2026'), findsNothing);
      expect(find.text('Send'), findsNothing);
      expect(
        find.text('Revoke'),
        findsNothing,
        reason: 'nothing left to close',
      );
    });

    testWidgets('a revoked one shows the day it was closed', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_revoked('inv-2')]),
      );
      await showState(tester, 'Revoked');

      expect(find.textContaining('Revoked · 19/09/2026'), findsOneWidget);
    });

    testWidgets('every row leads with the role, in every state', (
      WidgetTester tester,
    ) async {
      // It was the code while the invitation was live and the role afterwards,
      // so the one thing every row has in common moved about and the column
      // could not be read down.
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[
            _live('inv-9'),
            _used('inv-1'),
            _revoked('inv-2'),
          ],
        ),
      );
      await showState(tester, 'All');

      // Two editors among the invitations, plus the editor in the member list.
      expect(find.text('Editor'), findsNWidgets(3));
      expect(find.text('Viewer'), findsOneWidget);
    });

    testWidgets('a live one says how long it is good for, beside the buttons', (
      WidgetTester tester,
    ) async {
      // Still running, so the span is the thing worth knowing about it, and it
      // sits with the two things that can be done about it.
      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_live('inv-9')]),
      );

      expect(find.textContaining('25/09/2026 – '), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('and all of it fits on a phone', (WidgetTester tester) async {
      // The default test surface is 800 points wide, which is wider than any
      // phone and hides exactly the overflow this row now risks: a role, a
      // code, a span of two dates and two buttons, all on one line. Flutter
      // fails a test on a RenderFlex overflow, so the narrow surface is the
      // whole assertion.
      tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 Pro
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[_live('inv-9'), _used('inv-1')],
        ),
      );
      await showState(tester, 'All');

      expect(find.text('Send'), findsOneWidget);
    });

    testWidgets('a finished one does not, because the day it ended says more', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_used('inv-1')]),
      );
      await showState(tester, 'Used');

      expect(find.textContaining('20/09/2026 – 27/09/2026'), findsNothing);
      expect(find.textContaining('chuhai@example.test'), findsOneWidget);
    });

    testWidgets('one nobody used says so rather than showing a blank', (
      WidgetTester tester,
    ) async {
      // An empty line where an address goes reads as the screen having failed
      // to load a name — when what it means is that there was never one.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_revoked('inv-2')]),
      );
      await showState(tester, 'Revoked');

      expect(find.text('Nobody used it'), findsOneWidget);
    });
  });

  group('the list of invitations', () {
    testWidgets('a code this device holds can be sent again', (
      WidgetTester tester,
    ) async {
      // The answer to closing the message by accident.
      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');

      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_live('inv-9')]),
      );

      expect(find.textContaining('K7P2-9XMR-4T'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('one this device has forgotten is still listed, and still '
        'revocable', (WidgetTester tester) async {
      // A reinstall, or a different phone. The invitation is standing, so
      // hiding it would leave something live that nobody could close.
      await open(
        tester,
        StandInCircle(invitations: <Invitation>[_live('inv-9')]),
      );

      expect(
        find.textContaining('This device no longer holds the code'),
        findsOneWidget,
      );
      expect(find.text('Send'), findsNothing);
      expect(find.text('Revoke'), findsOneWidget);
    });

    testWidgets('revoking forgets the code as well', (
      WidgetTester tester,
    ) async {
      // Dead on the server, so a readable copy would only offer a Send button
      // for something nobody can redeem.
      await store.remember(id: 'inv-9', familyId: 'f-1', code: 'K7P2-9XMR-4T');
      final circle = StandInCircle(invitations: <Invitation>[_live('inv-9')]);
      await open(tester, circle);

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();

      expect(circle.revoked, <String>['inv-9']);
      expect(await store.forFamily('f-1'), isEmpty);
    });

    testWidgets('a used invitation offers neither button', (
      WidgetTester tester,
    ) async {
      // Revoking does not remove the person it let in; that is removing a
      // member. A button here would promise something it does not do.
      await open(
        tester,
        StandInCircle(
          invitations: <Invitation>[
            Invitation(
              id: 'inv-9',
              familyId: 'f-1',
              role: 'editor',
              createdAt: DateTime.utc(2026, 9, 25),
              expiresAt: DateTime.now().toUtc().add(const Duration(days: 6)),
              acceptedAt: DateTime.utc(2026, 9, 25, 12),
            ),
          ],
        ),
      );
      await showState(tester, 'Used');

      expect(find.textContaining('Used · '), findsOneWidget);
      expect(find.text('Revoke'), findsNothing);
      expect(find.text('Send'), findsNothing);
    });
  });
}
