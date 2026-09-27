/// One family: the people in it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../data/database/family_roles.dart';
import '../../domain/family.dart';
import '../../domain/name_search.dart';
import '../sync/conflicts_screen.dart';
import '../sync/sync_status.dart';
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

  final ScrollController _scroll = ScrollController();

  /// Chooses a đời without sending the reader back to the top.
  ///
  /// The list gets shorter, and a scroll position past the end of the new one
  /// is clamped — often to nothing, which puts the portrait back on screen
  /// and loses the place the reader had scrolled to. Their place is kept as
  /// far as the shorter list allows.
  void _chooseGeneration(GenerationChoice at) {
    final wasAt = _scroll.hasClients ? _scroll.offset : 0.0;
    setState(() => _generation = at);
    if (wasAt <= 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;

      final keep = wasAt.clamp(0.0, _scroll.position.maxScrollExtent);
      if ((_scroll.offset - keep).abs() > 0.5) _scroll.jumpTo(keep);
    });
  }

  /// Held rather than reached for through `ref`, because the send below runs
  /// while this screen is being taken down and a `WidgetRef` stops working the
  /// moment its widget is disposed. The container belongs to the scope above
  /// every screen, so it is still there to finish the work.
  ///
  /// Read with `listen: false` in [initState], which looks the element up
  /// without depending on it — the form a lookup has to take this early.
  late final ProviderContainer _container = ProviderScope.containerOf(
    context,
    listen: false,
  );

  @override
  void initState() {
    super.initState();

    // Opening a family is when somebody wants to be looking at it, which makes
    // it the moment worth spending a request on. Not at start-up: pulling six
    // families to draw a list of names would be paying for five of them.
    //
    // After the first frame, because this reads providers and writes to the
    // database, and neither belongs in the middle of building a widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(syncFamily(_container, widget.familyId));
    });
  }

  /// Synchronises, and says what happened.
  ///
  /// Only from the pull, which is the one moment somebody asked. The wheel
  /// stopping means "it finished", not "it worked" — offline it spun, stopped
  /// and said nothing at all, which is the shape of failure this whole step
  /// exists to end.
  Future<void> _syncAndSay(String familyId) async {
    // Read before the wait, not after: the screen may be gone by the time the
    // server answers, and a `BuildContext` does not survive that.
    final text = AppText.of(context);
    final report = syncReport(text, await syncFamily(_container, familyId));

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(report)));
  }

  @override
  void dispose() {
    // Leaving is when somebody has finished writing, and so when what they
    // wrote should go. Opening was the wrong moment for it: by then the work
    // had been sitting here since the last visit, and a person added to a
    // family nobody opened again stayed on one phone and reached nobody.
    //
    // The whole of a synchronisation and not only the sending half, for the
    // reason written on [syncFamily]: the server takes what it is given, so a
    // push with no pull in front of it overwrites whatever arrived since this
    // screen opened, and the device that wrote it has already cleared the flag
    // that would have sent it again. Somebody editing the same relative in the
    // minutes this screen was open would simply lose it.
    //
    // Not awaited, and deliberately outliving this screen. Nothing it brings
    // down has a screen left to draw it, and anything it fails to get away
    // stays flagged and goes on the next visit (PRODUCT §4.2).
    unawaited(syncFamily(_container, widget.familyId));

    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final familyId = widget.familyId;
    final snapshot = ref.watch(familySnapshotProvider(familyId));

    final data = snapshot.valueOrNull;

    // What this copy arrived as. Absent means nobody else has a claim on it,
    // and every right follows (PRODUCT §5.0).
    final role = ref.watch(familyRoleMapProvider).valueOrNull?[familyId];

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        // The name, and under it where this copy stands with the server. Two
        // short lines rather than one: the bar has the room, and the status
        // has nowhere else to be that is not in the way of the gia phả.
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(data?.family.name ?? ''),
            if (data != null) SyncStatusLine(familyId: familyId),
          ],
        ),
        actions: <Widget>[
          // A viewer reads; the server refuses their writes anyway
          // (`persons_insert`), so offering the button would be offering work
          // that cannot land (PRODUCT §5.0).
          if (data != null && role.mayEditPeople)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: text.personAdd,
                onPressed: () => showPersonForm(
                  context,
                  familyId: familyId,
                  familyName: data.family.name,
                  usesLunarCalendar: data.family.usesLunarCalendar,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Said where the family is, not on a screen somebody has to think to
          // open. A disagreement nobody is told about is a disagreement that
          // settles itself by being forgotten (ROADMAP M9, step 3b).
          if (ref.watch(conflictCountProvider(familyId)).valueOrNull
              case final waiting? when waiting > 0)
            Material(
              color: GroupedColors.orange.withValues(alpha: 0.15),
              child: InkWell(
                onTap: () => showConflicts(context, familyId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.call_split, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(text.conflictsWaiting(waiting))),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            ),

          // Said out loud, because every control vanishing with no explanation
          // reads as the application breaking rather than as a decision
          // somebody took (PRODUCT §5.0). The gia phả stays readable; nothing
          // more, and nothing less.
          if (role == FamilyRole.removed)
            Container(
              width: double.infinity,
              color: GroupedColors.red.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                text.familyRemovedNotice,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: GroupedColors.red),
              ),
            ),
          Expanded(
            child: snapshot.when(
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
                  onChosen: _chooseGeneration,
                );

                // Both narrow at once: đời five and named Hải is a reasonable thing
                // to be looking for, and either alone may be hundreds of people.
                //
                // Ranked rather than filtered: whoever is *called* what was typed
                // comes before whoever merely contains it somewhere.
                final matches = rankedByName(
                  ofGeneration(people, doi, _generation),
                  typed,
                  nameOf: (person) => person.displayName,
                );

                // Floating over the list rather than beside it: the tree and the
                // search field are always within reach, and the list keeps the full
                // height of the screen to scroll through.
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      // Pulling the gia phả down synchronises it. Opening a
                      // family and leaving one already do, so this is for the
                      // moment in between — somebody waiting on a relative's
                      // change who does not want to leave the screen and come
                      // back to see whether it has arrived.
                      //
                      // It is a hidden gesture, which is its weakness: the
                      // people this is for are relatives, not application
                      // users, and a control nobody discovers is a control
                      // nobody has. That is a cost taken knowingly, and M9's
                      // status line is where it will be said out loud.
                      child: RefreshIndicator(
                        onRefresh: () => _syncAndSay(familyId),
                        child: CustomScrollView(
                          controller: _scroll,
                          // Always scrollable, or a family short enough to fit
                          // the screen is one the gesture does not work on —
                          // and that is most of them at three people.
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
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
                              // Pinned: the row stays under the bar once the portrait
                              // above it has scrolled away. On three hundred names a
                              // reader is deep in the list by the time they know which
                              // đời they wanted, and a filter they have to scroll back
                              // to the top to reach is one they will not use.
                              //
                              // The portrait is not pinned with it. It says which
                              // family this is, which the bar already says, and it
                              // would cost half the screen to keep.
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _PinnedRow(
                                  height: GenerationFilter.height,
                                  background: GroupedColors.page(context),
                                  child: filter,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color:
                                                  GroupedColors.secondaryLabel(
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
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 150),
                            ),
                          ],
                        ),
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
                              padding: const EdgeInsets.only(
                                right: 16,
                                bottom: 4,
                              ),
                              child: FloatingActionButton(
                                heroTag: null,
                                // A circle, not Material 3's rounded square: it sits
                                // beside round icon buttons and a pill.
                                shape: const CircleBorder(),
                                onPressed: () =>
                                    showTreeScreen(context, familyId),
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
          ),
        ],
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

/// Holds one fixed-height row under the bar while the list scrolls past it.
class _PinnedRow extends SliverPersistentHeaderDelegate {
  const _PinnedRow({
    required this.child,
    required this.height,
    required this.background,
  });

  final Widget child;
  final double height;

  /// Opaque, or the names would scroll through the row it is holding still.
  final Color background;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_PinnedRow old) =>
      old.child != child ||
      old.height != height ||
      old.background != background;
}
