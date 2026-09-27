/// Families whose copy on this device has to go (PRODUCT.md §5.0, §5.10).
///
/// Two ways in, one ending. This account was put out of the family, or the
/// family itself was deleted by the one person entitled to delete it.
///
/// `reconcile` writes [FamilyRole.removed] on a family the server no longer
/// names, and until now the copy stayed: readable, unchangeable, and marked
/// with a line saying so. The decision has been made the other way — being put
/// out takes the copy with it.
///
/// ## Tombstoned, and marked as already sent
///
/// Tombstoned rather than erased, for the reason every deletion here is soft
/// (§15.1): a row that is simply gone cannot be told from one that was never
/// here, and synchronisation needs to tell them apart.
///
/// Marked sent is the part that is easy to miss. `deleteFamily` leaves its
/// tombstones **unsent**, because an owner deleting a family means everybody
/// should lose it. This is the opposite: the family is not being deleted, this
/// device is losing its copy. Left unsent, the sweep for stuck deletions would
/// pick it up and spend a request offering to delete, for everybody, a gia phả
/// this account no longer has any say over — and the server would refuse it in
/// silence, for ever.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'family_roles.dart';

/// Drops the copies this account no longer has any right to.
final class RemovedFamilies {
  RemovedFamilies(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Removes every family marked [FamilyRole.removed] that is still here, and
  /// every one named in [alsoGone].
  ///
  /// [alsoGone] is for families somebody deleted rather than families this
  /// account was put out of. The two arrive by different routes and keep
  /// different roles (see `FamilyRoles.reconcile`), and they end the same way:
  /// the copy here goes.
  ///
  /// Returns what it dropped, by id, with the name it had — because by the time
  /// a caller wants to say which family disappeared, there is nothing left to
  /// read the name from.
  ///
  /// Idempotent: a family already gone is left alone, which is what makes this
  /// safe to run on every refresh.
  Future<Map<String, String>> drop({
    Set<String> alsoGone = const <String>{},
  }) async {
    // Built rather than written inline because an empty `isIn` is not a
    // predicate SQLite will take.
    final rows =
        await (_db.select(_db.families)..where((f) {
              var mine = f.myRole.equals(FamilyRole.removed.name);
              if (alsoGone.isNotEmpty) {
                mine = mine | f.id.isIn(alsoGone.toList());
              }
              return mine & f.deletedAt.isNull();
            }))
            .get();

    if (rows.isEmpty) return const <String, String>{};

    final at = _now().toUtc();
    final gone = <String, String>{for (final row in rows) row.id: row.name};
    final ids = gone.keys.toList();

    await _db.transaction(() async {
      for (final id in ids) {
        await (_db.update(
          _db.relationships,
        )..where((r) => r.familyId.equals(id))).write(
          RelationshipsCompanion(
            deletedAt: Value<DateTime?>(at),
            updatedAt: Value<DateTime>(at),
            unsent: const Value<bool>(false),
          ),
        );

        await (_db.update(
          _db.persons,
        )..where((p) => p.familyId.equals(id))).write(
          PersonsCompanion(
            deletedAt: Value<DateTime?>(at),
            updatedAt: Value<DateTime>(at),
            unsent: const Value<bool>(false),
            // No question survives the family it was about.
            baseFields: const Value<String?>(null),
            theirsFields: const Value<String?>(null),
            theirsDeleted: const Value<bool>(false),
          ),
        );

        await (_db.update(_db.families)..where((f) => f.id.equals(id))).write(
          FamiliesCompanion(
            deletedAt: Value<DateTime?>(at),
            updatedAt: Value<DateTime>(at),
            unsent: const Value<bool>(false),
          ),
        );
      }
    });

    return gone;
  }
}
