/// One family: the people in it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/name_search.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';
import '../person/person_form_screen.dart';
import '../person/person_profile_screen.dart';
import '../person/person_style.dart';
import '../tree/tree_screen.dart';

/// Opens the screen for [family].
Future<void> showFamilyScreen(BuildContext context, Family family) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyScreen(familyId: family.id),
      ),
    );

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({required this.familyId, super.key});

  final String familyId;

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final familyId = widget.familyId;
    final snapshot = ref.watch(familySnapshotProvider(familyId));

    final data = snapshot.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(data?.family.name ?? ''),
        actions: <Widget>[
          if (data != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: text.personAdd,
                onPressed: () => showPersonForm(
                  context,
                  familyId: familyId,
                  usesLunarCalendar: data.family.usesLunarCalendar,
                ),
              ),
            ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          if (data == null) return const SizedBox.shrink();
          final people = data.graph.persons;
          if (people.isEmpty) return const _NoPeopleYet();

          // Diacritics are ignored, because half the family will type the name
          // without them (PRODUCT.md §1.1).
          final typed = _query.text.trim();
          final matches = <Person>[
            for (final person in people)
              if (nameMatches(person.displayName, typed)) person,
          ];

          // Floating over the list rather than beside it: the tree and the
          // search field are always within reach, and the list keeps the full
          // height of the screen to scroll through.
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      // Name and notes are not repeated under the portrait:
                      // the bar above already carries the name, and the notes
                      // were read on the way in.
                      child: AvatarHeader(
                        initials: familyInitial(data.family.name),
                        badge: CountBadge(
                          icon: Icons.person,
                          label: people.length.toString(),
                        ),
                      ),
                    ),
                    if (matches.isEmpty)
                      SliverToBoxAdapter(
                        child: GroupedSection(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                14,
                              ),
                              child: Text(
                                text.searchNoMatch,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: GroupedColors.secondaryLabel(
                                        context,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GroupedSliverSection(
                        // The count only earns its place while filtering; the
                        // badge on the avatar already gives the total.
                        header: typed.isEmpty
                            ? null
                            : text.familyPersonCount(matches.length),
                        itemCount: matches.length,
                        itemBuilder: (context, index) =>
                            _PersonTile(person: matches[index]),
                      ),
                    // Enough room to scroll the last row clear of what floats
                    // over it.
                    const SliverToBoxAdapter(child: SizedBox(height: 150)),
                  ],
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(right: 16, bottom: 4),
                        child: FloatingActionButton(
                          heroTag: null,
                          onPressed: () => showTreeScreen(context, familyId),
                          tooltip: text.treeTitle,
                          child: const Icon(Icons.account_tree_rounded),
                        ),
                      ),
                      // Never scrolled away: with a few thousand names, a
                      // search field that leaves the screen is one nobody can
                      // reach when they need it.
                      SearchPill(
                        controller: _query,
                        hint: text.searchByName,
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) => GroupedRow(
    icon: personIcon(person),
    iconColor: personColor(person),
    title: person.displayName,
    subtitle: _lifespan(person),
    // The profile, not the form. Reading is the common case, and editing is
    // one tap further in.
    onTap: () => showPersonProfile(
      context,
      familyId: person.familyId,
      personId: person.id,
    ),
  );

  /// `~1782–1851`, with whichever end is known.
  ///
  /// Years only, even where the full date is recorded: a row read at a glance
  /// wants the span, and mixing precisions gives `1835–1902-04`, which reads
  /// like two different kinds of thing. The full dates are one tap away.
  ///
  /// No space around the dash, so a missing end reads as unrecorded rather than
  /// as a value that failed to load. The tilde carries "about" through
  /// (DOMAIN.md §4.2).
  static String? _lifespan(Person person) {
    String? show(GenealogicalDate? date) => date == null
        ? null
        : '${date.isApproximate ? '~' : ''}${date.year}';

    final born = show(person.birthDate);
    final died = show(person.deathDate);
    if (born == null && died == null) return null;
    return '${born ?? ''}–${died ?? ''}';
  }
}

class _NoPeopleYet extends StatelessWidget {
  const _NoPeopleYet();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              text.peopleEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text.peopleEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
