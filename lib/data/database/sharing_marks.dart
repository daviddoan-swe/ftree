/// Which of this device's families have been sent to the cloud
/// (PRODUCT.md §4.2).
///
/// ## Why this is not on `FamilyRepository`
///
/// That interface has two implementations, and only one of them can answer
/// this. Ask the Postgres repository which families "this device has shared"
/// and there is no honest reply — it is not a device, and every family it can
/// see is shared by definition.
///
/// A method one implementation cannot answer is the shape ARCHITECTURE §7 has
/// in mind when it says to split rather than to widen. So this is its own
/// small thing, local by nature, and the cloud side never sees it.
///
/// ## Why a mark rather than a question
///
/// The interface needs the answer to decide what to offer on a family, and it
/// needs it with no network. Asking the server is not available on a train.
///
/// ## What it is for, twice over
///
/// The obvious use is knowing. The one found by trying it is that **Chia sẻ
/// must be offered only once**: pressing it on a family already shared is
/// allowed by the server, and `saveAll` would put this device's copy on top of
/// the shared one — "my copy wins", which is exactly the conflict resolution
/// that cannot be done without an ordering nobody has yet (§15.3). After the
/// first time, the action on that family is to invite somebody.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Reads and writes the mark. Nothing else touches `sharedAt`.
final class SharingMarks {
  /// [now] is injectable so tests can pin the moment, as the repositories are.
  SharingMarks(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// The families this device has shared, by id.
  ///
  /// A set rather than a list of rows: every caller is asking whether one
  /// particular family is in it.
  ///
  /// Tombstoned families are left out. A family that has been deleted here is
  /// not one the interface offers anything for, and including it would only
  /// invite a question nobody asks.
  Future<Set<String>> shared() async {
    final rows =
        await (_db.selectOnly(_db.families)
              ..addColumns(<Expression<Object>>[_db.families.id])
              ..where(
                _db.families.sharedAt.isNotNull() &
                    _db.families.deletedAt.isNull(),
              ))
            .get();

    return rows.map((row) => row.read(_db.families.id)!).toSet();
  }

  /// Whether [familyId] has been shared from this device.
  Future<bool> isShared(String familyId) async =>
      (await shared()).contains(familyId);

  /// Drops every mark on this device.
  ///
  /// For signing out. A mark says *this device sent that family up*, which is
  /// a fact about the account that is leaving rather than about the device —
  /// left behind it would lie to whoever signs in next.
  ///
  /// Safe to do because it heals: a family with no mark offers Chia sẻ again,
  /// and pressing it asks the server, which recovers the mark when the family
  /// is still ours (§4.3, case 2) and says so plainly when it is not.
  ///
  /// `updatedAt` is left alone, for the reason [markShared] gives.
  Future<void> forgetAll() async {
    await _db
        .update(_db.families)
        .write(const FamiliesCompanion(sharedAt: Value<DateTime?>(null)));
  }

  /// Records that [familyId] has been sent.
  ///
  /// Called after the send succeeds, never before: a mark written first would
  /// survive a failed send and hide the button that would retry it.
  ///
  /// `updatedAt` is deliberately not touched. This is a note about what this
  /// device did, not a change to the family — and `updatedAt` is what
  /// synchronisation orders by (§15.2). Moving it would make a family look
  /// edited when only a local mark changed.
  Future<void> markShared(String familyId) async {
    await (_db.update(_db.families)..where((f) => f.id.equals(familyId))).write(
      FamiliesCompanion(sharedAt: Value<DateTime?>(_now().toUtc())),
    );
  }
}
