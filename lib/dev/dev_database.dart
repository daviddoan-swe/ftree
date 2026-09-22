/// Putting a synthetic family into a database (ROADMAP M6, T28).
///
/// Development scaffolding. It writes through [DriftFamilyRepository] rather
/// than into the tables directly, so the rows it produces are the same rows the
/// application would have written — including the `updatedAt` stamps that
/// synchronisation will later depend on.
library;

import '../data/database/app_database.dart';
import '../data/repositories/drift_family_repository.dart';
import 'synthetic_family.dart';

/// Writes [data] into [db] in one transaction.
///
/// One transaction rather than a thousand: SQLite commits — and flushes to
/// disk — at the end of every statement that is not inside one, which turns a
/// three-hundred-person install into three hundred separate writes. Wrapping
/// them is the difference between a second and a minute on a real phone.
Future<void> installSyntheticFamily(
  AppDatabase db,
  SyntheticFamily data,
) async {
  final repository = DriftFamilyRepository(db);

  await db.transaction(() async {
    await repository.saveFamily(data.family);
    for (final person in data.persons) {
      await repository.savePerson(person);
    }
    for (final relationship in data.relationships) {
      await repository.saveRelationship(relationship);
    }
  });
}

/// Whether [db] already holds a row for [familyId], tombstoned or not.
///
/// Deliberately blind to the tombstone. A family that was generated and then
/// deleted has been seen, and installing it again would resurrect something the
/// reader chose to remove.
Future<bool> holdsFamily(AppDatabase db, String familyId) async {
  final row = await (db.select(
    db.families,
  )..where((f) => f.id.equals(familyId))).getSingleOrNull();

  return row != null;
}

/// Erases one family and everything belonging to it.
///
/// **Scoped to [familyId] on purpose.** This runs against the same database the
/// real gia phả lives in, so a blanket `DELETE FROM families` — which is what
/// "reset the development data" naturally suggests — would take a hundred years
/// of somebody's family history with it. A generated family is identified by
/// its seed and nothing else is touched.
///
/// A hard delete, unlike anything in the repository. Soft deletion exists so a
/// removal can be carried to other devices (DOMAIN.md §15.2); this row was never
/// real and leaving a tombstone would only stop the same seed being installed
/// again, since [holdsFamily] sees through tombstones.
Future<void> eraseFamily(AppDatabase db, String familyId) async {
  await db.transaction(() async {
    await (db.delete(
      db.relationships,
    )..where((r) => r.familyId.equals(familyId))).go();
    await (db.delete(
      db.persons,
    )..where((p) => p.familyId.equals(familyId))).go();
    await (db.delete(db.families)..where((f) => f.id.equals(familyId))).go();
  });
}
