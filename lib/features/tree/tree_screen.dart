/// The family drawn as a chart, pannable and zoomable.
///
/// A descendant chart of one root (DOMAIN.md §16), so anyone outside that
/// root's descendants is not on it. Rather than hide that, the screen says how
/// many people are missing and lets the reader redraw from whoever they select.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/providers.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/layout/tree_layout.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';
import '../person/person_profile_screen.dart';

/// Opens the tree for [familyId].
Future<void> showTreeScreen(BuildContext context, String familyId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => TreeScreen(familyId: familyId)),
    );

class TreeScreen extends ConsumerStatefulWidget {
  const TreeScreen({required this.familyId, super.key});

  final String familyId;

  @override
  ConsumerState<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends ConsumerState<TreeScreen> {
  final TransformationController _view = TransformationController();

  /// Whom the chart is drawn from, once the reader has chosen. Null means the
  /// default root, recomputed as the family changes.
  String? _rootId;

  /// The selected box, or null.
  String? _selectedId;

  /// The chart the view was last fitted to.
  ///
  /// A chart is fitted once, when it first appears or when it changes shape. It
  /// must not be refitted on every rebuild, or panning would spring back the
  /// moment anything else on the screen changes.
  Object? _fittedTo;

  /// Whether the next fit should show everything, however small.
  ///
  /// Set by the fit button, which is the reader asking for the shape of the
  /// whole tree and accepting that the names go with it.
  bool _showEverything = false;

  /// The smallest scale worth opening at.
  ///
  /// Eight generations measure some 2900 units across, which fits an iPhone
  /// only at 0.13 — names at under two pixels. A chart nobody can read is not
  /// an overview, so a large tree opens readable at its root instead, and the
  /// fit button is there when the shape is what is wanted.
  static const double _readableScale = 0.6;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  /// The person to draw from: the first without recorded parents.
  ///
  /// A gia phả is read from its founding ancestor down, and someone with no
  /// parents on record is the best guess at one. Falling back to the first
  /// person keeps a chart on screen even when every person has a parent, which
  /// a cycle can produce (§6.2).
  String? _defaultRoot(FamilyGraph graph) {
    for (final person in graph.persons) {
      if (graph.parents(person.id).isEmpty) return person.id;
    }
    return graph.persons.firstOrNull?.id;
  }

  /// Places the chart in the viewport, once per chart.
  ///
  /// A chart that fits is shown whole. One that does not opens at its root,
  /// readable, and is explored by panning — the founding ancestor is where a
  /// gia phả is read from, so it is the one place worth landing on.
  ///
  /// Never magnified past natural size: a family of three blown up to fill a
  /// tablet looks broken.
  void _fitOnce(TreeLayout layout, String rootId, Size viewport) {
    final key = <Object>[rootId, layout.nodes.length, viewport];
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

    // Across: the whole chart when it fits, otherwise the root's own box, so
    // the reader lands on the ancestor rather than on whichever branch happens
    // to sit at the left edge.
    final scaledWidth = chartWidth * scale;
    final double dx;
    if (scaledWidth <= viewport.width) {
      dx = (viewport.width - scaledWidth) / 2;
    } else {
      final root = layout.nodeFor(rootId);
      final rootCentre =
          (root?.x ?? 0) + layout.metrics.nodeWidth / 2 + _Chart.padding;
      dx = (viewport.width / 2 - rootCentre * scale).clamp(
        viewport.width - scaledWidth,
        0,
      );
    }

    // Down: against the top rather than centred. A tree is read from its
    // ancestor downwards, and a wide short chart floated into the middle of a
    // tall screen puts that ancestor nowhere in particular.
    final matrix = Matrix4.identity()
      ..translateByDouble(dx, 0, 0, 1)
      // All three axes, as InteractiveViewer does itself. Leaving z at 1 still
      // draws correctly, but the viewer reads the scale back with
      // `getMaxScaleOnAxis`, which takes the largest of the three — so it would
      // believe a chart shown at 0.15 was at 1.0 and clamp pinches against the
      // wrong number.
      ..scaleByDouble(scale, scale, scale, 1);

    // After this frame: the viewer is still being laid out, and assigning to a
    // controller mid-build would rebuild what is already building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _view.value = matrix;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final snapshot = ref.watch(familySnapshotProvider(widget.familyId));
    final data = snapshot.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(text.treeTitle),
        actions: <Widget>[
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

    final layout = layoutDescendants(graph, rootId);
    final offChart = graph.persons.length - layout.nodes.length;
    final selected = _selectedId == null
        ? null
        : layout.nodeFor(_selectedId!)?.person;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _fitOnce(layout, rootId, constraints.biggest);
              return _Chart(
                layout: layout,
                selectedId: selected?.id,
                view: _view,
                onTapPerson: (personId) =>
                    setState(() => _selectedId = personId),
              );
            },
          ),
        ),
        if (offChart > 0)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _Notice(message: text.treeOffChart(offChart)),
          ),
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
              onDrawFrom: () => setState(() => _rootId = selected.id),
            ),
          ),
      ],
    );
  }
}

