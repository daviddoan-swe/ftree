/// The family drawn as a chart, pannable and zoomable.
///
/// A descendant chart of one root (DOMAIN.md §16), so anyone outside that
/// root's descendants is not on it. Rather than hide that, the screen says how
/// many people are missing and lets the reader redraw from whoever they select.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/layout/tree_layout.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';
import '../person/person_profile_screen.dart';
import '../person/person_style.dart';

/// Opens the tree for [familyId].
/// Opens the tree for [familyId], drawn from [rootPersonId] where one is
/// given and from the family's thuỷ tổ otherwise.
Future<void> showTreeScreen(
  BuildContext context,
  String familyId, {
  String? rootPersonId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        TreeScreen(familyId: familyId, rootPersonId: rootPersonId),
  ),
);

class TreeScreen extends ConsumerStatefulWidget {
  const TreeScreen({required this.familyId, this.rootPersonId, super.key});

  /// Whom to draw from, or null for the family's thuỷ tổ.
  ///
  /// Reached from a person's own page, where the question is what came of
  /// that person rather than what the whole family looks like. The đời on the
  /// strip are still counted from the founder (§11.1), so opening on somebody
  /// in the fifth reads "Đời 5" rather than starting again at one.
  final String? rootPersonId;

  final String familyId;

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _view = TransformationController();

  /// Drives the slide that brings a newly opened generation into sight.
  ///
  /// Short. It is there so the reader can see that the chart moved and which
  /// way, not to be admired: the badge they pressed slides out from under
  /// their finger either way, and a long slide would only delay the answer.
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  /// Where the slide is going, or null when nothing is sliding.
  Animation<Matrix4>? _sliding;

  /// The view as it stood when the current touch began.
  ///
  /// Kept so that a gesture which moved nothing — a tap on a box, a tap on a
  /// badge — can be told apart from one that did.
  Matrix4? _touchedFrom;

  /// Whom the chart is drawn from, once the reader has chosen. Null means the
  /// default root, recomputed as the family changes.
  late String? _rootId = widget.rootPersonId;

  /// The selected box, or null.
  String? _selectedId;

  /// The chart the view was last fitted to.
  ///
  /// A chart is fitted once, when it first appears. It must not be refitted on
  /// every rebuild, or panning would spring back the moment anything else on
  /// the screen changes.
  ///
  /// The number of boxes is deliberately not part of this. Opening a fold
  /// changes it, and refitting then would throw the reader back to the root at
  /// the exact moment they reached what they were looking for.
  Object? _fittedTo;

  /// Whether the next fit should show everything, however small.
  ///
  /// Set by the fit button, which is the reader asking for the shape of the
  /// whole tree and accepting that the names go with it.
  bool _showEverything = false;

  /// A fold just opened whose new generation has still to be brought in sight.
  String? _reveal;

  /// The roots drawn before this one, most recent last.
  final List<String> _cameFrom = <String>[];

  /// The folds the reader has opened, on top of the default depth.
  ///
  /// Kept rather than the closed set, because the closed set is derived from
  /// the family and would have to be recomputed and reconciled every time a
  /// person was added. What the reader chose is small, and it is the only part
  /// a rebuild must not lose.
  Set<String> _expanded = <String>{};

  /// Which way the generations run, decided once and then left alone.
  ///
  /// Null until the first chart is measured. After that only the reader
  /// changes it.
  TreeOrientation? _orientation;

  /// How many generations a chart opens with, drawn as columns.
  ///
  /// Three. The generations run across, so the width is set by how many
  /// generations are shown rather than by how many people are in them: three
  /// is 1.6 screens across whether the family is three hundred people or a
  /// thousand. Only the height grows with the family.
  static const int _visibleGenerationsAcross = 3;

  /// How many generations a chart opens with, drawn as rows.
  ///
  /// Five, at the reader's instruction. Rows put every person in a generation
  /// side by side, so here the width is set by the number of people and it
  /// grows fast. Measured on the generated family, at the size names can still
  /// be read:
  ///
  /// |  depth | 300 people   | 1000 people   |
  /// |--------|--------------|---------------|
  /// |      3 | 7.3 screens  | 26.0 screens  |
  /// |      5 | 18.4 screens | 61.4 screens  |
  /// | unfold | 90.8 screens | 321.0 screens |
  ///
  /// So five is not a page — it is sixty screens of sideways scrolling for a
  /// thousand people, and 192 boxes to paint. It is a deliberate choice to see
  /// more of the line at once and to pay for it in scrolling; what keeps it
  /// usable is redrawing from somebody further down.
  ///
  /// The consequence for the opening view is that the measured default will
  /// almost always choose the columns, 1.6 screens against 61.4. The rows are
  /// something the reader turns the page to get to.
  static const int _visibleGenerationsDown = 5;

  /// How deep a chart is folded, which depends on which way it is drawn.
  static int _visibleGenerationsFor(TreeOrientation orientation) =>
      orientation.isTopDown
      ? _visibleGenerationsDown
      : _visibleGenerationsAcross;

  /// The smallest scale worth opening at.
  ///
  /// Eight generations measure some 2900 units across, which fits an iPhone
  /// only at 0.13 — names at under two pixels. A chart nobody can read is not
  /// an overview, so a large tree opens readable at its root instead, and the
  /// fit button is there when the shape is what is wanted.
  static const double _readableScale = 0.6;

