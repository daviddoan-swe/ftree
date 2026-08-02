/// SQLite-backed implementation of [FamilyRepository].
library;

import 'package:drift/drift.dart';

import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// Stores a family in the local database.
///
/// Deletion is soft throughout: a tombstone is written and reads skip it. See
/// [FamilyRepository] for why the schema's cascade cannot do that job.
final class DriftFamilyRepository implements FamilyRepository {
  /// [now] is injectable so tests can pin timestamps. Production leaves it out.
  DriftFamilyRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Always UTC. The schema stores ISO-8601 UTC text, and a local timestamp
  /// would be written with the wrong zone attached (§15.3).
  DateTime get _timestamp => _now().toUtc();

  @override
  Future<List<Family>> listFamilies() async {
    final rows = await (_db.select(
      _db.families,
    )..where((f) => f.deletedAt.isNull())).get();

    return rows.map(familyFromRow).toList();
  }

  @override
  Future<FamilySnapshot?> loadFamily(String familyId) async {
    final familyRow =
        await (_db.select(_db.families)..where(
              (f) => f.id.equals(familyId) & f.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (familyRow == null) return null;

    final personRows = await (_db.select(_db.persons)..where(
          (p) => p.familyId.equals(familyId) & p.deletedAt.isNull(),
        ))
        .get();

    final relationshipRows = await (_db.select(_db.relationships)..where(
          (r) => r.familyId.equals(familyId) & r.deletedAt.isNull(),
        ))
        .get();

    return FamilySnapshot(
      family: familyFromRow(familyRow),
      graph: FamilyGraph(
        persons: personRows.map(personFromRow),
        relationships: relationshipRows.map(relationshipFromRow),
      ),
    );
  }

  @override
  Future<void> saveFamily(Family family) async {
    await _db
        .into(_db.families)
        .insertOnConflictUpdate(familyToRow(family, updatedAt: _timestamp));
  }

  @override
  Future<void> savePerson(Person person) async {
    await _db
        .into(_db.persons)
        .insertOnConflictUpdate(personToRow(person, updatedAt: _timestamp));
  }

  @override
  Future<void> saveRelationship(Relationship relationship) async {
    await _db
        .into(_db.relationships)
        .insertOnConflictUpdate(
          relationshipToRow(relationship, updatedAt: _timestamp),
        );
  }

  @override
  Future<void> deletePerson(String personId) async {
    final at = _timestamp;

    await _db.transaction(() async {
      await (_db.update(_db.persons)..where((p) => p.id.equals(personId)))
          .write(PersonsCompanion(deletedAt: Value(at), updatedAt: Value(at)));

      // Edges naming a tombstoned person must be tombstoned too. Left live they
      // would still synchronise as real relationships pointing at somebody the
      // family no longer has.
      await (_db.update(_db.relationships)..where(
            (r) => r.personAId.equals(personId) | r.personBId.equals(personId),
          ))
          .write(
            RelationshipsCompanion(
              deletedAt: Value(at),
              updatedAt: Value(at),
            ),
          );
    });
  }

  @override
  Future<void> deleteRelationship(String relationshipId) async {
    final at = _timestamp;

    await (_db.update(_db.relationships)
          ..where((r) => r.id.equals(relationshipId)))
        .write(
          RelationshipsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
        );
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    final at = _timestamp;

    await _db.transaction(() async {
      await (_db.update(_db.relationships)
            ..where((r) => r.familyId.equals(familyId)))
          .write(
            RelationshipsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
          );

      await (_db.update(_db.persons)..where((p) => p.familyId.equals(familyId)))
          .write(PersonsCompanion(deletedAt: Value(at), updatedAt: Value(at)));

      await (_db.update(_db.families)..where((f) => f.id.equals(familyId)))
          .write(FamiliesCompanion(deletedAt: Value(at), updatedAt: Value(at)));
    });
  }
}
