/// Sending this device's changes up (ROADMAP M9, step 2).
///
/// What `unsent` was put there for. Until this exists an editor may edit, but
/// only their own copy, which nobody else will ever see — which makes "editor"
/// close to a label rather than a role.
///
/// ## Deletions do not travel with the rest
///
/// `save_family_all` sets `deleted_at = NULL` on every row it writes, because
/// writing a row asserts that it exists (§15.2). Push a tombstone through it
/// and the person comes back to life on the server. So removals are sent by
/// the path built for them, and only the living go in the batch.
///
/// ## A refused write does not announce itself
///
/// An UPDATE a policy forbids changes nothing and reports success — `USING`
/// decides which rows the statement can see, so a forbidden row is simply not
/// there (`20260924000003_policies.sql`). A push that trusted the absence of
/// an error would clear `unsent` on work the server never took, and the device
/// would stop retrying something it had not done.
///
/// So the flag is cleared only for rows the server is then seen to hold with
/// the timestamp this device sent. Anything else stays flagged and is tried
/// again. One extra read, in exchange for never quietly dropping somebody's
/// work.
library;

import 'package:drift/drift.dart';

import '../../domain/family.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// What this device is holding that the server has not been told about.
final class Outgoing {
  const Outgoing({
    required this.stampedAt,
    this.family,
    this.persons = const <Person>[],
    this.relationships = const <Relationship>[],
    this.deletedPersons = const <String>[],
    this.deletedRelationships = const <String>[],
  });

  /// The `updatedAt` these rows carry locally, and the one the server will be
  /// asked to store. Read back afterwards to tell a write that landed from one
  /// a policy silently refused.
  final DateTime stampedAt;

  final Family? family;
  final List<Person> persons;
  final List<Relationship> relationships;
  final List<String> deletedPersons;
  final List<String> deletedRelationships;

  bool get isEmpty =>
      family == null &&
      persons.isEmpty &&
      relationships.isEmpty &&
      deletedPersons.isEmpty &&
      deletedRelationships.isEmpty;

  /// Every id this carries, living and tombstoned.
  Set<String> get ids => <String>{
    if (family != null) family!.id,
    ...persons.map((p) => p.id),
    ...relationships.map((r) => r.id),
    ...deletedPersons,
    ...deletedRelationships,
  };
}

/// Reads what is waiting to go, and records what has gone.
final class FamilyPush {
  FamilyPush(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Everything in [familyId] this device has changed and not sent.
  ///
  /// One timestamp for the whole batch, taken now and written onto every row
  /// before it goes. It is what makes the read-back afterwards conclusive:
  /// a server row carrying it is one this push landed.
  Future<Outgoing> pending(String familyId) async {
    final at = _now().toUtc();

    final familyRow =
        await (_db.select(_db.families)
              ..where((f) => f.id.equals(familyId) & f.unsent.equals(true)))
            .getSingleOrNull();

    final personRows = await (_db.select(
      _db.persons,
    )..where((p) => p.familyId.equals(familyId) & p.unsent.equals(true))).get();

    final edgeRows = await (_db.select(
      _db.relationships,
    )..where((r) => r.familyId.equals(familyId) & r.unsent.equals(true))).get();

    return Outgoing(
      stampedAt: at,
      // A family this device has tombstoned is not pushed as a rename. Who may
      // delete a family is the server's to decide, and deleting one for
      // everybody is a larger act than synchronising an edit — it waits for a
      // later step rather than riding along in this batch.
      family: familyRow == null || familyRow.deletedAt != null
          ? null
          : familyFromRow(familyRow),
      persons: <Person>[
        for (final row in personRows)
          if (row.deletedAt == null) personFromRow(row),
      ],
      relationships: <Relationship>[
        for (final row in edgeRows)
          if (row.deletedAt == null) relationshipFromRow(row),
      ],
      deletedPersons: <String>[
        for (final row in personRows)
          if (row.deletedAt != null) row.id,
      ],
      deletedRelationships: <String>[
        for (final row in edgeRows)
          if (row.deletedAt != null) row.id,
      ],
    );
  }

  /// Clears the flag on [ids], which the caller has seen the server holding.
  ///
  /// Nothing else is touched — not `updatedAt`, which synchronisation orders
  /// by, and not the row's contents. The change was already made; this only
  /// records that it has gone.
  Future<void> markSent(Set<String> ids) async {
    if (ids.isEmpty) return;

    await _db.transaction(() async {
      for (final id in ids) {
        await (_db.update(_db.families)..where((f) => f.id.isValue(id))).write(
          const FamiliesCompanion(unsent: Value<bool>(false)),
        );
        await (_db.update(_db.persons)..where((p) => p.id.isValue(id))).write(
          const PersonsCompanion(unsent: Value<bool>(false)),
        );
        await (_db.update(_db.relationships)..where((r) => r.id.isValue(id)))
            .write(const RelationshipsCompanion(unsent: Value<bool>(false)));
      }
    });
  }

  /// How many rows are still waiting, for a screen that wants to say so.
  Future<int> waiting(String familyId) async {
    final outgoing = await pending(familyId);
    return outgoing.ids.length;
  }
}
