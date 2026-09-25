/// Taking a family's changes down from the server (ROADMAP M9, step 1).
///
/// ## One number, and a greater-than
///
/// Every row on the server carries `change_seq`, a counter the server stamps
/// on insert and on every update (`20260924000001_schema.sql`). The device
/// keeps the highest it has taken for each family and asks for what came
/// after. That is the whole protocol: `WHERE change_seq > lastSeen`.
///
/// `0` means nothing has been taken, so the first pull answers with the whole
/// family. The first download and every later pull are therefore the same
/// request, and there is no second path to keep in step with the first.
///
/// Ordering is the server's job for a reason written into the schema: the
/// number has to come from somewhere every device agrees about, and two
/// phones' clocks are not that (§15.3).
///
/// ## What it refuses to touch
///
/// A row this device has changed and not sent is left exactly as it is, and
/// reported rather than merged. Landing the server's version on top of unsent
/// work is the one failure a pull must not have — and until pushing exists
/// there is nothing to reconcile it against, because the work has nowhere to
/// have gone.
///
/// Those ids come back in [PullResult.held] so a screen can say so. Choosing
/// between two versions is step 3's job, and it needs both to exist first.
///
/// ## All of it, or none of it
///
/// `lastSeen` is written inside the same transaction as the rows, and last.
/// Written first, a pull interrupted halfway would leave the remainder below a
/// number already recorded, and nothing would ever ask for those rows again —
/// a silent hole, which is the worst shape a synchronisation defect can take.
library;

import 'package:drift/drift.dart';

import '../../domain/family.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// What the server answered, before anything has been decided about it.
final class IncomingChanges {
  const IncomingChanges({
    required this.highestSeq,
    this.family,
    this.persons = const <Person>[],
    this.relationships = const <Relationship>[],
    this.deletedPersons = const <String>[],
    this.deletedRelationships = const <String>[],
  });

  /// The largest `change_seq` in this answer, which becomes the new mark.
  ///
  /// Taken from the rows rather than from the sequence itself: one sequence
  /// serves every family on the server, so its current value says nothing
  /// about how far *this* family has been read.
  final int highestSeq;

  final Family? family;
  final List<Person> persons;
  final List<Relationship> relationships;

  /// Tombstoned on the server. Deletion travels as an update, so these arrive
  /// by the same route as everything else (§15.1).
  final List<String> deletedPersons;
  final List<String> deletedRelationships;

  bool get isEmpty =>
      family == null &&
      persons.isEmpty &&
      relationships.isEmpty &&
      deletedPersons.isEmpty &&
      deletedRelationships.isEmpty;
}

/// What a pull brought down, and what it would not overwrite.
final class PullResult {
  const PullResult({
    required this.applied,
    required this.held,
    required this.lastSeen,
  });

  /// Rows written into the local database.
  final int applied;

  /// Ids left alone because this device holds unsent changes to them.
  final List<String> held;

  /// The number now recorded for the family.
  final int lastSeen;
}

/// Writes what the server sent into the local database.
final class FamilyPull {
  FamilyPull(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Where this device has got to with [familyId].
  Future<int> lastSeen(String familyId) async {
    final row = await (_db.select(
      _db.families,
    )..where((f) => f.id.equals(familyId))).getSingleOrNull();

    return row?.lastSeen ?? 0;
  }

  /// Applies [changes], and records how far this family has now been read.
  Future<PullResult> apply(String familyId, IncomingChanges changes) async {
    if (changes.isEmpty) {
      return PullResult(
        applied: 0,
        held: const <String>[],
        lastSeen: await lastSeen(familyId),
      );
    }

    final held = <String>[];
    var applied = 0;
    final at = _now().toUtc();

    await _db.transaction(() async {
      final unsentPersons = await _unsentPersons(familyId);
      final unsentEdges = await _unsentRelationships(familyId);

      final family = changes.family;
      if (family != null) {
        final here = await (_db.select(
          _db.families,
        )..where((f) => f.id.equals(familyId))).getSingleOrNull();

        if (here != null && here.unsent) {
          held.add(familyId);
        } else {
          // Only what the server owns. `sharedAt`, `myRole` and `lastSeen` are
          // this device's own notes, and a pull has nothing to say about them.
          await (_db.update(
            _db.families,
          )..where((f) => f.id.equals(familyId))).write(
            familyToRow(
              family,
              updatedAt: at,
            ).copyWith(unsent: const Value<bool>(false)),
          );
          applied++;
        }
      }

      for (final person in changes.persons) {
        if (unsentPersons.contains(person.id)) {
          held.add(person.id);
          continue;
        }
        await _db
            .into(_db.persons)
            .insertOnConflictUpdate(
              personToRow(
                person,
                updatedAt: at,
              ).copyWith(unsent: const Value<bool>(false)),
            );
        applied++;
      }

      for (final edge in changes.relationships) {
        if (unsentEdges.contains(edge.id)) {
          held.add(edge.id);
          continue;
        }
        await _db
            .into(_db.relationships)
            .insertOnConflictUpdate(
              relationshipToRow(
                edge,
                updatedAt: at,
              ).copyWith(unsent: const Value<bool>(false)),
            );
        applied++;
      }

      // Deletion arrives as a tombstone and is applied as one. The row stays,
      // so a later pull can tell it has been dealt with and nothing has to
      // guess whether an absent row was never here or has been removed.
      for (final id in changes.deletedPersons) {
        if (unsentPersons.contains(id)) {
          held.add(id);
          continue;
        }
        await (_db.update(_db.persons)..where((p) => p.id.equals(id))).write(
          PersonsCompanion(
            deletedAt: Value<DateTime?>(at),
            updatedAt: Value<DateTime>(at),
            unsent: const Value<bool>(false),
          ),
        );
        applied++;
      }

      for (final id in changes.deletedRelationships) {
        if (unsentEdges.contains(id)) {
          held.add(id);
          continue;
        }
        await (_db.update(
          _db.relationships,
        )..where((r) => r.id.equals(id))).write(
          RelationshipsCompanion(
            deletedAt: Value<DateTime?>(at),
            updatedAt: Value<DateTime>(at),
            unsent: const Value<bool>(false),
          ),
        );
        applied++;
      }

      // Last, and inside the transaction. See the note at the top of the file.
      await (_db.update(_db.families)..where((f) => f.id.equals(familyId)))
          .write(FamiliesCompanion(lastSeen: Value<int>(changes.highestSeq)));
    });

    return PullResult(
      applied: applied,
      held: held,
      lastSeen: changes.highestSeq,
    );
  }

  Future<Set<String>> _unsentPersons(String familyId) async {
    final rows = await (_db.select(
      _db.persons,
    )..where((p) => p.familyId.equals(familyId) & p.unsent.equals(true))).get();

    return <String>{for (final row in rows) row.id};
  }

  Future<Set<String>> _unsentRelationships(String familyId) async {
    final rows = await (_db.select(
      _db.relationships,
    )..where((r) => r.familyId.equals(familyId) & r.unsent.equals(true))).get();

    return <String>{for (final row in rows) row.id};
  }
}
