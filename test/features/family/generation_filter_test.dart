import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/person.dart';
import 'package:ftree/features/family/generation_filter.dart';

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
}
