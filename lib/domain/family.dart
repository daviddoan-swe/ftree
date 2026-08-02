/// The dataset and access boundary a tree lives in (DOMAIN.md §2).
library;

import 'validation.dart';

/// A managed family-tree dataset.
///
/// "Family" here means a **dataset and access boundary**, not a kinship group.
/// It is the unit of authorization and, later, of synchronization. A family's
/// graph need not be connected: isolated people and unconnected sub-trees are
/// perfectly valid.
///
/// Timestamps are deliberately absent. No domain rule reads them, and carrying
/// them would put a clock in every constructor and make every test
/// non-deterministic. `updatedAt` and `deletedAt` are added by the persistence
/// layer, which is where synchronization needs them (§15.2).
///
/// An incomplete family is constructible. Validation reports problems rather
/// than throwing, so a half-filled form is a normal state to hold in memory —
/// unlike a structurally impossible value such as month 13, which
/// [GenealogicalDate] refuses outright.
final class Family {
  const Family({required this.id, required this.name, this.description});

  /// Globally unique identifier. Supplied rather than generated, so that
  /// constructing the same family twice yields the same value.
  final String id;

  /// What the family calls itself. Must not be blank.
  ///
  /// Stored exactly as given. Trimming here would mean the value read back
  /// differs from the value written, which surprises callers and complicates
  /// round-tripping through storage; normalising input belongs to the UI.
  final String name;

  /// Optional free-text note about the dataset.
  final String? description;

  /// Checks the rules that need nothing beyond this object.
  ValidationResult validate() {
    if (name.trim().isEmpty) {
      return ValidationResult.single(
        ValidationIssue(
          IssueCode.familyNameEmpty,
          involvedIds: <String>[id],
        ),
      );
    }
    return const ValidationResult.ok();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Family &&
          other.id == id &&
          other.name == name &&
          other.description == description;

  @override
  int get hashCode => Object.hash(id, name, description);

  @override
  String toString() => 'Family($id, $name)';
}
