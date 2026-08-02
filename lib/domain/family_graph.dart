/// Genealogical queries over one family (DOMAIN.md §13).
library;

import 'person.dart';
import 'relationship.dart';

/// Someone who shares at least one parent with the person asked about.
///
/// [sharedParentCount] is reported rather than a full/half distinction. Two
/// shared parents usually means a full sibling, but a person may have more than
/// two parents — biological and adoptive both (§17.3) — so naming the count
/// would encode an assumption the model deliberately refuses.
final class Sibling {
  const Sibling({required this.person, required this.sharedParentCount});

  /// The sibling.
  final Person person;

  /// How many parents the two have in common. At least one.
  final int sharedParentCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sibling &&
          other.person == person &&
          other.sharedParentCount == sharedParentCount;

  @override
  int get hashCode => Object.hash(person, sharedParentCount);

  @override
  String toString() => 'Sibling(${person.id}, shared: $sharedParentCount)';
}

/// A family's people and relationships, held in memory and queryable.
///
/// Built in full rather than queried from storage (§13.2). At the target scale
/// — thousands of people — that is a few megabytes, and it means validation,
/// traversal, and layout all work against plain in-memory structures with no
/// query optimisation to design.
///
/// Immutable. There is no way to add or remove anything: after a write, the
/// application builds a new graph. That removes any question of stale indexes
/// or half-updated state, and rebuilding a few thousand nodes costs
/// milliseconds.
///
/// Tolerant of damaged data. A relationship may name a person the family does
/// not contain — offline edits on two devices can produce exactly that — so
/// queries skip what they cannot resolve instead of throwing. The damaged edges
/// are kept, not discarded, so that validation can report them.
final class FamilyGraph {
  /// Builds a graph over [persons] and [relationships].
  ///
  /// Both are copied, so later changes to the caller's lists do not reach the
  /// graph.
  ///
  /// Throws [ArgumentError] if two people share an id. Ids are UUIDs, so a
  /// collision means a genuine defect, and silently dropping one of the two
  /// would be worse than refusing to build.
  FamilyGraph({
    required Iterable<Person> persons,
    required Iterable<Relationship> relationships,
  }) : _persons = List<Person>.unmodifiable(persons),
       _relationships = List<Relationship>.unmodifiable(relationships) {
    for (final person in _persons) {
      if (_personsById.containsKey(person.id)) {
        throw ArgumentError.value(
          person.id,
          'persons',
          'appears more than once',
        );
      }
      _personsById[person.id] = person;
    }

    for (final relationship in _relationships) {
      _index(relationship.personAId, relationship);
      // A self-referencing edge is invalid but can arrive from a merge; index
      // it once rather than twice.
      if (relationship.personBId != relationship.personAId) {
        _index(relationship.personBId, relationship);
      }
    }
  }

  final List<Person> _persons;
  final List<Relationship> _relationships;

  final Map<String, Person> _personsById = <String, Person>{};

  /// Every relationship naming a given person, whether or not that person is
  /// actually in the family.
  ///
  /// One index rather than three, split by role. Each person has a handful of
  /// edges, so filtering by type costs nothing measurable, and three indexes
  /// would be three things able to disagree.
  final Map<String, List<Relationship>> _edgesByPerson =
      <String, List<Relationship>>{};

  /// Everyone in the family, in the order supplied.
  List<Person> get persons => _persons;

  /// Every relationship in the family, in the order supplied.
  List<Relationship> get relationships => _relationships;

  /// The person with [personId], or null if the family does not contain them.
  Person? personById(String personId) => _personsById[personId];

  /// The parents of [personId].
  ///
  /// Any number, including none: a person may have biological and adoptive
  /// parents both, and most people in a tree have neither recorded (§17.3).
  List<Person> parents(String personId) => _resolve(
    _edges(personId)
        .where(
          (r) =>
              r.type == RelationshipType.parentChild &&
              r.childId == personId,
        )
        .map((r) => r.parentId),
  );

  /// The children of [personId], in the order their relationships were
  /// supplied.
  List<Person> children(String personId) => _resolve(
    _edges(personId)
        .where(
          (r) =>
              r.type == RelationshipType.parentChild &&
              r.parentId == personId,
        )
        .map((r) => r.childId),
  );

  /// The spouses of [personId], across a whole lifetime.
  ///
  /// Reads the opposite endpoint rather than a fixed column: spouse ids are
  /// stored in canonical order, so which of the two sits in `personAId` depends
  /// only on how the ids sort (§5.1).
  List<Person> spouses(String personId) => _resolve(
    _edges(personId)
        .where((r) => r.type == RelationshipType.spouse)
        .map((r) => r.otherThan(personId))
        .whereType<String>(),
  );

  /// The siblings of [personId] (§8.1).
  ///
  /// Anyone sharing at least one parent. The subject is excluded, each sibling
  /// appears once however many parents they share, and the count comes back
  /// with them so a caller can tell full from half without a second query.
  ///
  /// Step-siblings — the children of a parent's spouse, with no parent in
  /// common — are not siblings here. Nothing special is done to exclude them:
  /// only the children of this person's own parents are considered.
  ///
  /// With a single recorded parent, a full sibling is indistinguishable from a
  /// half sibling. That is a limit of the data, not of this query.
  List<Sibling> siblings(String personId) {
    final parentIds = <String>{for (final p in parents(personId)) p.id};
    if (parentIds.isEmpty) return const <Sibling>[];

    final counts = <String, int>{};
    final order = <String>[];

    for (final parentId in parentIds) {
      // Guard against a duplicated parent-child edge inflating the count.
      final countedForThisParent = <String>{};
      for (final child in children(parentId)) {
        if (child.id == personId) continue;
        if (!countedForThisParent.add(child.id)) continue;
        if (!counts.containsKey(child.id)) order.add(child.id);
        counts[child.id] = (counts[child.id] ?? 0) + 1;
      }
    }

    return <Sibling>[
      for (final id in order)
        if (_personsById[id] case final person?)
          Sibling(person: person, sharedParentCount: counts[id]!),
    ];
  }

  List<Relationship> _edges(String personId) =>
      _edgesByPerson[personId] ?? const <Relationship>[];

  /// Turns ids into people, dropping any the family does not contain.
  List<Person> _resolve(Iterable<String> ids) =>
      <Person>[for (final id in ids) ?_personsById[id]];

  void _index(String personId, Relationship relationship) {
    (_edgesByPerson[personId] ??= <Relationship>[]).add(relationship);
  }
}
