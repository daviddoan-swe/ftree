/// SQLite-backed implementation of [FamilyRepository].
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/person.dart';
import '../../domain/record_fields.dart';
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
        await (_db.select(_db.families)
              ..where((f) => f.id.equals(familyId) & f.deletedAt.isNull()))
            .getSingleOrNull();

    if (familyRow == null) return null;

    final personRows = await (_db.select(
      _db.persons,
    )..where((p) => p.familyId.equals(familyId) & p.deletedAt.isNull())).get();

    final relationshipRows = await (_db.select(
      _db.relationships,
    )..where((r) => r.familyId.equals(familyId) & r.deletedAt.isNull())).get();

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
    await _db.transaction(() async {
      await _rememberBase(person.id);
      await _db
          .into(_db.persons)
          .insertOnConflictUpdate(personToRow(person, updatedAt: _timestamp));
    });
  }

  /// Keeps the row as it stands, before this edit changes it.
  ///
  /// Only on the first edit after a synchronisation: while `unsent` is already
  /// true the base is the version the server last gave, and a second edit must
  /// not overwrite it with the first edit's result. That would leave a merge
  /// comparing this device's work against itself and finding no change where
  /// there was one (ROADMAP M9, step 3).
  ///
  /// Nothing is kept for a row being created here. There is no version two
  /// people started from if only one of them has ever had it.
  Future<void> _rememberBase(String personId) async {
    final row = await (_db.select(
      _db.persons,
    )..where((p) => p.id.equals(personId))).getSingleOrNull();

    if (row == null || row.unsent) return;

    await (_db.update(_db.persons)..where((p) => p.id.equals(personId))).write(
      PersonsCompanion(
        baseFields: Value<String?>(
          jsonEncode(personFields(personFromRow(row))),
        ),
      ),
    );
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
  Future<void> saveAll({
    Family? family,
    Iterable<Person> persons = const <Person>[],
    Iterable<Relationship> relationships = const <Relationship>[],
  }) async {
    // One timestamp for the whole write. Stamping each row as it goes would
    // spread a single act across a range of times, and a reader ordering by
    // change would see the people arrive before the edges that join them.
    final at = _timestamp;

    await _db.transaction(() async {
      if (family != null) {
        await _db
            .into(_db.families)
            .insertOnConflictUpdate(familyToRow(family, updatedAt: at));
      }

      // Batched rather than awaited one at a time: the round trip per
      // statement is what made writing a thousand people slow, and inside a
      // transaction there is no ordering to lose by sending them together.
      // The same rule as a single edit, before the batch rather than inside
      // it: a batch that skipped this would lose the version a merge needs
      // (ROADMAP M9, step 3), and a batch cannot read while it writes.
      for (final person in persons) {
        await _rememberBase(person.id);
      }

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.persons, <PersonsCompanion>[
          for (final person in persons) personToRow(person, updatedAt: at),
        ]);
        // After the people, because both endpoints are foreign keys.
        batch.insertAllOnConflictUpdate(
          _db.relationships,
          <RelationshipsCompanion>[
            for (final relationship in relationships)
              relationshipToRow(relationship, updatedAt: at),
          ],
        );
      });
    });
  }

  @override
  Future<void> deletePerson(String personId) async {
    final at = _timestamp;

    await _db.transaction(() async {
      await (_db.update(
        _db.persons,
      )..where((p) => p.id.equals(personId))).write(
        PersonsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(at),
          unsent: const Value<bool>(true),
        ),
      );

      // Edges naming a tombstoned person must be tombstoned too. Left live they
      // would still synchronise as real relationships pointing at somebody the
      // family no longer has.
      await (_db.update(_db.relationships)..where(
            (r) => r.personAId.equals(personId) | r.personBId.equals(personId),
          ))
          .write(
            RelationshipsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
          );
    });
  }

  @override
  Future<void> deleteRelationship(String relationshipId) async {
    final at = _timestamp;

    await (_db.update(
      _db.relationships,
    )..where((r) => r.id.equals(relationshipId))).write(
      RelationshipsCompanion(
        deletedAt: Value(at),
        updatedAt: Value(at),
        unsent: const Value<bool>(true),
      ),
    );
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    final at = _timestamp;

    await _db.transaction(() async {
      await (_db.update(
        _db.relationships,
      )..where((r) => r.familyId.equals(familyId))).write(
        RelationshipsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(at),
          unsent: const Value<bool>(true),
        ),
      );

      await (_db.update(
        _db.persons,
      )..where((p) => p.familyId.equals(familyId))).write(
        PersonsCompanion(
          deletedAt: Value(at),
          updatedAt: Value(at),
          unsent: const Value<bool>(true),
          // No question survives the family it was about. Left behind, a
          // disagreement about one person's birthplace would go on being
          // counted, and offered, in a gia phả that is gone (ROADMAP M9,
          // step 4).
          baseFields: const Value<String?>(null),
          theirsFields: const Value<String?>(null),
          theirsDeleted: const Value<bool>(false),
        ),
      );

      await (_db.update(
        _db.families,
      )..where((f) => f.id.equals(familyId))).write(
        FamiliesCompanion(
          deletedAt: Value(at),
          updatedAt: Value(at),
          unsent: const Value<bool>(true),
        ),
      );
    });
  }
}
