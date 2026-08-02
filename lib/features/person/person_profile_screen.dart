/// One person: what is recorded about them, and who they are connected to.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../../l10n/app_localizations.dart';
import 'date_display.dart';
import 'person_form_screen.dart';
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
        title: Text(person?.displayName ?? ''),
        actions: <Widget>[
          if (person != null && data != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: AppText.of(context).personEdit,
              onPressed: () => showPersonForm(
                context,
                familyId: familyId,
                usesLunarCalendar: data.family.usesLunarCalendar,
                editing: person,
              ),
            ),
        ],
      ),
      floatingActionButton: person == null || data == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => addRelative(
                context,
                ref,
                snapshot: data,
                subject: person,
              ),
              icon: const Icon(Icons.link),
              label: Text(AppText.of(context).relationshipAdd),
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

    return ListView(
      // Room for the floating button, which otherwise sits on the last rows.
      padding: const EdgeInsets.only(bottom: 96),
      children: <Widget>[
        _Section(title: text.personProfile),
        _Field(label: text.personDisplayName, value: person.displayName),
        _Field(label: text.personGivenName, value: person.givenName),
        _Field(
          label: text.personAdditionalNames,
          value: person.additionalNames,
        ),
        _Field(label: text.personFamilyName, value: person.familyName),
        _Field(
          label: text.personBirthFamilyName,
          value: person.birthFamilyName,
        ),
        // Left out when unknown. "We do not know" and "not filled in" are the
        // same statement here (DOMAIN.md §3.2), and a row saying so is a row
        // carrying nothing, on a screen that omits every other empty field.
        if (person.sex != Sex.unknown)
          _Field(label: text.personSex, value: _sexLabel(text, person.sex)),
        _DateField(
          label: text.personBirth,
          date: person.birthDate,
          usesLunarCalendar: family.usesLunarCalendar,
        ),
        _Field(label: text.personBirthPlace, value: person.birthPlace),
        _DateField(
          label: text.personDeath,
          date: person.deathDate,
          usesLunarCalendar: family.usesLunarCalendar,
        ),
        _Field(label: text.personDeathPlace, value: person.deathPlace),
        _Field(label: text.personBiography, value: person.biography),

        _Section(title: text.personRelatives),
        if (alone)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              text.personNoRelatives,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
      ],
    );
  }

  static String _sexLabel(AppText text, Sex sex) => switch (sex) {
    Sex.male => text.sexMale,
    Sex.female => text.sexFemale,
    Sex.unknown => text.sexUnknown,
  };
}

/// A heading between groups of rows.
class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

/// One recorded value, or nothing at all when it is absent.
///
/// An empty field is omitted rather than shown as "unknown". Most fields are
/// empty for most people in an old gia phả, and a screen of blanks buries what
/// is actually known.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final shown = value?.trim();
    if (shown == null || shown.isEmpty) return const SizedBox.shrink();

    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(shown, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

/// A date, with its lunar reading underneath where the family keeps one.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.usesLunarCalendar,
  });

  final String label;
  final GenealogicalDate? date;
  final bool usesLunarCalendar;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox.shrink();

    final lunar = formatLunar(
      context,
      date,
      usesLunarCalendar: usesLunarCalendar,
    );

    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            formatDate(context, date),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (lunar != null)
            Text(lunar, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        for (final (index, person) in people.indexed)
          ListTile(
            leading: CircleAvatar(
              child: Text(person.displayName.characters.firstOrNull ?? '?'),
            ),
            title: Text(person.displayName),
            subtitle: switch (subtitles?.elementAtOrNull(index)) {
              final String subtitle => Text(subtitle),
              null => null,
            },
            trailing: switch (removes) {
              final RelationshipType type => IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: AppText.of(context).actionRemove,
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
