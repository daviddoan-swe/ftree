/// Asking the server what has changed (ROADMAP M9, step 1).
///
/// One request per table, each of them `change_seq > lastSeen` for one family.
/// Nothing clever: the server already stamps every insert and every update
/// with a number it alone assigns, so "what came after" is a comparison rather
/// than a diff.
///
/// ## Tombstones come back as rows
///
/// Deletion is soft everywhere (§15.1), so a removed person arrives as an
/// ordinary changed row with `deleted_at` set. They are separated here rather
/// than left for the writer to notice, because the two are applied
/// differently and a caller reading [IncomingChanges] should not have to check
/// a field to know which it is holding.
///
/// ## The mark comes from the rows
///
/// `highestSeq` is the largest number in the answer, not the sequence's
/// current value. One sequence serves every family on the server, so its value
/// moves when a different family changes and would carry this one past rows it
/// has never seen.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_mappers.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import 'family_pull.dart';

/// Where a pull gets its changes from.
///
/// An interface so a test can hand in an answer: what the server would have
/// replied is one `WHERE change_seq > ?`, and doubting Postgres's
/// greater-than proves nothing, while every case worth checking is about what
/// the device does with the answer.
abstract interface class ChangeSource {
  Future<IncomingChanges> since(String familyId, int lastSeen);
}

/// Reads a family's changes from the server.
final class CloudChanges implements ChangeSource {
  const CloudChanges(this._db);

  final SupabaseClient _db;

  @override
  /// Everything in [familyId] stamped after [lastSeen].
  ///
  /// `0` asks for all of it, which is what a device that has never pulled
  /// wants — and is why the first download needs no separate path.
  Future<IncomingChanges> since(String familyId, int lastSeen) async {
    final families = await _db
        .from('families')
        .select()
        .eq('id', familyId)
        .gt('change_seq', lastSeen);

    final people = await _db
        .from('persons')
        .select()
        .eq('family_id', familyId)
        .gt('change_seq', lastSeen);

    final edges = await _db
        .from('relationships')
        .select()
        .eq('family_id', familyId)
        .gt('change_seq', lastSeen);

    var highest = lastSeen;
    for (final rows in <List<Map<String, dynamic>>>[families, people, edges]) {
      for (final row in rows) {
        final seq = row['change_seq'] as int? ?? 0;
        if (seq > highest) highest = seq;
      }
    }

    bool gone(Map<String, dynamic> row) => row['deleted_at'] != null;

    return IncomingChanges(
      highestSeq: highest,
      // A tombstoned family is not sent down as a rename — it is sent down as
      // a deletion. Applying the last name it had would be the one reading of
      // the row that says nothing about what happened to it.
      family: families.isEmpty || gone(families.first)
          ? null
          : familyFromRow(families.first),
      familyDeleted: families.isNotEmpty && gone(families.first),
      persons: <Person>[
        for (final row in people)
          if (!gone(row)) personFromRow(row),
      ],
      relationships: <Relationship>[
        for (final row in edges)
          if (!gone(row)) relationshipFromRow(row),
      ],
      deletedPersons: <String>[
        for (final row in people)
          if (gone(row)) row['id'] as String,
      ],
      deletedRelationships: <String>[
        for (final row in edges)
          if (gone(row)) row['id'] as String,
      ],
    );
  }
}
