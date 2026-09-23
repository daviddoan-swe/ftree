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

/// Which way the generations run.
///
/// Ancestor first either way; this is only which direction "first" points. It
/// is a property of the page rather than of the family, and the two are not
/// interchangeable on a phone: whichever axis the generations take, the
/// siblings get the other one, and only one of the two can be scrolled
/// comfortably.
///
/// The choice matters because the two axes are bounded differently. Depth can
/// be folded (see [collapseToDepth]); the width of a generation cannot — a
/// rule that hides siblings hides whoever carries the line. So the axis that
/// folding can bound is the one to put across the narrow side of the screen.
enum TreeOrientation {
  /// Generations downwards, siblings left to right. The form a printed gia
  /// phả takes, and the one a wide screen suits.
  topDown,

  /// Generations left to right, siblings downwards. Puts the foldable axis
  /// across the phone and lets the unfoldable one run down the side that
  /// scrolls.
  leftToRight;

  /// Whether generations run down the page.
  bool get isTopDown => this == TreeOrientation.topDown;
}

/// Spacing the layout works to.
///
/// Unitless. A renderer decides whether one unit is a pixel or something else.
///
/// Two axes, named for what they carry rather than for a direction: the
/// **sibling** axis holds the people of one generation, and the **generation**
/// axis runs from the ancestor towards the present. [orientation] decides
/// which of those lands on x and which on y.
final class LayoutMetrics {
  const LayoutMetrics({
    this.nodeWidth = 160,
    this.nodeHeight = 60,
    this.horizontalGap = 24,
    this.verticalGap = 80,
    this.spouseGap = 12,
    this.orientation = TreeOrientation.topDown,
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

  /// Which way the generations run, and so which axis is which.
  final TreeOrientation orientation;

  /// How much of the sibling axis one box takes up.
  double get nodeExtent => orientation.isTopDown ? nodeWidth : nodeHeight;

  /// Distance between the leading edges of two adjacent non-spouse boxes,
  /// along the sibling axis.
  double get siblingStride => nodeExtent + horizontalGap;

  /// The same for two boxes drawn as a couple. Narrower than
  /// [siblingStride], which is what makes a couple read as a pair.
  double get spouseStride => nodeExtent + spouseGap;

  /// Distance between one generation and the next, along the generation axis.
  double get generationStride =>
      (orientation.isTopDown ? nodeHeight : nodeWidth) + verticalGap;
}

/// One person, placed.
final class LayoutNode {
  const LayoutNode({
    required this.person,
    required this.generation,
    required this.x,
    required this.y,
    this.hiddenDescendantCount = 0,
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

  /// How many people hang below this box without being drawn.
  ///
  /// Non-zero only where the chart was folded: it is what the reader is being
  /// told they cannot see, and tapping is expected to reveal one generation of
  /// it. Zero everywhere else, including on a folded person whose descendants
  /// all happen to be drawn elsewhere on the chart — nothing is hidden there,
  /// so nothing is claimed.
  final int hiddenDescendantCount;

  /// Whether this box stands in front of people who are not drawn.
  bool get hidesDescendants => hiddenDescendantCount > 0;

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
    required this.fromAnchorAlong,
  });

  final LayoutEdgeKind kind;

  /// The parent, for [LayoutEdgeKind.parentChild]; otherwise the left-hand of
  /// the pair as placed.
  final String fromPersonId;

  /// The child, for [LayoutEdgeKind.parentChild]; otherwise the right-hand.
  final String toPersonId;

  /// Where the line should leave the parent's end, along the sibling axis.
  ///
  /// For a parent with a spouse this is the centre of the couple, not the
  /// centre of [fromPersonId]. Children belong to both partners, and a line
  /// dropping from one of them makes them look like that partner's alone.
  ///
  /// Supplied by the layout rather than worked out by the renderer: grouping
  /// spouses is the layout's job (§16), and a renderer recomputing it would be
  /// rebuilding structure the layout already knows.
  final double fromAnchorAlong;

  @override
  String toString() =>
      'LayoutEdge(${kind.name}, $fromPersonId → $toPersonId @ $fromAnchorAlong)';
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
/// Anyone in [collapsed] is drawn, but their children are not, and neither is
/// anything below them. A chart of a real gia phả is far wider than a phone:
/// three hundred people measure some fifty screens across at a size the names
/// can still be read at, so drawing all of it at once is not a view of
/// anything. Folding is what makes the chart answerable — the reader opens the
/// one branch they are following.
///
/// Known limitation, and a deliberate one: a family graph is not a tree. Someone
/// with parents in two different branches is reachable twice, and this draws
/// them once, under whichever branch reaches them first. Drawing them twice, or
/// joining across the chart, is a harder problem than a first layout needs.
TreeLayout layoutDescendants(
  FamilyGraph graph,
  String rootId, {
  LayoutMetrics metrics = const LayoutMetrics(),
  Set<String> collapsed = const <String>{},
}) {
  final assignment = GenerationAssignment.fromRoot(graph, rootId);
  if (assignment.length == 0) {
    return TreeLayout(
      nodes: const <LayoutNode>[],
      edges: const <LayoutEdge>[],
      metrics: metrics,
    );
  }

  final placer = _Placer(graph, assignment, metrics, collapsed);
  placer.run(rootId);

  return TreeLayout(
    nodes: placer.nodes,
    edges: placer.edges,
    metrics: metrics,
  );
}

/// Who has to be folded so that a chart from [rootId] shows no more than
/// [visibleGenerations] generations.
///
/// Everyone standing at or below the last visible generation who has a child,
/// so the fold holds however far the reader opens it: revealing one person's
/// children exposes a generation that is already folded in its turn, and the
/// chart never grows without being asked twice.
///
/// Spouses are returned alongside their partner where they too are parents.
/// Only the head of a drawn unit is consulted by the layout, so the extra ids
/// cost nothing and spare the caller from having to know which of a couple
/// the placement pass will treat as the head.
///
/// Returns an empty set when the chart is already short enough, which is the
/// common case for a small family and costs one traversal to find out.
Set<String> collapseToDepth(
  FamilyGraph graph,
  String rootId, {
  required int visibleGenerations,
}) {
  if (visibleGenerations < 1) {
    throw ArgumentError.value(
      visibleGenerations,
      'visibleGenerations',
      'a chart shows at least the root',
    );
  }

  final assignment = GenerationAssignment.fromRoot(graph, rootId);
  final last = visibleGenerations - 1;

  return <String>{
    for (final person in assignment.order)
      if ((assignment.generationOf(person.id) ?? 0) >= last &&
          graph.children(person.id).isNotEmpty)
        person.id,
  };
}

/// Runs the horizontal pass, accumulating placed nodes and the lines between
/// them.
final class _Placer {
  _Placer(this._graph, this._assignment, this._metrics, this._collapsed);

  final FamilyGraph _graph;
  final GenerationAssignment _assignment;
  final LayoutMetrics _metrics;

  /// Whose children are not to be drawn.
  final Set<String> _collapsed;

  /// The head of each folded unit, and the partners folded along with it.
  ///
  /// Collected during placement because only the placement pass knows which
  /// people ended up drawn side by side, and the count a folded box carries
  /// has to cover everyone the whole unit is standing in front of — a second
  /// wife's children by an earlier marriage included.
  final Map<String, List<String>> _foldedUnits = <String, List<String>>{};

  final List<LayoutNode> nodes = <LayoutNode>[];
  final List<LayoutEdge> edges = <LayoutEdge>[];

  /// Everyone already given a column, so nobody is drawn twice and a loop
  /// cannot run forever (§6.2).
  final Set<String> _placed = <String>{};

  /// The next free position on the sibling axis.
  double _nextSlot = 0;

  void run(String rootId) {
    _placeUnit(rootId);
    _countWhatIsHidden();
  }

  /// Fills in [LayoutNode.hiddenDescendantCount] for every folded unit.
  ///
  /// Only after placement, because a descendant of a folded person may have
  /// been drawn anyway — reached first through another branch, which a family
  /// graph allows. Counting them as hidden would put a number on the box that
  /// the reader can already see people behind.
  ///
  /// [FamilyGraph.descendants] tolerates a cycle (§6.2), so a corrupt graph
  /// gives a wrong number here rather than hanging the screen.
  void _countWhatIsHidden() {
    if (_foldedUnits.isEmpty) return;

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final partners = _foldedUnits[node.person.id];
      if (partners == null) continue;

      final hidden = <String>{};
      for (final id in <String>[node.person.id, ...partners]) {
        for (final person in _graph.descendants(id)) {
          if (!_placed.contains(person.id)) hidden.add(person.id);
        }
      }
      if (hidden.isEmpty) continue;

      nodes[index] = LayoutNode(
        person: node.person,
        generation: node.generation,
        x: node.x,
        y: node.y,
        hiddenDescendantCount: hidden.length,
      );
    }
  }

  /// Places [personId] with their spouses, then their children below.
  ///
  /// Returns the centre of **this person's own box**, not of the unit. Those
  /// are different once a spouse is drawn alongside, and the caller needs the
  /// person: a parent's connector meets its child's box, so the parent must
  /// centre over the boxes it actually joins to. Centring over unit centres
  /// instead leaves the vertical line off the middle of its own horizontal bar
  /// whenever a child is married.
  /// Turns a position on each axis into a point, according to the orientation.
  ///
  /// The one place the two orientations differ. Everything above it is the
  /// same packing problem either way: a run along the sibling axis, and a
  /// depth from the root.
  LayoutNode _node(
    Person person,
    int generation,
    double along,
    double depth,
  ) => LayoutNode(
    person: person,
    generation: generation,
    x: _metrics.orientation.isTopDown ? along : depth,
    y: _metrics.orientation.isTopDown ? depth : along,
  );

  double _placeUnit(String personId) {
    final person = _graph.personById(personId);
    if (person == null || !_placed.add(personId)) return _nextSlot;

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
    //
    // A folded unit enumerates nothing: the children are not placed, so no
    // column is claimed for them and the chart closes up to the width of what
    // is actually drawn. That width is the whole point of folding.
    final folded = _collapsed.contains(personId);
    if (folded) {
      _foldedUnits[personId] = <String>[
        for (final partner in partners) partner.id,
      ];
    }
    final marriageOfChild = folded
        ? const <String, int?>{}
        : _marriageOfChild(personId, partners);
    final childIds = marriageOfChild.keys.toList();

    // Centres of the child *boxes*, which is what the connectors will join.
    final childCentres = <double>[
      for (final childId in childIds) _placeUnit(childId),
    ];

    final unitExtent =
        _metrics.nodeExtent +
        partners.length * _metrics.spouseStride;

    final double unitStart;
    if (childCentres.isEmpty) {
      // A leaf claims the next free slot.
      unitStart = _nextSlot;
      _nextSlot += unitExtent + _metrics.horizontalGap;
    } else {
      // Put the unit's middle over the middle of the children's boxes, so the
      // stem meets the centre of its own bar. Never before a slot already
      // used.
      final span = (childCentres.first + childCentres.last) / 2;
      unitStart = _atLeast(span - unitExtent / 2, 0);
      _nextSlot = _atLeast(
        _nextSlot,
        unitStart + unitExtent + _metrics.horizontalGap,
      );
    }

    final depth = generation * _metrics.generationStride;

    nodes.add(_node(person, generation, unitStart, depth));

    var along = unitStart;
    var previousId = personId;
    var previousAlong = unitStart;
    for (final partner in partners) {
      along += _metrics.spouseStride;
      nodes.add(_node(partner, generation, along, depth));
      edges.add(
        LayoutEdge(
          kind: LayoutEdgeKind.spouse,
          fromPersonId: previousId,
          toPersonId: partner.id,
          fromAnchorAlong: previousAlong + _metrics.nodeExtent / 2,
        ),
      );
      previousId = partner.id;
      previousAlong = along;
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
    final personCentre = unitStart + _metrics.nodeExtent / 2;
    final unitCentre = unitStart + unitExtent / 2;

    for (final entry in marriageOfChild.entries) {
      final partnerIndex = entry.value;
      edges.add(
        LayoutEdge(
          kind: LayoutEdgeKind.parentChild,
          fromPersonId: personId,
          toPersonId: entry.key,
          fromAnchorAlong: partnerIndex == null
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
      personCentre + (partnerIndex + 0.5) * _metrics.spouseStride;

  /// Which marriage each child came from, keyed by child id.
  ///
  /// A null value means no second parent is recorded among the partners drawn
  /// here — which usually means the other parent is simply unknown, not that
  /// the child came from outside every marriage.
  ///
  /// Insertion order is the order the children will be placed, and it is the
  /// order [FamilyGraph.children] gives — eldest first as far as the recorded
  /// dates say (§13.3). Birth order is the first thing a gia phả is read by —
  /// Con Cả before Con Thứ — so it survives here even though regrouping by
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
