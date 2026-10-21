/// The sign-in screen (ROADMAP M8, PRODUCT §4.1).
///
/// No server, and not because one is inconvenient. What is worth checking here
/// is the screen's own judgement — what it refuses to send, what it says about
/// what came back, and whether it lets go of the reader — and a real auth
/// server cannot produce the case that matters most: an account created with
/// no session, which the local stack cannot make because it has confirmations
/// switched off.
///
/// The server's own behaviour is `test/cloud/auth.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import 'package:ftree/features/account/sign_in.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  /// Every call the screen made, in order.
  late List<({bool creating, String email, String password, String name})>
  asked;

  /// What the route popped: true, false, or null for backing out.
  bool? popped;

  setUp(() {
    asked = <({bool creating, String email, String password, String name})>[];
    popped = null;
  });

  /// Records the attempt and answers [signedIn].
  AccountAttempt answering(bool signedIn) =>
      ({
        required bool creating,
        required String email,
        required String password,
        required String name,
      }) async {
        asked.add((
          creating: creating,
          email: email,
          password: password,
          name: name,
        ));
        return signedIn;
      };

  /// Records the attempt and throws [error].
  AccountAttempt throwing(Object error) =>
      ({
        required bool creating,
        required String email,
        required String password,
        required String name,
      }) async {
        asked.add((
          creating: creating,
          email: email,
          password: password,
          name: name,
        ));
        throw error;
      };

  /// Opens the screen on a route that remembers what it pops.
  Future<void> open(WidgetTester tester, AccountAttempt attempt) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => ElevatedButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => SignInScreen(attempt: attempt),
                ),
              );
            },
            child: const Text('mở'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  /// The one button that acts, found by role rather than by its words — its
  /// words are also a segment's words, and change with the mood.
  String action(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Text),
        ),
      )
      .data!;

  /// Fills the boxes that are showing. The name box is there only while
  /// creating, so the fields are found by their labels rather than by order.
  Future<void> fill(
    WidgetTester tester, {
    required String email,
    required String password,
    String name = 'Bác Minh',
  }) async {
    final nameBox = find.widgetWithText(TextField, 'Name');
    if (nameBox.evaluate().isNotEmpty) {
      await tester.enterText(nameBox, name);
    }
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      password,
    );
    await tester.pump();
  }

  Future<void> press(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
  }

  group('what it refuses to send', () {
    testWidgets('it opens on creating an account, and says what one is for', (
      WidgetTester tester,
    ) async {
      await open(tester, answering(true));

      expect(action(tester), 'Sign up');
      expect(
        find.textContaining('only for sharing'),
        findsOneWidget,
        reason: 'a sign-in box implies the application now needs one (§4.1)',
      );
    });

    testWidgets('no name, nobody asked', (WidgetTester tester) async {
      // Asked for only when creating, and required: the member list is how an
      // owner decides who may change a gia phả, and a list of addresses is a
      // poor thing to decide from (§5.6).
      await open(tester, answering(true));

      await press(tester);

      expect(find.text('Enter your name'), findsOneWidget);
      expect(asked, isEmpty);
    });

    testWidgets('no email, nobody asked', (WidgetTester tester) async {
      await open(tester, answering(true));
      await fill(tester, email: '', password: 'correct horse');

      await press(tester);

      expect(find.text('Enter an email address'), findsOneWidget);
      expect(asked, isEmpty);
    });

    testWidgets('signing in is not asked for a name at all', (
      WidgetTester tester,
    ) async {
      // Somebody who already has an account named themselves when they made
      // it. Asking again would be asking them to rename themselves to get in.
      await open(tester, answering(true));

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Name'), findsNothing);
    });

    testWidgets('the name is carried up with the account', (
      WidgetTester tester,
    ) async {
      await open(tester, answering(true));
      await fill(
        tester,
        email: 'a@example.test',
        password: 'correct horse',
        name: 'Bác Minh',
      );

      await press(tester);

      expect(asked.single.name, 'Bác Minh');
    });

    testWidgets('an email that is not one, nobody asked', (
      WidgetTester tester,
    ) async {
      await open(tester, answering(true));
      // A password that is fine, so the address is the only thing wrong. It
      // used to be nine characters, which was above the old minimum and is
      // below this one — leaving the test with two faults where it means to
      // have one, and passing only because the address is checked first.
      await fill(
        tester,
        email: 'khong-phai-email',
        password: 'correct horse battery',
      );

      await press(tester);

      expect(find.text('That is not an email address'), findsOneWidget);
      expect(asked, isEmpty);
    });

    testWidgets('no password, nobody asked', (WidgetTester tester) async {
      await open(tester, answering(true));
      await fill(tester, email: 'a@example.test', password: '');

      await press(tester);

      expect(find.text('Enter your password'), findsOneWidget);
      expect(asked, isEmpty);
    });

    testWidgets('a new password below the minimum, nobody asked', (
      WidgetTester tester,
    ) async {
      await open(tester, answering(true));
      await fill(tester, email: 'a@example.test', password: '12345');

      await press(tester);

      expect(
        find.text('A password needs at least 12 characters'),
        findsOneWidget,
      );
      expect(asked, isEmpty);
    });

    testWidgets('but signing in sends a short password anyway', (
      WidgetTester tester,
    ) async {
      // The rule belongs to creating. An account made when the minimum was
      // lower still has the password it has, and refusing to send it would
      // lock its owner out over a rule that was never theirs.
      await open(tester, answering(true));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await fill(tester, email: 'a@example.test', password: '12345');

      await press(tester);

      expect(asked, hasLength(1));
      expect(asked.single.creating, isFalse);
      expect(asked.single.password, '12345');
    });

    testWidgets('backing out asks nobody and answers nothing', (
      WidgetTester tester,
    ) async {
      await open(tester, answering(true));

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(asked, isEmpty);
      expect(popped, isNull);
    });
  });

  group('what it does with an answer', () {
    testWidgets('a session means done', (WidgetTester tester) async {
      await open(tester, answering(true));
      await fill(tester, email: 'a@example.test', password: 'correct horse');

      await press(tester);

      expect(popped, isTrue);
      expect(find.byType(SignInScreen), findsNothing);
    });

    testWidgets('the address is trimmed before it is sent', (
      WidgetTester tester,
    ) async {
      // A keyboard that capitalises also offers a trailing space, and an
      // address with one on the end is a different address to the server.
      await open(tester, answering(true));
      await fill(
        tester,
        email: '  a@example.test  ',
        password: 'correct horse battery',
      );

      await press(tester);

      expect(asked.single.email, 'a@example.test');
    });

    testWidgets('created with no session asks for the email to be confirmed', (
      WidgetTester tester,
    ) async {
      // The case no live server available here can produce, and the first one
      // production will meet. Signing up succeeded; there is no token until a
      // link is followed, so the reader must not be sent onwards as though
      // there were.
      await open(tester, answering(false));
      await fill(tester, email: 'a@example.test', password: 'correct horse');

      await press(tester);

      expect(find.textContaining('Open your email'), findsOneWidget);
      expect(popped, isNull, reason: 'no session, so nothing to go on with');
      expect(
        action(tester),
        'Sign in',
        reason: 'once the link is followed, signing in is the next thing',
      );
    });

    testWidgets('one tap is one account', (WidgetTester tester) async {
      // Creating an account twice is not a double submit that resolves
      // harmlessly: the second is refused as a duplicate, and the reader is
      // told off for something the interface did.
      final gate = Completer<bool>();
      await open(tester, ({
        required bool creating,
        required String email,
        required String password,
        required String name,
      }) {
        asked.add((
          creating: creating,
          email: email,
          password: password,
          name: name,
        ));
        return gate.future;
      });
      await fill(tester, email: 'a@example.test', password: 'correct horse');

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();

      expect(asked, hasLength(1));

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(popped, isTrue);
    });
  });

  group('what it says about a refusal', () {
    Future<void> refusedWith(WidgetTester tester, Object error) async {
      await open(tester, throwing(error));
      await fill(tester, email: 'a@example.test', password: 'correct horse');
      await press(tester);
    }

    testWidgets('it does not name the password as the wrong one', (
      WidgetTester tester,
    ) async {
      // Read off the running server: a wrong password and an address with no
      // account both come back `invalid_credentials`, one code for both,
      // which is the server declining to say who is registered. Saying "wrong
      // password" would give away precisely what it withheld.
      await refusedWith(
        tester,
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
      );

      expect(find.text('That email and password do not match'), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('an address already taken points at the other mood', (
      WidgetTester tester,
    ) async {
      await refusedWith(
        tester,
        const AuthException(
          'User already registered',
          code: 'user_already_exists',
        ),
      );

      expect(find.textContaining('already has an account'), findsOneWidget);
    });

    testWidgets('the server calling a password weak says the rule', (
      WidgetTester tester,
    ) async {
      await refusedWith(
        tester,
        const AuthException(
          'Password should be at least 6 characters.',
          code: 'weak_password',
        ),
      );

      expect(
        find.text('A password needs at least 12 characters'),
        findsOneWidget,
      );
    });

    testWidgets('a code with no message of ours shows the server’s words', (
      WidgetTester tester,
    ) async {
      await refusedWith(
        tester,
        const AuthException('Signups not allowed', code: 'signup_disabled'),
      );

      expect(find.textContaining('Signups not allowed'), findsOneWidget);
    });

    testWidgets('a failure that is not the auth server is not silence', (
      WidgetTester tester,
    ) async {
      // No network, a dead host, a certificate. The worst answer is nothing:
      // somebody who taps and sees no change has nothing to report.
      await refusedWith(tester, Exception('mạng mất rồi'));

      expect(find.textContaining('mạng mất rồi'), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('and the button comes back', (WidgetTester tester) async {
      await refusedWith(
        tester,
        const AuthException('nope', code: 'invalid_credentials'),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'a refusal that left it disabled would end the attempt there',
      );
    });
  });
}
