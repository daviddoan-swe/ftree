/// Every validation code has words, and no two codes share them.
///
/// The switch in `issue_text.dart` is exhaustive, so the compiler already
/// refuses a code with no arm. What it cannot see is the two ways this file
/// goes wrong in practice: an arm pointing at the wrong message, which is what
/// a copy-pasted line looks like, and a message that exists in one language
/// and not the other.
///
/// Both produce a screen that compiles, runs, and tells somebody the wrong
/// thing about their family's record.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/issue_text.dart';
import 'package:ftree/domain/validation.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  /// Reads the message for every code, in [locale].
  Future<Map<IssueCode, String>> wordsFor(
    WidgetTester tester,
    Locale locale,
  ) async {
    final words = <IssueCode, String>{};
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppText.localizationsDelegates,
        supportedLocales: AppText.supportedLocales,
        home: Builder(
          builder: (context) {
            for (final code in IssueCode.values) {
              words[code] = issueText(context, code);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return words;
  }

  for (final locale in <Locale>[Locale('vi'), Locale('en')]) {
    group('in ${locale.languageCode}', () {
      testWidgets('every code has something to say', (tester) async {
        final words = await wordsFor(tester, locale);

        expect(words, hasLength(IssueCode.values.length));
        for (final entry in words.entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: '${entry.key.name} has no message',
          );
        }
      });

      testWidgets('no two codes say the same thing', (tester) async {
        // Two codes sharing a message is the shape of a mis-pasted arm, and
        // it is invisible to the compiler: both sides typecheck. The reader
        // sees a sentence about the wrong problem and corrects the wrong
        // thing.
        final words = await wordsFor(tester, locale);
        final byMessage = <String, List<String>>{};
        for (final entry in words.entries) {
          (byMessage[entry.value] ??= <String>[]).add(entry.key.name);
        }

        final shared = byMessage.entries.where((e) => e.value.length > 1);
        expect(
          shared.map((e) => '${e.value.join(' and ')}: "${e.key}"'),
          isEmpty,
        );
      });
    });
  }

  testWidgets('the two languages cover the same codes', (tester) async {
    // A message added to one .arb and forgotten in the other falls back to
    // the template, so a Vietnamese reader is shown an English sentence.
    // Comparing the two catches it; reading either alone does not.
    final vietnamese = await wordsFor(tester, const Locale('vi'));
    final english = await wordsFor(tester, const Locale('en'));

    expect(vietnamese.keys, english.keys);
    final untranslated = <String>[
      for (final code in IssueCode.values)
        if (vietnamese[code] == english[code]) code.name,
    ];
    expect(
      untranslated,
      isEmpty,
      reason: 'the same sentence in both languages means one is a fallback',
    );
  });
}
