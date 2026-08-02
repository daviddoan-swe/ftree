import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/layout/tree_layout.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  const familyId = 'f1';

  Person personOf(String id) =>
      Person(id: id, familyId: familyId, displayName: 'Person $id');

  Relationship parentOf(String parent, String child) =>
      Relationship.parentChild(
        id: 'pc-$parent-$child',
        familyId: familyId,
        parent: parent,
        child: child,
      );

  Relationship spouseOf(String a, String b) => Relationship.spouse(
    id: 'sp-$a-$b',
    familyId: familyId,
    personA: a,
    personB: b,
  );

  FamilyGraph graphOf(
    Iterable<String> ids,
    Iterable<Relationship> relationships,
  ) => FamilyGraph(
    persons: ids.map(personOf),
    relationships: relationships,
  );

  group('LayoutMetrics', () {
    test('derives spacing from box size and gaps', () {
      const metrics = LayoutMetrics(
        nodeWidth: 100,
        nodeHeight: 50,
        horizontalGap: 20,
        verticalGap: 60,
        spouseGap: 5,
      );

      expect(metrics.slotWidth, 120);
      expect(metrics.spouseSlotWidth, 105);
      expect(metrics.generationHeight, 110);
    });

    test('places a couple closer than two strangers', () {
      // What makes a pair read as a pair rather than as neighbours.
      const metrics = LayoutMetrics();
      expect(metrics.spouseSlotWidth, lessThan(metrics.slotWidth));
    });
  });

  group('generation assignment', () {
    test('puts the root at zero', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(<String>['a'], const <Relationship>[]),
        'a',
      );

      expect(assignment.generationOf('a'), 0);
      expect(assignment.length, 1);
    });

    test('counts downwards through four generations', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'c', 'd'],
          <Relationship>[
            parentOf('a', 'b'),
            parentOf('b', 'c'),
            parentOf('c', 'd'),
          ],
        ),
        'a',
      );

      expect(assignment.generationOf('a'), 0);
      expect(assignment.generationOf('b'), 1);
      expect(assignment.generationOf('c'), 2);
      expect(assignment.generationOf('d'), 3);
      expect(assignment.generationCount, 4);
    });

    test('puts siblings on the same row', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[parentOf('a', 'b'), parentOf('a', 'c')],
        ),
        'a',
      );

      expect(assignment.generationOf('b'), 1);
      expect(assignment.generationOf('c'), 1);
      expect(assignment.atGeneration(1).map((p) => p.id), <String>['b', 'c']);
    });

    test('draws a spouse beside their partner, not below', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(<String>['a', 'w'], <Relationship>[spouseOf('a', 'w')]),
        'a',
      );

      expect(assignment.generationOf('w'), 0);
    });

    test('gives a married-in spouse their partner’s generation', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'w'],
          <Relationship>[parentOf('a', 'b'), spouseOf('b', 'w')],
        ),
        'a',
      );

      expect(assignment.generationOf('b'), 1);
      expect(assignment.generationOf('w'), 1);
    });

    test('lists a couple next to each other', () {
      // The placement pass relies on this ordering to keep pairs adjacent.
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'w', 'b'],
          <Relationship>[spouseOf('a', 'w'), parentOf('a', 'b')],
        ),
        'a',
      );

      final ids = assignment.order.map((p) => p.id).toList();
      expect(ids.indexOf('w') - ids.indexOf('a'), 1);
    });

    test('leaves out anyone the root cannot reach', () {
      // A descendant chart of one root, not the whole family. Isolated people
      // and unconnected branches are valid data (§17.3) but belong elsewhere.
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'stranger'],
          <Relationship>[parentOf('a', 'b')],
        ),
        'a',
      );

      expect(assignment.includes('stranger'), isFalse);
      expect(assignment.generationOf('stranger'), isNull);
      expect(assignment.length, 2);
    });

    test('does not walk upwards to the root’s own parents', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['grandparent', 'a', 'b'],
          <Relationship>[parentOf('grandparent', 'a'), parentOf('a', 'b')],
        ),
        'a',
      );

      expect(assignment.includes('grandparent'), isFalse);
      expect(assignment.includes('b'), isTrue);
    });

    test('an unknown root produces an empty chart', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(<String>['a'], const <Relationship>[]),
        'nobody',
      );

      expect(assignment.length, 0);
      expect(assignment.generationCount, 0);
    });

    test('keeps the shallower generation when two routes reach a person', () {
      // a is both parent and grandparent of d, through b. Breadth-first order
      // means the shorter route wins.
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'd'],
          <Relationship>[
            parentOf('a', 'b'),
            parentOf('a', 'd'),
            parentOf('b', 'd'),
          ],
        ),
        'a',
      );

      expect(assignment.generationOf('d'), 1);
    });
  });

  group('a graph containing a cycle', () {
    test('assignment finishes rather than hanging', () {
      // Two devices editing offline can each add a valid edge that together
      // close a loop (§6.2). The chart must still draw.
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[
            parentOf('a', 'b'),
            parentOf('b', 'c'),
            parentOf('c', 'a'),
          ],
        ),
        'a',
      );

      expect(assignment.length, 3);
      expect(assignment.generationOf('a'), 0);
    });

    test('someone recorded as their own parent finishes too', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(<String>['a'], <Relationship>[parentOf('a', 'a')]),
        'a',
      );

      expect(assignment.generationOf('a'), 0);
      expect(assignment.length, 1);
    });

    test('a spouse loop finishes', () {
      final assignment = GenerationAssignment.fromRoot(
        graphOf(
          <String>['a', 'w'],
          <Relationship>[spouseOf('a', 'w'), spouseOf('w', 'a')],
        ),
        'a',
      );

      expect(assignment.length, 2);
    });
  });

  group('TreeLayout', () {
    const metrics = LayoutMetrics();

    TreeLayout layoutOf(List<LayoutNode> nodes) =>
        TreeLayout(nodes: nodes, edges: const <LayoutEdge>[], metrics: metrics);

    test('is empty in every measure when nothing was placed', () {
      final layout = layoutOf(const <LayoutNode>[]);

      expect(layout.width, 0);
      expect(layout.height, 0);
      expect(layout.generationCount, 0);
      expect(layout.nodeFor('a'), isNull);
    });

    test('measures to the far edge of the last box, not its origin', () {
      final layout = layoutOf(<LayoutNode>[
        LayoutNode(person: personOf('a'), generation: 0, x: 0, y: 0),
        LayoutNode(person: personOf('b'), generation: 1, x: 200, y: 140),
      ]);

      expect(layout.width, 200 + metrics.nodeWidth);
      expect(layout.height, 140 + metrics.nodeHeight);
    });

    test('finds a placed person by id', () {
      final layout = layoutOf(<LayoutNode>[
        LayoutNode(person: personOf('a'), generation: 0, x: 10, y: 20),
      ]);

      expect(layout.nodeFor('a')!.x, 10);
      expect(layout.nodeFor('missing'), isNull);
    });

    test('counts generations from the deepest node', () {
      final layout = layoutOf(<LayoutNode>[
        LayoutNode(person: personOf('a'), generation: 0, x: 0, y: 0),
        LayoutNode(person: personOf('b'), generation: 2, x: 0, y: 280),
      ]);

      expect(layout.generationCount, 3);
    });
  });
}
