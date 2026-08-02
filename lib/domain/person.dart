/// An individual recorded in a family tree (DOMAIN.md §3).
library;

import 'genealogical_date.dart';
import 'validation.dart';

/// Biological sex as genealogical records report it.
///
/// [unknown] is a value, not an absence, which is why [Person.sex] is not
/// nullable. In genealogy "we do not know this person's sex" and "this field
/// has not been filled in" are the same statement, and allowing null would give
/// two ways to say one thing that every caller then has to handle (§3.2).
///
/// Nothing in the domain derives a parental role from this. A parent-child edge
/// never becomes a "father" or "mother" edge. A tree view may use it as a hint
/// when labelling parents, but that is a presentation decision and it must
/// cope with [unknown] without falling apart.
enum Sex { male, female, unknown }

/// A person appearing in a family tree.
///
/// Almost everything is optional. Historical records are incomplete, and the
/// model must not demand information merely because modern applications
/// usually collect it.
///
/// Carries no relationships. Parents, children, and spouses are Relationship
/// entities, so that Person makes no assumption about family structure (§3.4).
///
/// Carries no timestamps, for the reasons given on [Family].
final class Person {
  const Person({
    required this.id,
    required this.familyId,
    required this.displayName,
    this.givenName,
    this.additionalNames,
    this.familyName,
    this.birthFamilyName,
    this.sex = Sex.unknown,
    this.birthDate,
    this.deathDate,
    this.birthPlace,
    this.deathPlace,
    this.biography,
    this.profileMediaRef,
  });

  /// Globally unique identifier, never composite with [familyId] (§14.1).
  final String id;

  /// The dataset this person belongs to.
  ///
  /// That the family actually exists is checked once a repository or graph can
  /// look it up, which is beyond a single entity.
  final String familyId;

  /// How the person is shown. Must not be blank.
  ///
  /// Stored and user-editable rather than composed from the parts: mononyms,
  /// patronymics, religious names, and non-Western name order cannot be
  /// produced reliably by joining three fields (§3.1). Kept exactly as given —
  /// trimming belongs to the UI.
  final String displayName;

  /// Personal name.
  final String? givenName;

  /// Any further names, as one free-text field.
  ///
  /// Not a `middleName`: real records carry zero, one, or several, so a single
  /// slot is wrong in both directions.
  final String? additionalNames;

  /// Current family name.
  final String? familyName;

  /// Family name at birth — maiden name.
  ///
  /// Core genealogical data rather than an edge case: it is how someone is
  /// linked into their parents' branch (§3.1).
  final String? birthFamilyName;

  /// Biological sex, or [Sex.unknown]. Never null.
  final Sex sex;

  /// Date of birth, at whatever precision the source gave.
  final GenealogicalDate? birthDate;

  /// Date of death, at whatever precision the source gave.
  final GenealogicalDate? deathDate;

  /// Free-text place of birth. A Place entity would be premature.
  final String? birthPlace;

  /// Free-text place of death.
  final String? deathPlace;

  /// Notes about the person.
  final String? biography;

  /// An opaque reference to a portrait, or null.
  ///
  /// Deliberately not a foreign key: the media entity does not exist until a
  /// much later milestone, and a constraint against a table that will not exist
  /// for months is one nobody can satisfy (§3.3).
  final String? profileMediaRef;

  /// Beyond this, a lifespan is worth questioning. The longest verified human
  /// life was 122 years (§9.2).
  static const int _implausibleLifespanYears = 120;

  /// Checks the rules that need nothing beyond this person.
  ///
  /// Date rules stay silent whenever the comparison is indeterminate, so
  /// partial dates never produce a standing wall of false warnings (§4.3).
  ValidationResult validate() {
    final issues = <ValidationIssue>[];

    if (displayName.trim().isEmpty) {
      issues.add(
        ValidationIssue(
          IssueCode.displayNameEmpty,
          involvedIds: <String>[id],
        ),
      );
    }

    final birth = birthDate;
    final death = deathDate;
    if (birth != null && death != null) {
      if (death.definitelyBefore(birth)) {
        issues.add(
          ValidationIssue(
            IssueCode.deathBeforeBirth,
            involvedIds: <String>[id],
          ),
        );
      } else if (birth.spanTo(death).minimumYears > _implausibleLifespanYears) {
        // The minimum, not the maximum: warn only when even the shortest
        // lifespan the dates allow is implausible. Using the maximum would
        // flag 1800-1920, which may be 119 years.
        issues.add(
          ValidationIssue(
            IssueCode.implausibleLifespan,
            involvedIds: <String>[id],
          ),
        );
      }
    }

    return issues.isEmpty
        ? const ValidationResult.ok()
        : ValidationResult(issues);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          other.id == id &&
          other.familyId == familyId &&
          other.displayName == displayName &&
          other.givenName == givenName &&
          other.additionalNames == additionalNames &&
          other.familyName == familyName &&
          other.birthFamilyName == birthFamilyName &&
          other.sex == sex &&
          other.birthDate == birthDate &&
          other.deathDate == deathDate &&
          other.birthPlace == birthPlace &&
          other.deathPlace == deathPlace &&
          other.biography == biography &&
          other.profileMediaRef == profileMediaRef;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    familyId,
    displayName,
    givenName,
    additionalNames,
    familyName,
    birthFamilyName,
    sex,
    birthDate,
    deathDate,
    birthPlace,
    deathPlace,
    biography,
    profileMediaRef,
  ]);

  @override
  String toString() => 'Person($id, $displayName)';
}
