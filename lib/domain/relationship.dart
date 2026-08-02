/// Edges between people (DOMAIN.md §5).
library;

import 'validation.dart';

/// The kinds of relationship V1 records.
enum RelationshipType {
  /// Directional: one person is a parent of the other.
  parentChild,

  /// Symmetric: the two are, or were, married.
  spouse;

  /// Whether the two endpoints are interchangeable.
  ///
  /// Symmetric types store their ids in canonical order, which is what lets a
  /// uniqueness constraint recognise `(B, A)` as the same pair as `(A, B)`.
  bool get isSymmetric => this == RelationshipType.spouse;
}

/// The tuple a uniqueness constraint is built on.
///
/// Mirrors the future `UNIQUE (familyId, type, personAId, personBId)` index, so
/// duplicate detection in the domain and in the database agree by construction.
///
/// Two relationships with different ids can share a key — that is exactly what
/// "duplicate" means.
final class RelationshipKey {
  const RelationshipKey({
    required this.familyId,
    required this.type,
    required this.personAId,
    required this.personBId,
  });

  final String familyId;
  final RelationshipType type;
  final String personAId;
  final String personBId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipKey &&
          other.familyId == familyId &&
          other.type == type &&
          other.personAId == personAId &&
          other.personBId == personBId;

  @override
  int get hashCode => Object.hash(familyId, type, personAId, personBId);

  @override
  String toString() =>
      'RelationshipKey($familyId, ${type.name}, $personAId, $personBId)';
}

/// A relationship between two people in one family.
///
/// The two endpoint columns mean different things depending on [type], which is
/// invisible in the schema and a likely source of defects (§5.1):
///
/// | type          | personAId  | personBId  | ordering                  |
/// | ------------- | ---------- | ---------- | ------------------------- |
/// | `parentChild` | the parent | the child  | directional, meaningful   |
/// | `spouse`      | lower id   | higher id  | canonical, **no meaning** |
///
/// There is no general constructor taking `personAId` and `personBId` — that
/// signature invites precisely the confusion above. Use [Relationship.parentChild],
/// whose parameter names make the direction unmistakable, or
/// [Relationship.spouse], which orders the ids for you.
///
/// Rehydrating from storage needs no extra constructor: switch on the stored
/// type and call the matching factory. Re-ordering an already-ordered spouse
/// pair is idempotent.
final class Relationship {
  const Relationship._({
    required this.id,
    required this.familyId,
    required this.type,
    required this.personAId,
    required this.personBId,
  });

  /// [parent] is a parent of [child]. Direction is preserved as given.
  factory Relationship.parentChild({
    required String id,
    required String familyId,
    required String parent,
    required String child,
  }) => Relationship._(
    id: id,
    familyId: familyId,
    type: RelationshipType.parentChild,
    personAId: parent,
    personBId: child,
  );

  /// [personA] and [personB] are spouses. The order given does not matter.
  ///
  /// The ids are sorted before storage. Without that, a uniqueness constraint
  /// would treat `(B, A)` as a different row from `(A, B)` and duplicate spouse
  /// records would slip through.
  factory Relationship.spouse({
    required String id,
    required String familyId,
    required String personA,
    required String personB,
  }) {
    final ordered = personA.compareTo(personB) <= 0
        ? <String>[personA, personB]
        : <String>[personB, personA];
    return Relationship._(
      id: id,
      familyId: familyId,
      type: RelationshipType.spouse,
      personAId: ordered[0],
      personBId: ordered[1],
    );
  }

  /// Globally unique identifier for this edge.
  final String id;

  /// The dataset this relationship belongs to.
  ///
  /// Denormalised on purpose: it lets server-side authorization filter edges
  /// without a join. That it matches both endpoints' family is checked where
  /// both people are available (§5.2).
  final String familyId;

  /// Which kind of relationship this is.
  final RelationshipType type;

  /// First endpoint. The parent for [RelationshipType.parentChild]; for
  /// symmetric types, simply the lower of the two ids.
  final String personAId;

  /// Second endpoint. The child for [RelationshipType.parentChild]; for
  /// symmetric types, simply the higher of the two ids.
  final String personBId;

  /// The parent in a parent-child relationship.
  ///
  /// Throws [StateError] on any other type, where the endpoint order carries no
  /// meaning and reading it as a parent would be wrong.
  String get parentId {
    if (type != RelationshipType.parentChild) {
      throw StateError(
        'parentId is meaningless for ${type.name}: its endpoints are ordered '
        'canonically, not by role',
      );
    }
    return personAId;
  }

  /// The child in a parent-child relationship.
  ///
  /// Throws [StateError] on any other type.
  String get childId {
    if (type != RelationshipType.parentChild) {
      throw StateError(
        'childId is meaningless for ${type.name}: its endpoints are ordered '
        'canonically, not by role',
      );
    }
    return personBId;
  }

  /// The tuple that must be unique within a family.
  RelationshipKey get key => RelationshipKey(
    familyId: familyId,
    type: type,
    personAId: personAId,
    personBId: personBId,
  );

  /// Whether [personId] is one of the two endpoints.
  bool involves(String personId) =>
      personId == personAId || personId == personBId;

  /// The endpoint that is not [personId], or null if [personId] is not an
  /// endpoint.
  String? otherThan(String personId) {
    if (personId == personAId) return personBId;
    if (personId == personBId) return personAId;
    return null;
  }

  /// Checks the rules that need nothing beyond this edge.
  ///
  /// Duplicate detection, family consistency, and cycle detection all need
  /// context this object does not have, and live where that context exists.
  ValidationResult validate() {
    if (personAId == personBId) {
      return ValidationResult.single(
        ValidationIssue(
          IssueCode.relationshipSelfReference,
          involvedIds: <String>[id, personAId],
        ),
      );
    }
    return const ValidationResult.ok();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Relationship &&
          other.id == id &&
          other.familyId == familyId &&
          other.type == type &&
          other.personAId == personAId &&
          other.personBId == personBId;

  @override
  int get hashCode => Object.hash(id, familyId, type, personAId, personBId);

  @override
  String toString() =>
      'Relationship($id, ${type.name}, $personAId -> $personBId)';
}
