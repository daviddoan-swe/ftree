import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/genealogical_date.dart';
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

      expect(metrics.siblingStride, 120);
      expect(metrics.spouseStride, 105);
      expect(metrics.generationStride, 110);
    });

    test('places a couple closer than two strangers', () {
      // What makes a pair read as a pair rather than as neighbours.
      const metrics = LayoutMetrics();
      expect(metrics.spouseStride, lessThan(metrics.siblingStride));
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
      expect(layout.nodeFor('b')!.y, metrics.generationStride);
      expect(layout.nodeFor('c')!.y, 2 * metrics.generationStride);
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
      expect(gap, metrics.siblingStride);
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
      expect(gap, metrics.spouseStride);
      expect(gap, lessThan(metrics.siblingStride));
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

      expect(layout.nodeFor('b')!.y, wide.generationStride);
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

    test('drop from the couple’s middle, not from one partner', () {
      // Children belong to both partners. A line leaving the husband's box
      // makes them look like his alone — the defect the rendered preview
      // exposed and that no coordinate assertion had caught.
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'c1', 'c2'],
          <Relationship>[
            spouseOf('a', 'w'),
            parentOf('a', 'c1'),
            parentOf('w', 'c1'),
            parentOf('a', 'c2'),
            parentOf('w', 'c2'),
          ],
        ),
        'a',
      );

      final husband = layout.nodeFor('a')!;
      final wife = layout.nodeFor('w')!;
      final coupleCentre =
          (husband.x + wife.x + metrics.nodeWidth) / 2;

      for (final edge in layout.edges.where(
        (e) => e.kind == LayoutEdgeKind.parentChild,
      )) {
        expect(
          edge.fromAnchorAlong,
          closeTo(coupleCentre, 0.001),
          reason: 'child ${edge.toPersonId}',
        );
        expect(
          edge.fromAnchorAlong,
          isNot(closeTo(husband.x + metrics.nodeWidth / 2, 0.001)),
          reason: 'must not sit on the husband alone',
        );
      }
    });

    test('the anchor sits over the middle of the children', () {
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'c1', 'c2'],
          <Relationship>[
            spouseOf('a', 'w'),
            parentOf('a', 'c1'),
            parentOf('w', 'c1'),
            parentOf('a', 'c2'),
            parentOf('w', 'c2'),
          ],
        ),
        'a',
      );

      double centre(String id) =>
          layout.nodeFor(id)!.x + metrics.nodeWidth / 2;
      final childMidpoint = (centre('c1') + centre('c2')) / 2;

      final anchor = layout.edges
          .firstWhere((e) => e.kind == LayoutEdgeKind.parentChild)
          .fromAnchorAlong;

      expect(anchor, closeTo(childMidpoint, 0.001));
    });

    test('a parent with no spouse anchors on their own centre', () {
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'c'],
          <Relationship>[parentOf('a', 'c')],
        ),
        'a',
      );

      final anchor = layout.edges.single.fromAnchorAlong;
      expect(
        anchor,
        closeTo(layout.nodeFor('a')!.x + metrics.nodeWidth / 2, 0.001),
      );
    });

    test('meet the middle of their own horizontal bar', () {
      // The second defect the preview exposed. A connector joins a child's
      // box, so the parent must centre over those boxes. Centring over child
      // *units* instead — child plus their spouse — leaves the vertical line
      // off to one side of the bar it draws, but only once a child is married,
      // which is why no earlier test saw it.
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['root', 'married', 'spouse', 'single'],
          <Relationship>[
            parentOf('root', 'married'),
            parentOf('root', 'single'),
            spouseOf('married', 'spouse'),
          ],
        ),
        'root',
      );

      double centre(String id) =>
          layout.nodeFor(id)!.x + metrics.nodeWidth / 2;

      final barMidpoint = (centre('married') + centre('single')) / 2;
      final anchors = layout.edges
          .where((e) => e.kind == LayoutEdgeKind.parentChild)
          .map((e) => e.fromAnchorAlong)
          .toSet();

      expect(anchors.length, 1, reason: 'both children share one drop point');
      expect(anchors.single, closeTo(barMidpoint, 0.001));
    });

    test('hang each marriage’s children from that marriage', () {
      // Which wife a child belongs to is information the data holds and a gia
      // phả cares about. Hanging everyone from the middle of the whole group
      // would flatten it away.
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w1', 'w2', 'c1', 'c2'],
          <Relationship>[
            spouseOf('a', 'w1'),
            spouseOf('a', 'w2'),
            parentOf('a', 'c1'),
            parentOf('w1', 'c1'),
            parentOf('a', 'c2'),
            parentOf('w2', 'c2'),
          ],
        ),
        'a',
      );

      double centre(String id) =>
          layout.nodeFor(id)!.x + metrics.nodeWidth / 2;
      double anchorTo(String childId) => layout.edges
          .firstWhere(
            (e) =>
                e.kind == LayoutEdgeKind.parentChild &&
                e.toPersonId == childId,
          )
          .fromAnchorAlong;

      // Each drop point is the gap immediately before that wife's box.
      double gapBefore(String id) =>
          layout.nodeFor(id)!.x - metrics.spouseGap / 2;

      expect(
        anchorTo('c1'),
        closeTo(gapBefore('w1'), 0.001),
        reason: 'first wife’s child',
      );
      expect(
        anchorTo('c2'),
        closeTo(gapBefore('w2'), 0.001),
        reason: 'second wife’s child',
      );
      expect(anchorTo('c1'), isNot(closeTo(anchorTo('c2'), 0.001)));
      // The first wife's centre is exactly the midpoint between the husband and
      // the second wife, so a midpoint rule would drop the second wife's child
      // through the first wife's box and read as her child.
      expect(anchorTo('c2'), isNot(closeTo(centre('w1'), 0.001)));
    });

    test('never drop a connector through somebody else’s box', () {
      // Only visible by looking at the chart: the second wife's children hung
      // from the middle of the first wife. Every drop point must land in a gap.
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w1', 'w2', 'w3', 'c1', 'c2', 'c3'],
          <Relationship>[
            spouseOf('a', 'w1'),
            spouseOf('a', 'w2'),
            spouseOf('a', 'w3'),
            parentOf('a', 'c1'),
            parentOf('w1', 'c1'),
            parentOf('a', 'c2'),
            parentOf('w2', 'c2'),
            parentOf('a', 'c3'),
            parentOf('w3', 'c3'),
          ],
        ),
        'a',
      );

      for (final edge in layout.edges.where(
        (e) => e.kind == LayoutEdgeKind.parentChild,
      )) {
        final parent = layout.nodeFor(edge.fromPersonId)!;
        for (final node in layout.nodes) {
          if (node.generation != parent.generation) continue;
          final inside =
              edge.fromAnchorAlong > node.x &&
              edge.fromAnchorAlong < node.x + metrics.nodeWidth;
          expect(
            inside,
            isFalse,
            reason:
                'the line to ${edge.toPersonId} passes through '
                '${node.person.id}',
          );
        }
      }
    });

    test('keep children in the order the graph gives them', () {
      // Regrouping the children by marriage would guarantee the connectors
      // never cross, but it would put Con Thứ before Con Cả, which is worse.
      // With no dates recorded, that order is the one the data was entered in
      // (§13.3), and the layout must not shuffle it.
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'eldest', 'second'],
          <Relationship>[
            spouseOf('a', 'w'),
            // The eldest has a recorded mother; the second does not.
            parentOf('a', 'eldest'),
            parentOf('w', 'eldest'),
            parentOf('a', 'second'),
          ],
        ),
        'a',
      );

      expect(
        layout.nodeFor('eldest')!.x,
        lessThan(layout.nodeFor('second')!.x),
      );
    });

    test('draw the eldest leftmost even when entered last', () {
      // The whole reason the graph orders children by birth: a transcriber
      // filling in Con Thứ first must not produce a chart that reads wrong.
      final layout = layoutDescendants(
        FamilyGraph(
          persons: <Person>[
            Person(id: 'a', familyId: 'f', displayName: 'Cha'),
            Person(
              id: 'second',
              familyId: 'f',
              displayName: 'Con Thứ',
              birthDate: GenealogicalDate(year: 1915),
            ),
            Person(
              id: 'eldest',
              familyId: 'f',
              displayName: 'Con Cả',
              birthDate: GenealogicalDate(year: 1912),
            ),
          ],
          relationships: <Relationship>[
            parentOf('a', 'second'),
            parentOf('a', 'eldest'),
          ],
        ),
        'a',
      );

      expect(
        layout.nodeFor('eldest')!.x,
        lessThan(layout.nodeFor('second')!.x),
      );
    });

    test('a child with no recorded second parent hangs from the whole unit',
        () {
      // Anchoring them on the person alone would assert they came from no
      // marriage, when the usual reading is that the other parent is simply
      // unrecorded. With one spouse it would also cross their siblings' lines
      // for no reason: here both children share the same anchor.
      const metrics = LayoutMetrics();
      final layout = layoutDescendants(
        graphOf(
          <String>['a', 'w', 'shared', 'unrecorded'],
          <Relationship>[
            spouseOf('a', 'w'),
            parentOf('a', 'shared'),
            parentOf('w', 'shared'),
            parentOf('a', 'unrecorded'),
          ],
        ),
        'a',
      );

      double centre(String id) =>
          layout.nodeFor(id)!.x + metrics.nodeWidth / 2;
      double anchorTo(String childId) => layout.edges
          .firstWhere(
            (e) =>
                e.kind == LayoutEdgeKind.parentChild &&
                e.toPersonId == childId,
          )
          .fromAnchorAlong;

      final coupleCentre = (centre('a') + centre('w')) / 2;
      expect(anchorTo('shared'), closeTo(coupleCentre, 0.001));
      expect(anchorTo('unrecorded'), closeTo(coupleCentre, 0.001));
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

  group('folding a branch away', () {
    /// Three generations: a couple, their two children, and four grandchildren.
    FamilyGraph threeGenerations() => graphOf(
      <String>['a', 'a2', 'b', 'c', 'd', 'e', 'f', 'g'],
      <Relationship>[
        spouseOf('a', 'a2'),
        parentOf('a', 'b'), parentOf('a2', 'b'),
        parentOf('a', 'c'), parentOf('a2', 'c'),
        parentOf('b', 'd'), parentOf('b', 'e'),
        parentOf('c', 'f'), parentOf('c', 'g'),
      ],
    );

    test('a folded person is drawn, their children are not', () {
      final layout = layoutDescendants(
        threeGenerations(), 'a', collapsed: <String>{'b'},
      );

      expect(layout.nodeFor('b'), isNotNull, reason: 'the box itself stays');
      expect(layout.nodeFor('d'), isNull);
      expect(layout.nodeFor('e'), isNull);
      expect(layout.nodeFor('f'), isNotNull, reason: 'a sibling is untouched');
    });

    test('the badge counts everyone the box stands in front of', () {
      final layout = layoutDescendants(
        threeGenerations(), 'a', collapsed: <String>{'b'},
      );

      expect(layout.nodeFor('b')!.hiddenDescendantCount, 2);
      expect(layout.nodeFor('b')!.hidesDescendants, isTrue);
    });

    test('nothing is claimed where nothing is folded', () {
      final layout = layoutDescendants(threeGenerations(), 'a');

      expect(
        layout.nodes.every((n) => n.hiddenDescendantCount == 0),
        isTrue,
      );
      expect(layout.nodeFor('b')!.hidesDescendants, isFalse);
    });

    test('the count reaches past the folded generation, not just to it', () {
      // Folding 'a' hides two children and four grandchildren.
      final layout = layoutDescendants(
        threeGenerations(), 'a', collapsed: <String>{'a'},
      );

      expect(layout.nodeFor('a')!.hiddenDescendantCount, 6);
      expect(layout.nodes.length, 2, reason: 'the couple, and nobody else');
    });

    test('a spouse folded with the head is drawn beside them', () {
      final layout = layoutDescendants(
        threeGenerations(), 'a', collapsed: <String>{'a', 'a2'},
      );

      expect(layout.nodeFor('a2'), isNotNull);
      expect(layout.nodeFor('a2')!.hiddenDescendantCount, 0,
          reason: 'the number belongs on the head, said once');
    });

    test('the unit hides a partner\'s children by an earlier marriage', () {
      // 'a' and 'a2' are married; 'a2' also has 'x' from before. Folding the
      // head has to account for 'x', who hangs from the same unit.
      final graph = graphOf(
        <String>['a', 'a2', 'b', 'x'],
        <Relationship>[
          spouseOf('a', 'a2'),
          parentOf('a', 'b'), parentOf('a2', 'b'),
          parentOf('a2', 'x'),
        ],
      );
      final layout = layoutDescendants(graph, 'a', collapsed: <String>{'a'});

      expect(layout.nodeFor('x'), isNull);
      expect(layout.nodeFor('a')!.hiddenDescendantCount, 2);
    });

    test('folding somebody childless changes nothing', () {
      final layout = layoutDescendants(
        threeGenerations(), 'a', collapsed: <String>{'d'},
      );

      expect(layout.nodes.length, 8);
      expect(layout.nodeFor('d')!.hiddenDescendantCount, 0);
    });

    test('nobody is counted twice when two folded units share a child', () {
      // 'd' is a child of both 'b' and 'c'. Folding both must not report four
      // hidden people where there are three.
      final graph = graphOf(
        <String>['a', 'b', 'c', 'd'],
        <Relationship>[
          parentOf('a', 'b'), parentOf('a', 'c'),
          parentOf('b', 'd'), parentOf('c', 'd'),
        ],
      );
      final layout = layoutDescendants(
        graph, 'a', collapsed: <String>{'b', 'c'},
      );

      expect(layout.nodeFor('b')!.hiddenDescendantCount, 1);
      expect(layout.nodeFor('c')!.hiddenDescendantCount, 1);
    });

    test('a descendant drawn elsewhere is not reported as hidden', () {
      // 'd' hangs from 'b' as well as from the folded 'c', and 'b' is open, so
      // 'd' is on the chart. Nothing is behind 'c' that cannot be seen.
      final graph = graphOf(
        <String>['a', 'b', 'c', 'd'],
        <Relationship>[
          parentOf('a', 'b'), parentOf('a', 'c'),
          parentOf('b', 'd'), parentOf('c', 'd'),
        ],
      );
      final layout = layoutDescendants(graph, 'a', collapsed: <String>{'c'});

      expect(layout.nodeFor('d'), isNotNull);
      expect(layout.nodeFor('c')!.hiddenDescendantCount, 0);
      expect(layout.nodeFor('c')!.hidesDescendants, isFalse);
    });

    test('folding narrows the chart, which is the whole point', () {
      final graph = threeGenerations();
      final open = layoutDescendants(graph, 'a');
      final shut = layoutDescendants(
        graph, 'a', collapsed: <String>{'b', 'c'},
      );

      expect(shut.width, lessThan(open.width));
    });

    test('survives a graph that loops back on itself', () {
      // A cycle can arrive through synchronisation (DOMAIN.md 6.2). Folding
      // must not turn that into a hang.
      final graph = graphOf(
        <String>['a', 'b', 'c'],
        <Relationship>[
          parentOf('a', 'b'), parentOf('b', 'c'), parentOf('c', 'a'),
        ],
      );

      final layout = layoutDescendants(graph, 'a', collapsed: <String>{'b'});

      expect(layout.nodeFor('a'), isNotNull);
      expect(layout.nodeFor('c'), isNull);
    });
  });

  group('collapseToDepth', () {
    FamilyGraph fourGenerations() => graphOf(
      <String>['a', 'b', 'c', 'd'],
      <Relationship>[parentOf('a', 'b'), parentOf('b', 'c'), parentOf('c', 'd')],
    );

    test('folds the last visible generation, and everything under it', () {
      final folded = collapseToDepth(
        fourGenerations(), 'a', visibleGenerations: 2,
      );

      // 'b' is the last visible; 'c' is already out of sight but folded too,
      // so that opening 'b' does not spill the whole line onto the chart.
      expect(folded, <String>{'b', 'c'});
    });

    test('opening one fold reveals exactly one more generation', () {
      final graph = fourGenerations();
      final folded = collapseToDepth(graph, 'a', visibleGenerations: 2);

      final opened = layoutDescendants(
        graph, 'a', collapsed: folded.difference(<String>{'b'}),
      );

      expect(opened.nodeFor('c'), isNotNull);
      expect(opened.nodeFor('d'), isNull, reason: 'the next fold still holds');
    });

    test('leaves a chart alone when it already fits', () {
      expect(
        collapseToDepth(fourGenerations(), 'a', visibleGenerations: 9),
        isEmpty,
      );
    });

    test('never folds somebody with no children', () {
      final folded = collapseToDepth(
        fourGenerations(), 'a', visibleGenerations: 1,
      );

      expect(folded, <String>{'a', 'b', 'c'});
      expect(folded, isNot(contains('d')), reason: 'a leaf hides nothing');
    });

    test('showing one generation leaves the root and nothing else', () {
      final graph = fourGenerations();
      final layout = layoutDescendants(
        graph,
        'a',
        collapsed: collapseToDepth(graph, 'a', visibleGenerations: 1),
      );

      expect(layout.nodes.map((n) => n.person.id), <String>['a']);
      expect(layout.nodeFor('a')!.hiddenDescendantCount, 3);
    });

    test('refuses a chart that shows nothing', () {
      expect(
        () => collapseToDepth(fourGenerations(), 'a', visibleGenerations: 0),
        throwsArgumentError,
      );
    });
  });

  group('turned on its side', () {
    const sideways = LayoutMetrics(orientation: TreeOrientation.leftToRight);

    FamilyGraph couple() => graphOf(
      <String>['a', 'a2', 'b', 'c'],
      <Relationship>[
        spouseOf('a', 'a2'),
        parentOf('a', 'b'), parentOf('a2', 'b'),
        parentOf('a', 'c'), parentOf('a2', 'c'),
      ],
    );

    test('generations run across, and siblings down', () {
      final layout = layoutDescendants(couple(), 'a', metrics: sideways);

      final root = layout.nodeFor('a')!;
      final child = layout.nodeFor('b')!;

      expect(child.x, greaterThan(root.x), reason: 'a generation across');
      expect(child.generation, root.generation + 1);

      final other = layout.nodeFor('c')!;
      expect(other.x, child.x, reason: 'siblings share a generation column');
      expect(other.y, isNot(child.y), reason: 'and are spread down it');
    });

    test('a couple is stacked, not laid side by side', () {
      final layout = layoutDescendants(couple(), 'a', metrics: sideways);

      final person = layout.nodeFor('a')!;
      final spouse = layout.nodeFor('a2')!;

      expect(spouse.x, person.x, reason: 'the same generation');
      expect(
        spouse.y - person.y,
        sideways.spouseStride,
        reason: 'and closer together than two siblings would be',
      );
      expect(sideways.spouseStride, lessThan(sideways.siblingStride));
    });

    test('the generation stride follows the box, not the other axis', () {
      // Across, a generation has to clear the width of a box; down, its
      // height. Reusing one number for both would overlap the boxes in
      // whichever orientation it was not chosen for.
      expect(
        sideways.generationStride,
        sideways.nodeWidth + sideways.verticalGap,
      );
      expect(
        const LayoutMetrics().generationStride,
        sideways.nodeHeight + sideways.verticalGap,
      );
      expect(sideways.nodeExtent, sideways.nodeHeight);
      expect(const LayoutMetrics().nodeExtent, sideways.nodeWidth);
    });

    test('it is the same arrangement, only transposed', () {
      // Same people, same generations, same number of lines. Turning the page
      // must not change who is drawn or what joins them.
      final graph = couple();
      final down = layoutDescendants(graph, 'a');
      final across = layoutDescendants(graph, 'a', metrics: sideways);

      expect(
        across.nodes.map((n) => n.person.id),
        down.nodes.map((n) => n.person.id),
      );
      expect(across.edges.length, down.edges.length);
      expect(across.generationCount, down.generationCount);
    });

    test('folding narrows the side that a phone is narrow in', () {
      // The reason for having the orientation at all. Folded to three
      // generations, the axis a fold can bound is the short one; the axis it
      // cannot bound runs the way a phone scrolls.
      // Wide rather than deep, which is the shape that makes the orientation
      // worth having: ten in a generation against two generations drawn. A
      // family with more generations than siblings is wider turned sideways,
      // and there the upright chart is the better of the two.
      final ids = <String>['a', for (var n = 0; n < 30; n++) 'k$n'];
      final links = <Relationship>[
        for (var n = 0; n < 10; n++) parentOf('a', 'k$n'),
        for (var n = 0; n < 10; n++) ...<Relationship>[
          parentOf('k$n', 'k${10 + n}'),
          parentOf('k$n', 'k${20 + n}'),
        ],
      ];
      final graph = graphOf(ids, links);
      final folded = collapseToDepth(graph, 'a', visibleGenerations: 2);

      final down = layoutDescendants(graph, 'a', collapsed: folded);
      final across = layoutDescendants(
        graph, 'a', collapsed: folded, metrics: sideways,
      );

      expect(down.width, greaterThan(down.height));
      expect(across.height, greaterThan(across.width));
      expect(across.width, lessThan(down.width));
    });

    test('the badge count does not depend on which way the page is turned', () {
      final graph = graphOf(
        <String>['a', 'b', 'c'],
        <Relationship>[parentOf('a', 'b'), parentOf('b', 'c')],
      );

      final down = layoutDescendants(graph, 'a', collapsed: <String>{'b'});
      final across = layoutDescendants(
        graph, 'a', collapsed: <String>{'b'}, metrics: sideways,
      );

      expect(down.nodeFor('b')!.hiddenDescendantCount, 1);
      expect(across.nodeFor('b')!.hiddenDescendantCount, 1);
    });
  });
}
