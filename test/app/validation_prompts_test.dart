/// The line between refusing and asking (DOMAIN.md §9, CLAUDE.md §6).
///
/// The domain's half is tested: which codes are errors and which are warnings,
/// and that a result with warnings alone does not report `hasErrors`. This is
/// the half the reader meets, and it is where the distinction either survives
/// or quietly stops mattering.
///
/// A warning that cannot be overruled is the failure that matters most here. A
/// gia phả holds entries that are implausible and genuine — a mother of
/// fifteen, a son born nine months after his father's death — and an
/// application that refuses them is an application nobody can record their own
/// family in.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/validation_prompts.dart';
import 'package:ftree/domain/validation.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  /// A warning, and an error, so a result can hold either or both.
  const warning = ValidationIssue(IssueCode.implausibleLifespan);
  const anotherWarning = ValidationIssue(IssueCode.parentBornAfterChild);
  const error = ValidationIssue(IssueCode.displayNameEmpty);

  /// Puts a screen up and hands back its context.
  ///
  /// Through a real [MaterialApp] rather than a bare widget, because both
  /// prompts are dialogs and one of the things being tested is what
  /// dismissing one returns. Where a test asserts only about what is on
  /// screen, the prompt's future is left unawaited: the dialog stays open,
  /// which is the state being looked at.
  Future<BuildContext> screen(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    return captured;
  }

  group('warnings are the reader’s to overrule', () {
    testWidgets('saying to save anyway returns true', (tester) async {
      final context = await screen(tester);
      final answer = confirmWarnings(
        context,
        ValidationResult(const <ValidationIssue>[warning]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save anyway'));
      await tester.pumpAndSettle();

      expect(await answer, isTrue);
    });

    testWidgets('choosing to review returns false', (tester) async {
      final context = await screen(tester);
      final answer = confirmWarnings(
        context,
        ValidationResult(const <ValidationIssue>[warning]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });

    testWidgets('dismissing it counts as declining, not as consent', (
      tester,
    ) async {
      // A tap outside the dialog returns null from showDialog. Read as
      // anything but "no", a stray tap would write the record.
      final context = await screen(tester);
      final answer = confirmWarnings(
        context,
        ValidationResult(const <ValidationIssue>[warning]),
      );
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(await answer, isFalse);
    });

    testWidgets('every warning is listed, not just the first', (tester) async {
      // A reader asked to accept one thing and given two is being asked to
      // agree to something they were not shown.
      final context = await screen(tester);
      unawaited(
        confirmWarnings(
          context,
          ValidationResult(const <ValidationIssue>[warning, anotherWarning]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('•'), findsNWidgets(2));
    });

    testWidgets('errors are left out of the warning prompt', (tester) async {
      // Both kinds in one result. Listing the error here would offer to save
      // past something that cannot be saved past.
      final context = await screen(tester);
      unawaited(
        confirmWarnings(
          context,
          ValidationResult(const <ValidationIssue>[warning, error]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('•'), findsOneWidget);
    });
  });

  group('errors are not', () {
    testWidgets('there is no way past the prompt but back', (tester) async {
      // The whole distinction, in one assertion: nothing on this dialog
      // proceeds. If a "save anyway" ever appears here, an empty name reaches
      // the database.
      final context = await screen(tester);
      unawaited(
        showBlockingIssues(
          context,
          ValidationResult(const <ValidationIssue>[error]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cannot save'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Save anyway'), findsNothing);
    });

    testWidgets('warnings are left out of the blocking prompt', (
      tester,
    ) async {
      // Mixing them would make the reader correct a plausibility warning to
      // get past a missing name.
      final context = await screen(tester);
      unawaited(
        showBlockingIssues(
          context,
          ValidationResult(const <ValidationIssue>[error, warning]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('•'), findsOneWidget);
    });

    testWidgets('closing it ends the prompt', (tester) async {
      final context = await screen(tester);
      final done = showBlockingIssues(
        context,
        ValidationResult(const <ValidationIssue>[error]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await done;
      expect(find.text('Cannot save'), findsNothing);
    });
  });
}
