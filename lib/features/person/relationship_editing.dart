/// Connecting one person to another, and undoing it.
///
/// Both directions of a parent-child edge are offered — *add a parent* and
/// *add a child* — because that is how a person is described. The domain has
/// one edge either way; only the parameter order differs (DOMAIN.md §6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/confirm.dart';
import '../../app/providers.dart';
import '../../app/validation_prompts.dart';
import '../../domain/family_repository.dart';
import '../../domain/ids.dart';
import '../../domain/name_search.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../../l10n/app_localizations.dart';

/// What the person being picked will be to the subject.
///
/// A presentation concept. [parent] and [child] both produce a parent-child
/// relationship, differing only in which end the subject occupies.
enum RelativeRole { parent, spouse, child }

/// Asks for a role and a person, then adds the relationship.
///
/// Validation runs against the graph the caller already holds, because a cycle
/// cannot be seen from a single edge (§13.1). Errors block; warnings are
/// confirmable, as everywhere else.
Future<void> addRelative(
  BuildContext context,
  WidgetRef ref, {
  required FamilySnapshot snapshot,
  required Person subject,
}) async {
  final role = await _chooseRole(context);
  if (role == null || !context.mounted) return;

  final candidates = <Person>[
    for (final person in snapshot.graph.persons)
      if (person.id != subject.id) person,
  ];
  final other = await _choosePerson(context, candidates);
  if (other == null || !context.mounted) return;

  final relationship = _build(role, subject: subject, other: other);
  final result = snapshot.graph.validateAddition(relationship);

  if (result.hasErrors) {
    await showBlockingIssues(context, result);
    return;
  }
  if (result.hasIssues && !await confirmWarnings(context, result)) return;

  await ref
      .read(familySnapshotProvider(subject.familyId).notifier)
      .saveRelationship(relationship);
}

Relationship _build(
  RelativeRole role, {
  required Person subject,
  required Person other,
}) => switch (role) {
  RelativeRole.parent => Relationship.parentChild(
    id: newId(),
    familyId: subject.familyId,
    parent: other.id,
    child: subject.id,
  ),
  RelativeRole.child => Relationship.parentChild(
    id: newId(),
    familyId: subject.familyId,
    parent: subject.id,
    child: other.id,
  ),
  RelativeRole.spouse => Relationship.spouse(
    id: newId(),
    familyId: subject.familyId,
    personA: subject.id,
    personB: other.id,
  ),
};

Future<RelativeRole?> _chooseRole(BuildContext context) {
  final text = AppText.of(context);
  return showModalBottomSheet<RelativeRole>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.escalator_warning_outlined),
            title: Text(text.relationshipAddParent),
            onTap: () =>
                Navigator.of(sheetContext).pop(RelativeRole.parent),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(text.relationshipAddSpouse),
            onTap: () =>
                Navigator.of(sheetContext).pop(RelativeRole.spouse),
          ),
          ListTile(
            leading: const Icon(Icons.child_care_outlined),
            title: Text(text.relationshipAddChild),
            onTap: () => Navigator.of(sheetContext).pop(RelativeRole.child),
          ),
        ],
      ),
    ),
  );
}

Future<Person?> _choosePerson(BuildContext context, List<Person> candidates) =>
    Navigator.of(context).push(
      MaterialPageRoute<Person>(
        builder: (_) => _PersonPicker(candidates: candidates),
      ),
    );

/// Asks whether to remove the relationship linking two people, then does it.
///
/// The relationship is looked up by its endpoints rather than passed in,
/// because the profile lists people, not edges. Where several edges link the
/// same pair — a duplicate arriving from a merge — the first is removed and
/// the rest stay visible, so nothing disappears without being asked about.
Future<void> removeRelative(
  BuildContext context,
  WidgetRef ref, {
  required FamilySnapshot snapshot,
  required Person subject,
  required Person other,
  required RelationshipType type,
}) async {
  final relationship = snapshot.graph.relationships
      .where(
        (r) =>
            r.type == type &&
            r.involves(subject.id) &&
            r.involves(other.id),
      )
      .firstOrNull;
  if (relationship == null) return;

  final text = AppText.of(context);
  final confirmed = await confirmDestructive(
    context,
    title: text.relationshipRemoveTitle,
    body: text.relationshipRemoveBody(
      subject.displayName,
      other.displayName,
    ),
    confirmLabel: text.actionRemove,
  );
  if (!confirmed) return;
  await ref
      .read(familySnapshotProvider(subject.familyId).notifier)
      .removeRelationship(relationship.id);
}

/// Picks somebody already in the family.
///
/// Only existing people: adding a person is its own screen, and folding the two
/// together would mean a half-filled person created as a side effect of drawing
/// a line.
class _PersonPicker extends StatefulWidget {
  const _PersonPicker({required this.candidates});

  final List<Person> candidates;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    // The same matching the family screen uses: diacritics ignored, so a name
    // typed off a phone keyboard still finds its owner (PRODUCT.md §1.1).
    final matches = <Person>[
      for (final person in widget.candidates)
        if (nameMatches(person.displayName, _query)) person,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(text.relationshipChoosePerson)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: text.searchByName,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (matches.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  widget.candidates.isEmpty
                      ? text.relationshipNobodyElse
                      : text.searchNoMatch,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      matches[index].displayName.characters.firstOrNull ?? '?',
                    ),
                  ),
                  title: Text(matches[index].displayName),
                  onTap: () => Navigator.of(context).pop(matches[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
