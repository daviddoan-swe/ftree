import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/grouped_list.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/features/family/generation_filter.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  const familyId = 'f1';

  Person personOf(String id) =>
      Person(id: id, familyId: familyId, displayName: 'Person $id');

  final people = <Person>[
    personOf('a'),
    personOf('b'),
    personOf('c'),
    personOf('stranger'),
  ];

  // 'stranger' is absent: a separate line has no đời in this family's count.
  const doi = <String, int>{'a': 1, 'b': 2, 'c': 2};

  group('ofGeneration', () {
    test('no choice leaves the list whole', () {
      expect(ofGeneration(people, doi, null), people);
    });

    test('keeps only those standing in the đời chosen', () {
      expect(
        ofGeneration(people, doi, 2).map((p) => p.id),
        <String>['b', 'c'],
      );
    });

    test('the unnumbered are reachable rather than lost', () {
      // They match no đời, so without a choice of their own they would be
      // filtered out by every chip and findable by none.
      expect(
        ofGeneration(people, doi, unknownGeneration).map((p) => p.id),
        <String>['stranger'],
      );
    });

    test('an empty đời comes back empty rather than whole', () {
      expect(ofGeneration(people, doi, 9), isEmpty);
    });
  });

  group('countByGeneration', () {
    test('counts each đời that somebody occupies', () {
      expect(countByGeneration(people, doi), <int?, int>{
        1: 1,
        2: 2,
        unknownGeneration: 1,
      });
    });

    test('leaves out đời nobody stands in', () {
      expect(
        countByGeneration(<Person>[personOf('a')], const <String, int>{'a': 4}),
        <int?, int>{4: 1},
      );
    });

    test('the counts add up to the people counted', () {
      final counts = countByGeneration(people, doi);
      expect(counts.values.fold<int>(0, (a, b) => a + b), people.length);
    });
  });

  group('the row offers itself only when it is a choice', () {
    GenerationFilter filterOf(Map<int?, int> counts) => GenerationFilter(
      counts: counts,
      chosen: null,
      onChosen: (_) {},
    );

    test('one đời is no choice', () {
      expect(filterOf(<int?, int>{1: 5}).isWorthShowing, isFalse);
    });

    test('two are', () {
      expect(filterOf(<int?, int>{1: 5, 2: 9}).isWorthShowing, isTrue);
    });

    test('so is one đời beside the unnumbered', () {
      expect(
        filterOf(<int?, int>{1: 5, unknownGeneration: 1}).isWorthShowing,
        isTrue,
      );
    });

    test('an empty family is not', () {
      expect(filterOf(const <int?, int>{}).isWorthShowing, isFalse);
    });
  });

  group('the count says which đời is being read', () {
    Future<void> showRow(WidgetTester tester, GenerationChoice chosen) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppText.localizationsDelegates,
          supportedLocales: AppText.supportedLocales,
          home: Scaffold(
            body: GenerationFilter(
              counts: const <int?, int>{1: 3, 2: 7},
              chosen: chosen,
              onChosen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The colour painted behind [count].
    ///
    /// Read off the decoration rather than compared against a constant, so a
    /// badge that stopped being drawn at all would fail rather than pass.
    Color badgeBehind(WidgetTester tester, String count) {
      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.text(count),
              matching: find.byType(Container),
            )
            .first,
      );
      return ((box.decoration ?? const BoxDecoration()) as BoxDecoration)
          .color!;
    }

    testWidgets('red on the đời chosen', (tester) async {
      await showRow(tester, 2);

      expect(badgeBehind(tester, '7'), GroupedColors.red);
    });

    testWidgets('grey on the rest', (tester) async {
      await showRow(tester, 2);

      // Both the other đời and the "all" chip, whose badge is the whole.
      expect(badgeBehind(tester, '3'), GroupedColors.grey);
      expect(badgeBehind(tester, '10'), GroupedColors.grey);
    });

    testWidgets('the whole is red when no đời is chosen', (tester) async {
      await showRow(tester, null);

      expect(badgeBehind(tester, '10'), GroupedColors.red);
      expect(badgeBehind(tester, '3'), GroupedColors.grey);
      expect(badgeBehind(tester, '7'), GroupedColors.grey);
    });

    testWidgets('the count is set inside the chip, not hung off it', (
      tester,
    ) async {
      await showRow(tester, 2);

      // As a badge it was positioned outside the chip's own bounds and drew
      // over whatever was there. Set in the line, it is within them.
      final chip = tester.getRect(find.byType(ChoiceChip).last);
      final count = tester.getRect(find.text('7'));

      expect(
        count.center.dy,
        moreOrLessEquals(chip.center.dy, epsilon: 1.5),
      );
      expect(chip.contains(count.topLeft), isTrue, reason: 'left and top');
      expect(
        chip.contains(count.bottomRight),
        isTrue,
        reason: 'right and bottom',
      );
    });

    testWidgets('label and count are centred together in the chip', (
      tester,
    ) async {
      await showRow(tester, 2);

      // Neither half is centred on its own: the pair is, which is what makes
      // the row read as one label rather than as text with a thing beside it.
      final chipAt = find.byType(ChoiceChip).last;
      final chip = tester.getRect(chipAt);
      // The pill, not the digit inside it: the digit is narrower than its own
      // minimum width, so measuring the text would read as off-centre when
      // the thing that is drawn is not.
      final count = tester.getRect(
        find.ancestor(of: find.text('7'), matching: find.byType(Container)),
      );
      // The chip's wording is localised, so it is found by not being the
      // number rather than by being any particular sentence.
      final label = tester.getRect(
        find.descendant(
          of: chipAt,
          matching: find.byWidgetPredicate(
            (w) => w is Text && w.data != null && w.data != '7',
          ),
        ),
      );

      expect(
        label.left - chip.left,
        moreOrLessEquals(chip.right - count.right, epsilon: 4),
        reason: 'the same air either side of the pair',
      );
      expect(
        label.right,
        lessThan(count.left),
        reason: 'the count follows the label rather than overlapping it',
      );
    });
  });
}
