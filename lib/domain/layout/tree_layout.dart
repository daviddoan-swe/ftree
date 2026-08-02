/// Turning a family graph into positions on a page (DOMAIN.md §16).
///
/// The domain says who is related to whom. This decides where they go. Nothing
/// here knows about Flutter, pixels, or a screen: coordinates are plain numbers
/// in whatever unit the caller chose through [LayoutMetrics], and the renderer
/// scales them.
///
/// The chart drawn is a **descendant chart**: pick a root and draw their
/// descendants downwards. That is the form a Vietnamese gia phả takes — the
/// founding ancestor at the top — and it is the simplest arrangement that still
/// has to cope with half siblings and several marriages.
library;

import '../family_graph.dart';
import '../person.dart';

/// Spacing the layout works to.
///
/// Unitless. A renderer decides whether one unit is a pixel or something else.
final class LayoutMetrics {
  const LayoutMetrics({
    this.nodeWidth = 160,
    this.nodeHeight = 60,
    this.horizontalGap = 24,
    this.verticalGap = 80,
    this.spouseGap = 12,
  });

  /// Width of one person's box.
  final double nodeWidth;

  /// Height of one person's box.
  final double nodeHeight;

  /// Space between neighbouring boxes that are not spouses.
  final double horizontalGap;

  /// Space between one generation and the next.
  final double verticalGap;

  /// Space between two people drawn as a couple. Narrower than
  /// [horizontalGap], which is what makes a couple read as a pair.
  final double spouseGap;

  /// Distance between the left edges of two adjacent non-spouse boxes.
  double get slotWidth => nodeWidth + horizontalGap;

  /// Distance between the left edges of two boxes drawn as a couple.
  double get spouseSlotWidth => nodeWidth + spouseGap;

  /// Distance between the top edges of one generation and the next.
  double get generationHeight => nodeHeight + verticalGap;
}

/// One person, placed.
final class LayoutNode {
  const LayoutNode({
    required this.person,
    required this.generation,
    required this.x,
    required this.y,
  });

  /// Who this box is.
  final Person person;

  /// Distance from the root, in generations. The root is 0; a spouse married in
  /// shares their partner's number.
  final int generation;

  /// Left edge of the box.
  final double x;

  /// Top edge of the box.
  final double y;

  @override
  String toString() =>
      'LayoutNode(${person.id}, gen $generation, $x, $y)';
}

/// What kind of line joins two boxes.
enum LayoutEdgeKind {
  /// A parent above, a child below.
  parentChild,

  /// Two people drawn side by side.
  spouse,
}

/// A line to draw between two placed people.
final class LayoutEdge {
  const LayoutEdge({
    required this.kind,
    required this.fromPersonId,
    required this.toPersonId,
  });

  final LayoutEdgeKind kind;

  /// The parent, for [LayoutEdgeKind.parentChild]; otherwise the left-hand of
  /// the pair as placed.
  final String fromPersonId;

  /// The child, for [LayoutEdgeKind.parentChild]; otherwise the right-hand.
  final String toPersonId;

  @override
  String toString() => 'LayoutEdge(${kind.name}, $fromPersonId → $toPersonId)';
}

/// A finished arrangement, ready to draw.
final class TreeLayout {
  const TreeLayout({
    required this.nodes,
    required this.edges,
    required this.metrics,
  });

  /// Every placed person, in the order they were placed.
  final List<LayoutNode> nodes;

  /// Every line to draw.
  final List<LayoutEdge> edges;

  /// The spacing this was laid out to.
  final LayoutMetrics metrics;

  /// The placed person with [personId], or null if they are not on the chart.
  LayoutNode? nodeFor(String personId) {
    for (final node in nodes) {
      if (node.person.id == personId) return node;
    }
    return null;
  }

  /// How many generations deep the chart runs. Zero when empty.
  int get generationCount => nodes.isEmpty
      ? 0
      : nodes.map((n) => n.generation).reduce((a, b) => a > b ? a : b) + 1;

  /// Total width covered, including the last box.
  double get width => nodes.isEmpty
      ? 0
      : nodes.map((n) => n.x).reduce((a, b) => a > b ? a : b) +
            metrics.nodeWidth;

  /// Total height covered, including the last box.
  double get height => nodes.isEmpty
      ? 0
      : nodes.map((n) => n.y).reduce((a, b) => a > b ? a : b) +
            metrics.nodeHeight;
}

/// The people to draw, and how far each sits from the root.
///
/// Separated from placement because the two axes are independent problems:
/// this decides the vertical position, and it can be tested without any
/// geometry at all.
final class GenerationAssignment {
  const GenerationAssignment._(this._byPersonId, this.order);

  /// Works outwards from [rootId], following children downwards and drawing in
  /// each person's spouses at the same level.
  ///
  /// A spouse who married in is placed at their partner's generation rather
  /// than being given one of their own. Their own ancestors are not drawn: this
  /// is a descendant chart of one root.
  ///
  /// Terminates on a corrupt graph. Acyclicity cannot be guaranteed once two
  /// devices edit offline (§6.2), and a loop here would otherwise hang the tree
  /// screen.
  factory GenerationAssignment.fromRoot(FamilyGraph graph, String rootId) {
    final root = graph.personById(rootId);
    if (root == null) {
      return const GenerationAssignment._(<String, int>{}, <Person>[]);
    }

    final generations = <String, int>{rootId: 0};
    final order = <Person>[root];

    // Breadth-first by generation, so a person reached by two routes keeps the
    // shallower of the two.
    final queue = <Person>[root];
    for (var head = 0; head < queue.length; head++) {
      final person = queue[head];
      final generation = generations[person.id]!;

      // Spouses first, so a couple stays adjacent in [order] and the placement
      // pass can rely on that.
      for (final spouse in graph.spouses(person.id)) {
        if (generations.containsKey(spouse.id)) continue;
        generations[spouse.id] = generation;
        order.add(spouse);
        queue.add(spouse);
      }

      for (final child in graph.children(person.id)) {
        if (generations.containsKey(child.id)) continue;
        generations[child.id] = generation + 1;
        order.add(child);
        queue.add(child);
      }
    }

    return GenerationAssignment._(generations, order);
  }

  final Map<String, int> _byPersonId;

  /// Everyone on the chart, root first, then outwards.
  final List<Person> order;

  /// How far [personId] sits from the root, or null if they are not on the
  /// chart at all.
  int? generationOf(String personId) => _byPersonId[personId];

  /// Whether [personId] appears on this chart.
  bool includes(String personId) => _byPersonId.containsKey(personId);

  /// How many people are on the chart.
  int get length => order.length;

  /// Everyone at a given distance from the root, in placement order.
  List<Person> atGeneration(int generation) => <Person>[
    for (final person in order)
      if (_byPersonId[person.id] == generation) person,
  ];

  /// How many generations the chart spans. Zero when nobody is on it.
  int get generationCount => _byPersonId.isEmpty
      ? 0
      : _byPersonId.values.reduce((a, b) => a > b ? a : b) + 1;
}
