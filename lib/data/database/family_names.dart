/// The name a shared family goes by on the server (PRODUCT.md §5.10).
///
/// ## Why this exists at all, next to a whole synchronisation
///
/// `pullFamily` already brings a family's rows down and merges them properly.
/// It runs when somebody opens a family, which is the wrong moment for the one
/// field the *list* draws: a gia phả nobody returns to kept its old name on
/// every other device indefinitely, and pulling down on the list — the gesture
/// somebody standing there actually has — did not fetch it.
///
/// So this is a deliberate shortcut, and its limits are the point:
///
/// * **the name only.** Everything else about the family arrives when the
///   family is opened, through the merge that is built for it. The list draws a
///   name, and that is what is fixed here.
/// * **never over unsent work.** A row this device has not sent is *held*, not
///   merged — the same rule the rest of synchronisation follows (ROADMAP M9,
///   step 1). Two devices renaming the same family is a disagreement nothing
///   here is equipped to settle, so this side simply does not enter it: the
///   local name stays and goes up on the next push.
/// * **never a resurrection.** A family tombstoned here is left alone.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Writes the server's name onto the families this device is merely holding.
final class FamilyNames {
  const FamilyNames(this._db);

  final AppDatabase _db;

  /// Applies [fromServer], keyed by family id, and answers with what changed.
  ///
  /// A family absent from here is not created: somebody was invited on another
  /// phone, and inventing a row would put a family on the list that is not on
  /// it. A name already matching is not written, so this is quiet on the
  /// refresh where nothing was renamed — which is almost every refresh.
  Future<Set<String>> apply(Map<String, String> fromServer) async {
    if (fromServer.isEmpty) return const <String>{};

    final rows =
        await (_db.select(_db.families)..where(
              (f) =>
                  f.id.isIn(fromServer.keys.toList()) &
                  f.deletedAt.isNull() &
                  f.unsent.equals(false),
            ))
            .get();

    final changed = <String>{};
    for (final row in rows) {
      final name = fromServer[row.id];
      if (name == null || name == row.name) continue;
      changed.add(row.id);
    }

    if (changed.isEmpty) return const <String>{};

    await _db.transaction(() async {
      for (final id in changed) {
        // The name alone. `unsent` stays false because nothing here is this
        // device's to send, and the columns that record what this device did
        // with the family — its role, its sharing mark, how far it has read —
        // are none of the server's business.
        await (_db.update(_db.families)..where((f) => f.id.equals(id))).write(
          FamiliesCompanion(name: Value<String>(fromServer[id]!)),
        );
      }
    });

    return changed;
  }
}