/// The chart itself: pan, zoom, and a tap that lands on a box.
class _Chart extends StatelessWidget {
  const _Chart({
    required this.layout,
    required this.selectedId,
    required this.view,
    required this.onTapPerson,
  });

  final TreeLayout layout;
  final String? selectedId;
  final TransformationController view;
  final ValueChanged<String?> onTapPerson;

  /// Room around the drawing, so the outermost boxes are not against the edge.
  static const double padding = 40;

  @override
  Widget build(BuildContext context) {
    final size = Size(
      layout.width + padding * 2,
      layout.height + padding * 2,
    );

    return InteractiveViewer(
      transformationController: view,
      // Generous margin: without it the chart cannot be dragged away from the
      // corner it starts in, which on a tall tree means the lower generations
      // are unreachable.
      boundaryMargin: const EdgeInsets.all(400),
      minScale: 0.1,
      maxScale: 3,
      constrained: false,
      child: GestureDetector(
        // The gesture sits inside the viewer, so the position it reports is
        // already in chart coordinates whatever the zoom.
        onTapUp: (details) => onTapPerson(_personAt(details.localPosition)),
        child: CustomPaint(
          size: size,
          painter: TreePainter(
            layout: layout,
            selectedId: selectedId,
            colors: Theme.of(context).colorScheme,
            padding: padding,
          ),
        ),
      ),
    );
  }

  /// The box under [point], or null for the space between boxes.
  String? _personAt(Offset point) {
    final metrics = layout.metrics;
    for (final node in layout.nodes) {
      final rect = Rect.fromLTWH(
        node.x + padding,
        node.y + padding,
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
          // goes. The horizontal origin comes from the edge, so a couple's
          // children hang from between the pair rather than from one of them.
          final start = Offset(
            edge.fromAnchorX + padding,
            from.y + metrics.nodeHeight + padding,
          );
          final end = Offset(centreOf(to).dx, to.y + padding);

          // One horizontal bar per marriage, at its own depth. Left at a shared
          // depth, two marriages' bars touch end to end and read as one, which
          // says every child came from the same wife.
          final siblingBars = bars[edge.fromPersonId] ?? <double>[];
          final rank = siblingBars.indexOf(edge.fromAnchorX);
          final fraction = (rank + 1) / (siblingBars.length + 1);
          final midY = start.dy + (end.dy - start.dy) * fraction;

          canvas
            ..drawLine(start, Offset(start.dx, midY), parentLine)
            ..drawLine(Offset(start.dx, midY), Offset(end.dx, midY), parentLine)
            ..drawLine(Offset(end.dx, midY), end, parentLine);
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
      (anchors[edge.fromPersonId] ??= <double>{}).add(edge.fromAnchorX);
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
      ..drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5
          ..color = selected ? colors.primary : colors.outlineVariant,
      );

    final years = _years(node.person);
    final label = TextPainter(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: colors.onSurface),
        children: <InlineSpan>[
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
  }

  /// `1887–1960`, or `1887–` with only a birth, or `–1960` with only a death.
  ///
  /// No space around the dash, and none where a year is missing: `1918 –` reads
  /// like something failed to load, where `1918–` is the ordinary genealogical
  /// way of saying no death is recorded.
  ///
  /// Years only: a box this size cannot carry a full date, and the year is what
  /// places a person in a generation at a glance.
  static String? _years(Person person) {
    final born = person.birthDate?.year;
    final died = person.deathDate?.year;
    if (born == null && died == null) return null;
    return '${born ?? ''}–${died ?? ''}';
  }

  @override
  bool shouldRepaint(TreePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.selectedId != selectedId ||
      oldDelegate.colors != colors;
}

/// What the chart is not showing.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    ),
  );
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
