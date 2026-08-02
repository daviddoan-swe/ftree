/// Rules that need a relationship and both of the people it connects, but not
/// the whole graph (DOMAIN.md §9).
///
/// Cycle detection, dangling endpoints, and the spouse-is-also-an-ancestor
/// warning all require knowledge of every edge in the family, so they belong
/// with the family graph rather than here (§13.1).
library;

import 'genealogical_date.dart';
import 'person.dart';
import 'relationship.dart';
import 'validation.dart';

/// Below this age at a child's birth, a parent is worth questioning (§9.2).
///
/// Approximate by design. Ages are derived from date intervals using a mean
/// year length, so behaviour exactly on the bound is a matter of rounding
/// rather than of domain meaning. Nothing should depend on the boundary case.
const int _minimumPlausibleParentAge = 12;

/// Above this age at a child's birth, a parent is worth questioning.
///
/// Approximate, as [_minimumPlausibleParentAge].
const int _maximumPlausibleParentAge = 70;

/// A child born more than this long after a parent's death is worth
/// questioning. Posthumous birth within a pregnancy is ordinary.
const int _maximumPosthumousBirthYears = 1;

/// Validates [relationship] against the two people it connects.
///
/// [personA] must be the person whose id is `relationship.personAId`, and
/// [personB] the one for `personBId`; passing them the other way round is a
/// programming error and throws [ArgumentError] rather than producing a
/// validation issue. For a parent-child edge this means [personA] is the parent
/// and [personB] the child, which the [Relationship.parentChild] factory
/// guarantees.
///
/// [existingKeys] holds the keys of the *other* relationships in the family.
/// A relationship being edited must not have its own key included, or it will
/// be reported as a duplicate of itself.
///
/// The people's own validity is not checked here. Adding an edge to a person
/// whose display name is blank should not report a name problem — that belongs
/// to editing the person, and mixing the two only confuses the reader.
ValidationResult validateRelationship({
  required Relationship relationship,
  required Person personA,
  required Person personB,
  Set<RelationshipKey> existingKeys = const <RelationshipKey>{},
}) {
  if (personA.id != relationship.personAId) {
    throw ArgumentError.value(
      personA.id,
      'personA',
      'must be the person at relationship.personAId '
          '(${relationship.personAId})',
    );
  }
  if (personB.id != relationship.personBId) {
    throw ArgumentError.value(
      personB.id,
      'personB',
      'must be the person at relationship.personBId '
          '(${relationship.personBId})',
    );
  }

  // A self-relationship makes every later check meaningless: comparing a
  // person's dates against their own, or their family against their own.
  final ownIssues = relationship.validate();
  if (ownIssues.hasErrors) return ownIssues;

  final issues = <ValidationIssue>[
    ..._familyIssues(relationship, personA, personB),
    ..._duplicateIssues(relationship, existingKeys),
  ];

  if (relationship.type == RelationshipType.parentChild) {
    issues.addAll(_parentChildDateIssues(relationship, personA, personB));
  }

  return issues.isEmpty
      ? const ValidationResult.ok()
      : ValidationResult(issues);
}

Iterable<ValidationIssue> _duplicateIssues(
  Relationship relationship,
  Set<RelationshipKey> existingKeys,
) sync* {
  if (existingKeys.contains(relationship.key)) {
    yield ValidationIssue(
      IssueCode.relationshipDuplicate,
      involvedIds: <String>[
        relationship.id,
        relationship.personAId,
        relationship.personBId,
      ],
    );
  }
}

Iterable<ValidationIssue> _familyIssues(
  Relationship relationship,
  Person personA,
  Person personB,
) sync* {
  if (personA.familyId != personB.familyId) {
    // Two people in different families cannot share an edge whose familyId
    // matches both, so reporting a mismatch as well would name a consequence
    // rather than the cause.
    yield ValidationIssue(
      IssueCode.personsInDifferentFamilies,
      involvedIds: <String>[relationship.id, personA.id, personB.id],
    );
    return;
  }

  if (relationship.familyId != personA.familyId) {
    yield ValidationIssue(
      IssueCode.relationshipFamilyIdMismatch,
      involvedIds: <String>[relationship.id, personA.id, personB.id],
    );
  }
}

Iterable<ValidationIssue> _parentChildDateIssues(
  Relationship relationship,
  Person parent,
  Person child,
) sync* {
  final parentBirth = parent.birthDate;
  final parentDeath = parent.deathDate;
  final childBirth = child.birthDate;

  final ids = <String>[relationship.id, parent.id, child.id];

  if (parentBirth != null && childBirth != null) {
    if (parentBirth.definitelyAfter(childBirth)) {
      // A negative age would also trip the age bounds below. One contradiction
      // should produce one message.
      yield ValidationIssue(
        IssueCode.parentBornAfterChild,
        involvedIds: ids,
      );
    } else {
      yield* _parentAgeIssues(parentBirth, childBirth, ids);
    }
  }

  if (parentDeath != null && childBirth != null) {
    final gap = parentDeath.spanTo(childBirth);
    if (gap.minimumYears > _maximumPosthumousBirthYears) {
      // The minimum, so a birth that merely might fall after the death stays
      // silent. One year is used for either parent: the domain does not derive
      // roles from sex, and a wider bound never warns wrongly about a genuine
      // posthumous birth.
      yield ValidationIssue(
        IssueCode.childBornLongAfterParentDeath,
        involvedIds: ids,
      );
    }
  }
}

Iterable<ValidationIssue> _parentAgeIssues(
  GenealogicalDate parentBirth,
  GenealogicalDate childBirth,
  List<String> ids,
) sync* {
  final age = parentBirth.spanTo(childBirth);

  // Bounds are read from the far side of the range so that an age which merely
  // might be implausible stays silent: warn only when every age the dates allow
  // is out of range.
  final certainlyTooYoung = age.maximumYears < _minimumPlausibleParentAge;
  final certainlyTooOld = age.minimumYears > _maximumPlausibleParentAge;

  if (certainlyTooYoung || certainlyTooOld) {
    yield ValidationIssue(
      IssueCode.implausibleParentAge,
      involvedIds: ids,
    );
  }
}
