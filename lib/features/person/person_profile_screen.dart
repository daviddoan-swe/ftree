/// One person: what is recorded about them, and who they are connected to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/age.dart';
import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../../l10n/app_localizations.dart';
import 'date_display.dart';
import 'person_form_screen.dart';
import 'person_style.dart';
import 'relationship_editing.dart';

/// Opens the profile of [personId] within [familyId].
Future<void> showPersonProfile(
  BuildContext context, {
  required String familyId,
  required String personId,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        PersonProfileScreen(familyId: familyId, personId: personId),
  ),
);

/// A person, read-only.
///
/// Takes ids rather than the entity: the person is re-read from the snapshot on
/// every build, so an edit made here — or on a relative's profile deeper in the
/// stack — is reflected when this screen comes back into view.
class PersonProfileScreen extends ConsumerWidget {
  const PersonProfileScreen({
    required this.familyId,
    required this.personId,
    super.key,
  });

  final String familyId;
  final String personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(familySnapshotProvider(familyId));
    final data = snapshot.valueOrNull;
    final person = data?.graph.personById(personId);

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(person?.displayName ?? ''),
        actions: <Widget>[
          // Adding a relative is the one thing done from here often enough to
          // earn the corner. Editing is rarer and waits at the foot of the
          // screen, where a change follows reading what is already recorded.
          if (person != null && data != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.add_link),
                tooltip: AppText.of(context).relationshipAdd,
                onPressed: () => addRelative(
                  context,
                  ref,
                  snapshot: data,
                  subject: person,
                ),
              ),
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
        // Deleted from under us, or the id was never in this family. Nothing to
        // say about a person who is not there; the user can go back.
        _ when person == null || data == null => const SizedBox.shrink(),
        _ => _Profile(person: person, snapshot: data),
      },
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.person, required this.snapshot});

  final Person person;
  final FamilySnapshot snapshot;

  Family get family => snapshot.family;
  FamilyGraph get graph => snapshot.graph;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final siblings = graph.siblings(person.id);
    final parents = graph.parents(person.id);
    final spouses = graph.spouses(person.id);
    final children = graph.children(person.id);
    final alone =
        parents.isEmpty &&
        spouses.isEmpty &&
        children.isEmpty &&
        siblings.isEmpty;

    // Grouped the way the information is read: who they are, then when they
    // lived, then what was written about them. A screen of identical rows makes
    // the reader do that sorting themselves.
    final names = <Widget>[
      ?_pair(
        context,
        text.personGivenName,
        person.givenName,
        text.personFamilyName,
        person.familyName,
      ),
      ?_pair(
        context,
        text.personAdditionalNames,
        person.additionalNames,
        text.personBirthFamilyName,
        person.birthFamilyName,
      ),
    ];

    final life = <Widget>[
      ?_dates(context),
      ?_pair(
        context,
        text.personBirthPlace,
        person.birthPlace,
        text.personDeathPlace,
        person.deathPlace,
      ),
    ];

    return ListView(
      // Nothing floats over this screen any more, so the tail is just breathing
      // room under the last button.
      padding: const EdgeInsets.only(bottom: 40),
      children: <Widget>[
        // No heading and no name: the bar above carries the name, and a line
        // repeating it is a line saying nothing. Sex rides in the badge rather
        // than taking a row of its own — one of three states does not need a
        // label and a value, and `unknown` is a real answer here, not a blank
        // (DOMAIN.md §3.2).
        AvatarHeader(
          initials: initialsOf(person.displayName),
          subtitle: _age(context),
          badge: CountBadge(icon: sexIcon(person.sex)),
          color: personColor(person),
        ),
        GroupedSection(children: names),
        GroupedSection(children: life),
        if (person.biography case final notes?
            when notes.trim().isNotEmpty)
          GroupedSection(
            header: text.personBiography,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  notes,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),

        if (alone)
          GroupedSection(
            header: text.personRelatives,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  text.personNoRelatives,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: GroupedColors.secondaryLabel(context),
                  ),
                ),
              ),
            ],
          ),
        _Relatives(
          label: text.relationParents,
          people: parents,
          snapshot: snapshot,
          subject: person,
          removes: RelationshipType.parentChild,
        ),
        _Relatives(
          label: text.relationSpouses,
          people: spouses,
          snapshot: snapshot,
          subject: person,
          removes: RelationshipType.spouse,
        ),
        _Relatives(
          label: text.relationChildren,
          people: children,
          snapshot: snapshot,
          subject: person,
          removes: RelationshipType.parentChild,
        ),
        _Relatives(
          label: text.relationSiblings,
          people: <Person>[for (final s in siblings) s.person],
          snapshot: snapshot,
          subject: person,
          // Nothing to remove: siblinghood is not an edge. It follows from the
          // parents they share, so it is unmade by unmaking one of those
          // (DOMAIN.md §8.1).
          removes: null,
          // The shared-parent count, not "full" or "half": with one recorded
          // parent the two are indistinguishable, and a person may have both
          // biological and adoptive parents (DOMAIN.md §8.1).
          subtitles: <String>[
            for (final s in siblings)
              text.siblingSharedParents(s.sharedParentCount),
          ],
        ),

        // Last, after everything recorded about this person has been scrolled
        // past. Deleting somebody is a decision that should follow reading, not
        // precede it.
        _DeletePerson(person: person, snapshot: snapshot),
      ],
    );
  }

  /// One row carrying up to two short values, or nothing when neither is
  /// recorded.
  ///
  /// A given name and a family name are a few characters each; a row apiece
  /// spreads them over a screen of white space and makes the reader scroll past
  /// what they could have taken in at a glance.
  Widget? _pair(
    BuildContext context,
    String labelA,
    String? valueA,
    String? labelB,
    String? valueB,
  ) {
    final a = valueA?.trim();
    final b = valueB?.trim();
    final hasA = a != null && a.isNotEmpty;
    final hasB = labelB != null && b != null && b.isNotEmpty;
    if (!hasA && !hasB) return null;

    return FieldRow(
      children: <Widget>[
        if (hasA) InfoField(label: labelA, value: a),
        if (hasB) InfoField(label: labelB, value: b),
      ],
    );
  }

  /// Born and died side by side, each with its lunar reading underneath.
  Widget? _dates(BuildContext context) {
    final text = AppText.of(context);
    final lunar = family.usesLunarCalendar;
    final birth = person.birthDate;
    final death = person.deathDate;
    if (birth == null && death == null) return null;

    return FieldRow(
      children: <Widget>[
        if (birth != null)
          InfoField(
            label: text.personBirth,
            value: formatDate(context, birth),
            note: formatLunar(context, birth, usesLunarCalendar: lunar),
          ),
        if (death != null)
          InfoField(
            label: text.personDeath,
            value: formatDate(context, death),
            note: formatLunar(context, death, usesLunarCalendar: lunar),
          ),
      ],
    );
  }

  /// `48 tuổi` under the portrait, or nothing when it cannot be told.
  ///
  /// An age says more at a glance than a pair of years: how long a life was,
  /// or how old somebody is now. The years themselves are two rows below.
  String? _age(BuildContext context) {
    final years = ageInYears(
      birth: person.birthDate,
      death: person.deathDate,
      currentYear: DateTime.now().year,
    );
    return years == null ? null : AppText.of(context).personAge(years);
  }
}

