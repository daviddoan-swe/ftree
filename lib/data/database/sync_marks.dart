/// When each family was last brought level with the server.
///
/// Its own small class beside [SharingMarks] and [FamilyRoles], and for the
/// same reason: this is a note about what *this device* did, not a fact about
/// the family. `FamilyRepository` is a domain abstraction and must not learn
/// about device notes, or the domain starts knowing there is a server
/// (ARCHITECTURE §3).
///
/// Not `lastSeen`, which sits on the same row. That is a position in the
/// server's sequence and says nothing about when it was reached: a device can
/// be at sequence 2853 from a week ago. This is the clock time, and it is the
/// only thing that can answer "is what I am looking at recent?".
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Reads and writes the mark. Nothing else touches `syncedAt`.
final class SyncMarks {
  /// [now] is injectable so tests can pin the moment, as the repositories are.
  SyncMarks(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// When [familyId] was last brought level, or null if it never has been.
  Future<DateTime?> forFamily(String familyId) async {
    final row = await (_db.select(
      _db.families,
    )..where((f) => f.id.equals(familyId))).getSingleOrNull();

    return row?.syncedAt;
  }

  /// Records that [familyId] has just been brought level.
  ///
  /// Called only where the server was actually reached. A mark written after a
  /// failed attempt would make the line say "a moment ago" at exactly the
  /// moment somebody is reading it to find out whether to worry — which is
  /// worse than having no line at all.
  ///
  /// `updatedAt` is deliberately not touched, for the reason [SharingMarks]
  /// gives: synchronisation orders by it, and moving it would make a family
  /// look edited when only a local note changed (§15.2).
  Future<void> mark(String familyId) async {
    await (_db.update(_db.families)..where((f) => f.id.equals(familyId))).write(
      FamiliesCompanion(syncedAt: Value<DateTime?>(_now().toUtc())),
    );
  }
}
