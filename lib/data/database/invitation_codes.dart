/// The codes this device issued, kept so they can be sent again
/// (PRODUCT.md §5.1).
///
/// ## Why the device keeps what the server refuses to
///
/// The server stores a hash. That is not caution about the owner's own phone;
/// it is about a database backup escaping, which would otherwise escape with
/// a column of working keys.
///
/// This device is a different room. It already holds the entire gia phả, and
/// anybody who can unlock it can issue a fresh invitation in three taps —
/// remembering one code hands them nothing they did not have. What it buys is
/// the ordinary case: the owner closed the message before sending it, or sent
/// it to the wrong person, and wants to try again without throwing the
/// invitation away.
///
/// ## Why this is not on `FamilyRepository`
///
/// Same shape as : two implementations, and only one of them is
/// a device. Ask Postgres which codes "this device issued" and there is no
/// honest answer (ARCHITECTURE §7).
///
/// ## What it forgets, and when
///
/// A code is removed once it has been used or revoked. Both make it dead on
/// the server, so keeping a readable copy would only offer somebody a Gửi
/// button that sends a code nobody can redeem.
library;

import 'app_database.dart';

/// Reads and writes the codes. Nothing else touches the table.
final class InvitationCodeStore {
  InvitationCodeStore(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Keeps [code] against the invitation [id] the server gave it.
  Future<void> remember({
    required String id,
    required String familyId,
    required String code,
  }) async {
    await _db
        .into(_db.invitationCodes)
        .insertOnConflictUpdate(
          InvitationCodesCompanion.insert(
            id: id,
            familyId: familyId,
            code: code,
            createdAt: _now().toUtc(),
          ),
        );
  }

  /// The codes this device holds for [familyId], by invitation id.
  ///
  /// A map rather than a list: every caller is matching it against the
  /// invitations the server listed, which is the set that decides what is
  /// shown.
  Future<Map<String, String>> forFamily(String familyId) async {
    final rows = await (_db.select(
      _db.invitationCodes,
    )..where((t) => t.familyId.equals(familyId))).get();

    return <String, String>{for (final row in rows) row.id: row.code};
  }

  /// Drops the code for [id], used or revoked.
  Future<void> forget(String id) async {
    await (_db.delete(_db.invitationCodes)..where((t) => t.id.equals(id))).go();
  }

  /// Drops every code this device holds, for signing out.
  ///
  /// These belong to the account that issued them. Left behind they would hand
  /// whoever signs in next somebody else's live codes.
  ///
  /// This one does not heal: an invitation still standing cannot be sent from
  /// here again. Revoking it and making another is the way back, and the
  /// confirmation before signing out says so.
  Future<void> forgetEverything() async {
    await _db.delete(_db.invitationCodes).go();
  }

  /// Drops every code for a family, for when the family itself goes.
  Future<void> forgetFamily(String familyId) async {
    await (_db.delete(
      _db.invitationCodes,
    )..where((t) => t.familyId.equals(familyId))).go();
  }
}
