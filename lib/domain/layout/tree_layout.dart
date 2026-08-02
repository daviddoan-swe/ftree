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
    required this.fromAnchorX,
  });

  final LayoutEdgeKind kind;

  /// The parent, for [LayoutEdgeKind.parentChild]; otherwise the left-hand of
  /// the pair as placed.
  final String fromPersonId;

  /// The child, for [LayoutEdgeKind.parentChild]; otherwise the right-hand.
  final String toPersonId;

  /// Where the line should leave the upper end, horizontally.
  ///
  /// For a parent with a spouse this is the centre of the couple, not the
  /// centre of [fromPersonId]. Children belong to both partners, and a line
  /// dropping from one of them makes them look like that partner's alone.
  ///
  /// Supplied by the layout rather than worked out by the renderer: grouping
  /// spouses is the layout's job (§16), and a renderer recomputing it would be
  /// rebuilding structure the layout already knows.
  final double fromAnchorX;

  @override
  String toString() =>
      'LayoutEdge(${kind.name}, $fromPersonId → $toPersonId @ $fromAnchorX)';
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

  /// Places [personId] with their spouses, then their children below.
  ///
  /// Returns the centre of **this person's own box**, not of the unit. Those
  /// are different once a spouse is drawn alongside, and the caller needs the
  /// person: a parent's connector meets its child's box, so the parent must
  /// centre over the boxes it actually joins to. Centring over unit centres
  /// instead leaves the vertical line off the middle of its own horizontal bar
  /// whenever a child is married.
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

    // Which marriage each child came from, so each can hang from its own
    // couple rather than from the middle of everybody. The order of the
    // children is left exactly as the data gives it.
    final marriageOfChild = _marriageOfChild(personId, partners);
    final childIds = marriageOfChild.keys.toList();

    // Centres of the child *boxes*, which is what the connectors will join.
    final childCentres = <double>[
      for (final childId in childIds) _placeUnit(childId),
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
      // Put the unit's middle over the middle of the children's boxes, so the
      // vertical line meets the centre of its own horizontal bar. Never to the
      // left of a column already used.
      final span = (childCentres.first + childCentres.last) / 2;
      unitLeft = _atLeast(span - unitWidth / 2, 0);
      _nextColumn = _atLeast(
        _nextColumn,
        unitLeft + unitWidth + _metrics.horizontalGap,
      );
    }

    final y = generation * _metrics.generationHeight;

    nodes.add(
      LayoutNode(person: person, generation: generation, x: unitLeft, y: y),
    );

    var x = unitLeft;
    var previousId = personId;
    var previousX = unitLeft;
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
          fromAnchorX: previousX + _metrics.nodeWidth / 2,
        ),
      );
      previousId = partner.id;
      previousX = x;
    }

    // Each child hangs from its own marriage. Drawing them all from the middle
    // of the whole unit would say nothing about which wife they belong to —
    // information the data holds and a gia phả cares about.
    //
    // A child with no recorded second parent hangs from the middle of the whole
    // unit rather than from this person alone. Anchoring them on the person
    // would assert that they came from no marriage at all, when the usual
    // reading is that the other parent is simply unrecorded — and with a single
    // spouse it would also cross the lines of their own siblings for no reason.
    final personCentre = unitLeft + _metrics.nodeWidth / 2;
    final unitCentre = unitLeft + unitWidth / 2;

    for (final entry in marriageOfChild.entries) {
      final partnerIndex = entry.value;
      edges.add(
        LayoutEdge(
          kind: LayoutEdgeKind.parentChild,
          fromPersonId: personId,
          toPersonId: entry.key,
          fromAnchorX: partnerIndex == null
              ? unitCentre
              : _marriageAnchor(personCentre, partnerIndex),
        ),
      );
    }

    return personCentre;
  }

  /// Where the children of one marriage leave the row of boxes.
  ///
  /// The gap immediately to the left of that partner's box. For a first
  /// marriage that is the gap between the two people, which is what a reader
  /// expects. For a later one it is the gap before that spouse — deliberately
  /// not the midpoint between the person and that spouse, which for a second
  /// marriage lands squarely on the *first* spouse's box and so says the child
  /// is theirs.
  ///
  /// A gap is never a box, at any number of marriages.
  double _marriageAnchor(double personCentre, int partnerIndex) =>
      personCentre + (partnerIndex + 0.5) * _metrics.spouseSlotWidth;

  /// Which marriage each child came from, keyed by child id.
  ///
  /// A null value means no second parent is recorded among the partners drawn
  /// here — which usually means the other parent is simply unknown, not that
  /// the child came from outside every marriage.
  ///
  /// Insertion order is the order the children will be placed, and it is the
  /// order the data gives. Birth order is the first thing a gia phả is read by
  /// — Con Cả before Con Thứ — so it survives even though regrouping by
  /// marriage instead would guarantee connectors never cross.
  Map<String, int?> _marriageOfChild(String personId, List<Person> partners) {
    final marriages = <String, int?>{};

    for (final child in _graph.children(personId)) {
      if (_placed.contains(child.id)) continue;
      marriages[child.id] = null;
    }

    for (var index = 0; index < partners.length; index++) {
      for (final child in _graph.children(partners[index].id)) {
        if (_placed.contains(child.id)) continue;
        // Assigning to an existing key updates which marriage it belongs to
        // without moving it, so the order above survives.
        marriages[child.id] = index;
      }
    }

    return marriages;
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
