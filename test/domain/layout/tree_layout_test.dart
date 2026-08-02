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

  group('placement', () {
    const metrics = LayoutMetrics();

    /// Fails if any two boxes share space. The property a coordinate assertion
    /// cannot express, and the one a reader of the chart notices first.
    void expectNoOverlap(TreeLayout layout) {
      for (var i = 0; i < layout.nodes.length; i++) {
        for (var j = i + 1; j < layout.nodes.length; j++) {
          final a = layout.nodes[i];
          final b = layout.nodes[j];

          final overlapsHorizontally =
              a.x < b.x + metrics.nodeWidth && b.x < a.x + metrics.nodeWidth;
          final overlapsVertically =
              a.y < b.y + metrics.nodeHeight && b.y < a.y + metrics.nodeHeight;

          expect(
            overlapsHorizontally && overlapsVertically,
            isFalse,
            reason:
                '${a.person.id} at (${a.x}, ${a.y}) overlaps '
                '${b.person.id} at (${b.x}, ${b.y})',
          );
        }
      }
    }

    double centreOf(TreeLayout layout, String id) =>
        layout.nodeFor(id)!.x + metrics.nodeWidth / 2;

    test('a lone root sits at the origin', () {
      final layout = layoutDescendants(
        graphOf(<String>['a'], const <Relationship>[]),
        'a',
      );

      expect(layout.nodeFor('a')!.x, 0);
      expect(layout.nodeFor('a')!.y, 0);
    });

    test('an unknown root gives an empty chart', () {
      final layout = layoutDescendants(
        graphOf(<String>['a'], const <Relationship>[]),
        'nobody',
      );

      expect(layout.nodes, isEmpty);
      expect(layout.edges, isEmpty);
    });

    test('generations are stacked by depth', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[parentOf('a', 'b'), parentOf('b', 'c')],
        ),
        'a',
      );

      expect(layout.nodeFor('a')!.y, 0);
      expect(layout.nodeFor('b')!.y, metrics.generationHeight);
      expect(layout.nodeFor('c')!.y, 2 * metrics.generationHeight);
    });

    test('siblings sit side by side without touching', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[parentOf('a', 'b'), parentOf('a', 'c')],
        ),
        'a',
      );

      final gap =
          (layout.nodeFor('c')!.x - layout.nodeFor('b')!.x).abs();
      expect(gap, metrics.slotWidth);
      expectNoOverlap(layout);
    });

    test('a parent is centred over its children', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[parentOf('a', 'b'), parentOf('a', 'c')],
        ),
        'a',
      );

      final childMidpoint =
          (centreOf(layout, 'b') + centreOf(layout, 'c')) / 2;
      expect(centreOf(layout, 'a'), closeTo(childMidpoint, 0.001));
    });

    test('a spouse is drawn closer than a sibling would be', () {
      // What makes a couple read as a couple rather than as two neighbours.
      final layout = layoutDescendants(
        graphOf(<String>['a', 'w'], <Relationship>[spouseOf('a', 'w')]),
        'a',
      );

      final gap = (layout.nodeFor('w')!.x - layout.nodeFor('a')!.x).abs();
      expect(gap, metrics.spouseSlotWidth);
      expect(gap, lessThan(metrics.slotWidth));
      expect(layout.nodeFor('w')!.y, layout.nodeFor('a')!.y);
    });

    test('children hang below the couple, not below one partner', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'b', 'c'],
          <Relationship>[
            spouseOf('a', 'w'),
            parentOf('a', 'b'),
            parentOf('w', 'b'),
            parentOf('a', 'c'),
          ],
        ),
        'a',
      );

      expect(layout.nodeFor('b')!.generation, 1);
      expect(layout.nodeFor('c')!.generation, 1);
      expectNoOverlap(layout);
    });

    test('a child of both parents is drawn once', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'b'],
          <Relationship>[
            spouseOf('a', 'w'),
            parentOf('a', 'b'),
            parentOf('w', 'b'),
          ],
        ),
        'a',
      );

      expect(layout.nodes.where((n) => n.person.id == 'b').length, 1);
    });

    test('nothing overlaps in a lopsided tree', () {
      // One branch three deep, another a single leaf. Uneven depth is where a
      // naive placement starts colliding.
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b', 'c', 'd', 'e'],
          <Relationship>[
            parentOf('a', 'b'),
            parentOf('b', 'c'),
            parentOf('c', 'd'),
            parentOf('a', 'e'),
          ],
        ),
        'a',
      );

      expect(layout.nodes.length, 5);
      expectNoOverlap(layout);
    });

    test('nothing overlaps across several marriages and half siblings', () {
      // The shape the M4 exit criterion names. a marries w1 and w2; each
      // marriage has children, who are half siblings to each other.
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w1', 'w2', 'c1', 'c2', 'c3'],
          <Relationship>[
            spouseOf('a', 'w1'),
            spouseOf('a', 'w2'),
            parentOf('a', 'c1'),
            parentOf('w1', 'c1'),
            parentOf('a', 'c2'),
            parentOf('w2', 'c2'),
            parentOf('a', 'c3'),
          ],
        ),
        'a',
      );

      expect(layout.nodes.length, 6);
      expectNoOverlap(layout);
    });

    test('nothing overlaps in a wide, deep family', () {
      final ids = <String>['root'];
      final edges = <Relationship>[];
      for (var branch = 0; branch < 4; branch++) {
        final child = 'c$branch';
        ids.add(child);
        edges.add(parentOf('root', child));
        for (var leaf = 0; leaf < 3; leaf++) {
          final grandchild = 'g$branch$leaf';
          ids.add(grandchild);
          edges.add(parentOf(child, grandchild));
        }
      }

      final layout = layoutDescendants(graphOf(ids, edges), 'root');

      expect(layout.nodes.length, 17);
      expect(layout.generationCount, 3);
      expectNoOverlap(layout);
    });

    test('is deterministic across runs', () {
      final graph = graphOf(
        <String>['a', 'b', 'c', 'd'],
        <Relationship>[
          parentOf('a', 'b'),
          parentOf('a', 'c'),
          parentOf('b', 'd'),
        ],
      );

      final first = layoutDescendants(graph, 'a');
      final second = layoutDescendants(graph, 'a');

      for (final node in first.nodes) {
        expect(second.nodeFor(node.person.id)!.x, node.x);
        expect(second.nodeFor(node.person.id)!.y, node.y);
      }
    });

    test('honours custom metrics', () {
      const wide = LayoutMetrics(nodeWidth: 300, verticalGap: 200);
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b'],
          <Relationship>[parentOf('a', 'b')],
        ),
        'a',
        metrics: wide,
      );

      expect(layout.nodeFor('b')!.y, wide.generationHeight);
      expect(layout.width, greaterThanOrEqualTo(300));
    });
  });

  group('edges', () {
    test('join each parent to each child', () {
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'b', 'c'],
          <Relationship>[parentOf('a', 'b'), parentOf('a', 'c')],
        ),
        'a',
      );

      final parentEdges = layout.edges
          .where((e) => e.kind == LayoutEdgeKind.parentChild)
          .map((e) => '${e.fromPersonId}->${e.toPersonId}')
          .toSet();

      expect(parentEdges, <String>{'a->b', 'a->c'});
    });

    test('join a couple', () {
      final layout = layoutDescendants(
        graphOf(<String>['a', 'w'], <Relationship>[spouseOf('a', 'w')]),
        'a',
      );

      final spouseEdges =
          layout.edges.where((e) => e.kind == LayoutEdgeKind.spouse).toList();

      expect(spouseEdges.length, 1);
      expect(
        <String>{spouseEdges.single.fromPersonId, spouseEdges.single.toPersonId},
        <String>{'a', 'w'},
      );
    });

    test('never name someone who is not on the chart', () {
      // A line to nowhere would crash the renderer or draw off the page.
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'b'],
          <Relationship>[spouseOf('a', 'w'), parentOf('a', 'b')],
        ),
        'a',
      );

      for (final edge in layout.edges) {
        expect(layout.nodeFor(edge.fromPersonId), isNotNull);
        expect(layout.nodeFor(edge.toPersonId), isNotNull);
      }
    });
  });

  group('placement on a corrupt graph', () {
    test('a loop finishes and draws each person once', () {
      final layout = layoutDescendants(
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

      expect(layout.nodes.length, 3);
      expect(layout.nodes.map((n) => n.person.id).toSet().length, 3);
    });

    test('someone recorded as their own parent finishes', () {
      final layout = layoutDescendants(
        graphOf(<String>['a'], <Relationship>[parentOf('a', 'a')]),
        'a',
      );

      expect(layout.nodes.length, 1);
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
