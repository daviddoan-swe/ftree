/// The persistence boundary the application depends on (ARCHITECTURE §7).
///
/// One repository, not three. Through the local milestones every operation is
/// either "load this family" or "write one row", and naming three interfaces
/// with three implementation flavours apiece would produce nine classes for a
/// problem that does not exist. Split it when a caller finds this awkward.
///
/// Pure Dart: no Drift, no SQLite, no Flutter. The implementation lives in
/// `lib/data`, and the dependency runs data → domain only.
library;

import 'family.dart';
import 'family_graph.dart';
import 'person.dart';
import 'relationship.dart';

/// Everything about one family, loaded together.
///
/// The graph is built here rather than by each caller, because §13.2 already
/// decided a family is loaded in full and every caller would otherwise repeat
/// the same assembly.
final class FamilySnapshot {
  const FamilySnapshot({required this.family, required this.graph});

  /// The dataset itself.
  final Family family;

  /// Its people and relationships, ready to query.
  final FamilyGraph graph;
}

/// Reads and writes families, people, and relationships.
///
/// **Deletion is soft.** Removing something sets a tombstone rather than
/// erasing the row, and reads skip tombstoned rows. Rows erased outright before
/// synchronisation exists would leave no record of the deletion, so on first
/// sync any peer still holding the row re-proposes it and it comes back —
/// deleted relatives reappearing, with no way to recover the intent (§15.2).
///
/// Deleting a person also tombstones every relationship naming them. The
/// schema's `ON DELETE CASCADE` cannot do this, because it only fires on a
/// physical delete and nothing here performs one; it remains as a safety net
/// for a purge or a migration (§15.1).
///
/// Writes do not validate. Callers run the domain rules first — a repository
/// that silently refused data would be a second, invisible place where
/// validation lives.
abstract interface class FamilyRepository {
  /// Every family that has not been deleted.
  Future<List<Family>> listFamilies();

  /// One family with its graph, or null if it is absent or deleted.
  Future<FamilySnapshot?> loadFamily(String familyId);

  /// Inserts [family], or updates it if the id already exists.
  Future<void> saveFamily(Family family);

  /// Inserts [person], or updates them if the id already exists.
  Future<void> savePerson(Person person);

  /// Inserts [relationship], or updates it if the id already exists.
  Future<void> saveRelationship(Relationship relationship);

  /// Writes a family, people, and edges **together, or not at all**.
  ///
  /// The single-row writes above cannot express this. Calling [savePerson] a
  /// thousand times leaves a thousand rows that are each already committed, so
  /// anything that interrupts the run — the application killed, the battery
  /// gone, the disk full — leaves a family half written, with edges naming
  /// people who are not there and nothing to say it happened.
  ///
  /// Ordered within the write: the family, then its people, then the edges
  /// between them. The foreign keys require it.
  ///
  /// Semantics per row match [savePerson] — insert, or update where the id is
  /// already present. Choosing *which* rows to pass is the caller's, and where
  /// a caller must not overwrite what is already stored it passes only what is
  /// new (see `planImport`).
  ///
  /// [family] is null when writing into one already stored.
  Future<void> saveAll({
    Family? family,
    Iterable<Person> persons,
    Iterable<Relationship> relationships,
  });

  /// Tombstones [personId] and every relationship naming them.
  Future<void> deletePerson(String personId);

  /// Tombstones one relationship, leaving both people in place.
  Future<void> deleteRelationship(String relationshipId);

  /// Tombstones a family together with its people and their relationships.
  Future<void> deleteFamily(String familyId);

  /// Whether [familyId] is here but tombstoned.
  ///
  /// [loadFamily] cannot answer this: it returns null for a family that was
  /// deleted and for one that was never here, and those are different facts.
  /// A file arriving for the first is somebody trying to undo a deletion; for
  /// the second it is an ordinary import (§15.1).
  Future<bool> wasDeleted(String familyId);
}
