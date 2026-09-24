/// The path of relatives a reader has walked, shown where the title goes.
///
/// Reading a gia phả is walking: open somebody, open their father, open his
/// brother, open the brother's wife. Each of those pushes a screen, so getting
/// back to the list of people means pressing back once per person — and the
/// reader has no idea how many that is.
///
/// A trail in the title row rather than a row of its own, and rather than a
/// lone "home" button:
///
/// * **Nowhere else has room.** A phone's vertical space is the scarcest thing
///   on this screen. The title row already exists, and at depth it is showing
///   a name the body can show better — so the path costs no height at all.
/// * **A home button is one-way.** It throws the whole path away. The trail
///   gets back to *any* point on it, which is what somebody comparing two
///   cousins actually wants.
/// * **The first entry does the home button's job anyway**, so there is one
///   affordance to learn rather than two.
///
/// Only the given name is shown. A full Vietnamese name runs to some 100–140
/// points, and the title row has about 280 between the back button and the
/// action opposite — two names, with no sense of a path. Given names run to
/// some 55, which fits four or five, and that is where a trail starts being
/// one.
library;

import 'package:flutter/material.dart';

import '../../app/grouped_list.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';

/// Where a walk through relatives began, which is where its first entry goes.
enum TrailOrigin {
  /// The family's list of people.
  personList,

  /// The chart. A profile opened from a box on it returns to the chart.
  tree;

  IconData get icon => switch (this) {
    TrailOrigin.personList => Icons.people_alt_rounded,
    TrailOrigin.tree => Icons.account_tree_rounded,
  };

  String label(BuildContext context) => switch (this) {
    TrailOrigin.personList => AppText.of(context).trailToList,
    TrailOrigin.tree => AppText.of(context).trailToTree,
  };
}

/// The name a person is called by, for somewhere too narrow for all of it.
///
/// The recorded given name when there is one, and otherwise the last word of
/// the display name — the same rule `rankName` uses to decide what a search
/// matched, so the two cannot disagree about which word is the name.
String shortName(Person person) {
  final given = person.givenName?.trim();
  if (given != null && given.isNotEmpty) return given;

  final words = person.displayName.trim().split(RegExp(r'\s+'));
  return words.isEmpty ? person.displayName : words.last;
}

/// The walked path, as a scrolling row of given names.
///
/// [path] runs from the first person opened to the one on screen, who is last
/// and is always the active entry — there is no forward history, because
/// stepping back pops the screens ahead.
class PersonTrail extends StatefulWidget {
  const PersonTrail({
    required this.path,
    required this.origin,
    required this.onGoTo,
    required this.onGoHome,
    super.key,
  });

  /// The people walked through, in order. The last is the one being read.
  final List<Person> path;

  /// How much height the row needs, so a bar can reserve exactly this much.
  static const double height = 40;

  final TrailOrigin origin;

  /// Step back to `path[index]`, dropping everyone after them.
  final ValueChanged<int> onGoTo;

  /// Leave the chain entirely, for wherever it started.
  final VoidCallback onGoHome;

  @override
  State<PersonTrail> createState() => _PersonTrailState();
}

class _PersonTrailState extends State<PersonTrail> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd());
  }

  @override
  void didUpdateWidget(PersonTrail old) {
    super.didUpdateWidget(old);
    if (old.path.length != widget.path.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showEnd());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls to the end of the path, which is where the reader is.
  ///
  /// The end rather than anywhere else, because the person being read is
  /// always the last entry — there is no forward history, since stepping back
  /// pops the screens ahead. An earlier version tried to centre them, which
  /// cannot mean anything for something that is always last: it only put
  /// blank space to their right.
  ///
  /// Nothing happens when the whole path fits, because there is then no
  /// scroll extent to move through.
  void _showEnd() {
    if (!_scroll.hasClients) return;

    _scroll.position.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.path.length - 1;

    return SizedBox(
      height: PersonTrail.height,
      // Told to fill the slot rather than left to size itself. A horizontal
      // scroll view under loose constraints shrink-wraps its content, and the
      // theme centres titles — so a long path ended up in a box the width of
      // a short one, centred, scrolling inside that.
      width: double.infinity,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Home(origin: widget.origin, onTap: widget.onGoHome),
            for (var i = 0; i < widget.path.length; i++) ...<Widget>[
              const _Separator(),
              _Step(
                name: shortName(widget.path[i]),
                active: i == last,
                // The one being read is where the reader already is.
                onTap: i == last ? null : () => widget.onGoTo(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.origin, required this.onTap});

  final TrailOrigin origin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    icon: Icon(origin.icon, size: 20),
    color: GroupedColors.secondaryLabel(context),
    tooltip: origin.label(context),
    onPressed: onTap,
  );
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Icon(
      Icons.chevron_right,
      size: 16,
      color: GroupedColors.secondaryLabel(context),
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({
    required this.name,
    required this.active,
    required this.onTap,
  });

  final String name;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The one being read carries the application's colour; the path behind it
    // is quiet. Weight as well as colour, so the difference survives being
    // read in sunlight or by somebody who does not separate the two hues.
    final style = theme.textTheme.titleMedium?.copyWith(
      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
      color: active
          ? GroupedColors.primary(context)
          : GroupedColors.secondaryLabel(context),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(name, style: style, maxLines: 1, softWrap: false),
      ),
    );
  }
}