/// What can be done to this person, at the foot of everything recorded.
///
/// Editing is an ordinary button — bordered and filled — because it is an
/// ordinary act. Deleting is bare red text: no border to invite a thumb, and
/// it comes last.
///
/// Deletion is soft, like every deletion here: the row is tombstoned rather
/// than erased, so it still exists to be synchronised (DOMAIN.md §15.2). The
/// application offers no way back, which is what the confirmation says.
class _DeletePerson extends ConsumerWidget {
  const _DeletePerson({required this.person, required this.snapshot});

  final Person person;
  final FamilySnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: GroupedColors.card(context),
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: GroupedColors.separator(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: Text(text.personEdit),
            onPressed: () => showPersonForm(
              context,
              familyId: person.familyId,
              usesLunarCalendar: snapshot.family.usesLunarCalendar,
              editing: person,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: Text(text.personDelete),
            onPressed: () => _confirmAndDelete(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final text = AppText.of(context);
    final navigator = Navigator.of(context);

    // Counted here rather than left to the repository, because the number is
    // the whole point of asking: relationships go with the person.
    final losing = snapshot.graph.relationships
        .where((r) => r.involves(person.id))
        .length;

    final confirmed = await confirmDestructive(
      context,
      title: text.deleteTitle(person.displayName),
      body: text.personDeleteBody(losing),
      confirmLabel: text.actionDelete,
    );
    if (!confirmed) return;

    await ref
        .read(familySnapshotProvider(person.familyId).notifier)
        .removePerson(person.id);

    // Only if there is somewhere to go. Popping the last route leaves a blank
    // window, which reads as a crash — and the screen the reader was on is
    // gone either way, since the person is.
    if (navigator.canPop()) navigator.pop();
  }
}

/// One kind of relative, each tappable through to their own profile.
class _Relatives extends ConsumerWidget {
  const _Relatives({
    required this.label,
    required this.people,
    required this.snapshot,
    required this.subject,
    required this.removes,
    this.subtitles,
  });

  final String label;
  final List<Person> people;
  final FamilySnapshot snapshot;

  /// Whose profile this is; one end of every link listed here.
  final Person subject;

  /// The kind of edge to unmake, or null when the list is derived rather than
  /// stored.
  final RelationshipType? removes;

  /// Extra line per person, positionally matched with [people].
  final List<String>? subtitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (people.isEmpty) return const SizedBox.shrink();

    return GroupedSection(
      header: label,
      children: <Widget>[
        for (final (index, person) in people.indexed)
          GroupedRow(
            icon: personIcon(person),
            iconColor: personColor(person),
            title: person.displayName,
            subtitle: subtitles?.elementAtOrNull(index),
            trailing: switch (removes) {
              final RelationshipType type => IconButton(
                icon: const Icon(Icons.link_off, size: 20),
                tooltip: AppText.of(context).actionRemove,
                color: GroupedColors.secondaryLabel(context),
                onPressed: () => removeRelative(
                  context,
                  ref,
                  snapshot: snapshot,
                  subject: subject,
                  other: person,
                  type: type,
                ),
              ),
              null => null,
            },
            onTap: () => showPersonProfile(
              context,
              familyId: subject.familyId,
              personId: person.id,
            ),
          ),
      ],
    );
  }
}
