/// Validation results for the domain layer.
///
/// Genealogical source data is messy. A model that only answers valid/invalid
/// rejects correctly transcribed records and becomes unusable on real family
/// documents, so validation returns a result carrying severities instead of a
/// boolean (DOMAIN.md §9).
///
/// * [ValidationSeverity.error] blocks the write — the data is structurally
///   impossible.
/// * [ValidationSeverity.warning] does not block — it is implausible but
///   possible, and the user may confirm and proceed.
library;

/// Whether an issue blocks a write or merely warns about it.
enum ValidationSeverity {
  /// Structurally impossible data. The write must be refused.
  error,

  /// Implausible but possible data. Surfaced to the user, who may proceed.
  warning,
}

/// A stable identifier for something that can be wrong with domain data.
///
/// Severity is a property of the code rather than of an individual issue, so
/// the same condition cannot be raised as an error in one place and a warning
/// in another. If a condition ever genuinely needs both, it should become two
/// codes with two names.
///
/// Human-readable messages deliberately live in the presentation layer: the
/// domain must run without Flutter, and messages need localisation.
///
/// Graph-level codes — cycle creation, missing endpoints, and spouses who are
/// also ancestors — arrive with the family graph, since none of them can be
/// decided without it (DOMAIN.md §13.1).
enum IssueCode {
  // ---- Errors (DOMAIN.md §9.1) ----

  /// `Family.name` is empty or whitespace only.
  familyNameEmpty(ValidationSeverity.error),

  /// `Person.displayName` is empty or whitespace only.
  displayNameEmpty(ValidationSeverity.error),

  /// A relationship's two endpoints are the same person.
  relationshipSelfReference(ValidationSeverity.error),

  /// A relationship of this type already exists between the same two people.
  relationshipDuplicate(ValidationSeverity.error),

  /// A relationship's `familyId` differs from that of one of its endpoints.
  relationshipFamilyIdMismatch(ValidationSeverity.error),

  /// A person is being marked as having died with nothing recorded about it.
  ///
  /// Raised by the form, not by `Person.validate`. The domain derives death
  /// from the fields themselves (`Person.hasDied`), so it has no notion of an
  /// assertion that nothing backs — to the entity, a person with no death date
  /// and no place of death is simply a person nothing was written about. It is
  /// the interface that let somebody claim otherwise, so it is the interface
  /// that has to ask them to say what they know.
  deceasedWithoutDetail(ValidationSeverity.error),

  /// The two people in a relationship belong to different families.
  personsInDifferentFamilies(ValidationSeverity.error),

  /// A relationship names a person the family does not contain.
  relationshipEndpointMissing(ValidationSeverity.error),

  /// A parent-child edge would make someone their own ancestor.
  relationshipCreatesCycle(ValidationSeverity.error),

  // ---- Warnings (DOMAIN.md §9.2) ----

  /// A person's death date falls before their birth date.
  deathBeforeBirth(ValidationSeverity.warning),

  /// A person's lifespan is implausibly long.
  implausibleLifespan(ValidationSeverity.warning),

  /// A parent was born after their child.
  parentBornAfterChild(ValidationSeverity.warning),

  /// A child was born well after the parent's death.
  ///
  /// A warning and never an error: posthumous birth is real.
  childBornLongAfterParentDeath(ValidationSeverity.warning),

  /// A parent was implausibly young or old at the child's birth.
  implausibleParentAge(ValidationSeverity.warning),

  /// Two spouses are also ancestor and descendant of one another.
  ///
  /// A warning rather than an error: cousin marriage is historically common,
  /// and while a parent-child marriage is almost always a transcription
  /// mistake, the record belongs to the user.
  spouseIsAncestorOrDescendant(ValidationSeverity.warning);

  const IssueCode(this.severity);

  /// Whether this code blocks a write.
  final ValidationSeverity severity;
}

/// A single problem found in domain data.
final class ValidationIssue {
  const ValidationIssue(this.code, {this.involvedIds = const <String>[]});

  /// What is wrong.
  final IssueCode code;

  /// Ids of the entities this issue concerns.
  ///
  /// Plain strings because a single issue may reference a mix of person,
  /// relationship, and family ids.
  final List<String> involvedIds;

  /// Whether this issue blocks a write. Determined entirely by [code].
  ValidationSeverity get severity => code.severity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ValidationIssue &&
        other.code == code &&
        _sameIds(other.involvedIds, involvedIds);
  }

  @override
  int get hashCode => Object.hash(code, Object.hashAll(involvedIds));

  @override
  String toString() =>
      'ValidationIssue(${code.name}, ${severity.name}, $involvedIds)';

  static bool _sameIds(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The outcome of validating something: zero or more [ValidationIssue]s.
///
/// An empty result means the data is clean. A result carrying only warnings is
/// still writable — callers must check [hasErrors], not [hasIssues], before
/// refusing a write.
final class ValidationResult {
  ValidationResult(List<ValidationIssue> issues)
    : issues = List<ValidationIssue>.unmodifiable(issues);

  /// No issues at all.
  const ValidationResult.ok() : issues = const <ValidationIssue>[];

  /// A single issue.
  ValidationResult.single(ValidationIssue issue)
    : issues = List<ValidationIssue>.unmodifiable(<ValidationIssue>[issue]);

  /// Every issue found, in the order they were reported. Unmodifiable.
  final List<ValidationIssue> issues;

  /// Whether any issue blocks the write. This is the check that gates a write.
  bool get hasErrors =>
      issues.any((i) => i.severity == ValidationSeverity.error);

  /// Whether there is anything at all to show the user, blocking or not.
  bool get hasIssues => issues.isNotEmpty;

  /// The blocking issues only.
  Iterable<ValidationIssue> get errors =>
      issues.where((i) => i.severity == ValidationSeverity.error);

  /// The non-blocking issues only.
  Iterable<ValidationIssue> get warnings =>
      issues.where((i) => i.severity == ValidationSeverity.warning);

  /// This result followed by [other], preserving order.
  ValidationResult merge(ValidationResult other) {
    if (other.issues.isEmpty) return this;
    if (issues.isEmpty) return other;
    return ValidationResult(<ValidationIssue>[...issues, ...other.issues]);
  }

  /// All of [results] concatenated, preserving order.
  static ValidationResult combine(Iterable<ValidationResult> results) {
    final combined = <ValidationIssue>[];
    for (final result in results) {
      combined.addAll(result.issues);
    }
    if (combined.isEmpty) return const ValidationResult.ok();
    return ValidationResult(combined);
  }

  @override
  String toString() => 'ValidationResult($issues)';
}