  /// How far below the top of the viewport a chart's root box opens.
  ///
  /// Screen points, deliberately, so that every family opens with its
  /// ancestor in the same place however far the chart had to be zoomed out.
  static const double _rootInset = 24;

  @override
  void initState() {
    super.initState();
    _slide.addListener(() {
      final sliding = _sliding;
      if (sliding != null) _view.value = sliding.value;
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Slides the view to [target] rather than putting it there.
  void _slideTo(Matrix4 target) {
    _sliding = Matrix4Tween(begin: _view.value, end: target).animate(
      CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
    );
    _slide.forward(from: 0);
  }

  /// Abandons a slide in progress.
  ///
  /// Left running, the slide would go on writing to the same controller the
  /// drag is writing to, and the chart would pull against the hand moving it.
  void _stopSliding() {
    if (!_slide.isAnimating) return;
    _slide.stop();
    _sliding = null;
  }

  /// A finger has landed on the chart.
  void _touched() {
    _stopSliding();
    _touchedFrom = _view.value.clone();
  }

  /// Settles the chart back to the middle of whichever axis it no longer
  /// fills, once the hand has left it.
  ///
  /// Only such an axis: where the drawing is larger than the viewport there
  /// is more of it to look at in every direction, and pulling the reader back
  /// would be taking the chart away from them. Where it is smaller there is
  /// nothing off to the side but empty page, and a chart shoved into a corner
  /// has no way back except a button the reader has to think of.
  ///
  /// A tap settles nothing. It ends an interaction like any other gesture,
  /// but it has moved nothing, and sliding the chart because somebody touched
  /// it would be exactly the unasked-for movement this screen has been
  /// getting rid of.
  void _recentreIfAdrift(TreeLayout layout, Size viewport) {
    final from = _touchedFrom;
    _touchedFrom = null;
    if (viewport.isEmpty || from == null || from == _view.value) return;

    final matrix = _view.value;
    final scale = matrix.getMaxScaleOnAxis();
    final at = matrix.getTranslation();

    /// The centred offset, or null where the axis is worth panning along.
    double? settled(double extent, double room, double offset) {
      if (extent > room) return null;
      final middle = (room - extent) / 2;
      return (offset - middle).abs() < 0.5 ? null : middle;
    }

    final x = settled(
      (layout.width + _Chart.padding * 2) * scale,
      viewport.width,
      at.x,
    );
    final y = settled(
      (layout.height + _Chart.padding * 2) * scale,
      viewport.height,
      at.y,
    );
    if (x == null && y == null) return;

    _slideTo(matrix.clone()..setTranslationRaw(x ?? at.x, y ?? at.y, at.z));
  }

  /// The person to draw from: the family's thuỷ tổ.
  ///
  /// [FamilyGraph.foundingAncestor] rather than the first person without
  /// recorded parents, which is what this used to take. Every spouse who
  /// married in has no parents on record either, so in a family entered in any
  /// order that could open the chart on somebody's wife and draw her
  /// descendants as though the line were hers.
  ///
  /// Falling back to the first person keeps a chart on screen even when
  /// everybody has a parent, which a cycle can produce (§6.2).
  String? _defaultRoot(FamilyGraph graph) =>
      graph.foundingAncestor()?.id ?? graph.persons.firstOrNull?.id;

  /// Places the chart in the viewport, once per chart.
  ///
  /// A chart that fits is shown whole. One that does not opens at its root,
  /// readable, and is explored by panning — the founding ancestor is where a
  /// gia phả is read from, so it is the one place worth landing on.
  ///
  /// Never magnified past natural size: a family of three blown up to fill a
  /// tablet looks broken.
  void _fitOnce(TreeLayout layout, String rootId, Size viewport) {
    final key = <Object>[rootId, viewport];
    if (_fittedTo.toString() == key.toString()) return;
    _fittedTo = key;

    final everything = _showEverything;
    _showEverything = false;

    final chartWidth = layout.width + _Chart.padding * 2;
    final chartHeight = layout.height + _Chart.padding * 2;
    if (chartWidth <= 0 || chartHeight <= 0 || viewport.isEmpty) return;

    final whole = <double>[
      viewport.width / chartWidth,
      viewport.height / chartHeight,
      1,
    ].reduce((a, b) => a < b ? a : b);
    final scale = everything || whole >= _readableScale
        ? whole
        : _readableScale;

    // One rule, used for opening and for the fit button alike. Two of them is
    // what made the chart jump: it opened against the top and moved to the
    // middle the moment anything was pressed.
    final root = layout.nodeFor(rootId);
    final metrics = layout.metrics;
    final topDown = metrics.orientation.isTopDown;

    // Centred over the root's own box on the sibling axis. Not over the middle
    // of the drawing, which is a different place: the root sits above the span
    // of its own children, and a family whose descendants are mostly down one
    // branch carries its weight to one side — six hundred points away from the
    // ancestor on a real gia phả, which is more than a screen.
    final rootAlongCentre =
        (topDown
            ? (root?.x ?? 0) + metrics.nodeWidth / 2
            : (root?.y ?? 0) + metrics.nodeHeight / 2) +
        _Chart.padding;
    final rootDepthStart =
        (topDown ? (root?.y ?? 0) : (root?.x ?? 0)) + _Chart.padding;

    final along = _place(
      viewport: topDown ? viewport.width : viewport.height,
      extent: (topDown ? chartWidth : chartHeight) * scale,
      preferred:
          (topDown ? viewport.width : viewport.height) / 2 -
          rootAlongCentre * scale,
    );
    final depth = _place(
      viewport: topDown ? viewport.height : viewport.width,
      extent: (topDown ? chartHeight : chartWidth) * scale,
      preferred: _rootInset - rootDepthStart * scale,
    );

    final dx = topDown ? along : depth;
    final dy = topDown ? depth : along;

    final matrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      // All three axes, as InteractiveViewer does itself. Leaving z at 1 still
      // draws correctly, but the viewer reads the scale back with
      // `getMaxScaleOnAxis`, which takes the largest of the three — so it would
      // believe a chart shown at 0.15 was at 1.0 and clamp pinches against the
      // wrong number.
      ..scaleByDouble(scale, scale, scale, 1);

    // After this frame: the viewer is still being laid out, and assigning to a
    // controller mid-build would rebuild what is already building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stopSliding();
      _view.value = matrix;
    });
  }

  /// Where one axis of the chart sits in one axis of the viewport.
  ///
  /// Two cases, and the reason they are written as one function is that they
  /// have to agree where they meet. A rule that changes at a threshold moves
  /// the chart as a family grows past it, which is the jump this replaces.
  ///
  /// * **It fits.** Centred, and nothing else is worth considering: there is
  ///   no other position that shows more of it.
  /// * **It does not fit.** [preferred] decides — the ancestor, centred across
  ///   and a fixed inset down — but never far enough to leave a margin at an
  ///   edge the drawing could be covering.
  ///
  /// The two agree exactly when the chart is the size of the viewport: the
  /// slack is zero, so the centre is zero and the clamp has nowhere to go but
  /// zero. Nothing jumps, at any size.
  static double _place({
    required double viewport,
    required double extent,
    required double preferred,
  }) {
    final slack = viewport - extent;
    return slack >= 0 ? slack / 2 : preferred.clamp(slack, 0);
  }

  /// Redraws the chart with [personId] at the top, remembering [from].
  ///
  /// [from] is the root actually on screen, which is not always [_rootId]:
  /// until the reader picks one that is null and the chart is drawn from the
  /// thuỷ tổ. Reading the field instead meant the first redraw remembered
  /// nothing, and the way back appeared only from the second onwards.
  void _drawFrom(String personId, {required String from}) => setState(() {
    if (from != personId) _cameFrom.add(from);

    _rootId = personId;
    _selectedId = personId;
    // A new root is a new chart. Folds opened on the old one describe branches
    // that may not even be drawn here.
    _expanded = <String>{};
  });

  /// Which way round to draw, measured rather than guessed at.
  ///
  /// Whichever orientation is narrower, because a phone scrolls down readily
  /// and sideways badly. Counting people instead would get it wrong in both
  /// directions: a long thin line of descent is fine upright however many
  /// people it holds, and one generation of twelve is not.
  ///
  /// **Measured once, for the first chart, and then held.** Redrawing from
  /// somebody lower down is how the family is explored, and re-measuring at
  /// every step turned the page under the reader whenever a branch happened
  /// to be small enough to suit the other way round. Reading a gia phả is not
  /// helped by the page rotating between one generation and the next; a
  /// reader who wants it the other way says so with the button.
  TreeOrientation _decideOrientation(
    FamilyGraph graph,
    String rootId,
    Set<String> Function(TreeOrientation) foldFor,
  ) {
    final decided = _orientation;
    if (decided != null) return decided;

    // Each measured as it would actually be drawn, folds and all. The two
    // orientations no longer fold alike, so measuring them against a single
    // fold would compare one against a chart the other never shows.
    double widthOf(TreeOrientation orientation) => layoutDescendants(
      graph,
      rootId,
      collapsed: foldFor(orientation),
      metrics: LayoutMetrics(orientation: orientation),
    ).width;

    return _orientation =
        widthOf(TreeOrientation.leftToRight) < widthOf(TreeOrientation.topDown)
        ? TreeOrientation.leftToRight
        : TreeOrientation.topDown;
  }

  /// Turns the page, and says that the reader meant it.
  void _turnPage() => setState(() {
    _orientation = (_orientation ?? TreeOrientation.topDown).isTopDown
        ? TreeOrientation.leftToRight
        : TreeOrientation.topDown;
    // A different shape entirely, so the view is placed again rather than
    // left pointing at where something used to be.
    _fittedTo = null;
  });

  /// Redraws from wherever the reader was before the last double tap.
  ///
  /// The folds go with it, as they do on any change of root: they described
  /// branches of a chart that is no longer the one on screen.
  void _drawFromPrevious() {
    if (_cameFrom.isEmpty) return;
    setState(() {
      _rootId = _cameFrom.removeLast();
      _selectedId = _rootId;
      _expanded = <String>{};
    });
  }

  /// Reveals one more generation below [personId].
  ///
  /// Only that generation: whoever comes into view is folded in their turn
  /// (see [collapseToDepth]), so the chart never widens by more than the
  /// reader asked for.
  void _openFold(String personId) => setState(() {
    _expanded = <String>{..._expanded, personId};
    _reveal = personId;
  });

  /// Pans the least distance that brings a newly opened generation into sight.
  ///
  /// Opening a fold does not move the view on its own, which is right — the
  /// reader keeps their place. But the people revealed hang below the box that
  /// was pressed, and once the chart is centred there is less room under it
  /// than there used to be, so they can arrive off the edge. Pressing a badge
  /// and seeing nothing happen is the worst of both.
  ///
  /// The least distance, and no zoom change: this is not a refit. Anything
  /// already in sight is left exactly where it is, because movement nobody
  /// asked for is the thing that made the chart feel unsteady in the first
  /// place.
  void _revealOnce(TreeLayout layout, FamilyGraph graph, Size viewport) {
    final personId = _reveal;
    if (personId == null || viewport.isEmpty) return;
    _reveal = null;

    final metrics = layout.metrics;
    Rect boxOf(LayoutNode node) => Rect.fromLTWH(
      node.x + _Chart.padding,
      node.y + _Chart.padding,
      metrics.nodeWidth,
      metrics.nodeHeight,
    );

    // The generation just revealed, and only it. Including the parent would
    // make the group taller than the screen on a wide family, and then what
    // gets shown is the parent — which was already in sight.
    Rect? revealed;
    for (final child in graph.children(personId)) {
      final node = layout.nodeFor(child.id);
      if (node == null) continue;
      revealed = revealed == null
          ? boxOf(node)
          : revealed.expandToInclude(boxOf(node));
    }
    if (revealed == null) return;

    final target = revealed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final matrix = _view.value;
      final shift = _shiftInto(
        MatrixUtils.transformRect(matrix, target),
        // A margin, so what arrives is not flush against the edge with its
        // connector cut off.
        (Offset.zero & viewport).deflate(16),
      );
      if (shift == Offset.zero) return;

      // The view matrix is a translation times a scale, so its translation
      // column is already in screen units: adding to it pans, and leaves the
      // zoom alone.
      final panned = matrix.clone();
      final at = panned.getTranslation();
      panned.setTranslationRaw(at.x + shift.dx, at.y + shift.dy, at.z);
      _slideTo(panned);
    });
  }

  /// The least movement that brings [rect] inside [viewport].
  ///
  /// Zero on an axis where it already sits inside, and zero also where it is
  /// larger than the viewport and already spans it — there is nothing to show
  /// that is not being shown. Where it is too large and lies off to one side,
  /// its near edge is what gets brought in, because that is the end the reader
  /// is coming from.
  static Offset _shiftInto(Rect rect, Rect viewport) {
    double along(double low, double high, double from, double to) {
      if (low >= from && high <= to) return 0;
      if (low <= from && high >= to) return 0;
      return low < from ? from - low : to - high;
    }

    return Offset(
      along(rect.left, rect.right, viewport.left, viewport.right),
      along(rect.top, rect.bottom, viewport.top, viewport.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final snapshot = ref.watch(familySnapshotProvider(widget.familyId));
    final data = snapshot.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        // Two ways back, side by side and in the order they undo things: the
        // outer one leaves the chart, the inner one steps back through the
        // branches drawn within it. Putting the branch one over on the right
        // among the view controls made it read as another way of changing the
        // drawing rather than as a way of retracing.
        // 88 for the pair: two forty-point buttons and the eight between them
        // that the two on the right happen to have. Their spacing comes from
        // an IconButton's own forty-eight-point tap target, which the leading
        // slot does not give these, so it is put back here by hand.
        leadingWidth: _cameFrom.isEmpty ? null : 88,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ?circleBackButton(context),
            if (_cameFrom.isNotEmpty) const SizedBox(width: 8),
            // Only once there is somewhere to go back to. A dead button is
            // worse than no button.
            if (_cameFrom.isNotEmpty)
              Center(
                child: SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.undo),
                    tooltip: text.treeBack,
                    onPressed: _drawFromPrevious,
                  ),
                ),
              ),
          ],
        ),
        title: Text(text.treeTitle),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
            tooltip: text.treeTurn,
            onPressed: _turnPage,
          ),
          IconButton(
            icon: const Icon(Icons.fit_screen_outlined),
            tooltip: text.treeFit,
            onPressed: () => setState(() {
              _showEverything = true;
              _fittedTo = null;
            }),
          ),
        ],
      ),
      body: switch (snapshot) {
        AsyncLoading<FamilySnapshot?>() => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncError<FamilySnapshot?>(:final error) => Center(
          child: Text('$error'),
        ),
        _ when data == null => const SizedBox.shrink(),
        _ => _body(context, data),
      },
    );
  }

  Widget _body(BuildContext context, FamilySnapshot data) {
    final text = AppText.of(context);
    final graph = data.graph;

    // A root the reader chose may have been deleted from another screen.
    final rootId = (_rootId != null && graph.personById(_rootId!) != null)
        ? _rootId!
        : _defaultRoot(graph);
    if (rootId == null) return Center(child: Text(text.treeEmpty));

    // The default fold, less whatever the reader has opened. Derived on every
    // build rather than stored, so a person added from another screen is
    // folded or drawn according to where they landed, with no second copy of
    // the rule to keep in step.
    Set<String> foldFor(TreeOrientation orientation) => collapseToDepth(
      graph,
      rootId,
      visibleGenerations: _visibleGenerationsFor(orientation),
    ).difference(_expanded);

    // Which đời the top of the chart is, counted from the family's thuỷ tổ
    // rather than from whatever the chart happens to be rooted at (§11.1).
    // Read from the graph, which is where every screen gets these, so that no
    // two of them can contradict each other about a reader's own family.
    //
    // One where the founder's line does not reach this root, which is a
    // separate line with no đời in this family's counting: the chart still
    // draws, and counts its own generations from the top.
    final rootDoi = graph.generations()[rootId] ?? 1;

    final orientation = _decideOrientation(graph, rootId, foldFor);
    final layout = layoutDescendants(
      graph,
      rootId,
      collapsed: foldFor(orientation),
      metrics: LayoutMetrics(orientation: orientation),
    );

    final selected = _selectedId == null
        ? null
        : layout.nodeFor(_selectedId!)?.person;

    // The notice takes its own strip above the chart rather than floating over
    // it. Laid over the drawing it covered the top generation — which on a
    // descendant chart is the founding ancestor, the one box a reader is most
    // likely to be looking for.
    //
    // The strip of đời labels takes a band of its own beside the drawing
    // rather than floating over it. Laid on top it covered the boxes at the
    // near edge of each generation — which on a descendant chart is the eldest
    // of them, the one most worth reading.
    final band = _GenerationStrip(
      layout: layout,
      view: _view,
      rootDoi: rootDoi,
      padding: _Chart.padding,
    );

    return Column(
      children: <Widget>[
        if (!orientation.isTopDown)
          SizedBox(height: _GenerationStrip.thickness, child: band),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: Row(
                  children: <Widget>[
                    // Upright, the generations run down the page, so their
                    // labels run down beside it.
                    if (orientation.isTopDown)
                      SizedBox(
                        width: _GenerationStrip.thickness,
                        child: band,
                      ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _fitOnce(layout, rootId, constraints.biggest);
                          _revealOnce(layout, graph, constraints.biggest);
                          return _Chart(
                            layout: layout,
                            selectedId: selected?.id,
                            view: _view,
                            onTapPerson: (personId) =>
                                setState(() => _selectedId = personId),
                            // Reached two ways — the button on the selection
                            // bar, and a double tap on the box itself. The
                            // gesture is the quick one for somebody exploring;
                            // the button is how anyone finds out it exists.
                            onDrawFrom: (id) => _drawFrom(id, from: rootId),
                            onOpenFold: _openFold,
                            onTouched: _touched,
                            onSettled: () => _recentreIfAdrift(
                              layout,
                              constraints.biggest,
                            ),
                            viewport: constraints.biggest,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // A strip down each edge that turns the page when swiped.
              //
              // Laid over the viewer rather than wrapped around it, which is
              // what keeps the gesture out of the way of panning: a drag that
              // begins in the middle of the chart never reaches these, and a
              // drag that begins on them was never going to pan. Wrapping the
              // chart in a horizontal-drag detector instead would put the two
              // in the same arena, and one of them has to lose.
              //
              // The cost is that the outermost few points of the chart cannot
              // be grabbed to pan. There is nothing to grab there: the layout
              // leaves a margin all the way round.
              for (final edge in <Alignment>[
                Alignment.centerLeft,
                Alignment.centerRight,
              ])
                Align(
                  alignment: edge,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (_) => _turnPage(),
                    child: const SizedBox(width: 20, height: double.infinity),
                  ),
                ),
              // The selection bar stays laid over the chart: it is there for
              // as long as a box is selected and goes when it is deselected,
              // so giving it permanent room would leave a gap most of the time.
              if (selected != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SelectionBar(
                    person: selected,
                    isRoot: selected.id == rootId,
                    onOpen: () => showPersonProfile(
                      context,
                      familyId: widget.familyId,
                      personId: selected.id,
                    ),
                    onDrawFrom: () => _drawFrom(selected.id, from: rootId),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The chart itself: pan, zoom, and a tap that lands on a box.
class _Chart extends StatefulWidget {
  const _Chart({
    required this.layout,
    required this.selectedId,
    required this.view,
    required this.onTapPerson,
    required this.onDrawFrom,
    required this.onOpenFold,
    required this.onTouched,
    required this.onSettled,
    required this.viewport,
  });

  final TreeLayout layout;
  final String? selectedId;
  final TransformationController view;
  final ValueChanged<String?> onTapPerson;

  /// Double-tapping a box redraws the chart from that person.
  final ValueChanged<String> onDrawFrom;

  /// Tapping the badge on a folded box opens it.
  final ValueChanged<String> onOpenFold;

  /// A finger has landed on the chart.
  final VoidCallback onTouched;

  /// The last finger has left it.
  final VoidCallback onSettled;

  /// How much room the chart is being shown in.
  final Size viewport;

  /// The smallest zoom worth allowing: the one that shows the whole chart.
  ///
  /// Past it there is nothing further to see — the drawing simply shrinks in
  /// the middle of a growing emptiness, and the reader can lose it in a
  /// corner with no way back but the fit button. Where the chart already fits
  /// at natural size this comes out at 1, and zooming out is refused
  /// altogether, which is the same statement.
  double get smallestUsefulScale {
    if (viewport.isEmpty) return 0.1;

    return <double>[
      viewport.width / (layout.width + padding * 2),
      viewport.height / (layout.height + padding * 2),
      1,
    ].reduce((a, b) => a < b ? a : b);
  }

  /// Room around the drawing, so the outermost boxes are not against the edge.
  static const double padding = 40;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  /// Where the second tap landed. A double tap reports no position of its own,
  /// so the one from the tap that preceded it is kept.
  Offset? _doubleTapAt;

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    const padding = _Chart.padding;
    final size = Size(
      layout.width + padding * 2,
      layout.height + padding * 2,
    );

    return InteractiveViewer(
      transformationController: widget.view,
      // A hand on the chart wins over anything the screen was doing to it.
      onInteractionStart: (_) => widget.onTouched(),
      onInteractionEnd: (_) => widget.onSettled(),
      // Generous margin: without it the chart cannot be dragged away from the
      // corner it starts in, which on a tall tree means the lower generations
      // are unreachable.
      boundaryMargin: const EdgeInsets.all(400),
      minScale: widget.smallestUsefulScale,
      maxScale: 3,
      constrained: false,
      child: GestureDetector(
        // The gesture sits inside the viewer, so the position it reports is
        // already in chart coordinates whatever the zoom.
        onTapUp: (details) {
          // The badge before the box: it overlaps the corner it is anchored
          // to, and a tap there means "show me these people", not "select the
          // person standing in front of them".
          final fold = _foldAt(details.localPosition);
          if (fold != null) {
            widget.onOpenFold(fold);
            return;
          }
          widget.onTapPerson(_personAt(details.localPosition));
        },
        onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
        onDoubleTap: () {
          final person = _personAt(_doubleTapAt ?? Offset.zero);
          if (person != null) widget.onDrawFrom(person);
        },
        child: CustomPaint(
          size: size,
          painter: TreePainter(
            layout: layout,
            selectedId: widget.selectedId,
            colors: Theme.of(context).colorScheme,
            padding: padding,
          ),
        ),
      ),
    );
  }

  /// The folded box whose badge is under [point], or null.
  String? _foldAt(Offset point) {
    for (final node in widget.layout.nodes) {
      if (!node.hidesDescendants) continue;
      final target = TreePainter.foldBadgeTarget(
        node,
        widget.layout.metrics,
        _Chart.padding,
      );
      if (target.contains(point)) return node.person.id;
    }
    return null;
  }

  /// The box under [point], or null for the space between boxes.
  String? _personAt(Offset point) {
    final layout = widget.layout;
    final metrics = layout.metrics;
    for (final node in layout.nodes) {
      final rect = Rect.fromLTWH(
        node.x + _Chart.padding,
        node.y + _Chart.padding,
        metrics.nodeWidth,
        metrics.nodeHeight,
      );
      if (rect.contains(point)) return node.person.id;
    }
    return null;
  }
}

/// Draws a laid-out family: a box per person, a line per relationship.
///
/// Nothing here adjusts a position. Where the picture looks wrong, the layout
/// is wrong, and that is where the fix belongs.
class TreePainter extends CustomPainter {
  const TreePainter({
    required this.layout,
    required this.selectedId,
    required this.colors,
    required this.padding,
  });

  final TreeLayout layout;
  final String? selectedId;
  final ColorScheme colors;
  final double padding;

  /// Where a folded box's badge sits, and what a finger has to hit.
  ///
  /// One function, because the badge is drawn here and the gesture has to find
  /// it again; two copies of this arithmetic would drift and the badge would
  /// stop answering taps somewhere nobody looked.
  ///
  /// Sized from the digit count rather than from measured text, so the tap
  /// target needs no [TextPainter] and cannot disagree with one. Generous: it
  /// spills into the gap between boxes, which is a target for nothing else.
  static Rect foldBadgeTarget(
    LayoutNode node,
    LayoutMetrics metrics,
    double padding,
  ) {
    final digits = '${node.hiddenDescendantCount}'.length;
    final width = digits * 8 + 26;

    return Rect.fromCenter(
      // Straddling the bottom-right corner, which is the one place a box has
      // that no connector leaves from.
      center: Offset(
        node.x + metrics.nodeWidth + padding - 12,
        node.y + metrics.nodeHeight + padding,
      ),
      width: width < 48 ? 48 : width.toDouble(),
      height: 30,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = layout.metrics;

    final parentLine = Paint()
      ..strokeWidth = 1.5
      ..color = colors.outline;
    final spouseLine = Paint()
      ..strokeWidth = 3
      ..color = colors.tertiary;

    Offset centreOf(LayoutNode node) => Offset(
      node.x + metrics.nodeWidth / 2 + padding,
      node.y + metrics.nodeHeight / 2 + padding,
    );

    // The layout thinks in two axes — along the siblings, and down towards the
    // present. Which of them is x depends on how the page is turned.
    final topDown = metrics.orientation.isTopDown;
    Offset point(double along, double depth) =>
        topDown ? Offset(along, depth) : Offset(depth, along);

    final bars = _barsByParent();

    for (final edge in layout.edges) {
      final from = layout.nodeFor(edge.fromPersonId);
      final to = layout.nodeFor(edge.toPersonId);
      if (from == null || to == null) continue;

      switch (edge.kind) {
        case LayoutEdgeKind.spouse:
          canvas.drawLine(centreOf(from), centreOf(to), spouseLine);
        case LayoutEdgeKind.parentChild:
          // An elbow, not a diagonal: it is far easier to see where a line
          // goes. Drawn in the layout's own two axes and mapped at the last
          // moment, so the same three segments serve either orientation — an
          // elbow turned sideways is still an elbow.
          //
          // The origin along the sibling axis comes from the edge, so a
          // couple's children hang from between the pair rather than from one
          // of them.
          final startAlong = edge.fromAnchorAlong + padding;
          final startDepth =
              (topDown
                  ? from.y + metrics.nodeHeight
                  : from.x + metrics.nodeWidth) +
              padding;
          final endAlong = topDown ? centreOf(to).dx : centreOf(to).dy;
          final endDepth = (topDown ? to.y : to.x) + padding;

          // One bar per marriage, at its own depth. Left at a shared depth,
          // two marriages' bars touch end to end and read as one, which says
          // every child came from the same wife.
          final siblingBars = bars[edge.fromPersonId] ?? <double>[];
          final rank = siblingBars.indexOf(edge.fromAnchorAlong);
          final fraction = (rank + 1) / (siblingBars.length + 1);
          final mid = startDepth + (endDepth - startDepth) * fraction;

          canvas
            ..drawLine(point(startAlong, startDepth), point(startAlong, mid),
                parentLine)
            ..drawLine(point(startAlong, mid), point(endAlong, mid), parentLine)
            ..drawLine(point(endAlong, mid), point(endAlong, endDepth),
                parentLine);
      }
    }

    for (final node in layout.nodes) {
      _paintNode(canvas, node, selected: node.person.id == selectedId);
    }
  }

  /// The distinct drop points below each parent, left to right.
  ///
  /// One per marriage that produced children, because the layout gives each
  /// marriage its own anchor.
  Map<String, List<double>> _barsByParent() {
    final anchors = <String, Set<double>>{};
    for (final edge in layout.edges) {
      if (edge.kind != LayoutEdgeKind.parentChild) continue;
      (anchors[edge.fromPersonId] ??= <double>{}).add(edge.fromAnchorAlong);
    }
    return <String, List<double>>{
      for (final entry in anchors.entries)
        entry.key: entry.value.toList()..sort(),
    };
  }

  void _paintNode(Canvas canvas, LayoutNode node, {required bool selected}) {
    final metrics = layout.metrics;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        node.x + padding,
        node.y + padding,
        metrics.nodeWidth,
        metrics.nodeHeight,
      ),
      const Radius.circular(8),
    );

    canvas
      ..drawRRect(
        rect,
        Paint()
          ..color = selected ? colors.primaryContainer : colors.surface,
      )
      // The border carries the person's colour — grey once they have died.
      // The border rather than the fill: a few hundred tinted boxes would
      // fight the connector lines, which are what the chart is for, and pale
      // washes behind text make the names harder to read.
      //
      // Selection overrides it. Being told which box is selected matters more
      // for the moment it lasts than being told the sex again.
      ..drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 2
          ..color = selected ? colors.primary : personColor(node.person),
      );

    final years = lifeYears(node.person);
    // The sex glyph is set inline in the same paragraph rather than drawn
    // separately: an icon is a character in a font, so the line wraps and
    // centres as one piece instead of needing its own geometry.
    final glyph = personIcon(node.person);

    final label = TextPainter(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: colors.onSurface),
        children: <InlineSpan>[
          TextSpan(
            text: '${String.fromCharCode(glyph.codePoint)} ',
            style: TextStyle(
              fontFamily: glyph.fontFamily,
              package: glyph.fontPackage,
              fontSize: 13,
              color: personColor(node.person),
            ),
          ),
          TextSpan(text: node.person.displayName),
          if (years != null)
            TextSpan(
              text: '\n$years',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: metrics.nodeWidth - 12);

    label.paint(
      canvas,
      Offset(
        rect.center.dx - label.width / 2,
        rect.center.dy - label.height / 2,
      ),
    );

    if (node.hidesDescendants) _paintFoldBadge(canvas, node);
  }

  /// The `+12` pill on a box standing in front of people who are not drawn.
  ///
  /// A number and nothing else, in the accent colour: it has to read as
  /// something to press, and as a count, without a word in either language.
  void _paintFoldBadge(Canvas canvas, LayoutNode node) {
    final target = foldBadgeTarget(node, layout.metrics, padding);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: target.center,
        width: target.width - 8,
        height: 20,
      ),
      const Radius.circular(10),
    );

    canvas
      // A ring in the page colour first, so the pill reads as lying on top of
      // the box rather than as a lump in its border.
      ..drawRRect(pill.inflate(2.5), Paint()..color = colors.surface)
      ..drawRRect(pill, Paint()..color = GroupedColors.red);

    final label = TextPainter(
      text: TextSpan(
        text: '+${node.hiddenDescendantCount}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    label.paint(
      canvas,
      target.center - Offset(label.width / 2, label.height / 2),
    );
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.colors != colors;
}

/// The selected person, and what can be done with them.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.person,
    required this.isRoot,
    required this.onOpen,
    required this.onDrawFrom,
  });

  final Person person;
  final bool isRoot;
  final VoidCallback onOpen;
  final VoidCallback onDrawFrom;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  person.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Redrawing from a person already at the top would change
              // nothing, so it is not offered.
              if (!isRoot)
                TextButton(
                  onPressed: onDrawFrom,
                  child: Text(text.treeDrawFrom),
                ),
              FilledButton(onPressed: onOpen, child: Text(text.personProfile)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which đời each band of the chart is, in a band of its own beside it.
///
/// The drawing scrolls; this does not. A label follows its own generation
/// along the axis the generations run down, and is held inside the band at
/// both ends — so whichever part of a three-hundred-person gia phả is on
/// screen, the đời it belongs to is named without scrolling back to find out.
///
/// Beside the chart rather than over it. Laid on top, a label covered the
/// boxes at the near edge of its own generation, which on a descendant chart
/// is the eldest of them.
class _GenerationStrip extends StatelessWidget {
  const _GenerationStrip({
    required this.layout,
    required this.view,
    required this.rootDoi,
    required this.padding,
  });

  final TreeLayout layout;
  final TransformationController view;

  /// The đời of the person the chart is drawn from, so that redrawing from
  /// somebody lower down does not start counting again at one.
  final int rootDoi;

  final double padding;

  /// How much room the band takes from the drawing.
  ///
  /// The same either way round, so that turning the page does not resize the
  /// chart as well as turning it.
  static const double thickness = 92;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: view,
        builder: (context, _) => _labels(constraints.biggest),
      ),
    ),
  );

  Widget _labels(Size band) {
    if (layout.nodes.isEmpty || band.isEmpty) return const SizedBox.shrink();

    final metrics = layout.metrics;
    final topDown = metrics.orientation.isTopDown;
    final matrix = view.value;
    final scale = matrix.getMaxScaleOnAxis();
    final offset = topDown
        ? matrix.getTranslation().y
        : matrix.getTranslation().x;

    // The band runs the same way the generations do, so its own length is the
    // room a label has to be placed in.
    final room = topDown ? band.height : band.width;

    // Counted off the drawing, not off the family. The chart is one branch of
    // it — redrawn from somebody in the fifth đời it may hold two people where
    // the family holds twenty — and a number beside a column that does not
    // match the boxes in it describes nothing the reader can see.
    final drawn = <int, int>{};
    for (final node in layout.nodes) {
      drawn[node.generation] = (drawn[node.generation] ?? 0) + 1;
    }

    final generations = drawn.keys.toList()..sort();

    // Where each generation begins, in the band's own coordinates.
    double startOf(int generation) =>
        (generation * metrics.generationStride + padding) * scale + offset;

    return Stack(
      children: <Widget>[
        for (var i = 0; i < generations.length; i++)
          if (_place(
                startOf(generations[i]),
                i + 1 < generations.length ? startOf(generations[i + 1]) : null,
                room,
                topDown
                    ? _GenerationLabel.height
                    : _GenerationLabel.width,
              )
              case final double along)
            Positioned(
              left: topDown ? 6 : along,
              top: topDown ? along : 6,
              child: _GenerationLabel(
                ordinal: rootDoi + generations[i],
                drawn: drawn[generations[i]] ?? 0,
              ),
            ),
      ],
    );
  }

  /// Where a generation's label sits along the band, or null when it should
  /// not be shown at all.
  ///
  /// A generation that has scrolled past the leading edge keeps its label
  /// there, so the đời under the reader's eye is always named. But only until
  /// the next generation arrives: then the label is pushed out ahead of it and
  /// gone, which is what stops the two sitting on top of each other.
  ///
  /// Pinning every generation that had scrolled past — which is what this did
  /// first — piled every label it had ever shown into the same corner.
  static double? _place(
    double start,
    double? next,
    double room,
    double extent,
  ) {
    if (start > room) return null;

    const gap = 8.0;
    final limit = next == null ? room - extent : next - extent - gap;

    if (start >= 0) return start > room - extent ? null : start;

    // Past the edge: hold it there, unless the next generation has come close
    // enough to need the room.
    return limit < 0 ? null : 0;
  }
}

/// `Đời 5` and, beside it, how many of them this branch holds.
///
/// The đời is plain text: it names a column rather than marking anything, and
/// a filled chip for every generation turned the top of the chart into a row
/// of buttons that do nothing when pressed.
///
/// The count is a badge, because it is a quantity and because it is the part
/// that changes as the reader moves about the family.
class _GenerationLabel extends StatelessWidget {
  const _GenerationLabel({required this.ordinal, required this.drawn});

  final int ordinal;

  /// How many of that đời are on the chart as drawn.
  final int drawn;

  /// How much room a label takes on each axis.
  ///
  /// Both, because the band runs one way upright and the other way sideways,
  /// and reserving the wrong one lets two labels share a spot.
  static const double height = 30;
  static double get width => _GenerationStrip.thickness - 12;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              text.treeGenerationOrdinal(ordinal),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            // A node of its own carrying the whole phrase. Left to itself the
            // badge reads out as a bare number, and "5, 2" tells somebody
            // listening to the screen nothing about what the two counts are.
            container: true,
            label: text.treeGenerationCount(drawn),
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: GroupedColors.red,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$drawn',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
