/// Putting this device's changes on the server (ROADMAP M9, step 2).
///
/// ## Confirming, rather than assuming
///
/// The whole of this file turns on one fact written into the policies: an
/// UPDATE a policy forbids changes nothing and reports success. A push that
/// took silence for agreement would clear `unsent` on work the server never
/// accepted, and the device would never try again.
///
/// So every row goes up carrying one timestamp, taken before the batch left,
/// and afterwards the server is asked which rows it holds with exactly that
/// timestamp. Those are the ones that landed. Anything else stays flagged.
///
/// It costs one read per push. The alternative costs somebody's work, once,
/// with nothing to show that it happened.
///
/// ## Removals go by their own road
///
/// `save_family_all` clears `deleted_at` on everything it writes, so a
/// tombstone sent through it would revive the person. Removals use the
/// functions built for them, which is also what keeps a deleted person's edges
/// from being left pointing at somebody who is gone (§15.1).
///
/// Deleting a whole family goes **instead of** the rest, not after it: one
/// call does all three tables, so anything sent before it would be undone by
/// it and anything after it left alive in a family that is gone.
///
/// Its refusal is the loud shape, not the silent one. `delete_family_deep`
/// raises `insufficient_privilege` for anybody but the owner, so the push
/// throws rather than coming back with a short list, and the caller leaves
/// everything flagged without reaching the read-back at all. Measured, not
/// assumed: `test/cloud/push.dart` signs an editor in and watches it throw
/// (ROADMAP M9, step 4).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/supabase_family_repository.dart';
import 'family_push.dart';

/// Where this device's changes go.
///
/// An interface so a test can watch what was sent and answer for the server.
/// What Postgres does with an upsert is `test/cloud/`; what the device does
/// with the answer is the part worth checking in isolation.
abstract interface class ChangeSink {
  /// Sends [outgoing] and answers with the ids the server is then holding.
  Future<Set<String>> send(String familyId, Outgoing outgoing);
}

final class CloudPush implements ChangeSink {
  const CloudPush(this._db);

  final SupabaseClient _db;

  @override
  Future<Set<String>> send(String familyId, Outgoing outgoing) async {
    if (outgoing.isEmpty) return const <String>{};

    // Pinned to the batch's own timestamp, so what the server stores is what
    // the read-back below looks for.
    final repository = SupabaseFamilyRepository(
      _db,
      now: () => outgoing.stampedAt,
    );

    // On its own, and instead of everything else. `delete_family_deep` takes
    // the family, its people and their edges together, so anything sent before
    // it would be undone by it and anything sent after it would be left alive
    // in a family that is gone. It also saves three hundred round trips on a
    // three-hundred-person gia phả.
    //
    // The read-back still covers every row, because the function stamps them
    // all with this batch's timestamp — so a refusal is caught here exactly as
    // it is anywhere else, and the device goes on offering the family.
    if (outgoing.deletedFamily != null) {
      await repository.deleteFamily(outgoing.deletedFamily!);
      return _held(familyId, outgoing);
    }

    if (outgoing.family != null ||
        outgoing.persons.isNotEmpty ||
        outgoing.relationships.isNotEmpty) {
      await repository.saveAll(
        family: outgoing.family,
        persons: outgoing.persons,
        relationships: outgoing.relationships,
      );
    }

    for (final id in outgoing.deletedPersons) {
      await repository.deletePerson(id);
    }
    for (final id in outgoing.deletedRelationships) {
      await repository.deleteRelationship(id);
    }

    return _held(familyId, outgoing);
  }

  /// Which of [outgoing] the server is holding with this batch's timestamp.
  ///
  /// Read rather than inferred. A viewer's writes, or an editor's on a family
  /// they have been demoted out of, come back missing from here — which is the
  /// answer the device needs and the only one it can trust.
  Future<Set<String>> _held(String familyId, Outgoing outgoing) async {
    final stamp = outgoing.stampedAt.toIso8601String();
    final held = <String>{};

    if (outgoing.family != null || outgoing.deletedFamily != null) {
      final rows = await _db
          .from('families')
          .select('id')
          .eq('id', familyId)
          .eq('updated_at', stamp);
      held.addAll(rows.map((row) => row['id'] as String));
    }

    // One row answers for all of them. `delete_family_deep` is a single
    // transaction over the three tables, so the family carrying this batch's
    // timestamp means every person and edge in it does too — and its absence
    // means nothing happened at all, because the refusal is raised before the
    // first statement.
    //
    // Asking row by row would also be asking in one URL: three hundred people
    // is an `id=in.(...)` of some eleven kilobytes, which is past what a
    // request line is safely allowed to be.
    if (outgoing.deletedFamily != null) {
      return held.isEmpty ? const <String>{} : outgoing.ids;
    }

    for (final table in <String>['persons', 'relationships']) {
      final ids = table == 'persons'
          ? <String>[
              ...outgoing.persons.map((p) => p.id),
              ...outgoing.deletedPersons,
            ]
          : <String>[
              ...outgoing.relationships.map((r) => r.id),
              ...outgoing.deletedRelationships,
            ];
      if (ids.isEmpty) continue;

      final rows = await _db
          .from(table)
          .select('id')
          .inFilter('id', ids)
          .eq('updated_at', stamp);
      held.addAll(rows.map((row) => row['id'] as String));
    }

    return held;
  }
}
