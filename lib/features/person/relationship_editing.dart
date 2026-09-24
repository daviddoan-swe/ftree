/// Connecting one person to another, and undoing it.
///
/// Both directions of a parent-child edge are offered — *add a parent* and
/// *add a child* — because that is how a person is described. The domain has
/// one edge either way; only the parameter order differs (DOMAIN.md §6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../app/validation_prompts.dart';
import '../../domain/family_repository.dart';
import '../../domain/ids.dart';
import '../../domain/name_search.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../../l10n/app_localizations.dart';
import '../family/generation_filter.dart';
import 'person_style.dart';

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
  final doi = snapshot.graph.generations();
  final other = await _choosePerson(
    context,
    candidates,
    doi,
    _doiOfRelative(role, doi[subject.id]),
  );
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

/// Which đời a relative of [role] would most likely stand in.
///
/// A parent is one above, a spouse alongside, a child one below — which is
/// where a reader adding one will look first, so it is where the picker
/// opens.
///
/// **A suggestion, never a restriction.** A gia phả holds a second wife half a
/// generation younger, a son-in-law adopted into the line, a cousin married
/// back in. Every one of them is a relationship somebody has to be able to
/// record, and a picker that refused the đời it did not expect would make the
/// application useless on exactly the families most worth keeping.
///
/// Null where the subject has no đời of their own — a line the founder's does
/// not reach — because there is then nothing to count from.
int? _doiOfRelative(RelativeRole role, int? subjectDoi) => switch (subjectDoi) {
  null => null,
  final int at => switch (role) {
    RelativeRole.parent => at - 1,
    RelativeRole.spouse => at,
    RelativeRole.child => at + 1,
  },
};

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

Future<Person?> _choosePerson(
  BuildContext context,
  List<Person> candidates,
  Map<String, int> doi,
  int? suggested,
) =>
    Navigator.of(context).push(
      MaterialPageRoute<Person>(
        builder: (_) => _PersonPicker(
          candidates: candidates,
          doi: doi,
          suggested: suggested,
        ),
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
  final confirmed = await confirmIrreversible(
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
  const _PersonPicker({
    required this.candidates,
    required this.doi,
    required this.suggested,
  });

  /// The đời to open on, from [_doiOfRelative], or null for all of them.
  final int? suggested;

  final List<Person> candidates;

  /// Which đời each of them stands in (DOMAIN.md §11.1).
  ///
  /// Picking a relative out of three hundred names is the same problem the
  /// family list has, and a reader adding a father already knows roughly which
  /// đời he is in — often better than they remember his name.
  final Map<String, int> doi;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The đời being shown, or null for all of them.
  late GenerationChoice _generation = _opening();

  /// Where to open.
  ///
  /// The suggested đời, but only if somebody stands in it. Opening on an
  /// empty list because the arithmetic said so would read as a screen that
  /// had failed to load, and the reader would have to guess that a filter
  /// they never set is the reason.
  GenerationChoice _opening() {
    final at = widget.suggested;
    if (at == null) return null;

    return widget.candidates.any((p) => widget.doi[p.id] == at) ? at : null;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    // The same narrowing the family screen does, for the same reasons: by đời
    // and by name, both at once, with diacritics ignored (PRODUCT.md §1.1).
    final filter = GenerationFilter(
      counts: countByGeneration(widget.candidates, widget.doi),
      chosen: _generation,
      onChosen: (at) => setState(() => _generation = at),
    );
    final matches = rankedByName(
      ofGeneration(widget.candidates, widget.doi, _generation),
      _query.text,
      nameOf: (person) => person.displayName,
    );

    return Scaffold(
      appBar: AppBar(title: Text(text.relationshipChoosePerson)),
      body: Column(
        children: <Widget>[
          // The same field the family list carries. Picking a relative out of
          // three hundred names is the same task as finding one to read, and
          // two screens that do the same thing should not look like two
          // different applications.
          SearchPill(
            controller: _query,
            hint: text.searchByName,
            onChanged: (_) => setState(() {}),
          ),
          if (filter.isWorthShowing) filter,
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
                  // The same glyph and the same colour the family list gives
                  // this person: man, woman or unknown, and grey once a death
                  // is recorded. A reader should not have to learn the code
                  // twice.
                  leading: RowIcon(
                    personIcon(matches[index]),
                    color: personColor(matches[index]),
                  ),
                  title: Text(matches[index].displayName),
                  subtitle: switch (lifeYears(matches[index])) {
                    final String years => Text(years),
                    _ => null,
                  },
                  onTap: () => Navigator.of(context).pop(matches[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
