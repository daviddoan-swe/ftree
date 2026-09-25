/// What this device may do with each family (PRODUCT.md §5.0).
///
/// ## Why it is here rather than asked for
///
/// The role that decides anything lives on the server, in
/// `family_memberships`, and the policies there are what actually refuse a
/// write. This is a copy kept so the interface can offer the right controls
/// **without a network** — a gia phả opens on a train, and a screen that has
/// to ask before it can draw a button is a screen that cannot.
///
/// ## Why this is not on `FamilyRepository`
///
/// The same reason as `SharingMarks`: two implementations, only one of them a
/// device. Ask Postgres what *this device* may do and there is no honest reply
/// (ARCHITECTURE §7).
///
/// ## Null is a role
///
/// It means nobody else has a claim: a family made here, or one that arrived
/// as a file, which carries no rights with it (§5.7). Full rights, and not an
/// absence of information.
library;

import 'package:drift/drift.dart';

import 'app_database.dart';

/// The three roles the server knows, and the fourth state a device can be in.
///
/// Written out rather than passed around as strings, so a typo is a compile
/// error rather than a silently missing button.
enum FamilyRole {
  owner,
  editor,
  viewer,

  /// Not a role the server stores — the state a copy is left in when its
  /// membership is gone.
  ///
  /// The server has already done everything it can: the family is invisible
  /// to them, and every write is refused. What it cannot reach is the copy
  /// sitting on their phone, and **deleting that is not on the table**. An
  /// editor's own additions never went anywhere — there is no synchronisation
  /// yet — so erasing the copy would destroy work that exists nowhere else,
  /// and it would still not be security: a file may have been exported, or a
  /// screen photographed, long before.
  ///
  /// So the copy is locked to reading, and the person is told why. Everything
  /// they added is still there to look at; none of it can leave, and nothing
  /// more can be changed.
  removed;

  /// The name the server stores, and the one written into the local column.
  static FamilyRole? from(String? stored) => switch (stored) {
    'owner' => FamilyRole.owner,
    'editor' => FamilyRole.editor,
    'viewer' => FamilyRole.viewer,
    'removed' => FamilyRole.removed,
    _ => null,
  };
}

/// What a copy of a family allows, from the role it arrived with.
///
/// Every one of these but [mayExport] mirrors a policy in
/// `20260924000003_policies.sql`, and the policy is what decides. These only
/// keep somebody from doing work that would be refused.
extension FamilyRights on FamilyRole? {
  bool get _isOwnerOrNone => this == null || this == FamilyRole.owner;
  bool get _mayWrite =>
      this == null || this == FamilyRole.owner || this == FamilyRole.editor;

  /// Whether the copy is still ours in any sense.
  ///
  /// False only for [FamilyRole.removed], and what it turns off is every
  /// control at once — there is no server left to refuse anything, so the
  /// interface has to be the whole of it.
  bool get stillMine => this != FamilyRole.removed;

  /// Sending the gia phả out as a file.
  ///
  /// The one right with no policy behind it: an export never reaches the
  /// server. Hiding it closes the easy path and states the intent; it is not a
  /// lock, because an editor holds the whole record already (§5.0).
  bool get mayExport => stillMine && _isOwnerOrNone;

  /// Putting the family on the server. Only for one that is not there yet.
  bool get mayShare => this == null;

  /// Opening the member list. `family_members` answers only an owner anyway.
  bool get mayManageMembers => this == FamilyRole.owner;

  /// Changing the family's own name and notes (`families_update_editor`).
  bool get mayRenameFamily => stillMine && _mayWrite;

  /// Tombstoning the family. An editor is refused this by the server, which
  /// is written into the policy as "and `deleted_at IS NULL`" on both sides.
  bool get mayDeleteFamily => stillMine && _isOwnerOrNone;

  /// Adding, editing and removing people and the edges between them
  /// (`persons_insert`, `persons_update`, and the same pair for
  /// relationships). Deleting is soft, so it is an update and an editor may
  /// do it.
  bool get mayEditPeople => stillMine && _mayWrite;

  /// Merging a file into this family. Add-only, but still a write.
  bool get mayImportInto => stillMine && _mayWrite;
}

/// Reads and writes the role each family arrived with. Nothing else touches
/// `myRole`.
final class FamilyRoles {
  FamilyRoles(this._db);

  final AppDatabase _db;

  /// The role of every family on this device, by id.
  ///
  /// Families with no role are left out rather than mapped to null: a caller
  /// asking a map for a missing key gets null anyway, and one entry per
  /// restricted copy is a smaller thing to carry.
  Future<Map<String, FamilyRole>> all() async {
    final rows = await (_db.select(
      _db.families,
    )..where((f) => f.myRole.isNotNull() & f.deletedAt.isNull())).get();

    final roles = <String, FamilyRole>{};
    for (final row in rows) {
      final role = FamilyRole.from(row.myRole);
      if (role != null) roles[row.id] = role;
    }

    return roles;
  }

  /// Brings the local roles in line with what the server says.
  ///
  /// [fromServer] is every membership the signed-in account holds, by family
  /// id. Called only when that was actually fetched — never on a guess, and
  /// never when the request failed, because an empty answer and a failed one
  /// look the same from here and one of them would mark everything removed.
  ///
  /// Two rules, and the second is the one worth reading twice:
  ///
  /// * a family the server names takes the role the server gives it, whether
  ///   that is larger or smaller than what the device believed;
  /// * a family the device holds **with a role** that the server does not name
  ///   is one this account has been put out of, and becomes
  ///   [FamilyRole.removed].
  ///
  /// A family with no role is left alone either way. It was made here or came
  /// in as a file, and neither gives the server anything to say about it.
  ///
  /// Returns whether anything changed, so a caller can avoid redrawing — and,
  /// more to the point, avoid looping on itself.
  Future<bool> reconcile(Map<String, FamilyRole> fromServer) async {
    final here = <String, FamilyRole?>{};
    final rows = await (_db.select(
      _db.families,
    )..where((f) => f.deletedAt.isNull())).get();
    for (final row in rows) {
      here[row.id] = FamilyRole.from(row.myRole);
    }

    var changed = false;

    for (final entry in fromServer.entries) {
      if (!here.containsKey(entry.key)) continue;
      if (here[entry.key] == entry.value) continue;
      await remember(entry.key, entry.value);
      changed = true;
    }

    for (final entry in here.entries) {
      if (entry.value == null) continue;
      if (entry.value == FamilyRole.removed) continue;
      if (fromServer.containsKey(entry.key)) continue;
      await remember(entry.key, FamilyRole.removed);
      changed = true;
    }

    return changed;
  }

  /// Records the role this copy of [familyId] arrived with.
  ///
  /// `updatedAt` is deliberately not touched, for the reason
  /// `SharingMarks.markShared` gives: this is a note about the copy, not a
  /// change to the family, and synchronisation orders by that column (§15.2).
  Future<void> remember(String familyId, FamilyRole role) async {
    await (_db.update(_db.families)..where((f) => f.id.equals(familyId))).write(
      FamiliesCompanion(myRole: Value<String?>(role.name)),
    );
  }
}
