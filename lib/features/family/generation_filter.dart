/// Picking a đời to narrow a list of people by (DOMAIN.md §11.1).
///
/// A gia phả is read by generation as much as by name — "who is in đời năm"
/// is how somebody looks through a paper one — and on a family of three
/// hundred a list that can only be filtered by typing is a list nobody can
/// survey.
///
/// Chips rather than a typed `đời 5`: a syntax nobody discovers is a feature
/// nobody has, and a bare number in the search field cannot be told apart from
/// a year of birth. The row also says, without being asked, how many đời the
/// family runs to and how many people stand in each.
library;

import 'package:flutter/material.dart';

import '../../app/grouped_list.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';

/// The people of one đời, or of none.
///
/// Null means everybody: no đời is chosen and the list is whole.
typedef GenerationChoice = int?;

/// Narrows [people] to those standing in [chosen].
///
/// [chosen] of null returns everybody. [unknownGeneration] returns those the
/// founding line does not reach, who are absent from [doi] — a separate line
/// recorded in the same family has no đời in this one's counting, and hiding
/// them behind a filter they can never match would lose them.
List<Person> ofGeneration(
  List<Person> people,
  Map<String, int> doi,
  GenerationChoice chosen,
) {
  if (chosen == null) return people;

  return <Person>[
    for (final person in people)
      if (chosen == unknownGeneration
          ? !doi.containsKey(person.id)
          : doi[person.id] == chosen)
        person,
  ];
}

/// The chip standing for people with no đời at all.
///
/// A sentinel rather than a separate field: it is one more choice in the same
/// row, and a second piece of state would have to be kept in step with this
/// one at every call site.
const int unknownGeneration = -1;

/// How many people stand in each đời, and how many in none.
///
/// Only đời that somebody occupies get an entry, so the row shows the family
/// as it is rather than every number up to the deepest.
Map<GenerationChoice, int> countByGeneration(
  List<Person> people,
  Map<String, int> doi,
) {
  final counts = <GenerationChoice, int>{};
  for (final person in people) {
    final at = doi[person.id] ?? unknownGeneration;
    counts[at] = (counts[at] ?? 0) + 1;
  }
  return counts;
}

/// A row of đời to filter a list of people by.
class GenerationFilter extends StatefulWidget {
  const GenerationFilter({
    required this.counts,
    required this.chosen,
    required this.onChosen,
    super.key,
  });

  /// How many people each đời holds, from [countByGeneration].
  final Map<GenerationChoice, int> counts;

  /// The đời being shown, or null for all of them.
  final GenerationChoice chosen;

  final ValueChanged<GenerationChoice> onChosen;

  /// Whether there is anything worth choosing between.
  ///
  /// One đời is no choice at all, and a row of a single chip is furniture.
  bool get isWorthShowing => counts.length > 1;

  /// How much room the row needs, badges and all.
  ///
  /// Published because the screen has to reserve exactly this much to pin the
  /// row under the bar, and a second copy of the number would drift.
  static const double height = 60;

  @override
  State<GenerationFilter> createState() => _GenerationFilterState();
}

class _GenerationFilterState extends State<GenerationFilter> {
  final ScrollController _scroll = ScrollController();

  /// Where the chosen chip is, so the row can be scrolled to it.
  final GlobalKey _chosenKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // The picker opens already narrowed to the đời a relative would stand in,
    // and on a family of twelve that chip can be off the right-hand end. A
    // reader would see a shortened list and no sign of why.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showChosen());
  }

  @override
  void didUpdateWidget(GenerationFilter old) {
    super.didUpdateWidget(old);
    if (old.chosen != widget.chosen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showChosen());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the chosen chip to the middle of the row.
  ///
  /// The middle rather than merely into view: the đời either side of it are
  /// the ones a reader is most likely to want next, and centring shows both.
  /// Against an end the scrollable clamps, so the first and last chips stay
  /// where they are rather than being dragged inwards.
  void _showChosen() {
    final box = _chosenKey.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return;

    // This row's own position, and nothing else's. `Scrollable.ensureVisible`
    // walks every scrollable above it as well, and on the family list that
    // meant the whole list of people scrolled too — throwing the reader back
    // to the top each time they chose a đời.
    _scroll.position.ensureVisible(
      box,
      alignment: 0.5,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    final order = widget.counts.keys.toList()
      ..sort((a, b) {
        // The unnumbered last: they are the exception, not đời zero.
        if (a == unknownGeneration) return 1;
        if (b == unknownGeneration) return -1;
        return a!.compareTo(b!);
      });

    return SizedBox(
      // Tall enough for the chip and the badge hanging over its corner.
      height: GenerationFilter.height,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // Every chip built, not only those on screen: one off the end cannot
        // be scrolled to if it does not exist, and a family runs to tens of
        // đời rather than thousands.
        child: Row(
          children: <Widget>[
            _chip(
              context,
              label: text.generationFilterAll,
              // Everybody, which is the sum of the đời beside it: the badges
              // are then a set of parts and their whole rather than a row of
              // unrelated numbers.
              count: widget.counts.values.fold<int>(0, (a, b) => a + b),
              selected: widget.chosen == null,
              onTap: () => widget.onChosen(null),
            ),
            for (final at in order)
              _chip(
                context,
                label: at == unknownGeneration
                    ? text.generationFilterUnknown
                    : text.treeGenerationOrdinal(at!),
                count: widget.counts[at],
                selected: widget.chosen == at,
                onTap: () =>
                    widget.onChosen(widget.chosen == at ? null : at),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    final theme = Theme.of(context);

    // Filled when chosen, a quiet grey when not, and no outline either way. A
    // row of outlined chips reads as a dozen things waiting to be pressed; a
    // row of flat ones reads as a scale with a place marked on it, which is
    // what a list of đời is.
    final ink = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      key: selected ? _chosenKey : null,
      // Room above and to the right for the badge to hang over the corner.
      padding: const EdgeInsets.fromLTRB(4, 10, 8, 6),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          ChoiceChip(
            selected: selected,
            onSelected: (_) => onTap(),
            showCheckmark: false,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            selectedColor: theme.colorScheme.primary,
            side: BorderSide.none,
            shape: const StadiumBorder(),
            // The label is the whole chip now that the count has moved out,
            // so it is centred rather than laid out beside something.
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            padding: EdgeInsets.zero,
            label: SizedBox(
              height: 36,
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: ink,
                  ),
                ),
              ),
            ),
          ),
          if (count != null)
            // Straddling the corner, as the fold badge does on a box in the
            // chart: the same thing said the same way in both places.
            Positioned(
              top: -8,
              right: -8,
              child: IgnorePointer(child: _CountBadge(count: count)),
            ),
        ],
      ),
    );
  }
}

/// How many people a đời holds, on the corner of its chip.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: GroupedColors.red,
        borderRadius: BorderRadius.circular(9),
        // A ring in the page colour, so the badge reads as lying on the chip
        // rather than as a lump grown out of its edge.
        border: Border.all(color: GroupedColors.page(context), width: 2),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
