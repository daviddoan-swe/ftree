/// A throwaway renderer for looking at the layout engine's output.
///
/// ARCHITECTURE §14.1: unit tests can assert a node sits at (100, 50), but they
/// cannot say whether connectors cross or whether the result reads as a family
/// tree. This exists to close that loop and nothing more — boxes, straight
/// lines, no styling, no interaction.
///
/// Run it with:
///
/// ```sh
/// flutter run -t lib/dev/layout_preview.dart
/// ```
///
/// It is deliberately not `lib/main.dart`. The real interface is M5, and this
/// should be deleted once that exists rather than grown into it.
library;

import 'package:flutter/material.dart';

import '../domain/family_graph.dart';
import '../domain/layout/tree_layout.dart';
import '../domain/person.dart';
import '../domain/relationship.dart';

void main() {
  runApp(const LayoutPreviewApp());
}

/// The sample families to look at.
///
/// Chosen to be the shapes a layout gets wrong: uneven branch depth, several
/// marriages, half siblings, and a graph with a loop in it.
final Map<String, ({FamilyGraph graph, String rootId})> _samples = {
  'Half siblings, two marriages': _halfSiblings(),
  'Four generations': _fourGenerations(),
  'Lopsided branches': _lopsided(),
  'Wide family': _wide(),
  'Corrupt: contains a loop': _looped(),
};

class LayoutPreviewApp extends StatelessWidget {
  const LayoutPreviewApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Layout preview',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
    home: const _PreviewScreen(),
  );
}

