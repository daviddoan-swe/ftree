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

/// Arranges a family into a descendant chart.
///
/// Two passes over two independent axes. [GenerationAssignment] decides the
/// vertical position; this decides the horizontal one.
///
/// The horizontal pass is the classic tidy-tree shape: walk depth-first, give
/// each childless unit the next free column, and centre every parent over the
/// span of its children. Because columns are handed out left to right and never
/// reused, nothing can overlap.
///
/// A **unit** is a person together with the spouses drawn beside them, so a
/// couple is placed as one thing and their children hang below the pair rather
/// than below one of them.
///
/// Known limitation, and a deliberate one: a family graph is not a tree. Someone
/// with parents in two different branches is reachable twice, and this draws
/// them once, under whichever branch reaches them first. Drawing them twice, or
/// joining across the chart, is a harder problem than a first layout needs.
TreeLayout layoutDescendants(
  FamilyGraph graph,
  String rootId, {
  LayoutMetrics metrics = const LayoutMetrics(),
}) {
  final assignment = GenerationAssignment.fromRoot(graph, rootId);
  if (assignment.length == 0) {
    return TreeLayout(
      nodes: const <LayoutNode>[],
      edges: const <LayoutEdge>[],
      metrics: metrics,
    );
  }

  final placer = _Placer(graph, assignment, metrics);
  placer.run(rootId);

  return TreeLayout(
    nodes: placer.nodes,
    edges: placer.edges,
    metrics: metrics,
  );
}

/// Runs the horizontal pass, accumulating placed nodes and the lines between
/// them.
final class _Placer {
  _Placer(this._graph, this._assignment, this._metrics);

  final FamilyGraph _graph;
  final GenerationAssignment _assignment;
  final LayoutMetrics _metrics;

  final List<LayoutNode> nodes = <LayoutNode>[];
  final List<LayoutEdge> edges = <LayoutEdge>[];

  /// Everyone already given a column, so nobody is drawn twice and a loop
  /// cannot run forever (§6.2).
  final Set<String> _placed = <String>{};

  /// Left edge of the next free column.
  double _nextColumn = 0;

  void run(String rootId) {
    _placeUnit(rootId);
  }

  /// Places [personId] with their spouses, then their children below, and
  /// returns the horizontal centre of the whole unit.
  double _placeUnit(String personId) {
    final person = _graph.personById(personId);
    if (person == null || !_placed.add(personId)) return _nextColumn;

    final generation = _assignment.generationOf(personId)!;

    // The people drawn side by side: this person, then any spouse not already
    // on the chart elsewhere.
    final partners = <Person>[
      for (final spouse in _graph.spouses(personId))
        if (_placed.add(spouse.id)) spouse,
    ];

    // Children of the whole couple, gathered before any column is claimed so
    // that the parents can be centred over them afterwards.
    final childIds = <String>[
      for (final member in <String>[personId, ...partners.map((p) => p.id)])
        for (final child in _graph.children(member))
          if (!_placed.contains(child.id)) child.id,
    ];

    final childCentres = <double>[
      for (final childId in _seenOnce(childIds)) _placeUnit(childId),
    ];

    final unitWidth =
        _metrics.nodeWidth +
        partners.length * _metrics.spouseSlotWidth;

    final double unitLeft;
    if (childCentres.isEmpty) {
      // A leaf claims the next free column.
      unitLeft = _nextColumn;
      _nextColumn += unitWidth + _metrics.horizontalGap;
    } else {
      // Centre the couple over the span its children occupy, but never to the
      // left of a column already used.
      final span = (childCentres.first + childCentres.last) / 2;
      unitLeft = _atLeast(span - unitWidth / 2, 0);
      _nextColumn = _atLeast(_nextColumn, unitLeft + unitWidth + _metrics.horizontalGap);
    }

    final y = generation * _metrics.generationHeight;

    nodes.add(
      LayoutNode(person: person, generation: generation, x: unitLeft, y: y),
    );

    var x = unitLeft;
    var previousId = personId;
    for (final partner in partners) {
      x += _metrics.spouseSlotWidth;
      nodes.add(
        LayoutNode(person: partner, generation: generation, x: x, y: y),
      );
      edges.add(
        LayoutEdge(
          kind: LayoutEdgeKind.spouse,
          fromPersonId: previousId,
          toPersonId: partner.id,
        ),
      );
      previousId = partner.id;
    }

    for (final childId in _seenOnce(childIds)) {
      edges.add(
        LayoutEdge(
          kind: LayoutEdgeKind.parentChild,
          fromPersonId: personId,
          toPersonId: childId,
        ),
      );
    }

    return unitLeft + unitWidth / 2;
  }

  /// Removes repeats while keeping the first occurrence, so a child of both
  /// members of a couple is drawn once.
  List<String> _seenOnce(List<String> ids) {
    final seen = <String>{};
    return <String>[
      for (final id in ids)
        if (seen.add(id)) id,
    ];
  }

  static double _atLeast(double value, double floor) =>
      value < floor ? floor : value;
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
