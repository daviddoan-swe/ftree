/// One family: the people in it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../domain/name_search.dart';
import 'generation_filter.dart';
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

  /// The đời being shown, or null for all of them.
  GenerationChoice _generation;

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

          // Đời from the graph, which is where every screen gets them, so no
          // two can disagree about a reader's own family (DOMAIN.md §11.1).
          final doi = data.graph.generations();
          final counts = countByGeneration(people, doi);
          final filter = GenerationFilter(
            counts: counts,
            chosen: _generation,
            onChosen: (at) => setState(() => _generation = at),
          );

          // Both narrow at once: đời five and named Hải is a reasonable thing
          // to be looking for, and either alone may be hundreds of people.
          final matches = <Person>[
            for (final person in ofGeneration(people, doi, _generation))
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
                    if (filter.isWorthShowing)
                      SliverToBoxAdapter(child: filter),
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
                        // No count above the list: the chip that is chosen
                        // carries its own, and the same number twice on one
                        // screen is one of them going stale.
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
                          // A circle, not Material 3's rounded square: it sits
                          // beside round icon buttons and a pill.
                          shape: const CircleBorder(),
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
    subtitle: lifeYears(person),
    // The profile, not the form. Reading is the common case, and editing is
    // one tap further in.
    onTap: () => showPersonProfile(
      context,
      familyId: person.familyId,
      personId: person.id,
    ),
  );

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