/// Every sample stacked in one scroll, each scaled to fit the width.
///
/// Not a menu of charts to tap between: a screenshot is the point, and a
/// simulator cannot be tapped from a script. One pass down this screen shows
/// every shape the layout is meant to handle.
class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Layout preview')),
    body: ListView(
      children: <Widget>[
        for (final entry in _samples.entries)
          _SampleCard(title: entry.key, sample: entry.value),
      ],
    ),
  );
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({required this.title, required this.sample});

  final String title;
  final ({FamilyGraph graph, String rootId}) sample;

  @override
  Widget build(BuildContext context) {
    final layout = layoutDescendants(sample.graph, sample.rootId);
    final canvasSize = Size(layout.width + 80, layout.height + 80);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${layout.nodes.length} people · '
            '${layout.generationCount} generations · '
            '${layout.width.round()}×${layout.height.round()}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          // Scaled to fit rather than panned, so the whole shape is visible at
          // once and a screenshot captures it.
          FittedBox(
            child: SizedBox.fromSize(
              size: canvasSize,
              child: CustomPaint(
                size: canvasSize,
                painter: _TreePainter(layout),
              ),
            ),
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// Draws the layout exactly as given: a rectangle per node, a line per edge.
///
/// Nothing here adjusts positions. If the picture looks wrong, the engine is
/// wrong — which is the whole point of having it.
class _TreePainter extends CustomPainter {
  const _TreePainter(this.layout);

  final TreeLayout layout;

  static const double _padding = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = layout.metrics;

    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.teal.shade700;
    final parentLine = Paint()
      ..strokeWidth = 1.5
      ..color = Colors.blueGrey.shade600;
    final spouseLine = Paint()
      ..strokeWidth = 3
      ..color = Colors.pink.shade400;

    Offset centreOf(LayoutNode node) => Offset(
      node.x + metrics.nodeWidth / 2 + _padding,
      node.y + metrics.nodeHeight / 2 + _padding,
    );

    for (final edge in layout.edges) {
      final from = layout.nodeFor(edge.fromPersonId);
      final to = layout.nodeFor(edge.toPersonId);
      if (from == null || to == null) continue;

      switch (edge.kind) {
        case LayoutEdgeKind.spouse:
          canvas.drawLine(centreOf(from), centreOf(to), spouseLine);
        case LayoutEdgeKind.parentChild:
          // Elbow rather than a diagonal: crossings are far easier to see.
          // The horizontal origin comes from the edge, not from the box, so a
          // couple's children hang from between the pair.
          final start = Offset(
            edge.fromAnchorX + _padding,
            from.y + metrics.nodeHeight + _padding,
          );
          final end = Offset(centreOf(to).dx, to.y + _padding);
          final midY = (start.dy + end.dy) / 2;

          canvas
            ..drawLine(start, Offset(start.dx, midY), parentLine)
            ..drawLine(Offset(start.dx, midY), Offset(end.dx, midY), parentLine)
            ..drawLine(Offset(end.dx, midY), end, parentLine);
      }
    }

    for (final node in layout.nodes) {
      final rect = Rect.fromLTWH(
        node.x + _padding,
        node.y + _padding,
        metrics.nodeWidth,
        metrics.nodeHeight,
      );
      canvas
        ..drawRect(rect, Paint()..color = Colors.white)
        ..drawRect(rect, boxPaint);

      final label = TextPainter(
        text: TextSpan(
          text: '${node.person.displayName}\ngen ${node.generation}',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: metrics.nodeWidth - 8);

      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          rect.center.dy - label.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_TreePainter oldDelegate) => oldDelegate.layout != layout;
}

// ------------------------------------------------------------- samples ---

const String _familyId = 'preview';

Person _person(String id, String name) =>
    Person(id: id, familyId: _familyId, displayName: name);

Relationship _parent(String parent, String child) =>
    Relationship.parentChild(
      id: 'pc-$parent-$child',
      familyId: _familyId,
      parent: parent,
      child: child,
    );

Relationship _spouse(String a, String b) => Relationship.spouse(
  id: 'sp-$a-$b',
  familyId: _familyId,
  personA: a,
  personB: b,
);

({FamilyGraph graph, String rootId}) _fourGenerations() => (
  graph: FamilyGraph(
    persons: <Person>[
      _person('t', 'Cụ Tổ'),
      _person('tw', 'Cụ Bà'),
      _person('c1', 'Con Cả'),
      _person('c1w', 'Dâu Cả'),
      _person('c2', 'Con Thứ'),
      _person('g1', 'Cháu Một'),
      _person('g2', 'Cháu Hai'),
      _person('gg', 'Chắt'),
    ],
    relationships: <Relationship>[
      _spouse('t', 'tw'),
      _parent('t', 'c1'),
      _parent('tw', 'c1'),
      _parent('t', 'c2'),
      _spouse('c1', 'c1w'),
      _parent('c1', 'g1'),
      _parent('c1w', 'g1'),
      _parent('c1', 'g2'),
      _parent('g1', 'gg'),
    ],
  ),
  rootId: 't',
);

({FamilyGraph graph, String rootId}) _halfSiblings() => (
  graph: FamilyGraph(
    persons: <Person>[
      _person('a', 'Ông Bảy'),
      _person('w1', 'Vợ Cả'),
      _person('w2', 'Vợ Hai'),
      _person('c1', 'Con Vợ Cả'),
      _person('c2', 'Con Vợ Cả 2'),
      _person('c3', 'Con Vợ Hai'),
    ],
    relationships: <Relationship>[
      _spouse('a', 'w1'),
      _spouse('a', 'w2'),
      _parent('a', 'c1'),
      _parent('w1', 'c1'),
      _parent('a', 'c2'),
      _parent('w1', 'c2'),
      _parent('a', 'c3'),
      _parent('w2', 'c3'),
    ],
  ),
  rootId: 'a',
);

({FamilyGraph graph, String rootId}) _lopsided() => (
  graph: FamilyGraph(
    persons: <Person>[
      _person('a', 'Gốc'),
      _person('deep1', 'Sâu 1'),
      _person('deep2', 'Sâu 2'),
      _person('deep3', 'Sâu 3'),
      _person('leaf', 'Lá'),
    ],
    relationships: <Relationship>[
      _parent('a', 'deep1'),
      _parent('deep1', 'deep2'),
      _parent('deep2', 'deep3'),
      _parent('a', 'leaf'),
    ],
  ),
  rootId: 'a',
);

({FamilyGraph graph, String rootId}) _wide() {
  final persons = <Person>[_person('root', 'Cụ Tổ')];
  final relationships = <Relationship>[];

  for (var branch = 0; branch < 4; branch++) {
    final child = 'c$branch';
    persons.add(_person(child, 'Chi ${branch + 1}'));
    relationships.add(_parent('root', child));
    for (var leaf = 0; leaf < 3; leaf++) {
      final grandchild = 'g$branch$leaf';
      persons.add(_person(grandchild, 'Cháu ${branch + 1}.${leaf + 1}'));
      relationships.add(_parent(child, grandchild));
    }
  }

  return (
    graph: FamilyGraph(persons: persons, relationships: relationships),
    rootId: 'root',
  );
}

({FamilyGraph graph, String rootId}) _looped() => (
  graph: FamilyGraph(
    persons: <Person>[
      _person('a', 'A'),
      _person('b', 'B'),
      _person('c', 'C'),
    ],
    relationships: <Relationship>[
      _parent('a', 'b'),
      _parent('b', 'c'),
      _parent('c', 'a'),
    ],
  ),
  rootId: 'a',
);
