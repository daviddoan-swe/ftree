/// Genealogical queries over one family (DOMAIN.md §13).
library;

import 'genealogical_date.dart';
import 'person.dart';
import 'relationship.dart';
import 'relationship_rules.dart';
import 'validation.dart';

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

      if (relationship.type == RelationshipType.parentChild) {
        // Children the family does not contain are dropped, as everywhere else
        // a damaged edge is met.
        if (_personsById[relationship.childId] case final child?) {
          (_childrenByParent[relationship.parentId] ??= <Person>[]).add(child);
        }
      }
    }

    // Ordered once, here, rather than on every call. The graph is immutable
    // (§13.2) and [children] is asked repeatedly — once per parent by
    // [siblings], once per node by [descendants], and again by the layout.
    for (final parentId in _childrenByParent.keys.toList()) {
      _childrenByParent[parentId] = List<Person>.unmodifiable(
        _byBirthWhereKnown<Person>(
          _childrenByParent[parentId]!,
          (person) => person.birthDate,
        ),
      );
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

  /// Each parent's children, already in the order they should be read.
  final Map<String, List<Person>> _childrenByParent = <String, List<Person>>{};

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

  /// The children of [personId], eldest first as far as the dates say (§13.3).
  ///
  /// Where a birth date is missing or the two overlap, the order the
  /// relationships were supplied is kept.
  List<Person> children(String personId) =>
      _childrenByParent[personId] ?? const <Person>[];

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

    return _byBirthWhereKnown(<Sibling>[
      for (final id in order)
        if (_personsById[id] case final person?)
          Sibling(person: person, sharedParentCount: counts[id]!),
    ], (s) => s.person.birthDate);
  }

  /// Puts what is known to be earlier first, and moves nothing else (§13.3).
  ///
  /// An insertion pass rather than a sort, because there is no total order to
  /// sort by. Comparing partial dates yields *before*, *after*, or *cannot
  /// tell* (§4.3), and a comparator answering "equal" to the third case is not
  /// transitive: with 1900, an unrecorded date, and 1800 it produces a cycle,
  /// and `List.sort` — which is not stable either — would return an arbitrary
  /// arrangement.
  ///
  /// So an element only moves past a neighbour when [GenealogicalDate
  /// .definitelyBefore] says so, and stops at the first one it cannot pass.
  /// Being blocked by an undated sibling is the point, not a shortcoming:
  /// passing them would be a reordering with nothing behind it.
  ///
  /// The result can therefore be incomplete, never wrong — the same bargain
  /// §4.3 makes when it keeps a warning silent rather than guess.
  ///
  /// Quadratic in the number of children, which is a number under twenty.
  static List<T> _byBirthWhereKnown<T>(
    List<T> items,
    GenealogicalDate? Function(T) birthOf,
  ) {
    final ordered = List<T>.of(items);

    for (var i = 1; i < ordered.length; i++) {
      final moving = ordered[i];
      final birth = birthOf(moving);
      if (birth == null) continue;

      var at = i;
      while (at > 0) {
        final ahead = birthOf(ordered[at - 1]);
        if (ahead == null || !birth.definitelyBefore(ahead)) break;
        ordered[at] = ordered[at - 1];
        at--;
      }
      ordered[at] = moving;
    }

    return ordered;
  }

  /// Everyone [personId] descends from, nearest generation first (§10).
  ///
  /// The subject is excluded, including in a damaged graph where a cycle makes
  /// them their own ancestor.
  List<Person> ancestors(String personId) => _traverse(personId, parents);

  /// Everyone descended from [personId], nearest generation first (§10).
  ///
  /// The subject is excluded, as in [ancestors].
  List<Person> descendants(String personId) => _traverse(personId, children);

  /// The person the family is counted from: its thuỷ tổ.
  ///
  /// Whoever has no recorded parents and the most descendants. Both halves are
  /// needed. Having no parents is not enough on its own — every spouse who
  /// married in has none either, and in a three-hundred-person gia phả that is
  /// eighty-six people, most of whom founded nothing. Nor is descendant count
  /// enough by itself: the founder's eldest son may carry nearly as many, and
  /// he is not the one a gia phả counts from.
  ///
  /// Ties go to whoever the family lists first, so the answer does not move
  /// about between reads of the same data.
  ///
  /// Null for an empty family, and for a damaged one in which a cycle leaves
  /// nobody parentless (§6.2). For a family holding several unconnected lines
  /// this names the largest of them and says nothing about the rest, which is
  /// the same thing the tree screen does when it has to choose a root.
  Person? foundingAncestor() => _founder;

  /// Worked out once. A graph is immutable — both lists are copied at
  /// construction — so the answer cannot go stale, and a new graph is built
  /// whenever the family changes.
  ///
  /// Worth caching because it is not cheap: it walks the descendants of every
  /// person without recorded parents, which in a three-hundred-person family
  /// is eighty-six traversals. Called afresh on every rebuild of a screen —
  /// every keystroke in a search field — that is work done over and over for
  /// an answer that never changes.
  late final Person? _founder = _findFoundingAncestor();

  Person? _findFoundingAncestor() {
    Person? best;
    var mostDescendants = -1;

    for (final person in _persons) {
      if (parents(person.id).isNotEmpty) continue;

      final count = descendants(person.id).length;
      if (count > mostDescendants) {
        best = person;
        mostDescendants = count;
      }
    }

    return best;
  }

  /// Which đời each person stands in, counted from [foundingAncestor].
  ///
  /// One đời for the thuỷ tổ, two for their children, and so on: the numbers a
  /// gia phả is written in, not distances from whatever a screen happens to be
  /// showing (§11.1).
  ///
  /// **The one place these are worked out.** Every screen that names a đời
  /// reads them from here, because two screens arriving at the number
  /// separately is two screens able to contradict each other about a reader's
  /// own family.
  ///
  /// Spouses take their partner's đời rather than one of their own, which is
  /// what lets the count reach people who married in and have no parents on
  /// record. Anyone the founder's line does not reach is absent from the map:
  /// a separate line has no đời in this family's counting, and saying so is
  /// better than guessing one.
  ///
  /// Breadth-first, so somebody reachable by two routes keeps the shorter, and
  /// visited-guarded, so a cycle ends the walk rather than continuing it
  /// (§6.2).
  Map<String, int> generations() => _generations;

  /// Worked out once, for the same reason as [_founder].
  late final Map<String, int> _generations = _computeGenerations();

  Map<String, int> _computeGenerations() {
    final founder = foundingAncestor();
    if (founder == null) return const <String, int>{};

    final doi = <String, int>{founder.id: 1};
    final queue = <Person>[founder];

    for (var head = 0; head < queue.length; head++) {
      final person = queue[head];
      final at = doi[person.id]!;

      for (final spouse in spouses(person.id)) {
        if (doi.containsKey(spouse.id)) continue;
        doi[spouse.id] = at;
        queue.add(spouse);
      }
      for (final child in children(person.id)) {
        if (doi.containsKey(child.id)) continue;
        doi[child.id] = at + 1;
        queue.add(child);
      }
    }

    return Map<String, int>.unmodifiable(doi);
  }

  /// Checks whether [candidate] may be added to this family (§13.1).
  ///
  /// Relationship validation lives here rather than on the entity because a
  /// cycle cannot be seen from a single edge. What can be decided without the
  /// graph — self-reference, duplication, family consistency, and the
  /// parent-child date warnings — is delegated to [validateRelationship] rather
  /// than repeated, so those rules have one home.
  ///
  /// [candidate] is expected not to be part of the graph already. Its own key
  /// is excluded from the duplicate check so that revalidating a stored edge
  /// does not report it as a duplicate of itself.
  ValidationResult validateAddition(Relationship candidate) {
    final personA = _personsById[candidate.personAId];
    final personB = _personsById[candidate.personBId];

    if (personA == null || personB == null) {
      // Nothing further can be judged: the date, family and cycle checks all
      // need both people.
      return ValidationResult.single(
        ValidationIssue(
          IssueCode.relationshipEndpointMissing,
          involvedIds: <String>[
            candidate.id,
            if (personA == null) candidate.personAId,
            if (personB == null) candidate.personBId,
          ],
        ),
      );
    }

    final existingKeys = <RelationshipKey>{
      for (final r in _relationships)
        if (r.id != candidate.id) r.key,
    };

    return validateRelationship(
      relationship: candidate,
      personA: personA,
      personB: personB,
      existingKeys: existingKeys,
    ).merge(_graphOnlyIssues(candidate));
  }

  ValidationResult _graphOnlyIssues(Relationship candidate) {
    final issues = <ValidationIssue>[];

    switch (candidate.type) {
      case RelationshipType.parentChild:
        // The parent must not already descend from the child. Checking
        // descendants rather than ancestors is deliberate: a traversal excludes
        // its own subject, so asking whether the parent is among the child's
        // descendants gives the right answer even in an already-looped graph.
        final closesLoop = descendants(
          candidate.childId,
        ).any((p) => p.id == candidate.parentId);

        if (closesLoop) {
          issues.add(
            ValidationIssue(
              IssueCode.relationshipCreatesCycle,
              involvedIds: <String>[
                candidate.id,
                candidate.parentId,
                candidate.childId,
              ],
            ),
          );
        }

      case RelationshipType.spouse:
        final a = candidate.personAId;
        final b = candidate.personBId;
        final related =
            ancestors(a).any((p) => p.id == b) ||
            descendants(a).any((p) => p.id == b);

        if (related) {
          issues.add(
            ValidationIssue(
              IssueCode.spouseIsAncestorOrDescendant,
              involvedIds: <String>[candidate.id, a, b],
            ),
          );
        }
    }

    return issues.isEmpty
        ? const ValidationResult.ok()
        : ValidationResult(issues);
  }

  /// Breadth-first walk from [startId], following [step] outwards.
  ///
  /// Keeps a visited set and stops on revisit. That is a contract, not
  /// defensive coding (§6.2): acyclicity cannot be guaranteed in a system that
  /// permits offline editing, because two devices can each add a valid edge
  /// that together close a loop. A single such cycle arriving from a merge
  /// would otherwise hang the tree screen forever.
  ///
  /// The visited set also collapses diamonds — two routes to one ancestor yield
  /// one entry — and breadth-first order means results come back by distance,
  /// which is what a layout wants.
  List<Person> _traverse(String startId, List<Person> Function(String) step) {
    final visited = <String>{startId};
    final found = <Person>[];

    // A plain list walked by index is the queue; no import, amortised O(1).
    final queue = <String>[startId];
    for (var head = 0; head < queue.length; head++) {
      for (final next in step(queue[head])) {
        if (!visited.add(next.id)) continue;
        found.add(next);
        queue.add(next.id);
      }
    }

    return found;
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
