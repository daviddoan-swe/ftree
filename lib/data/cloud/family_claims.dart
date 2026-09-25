/// Whether a family is already on the server, and who may still take it
/// (PRODUCT.md §4.2).
///
/// ## Why this is not on `FamilyRepository`
///
/// The same reason as `SharingMarks`, from the other side. That interface has
/// two implementations and only one of them can answer this: ask SQLite
/// whether a family is claimed and there is no honest reply, because a device
/// holds no claims. A method one implementation cannot answer is the shape
/// ARCHITECTURE §7 has in mind when it says to split rather than to widen.
///
/// ## Why it takes a server round trip at all
///
/// `SharingMarks` records what **this device** did. It cannot know what
/// another device did with the same family — and after a file has been sent,
/// two devices hold the same family, keeping the same id (DOMAIN §14.1). The
/// mark is therefore right about this device and silent about the row.
///
/// The client cannot work it out either. A family belonging to somebody else
/// is not forbidden to read, it is **absent**, so asking `families` returns
/// nothing and proves nothing. Only `family_is_claimed`, which steps outside
/// RLS on purpose, can tell the two apart.
///
/// ## First to press becomes the owner
///
/// Decided, and not a placeholder: a file carries no proof of who made it, so
/// there is nothing for the server to weigh. Whoever presses Chia sẻ first is
/// the owner, and the second is told plainly rather than shown a constraint.
/// Handing the family over afterwards is a separate feature (ROADMAP M9+); it
/// needs an owner willing to do it, which is a conversation between people
/// rather than a rule.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the claim. Nothing else knows the server's word for it.
final class FamilyClaims {
  FamilyClaims(this._db);

  final SupabaseClient _db;

  /// The word `save_family_all` raises when the id is taken. It is matched, so
  /// it is fixed on both sides; changing it means changing the migration.
  static const String _refusal = 'family_already_claimed';

  /// Whether [familyId] already exists on the server, under anybody.
  ///
  /// True for a family this account owns, one another account owns, and one
  /// that has been deleted — all three hold the id, which is the only thing
  /// being asked about.
  ///
  /// Requires a signed-in caller; the function is not granted to `anon`.
  Future<bool> isClaimed(String familyId) async => await _db.rpc<bool>(
    'family_is_claimed',
    params: <String, Object?>{'target': familyId},
  );

  /// Whether [error] is the server refusing a family that is already taken.
  ///
  /// Asking first is a separate request, so two devices can fall between the
  /// question and the answer. Sharing therefore has to recognise the refusal
  /// too, and this is the one place that knows what it looks like.
  static bool wasAlreadyClaimed(Object error) =>
      error is PostgrestException && error.message.contains(_refusal);
}
