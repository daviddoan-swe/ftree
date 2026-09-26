/// The disagreements waiting for somebody to settle them
/// (ROADMAP M9, step 3b).
///
/// A pull that cannot merge two edits keeps the other side's version beside
/// the row rather than choosing. This reads those back, and writes down what
/// somebody decided.
///
/// ## Why it re-runs the merge rather than storing the questions
///
/// The row holds three things: what this device has, what the server had, and
/// what the two started from. Which fields disagree follows from them, and
/// working it out again is cheaper than keeping a fourth thing in step with
/// the other three. A stored list of questions could go stale — somebody edits
/// the person again, and the question is about a value that is no longer
/// theirs.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/merge.dart';
import '../../domain/person.dart';
import '../../domain/record_fields.dart';
import '../database/app_database.dart';
import '../database/mappers.dart';

/// What the two devices disagree about.
enum Dispute {
  /// Both sides changed the same fields to different values.
  fields,

  /// The server removed this person, and this device has changes to them.
  theyRemoved,

  /// This device removed this person, and the server has changes to them.
  iRemoved,
}

/// One person two devices disagree about.
final class Disagreement {
  const Disagreement({
    required this.kind,
    required this.mine,
    this.theirs,
    this.fields = const <FieldConflict>[],
  });

  /// Which sort of question this is, and so which answers it has.
  ///
  /// A removal is not a disagreement about fields that happens to involve a
  /// tombstone. There is no version of a person that is both gone and
  /// corrected, so it cannot be offered field by field: the answer is whether
  /// they are in the gia phả at all (ROADMAP M9, step 4).
  final Dispute kind;

  /// The person as this device holds them, which is what its owner typed.
  ///
  /// Present even for [Dispute.iRemoved], where the row is a tombstone: the
  /// tombstone keeps the person's details, which is how the screen can say who
  /// it is asking about.
  final Person mine;

  /// The person as the server held them when the pull found the disagreement.
  ///
  /// Null for [Dispute.theyRemoved]. They removed the person, so there is no
  /// version of theirs to show — that is the whole of what they are saying.
  final Person? theirs;

  /// The fields the two sides changed differently.
  ///
  /// Only for [Dispute.fields], and never empty there — a person with nothing
  /// left to disagree about is not a disagreement, and is cleared rather than
  /// listed.
  final List<FieldConflict> fields;
}

/// Reads disagreements, and records the answers.
final class Conflicts {
  Conflicts(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  /// How many people in [familyId] are waiting on somebody.
  ///
  /// Counted rather than loaded, because a screen usually wants to say the
  /// number and nothing more.
  Future<int> countIn(String familyId) async =>
      (await _waitingRows(familyId)).length;

  /// Rows carrying a question, of either shape.
  ///
  /// Tombstones are not filtered out here, unlike everywhere else that reads
  /// people. A row this device removed while the server was changing it is a
  /// tombstone *and* a question, and the usual `deletedAt IS NULL` would hide
  /// exactly the case step 4 exists for.
  Future<List<PersonRow>> _waitingRows(String familyId) =>
      (_db.select(_db.persons)..where(
            (p) =>
                p.familyId.equals(familyId) &
                (p.theirsFields.isNotNull() | p.theirsDeleted.equals(true)),
          ))
          .get();

  /// Every disagreement in [familyId].
  Future<List<Disagreement>> inFamily(String familyId) async {
    final rows = await _waitingRows(familyId);

    final found = <Disagreement>[];
    for (final row in rows) {
      final one = _read(row);
      if (one != null) found.add(one);
    }

    return found;
  }

  /// One person's disagreement, or null if there is none.
  Future<Disagreement?> forPerson(String personId) async {
    final row = await (_db.select(
      _db.persons,
    )..where((p) => p.id.equals(personId))).getSingleOrNull();

    return row == null ? null : _read(row);
  }

  Disagreement? _read(PersonRow row) {
    final mine = personFromRow(row);

    // Asked first, and it can be true alongside `theirsFields`: a field
    // disagreement recorded by one pull, and the person removed by the next.
    // The removal is the larger question — there is no point settling a
    // birthplace for somebody the other side has taken out.
    if (row.theirsDeleted) {
      return Disagreement(kind: Dispute.theyRemoved, mine: mine);
    }

    final storedTheirs = row.theirsFields;
    if (storedTheirs == null) return null;

    final theirFields = (jsonDecode(storedTheirs) as Map<String, dynamic>)
        .cast<String, Object?>();
    final theirs = personFromFields(mine, theirFields);

    // This device removed them while the server was changing them. Also not a
    // question about fields: what is being asked is whether they are in the
    // gia phả at all.
    if (row.deletedAt != null) {
      return Disagreement(kind: Dispute.iRemoved, mine: mine, theirs: theirs);
    }

    final storedBase = row.baseFields;
    if (storedBase == null) return null;

    final result = merge3(
      base: (jsonDecode(storedBase) as Map<String, dynamic>)
          .cast<String, Object?>(),
      mine: personFields(mine),
      theirs: theirFields,
    );

    if (result.isClean) return null;

    return Disagreement(
      kind: Dispute.fields,
      mine: mine,
      theirs: theirs,
      fields: result.conflicts,
    );
  }

  /// Settles [personId] with [chosen], a value for each field in dispute.
  ///
  /// Fields left out keep what this device holds, which is what the screen
  /// shows selected until somebody changes it.
  ///
  /// Afterwards the row is **unsent**: a decision is a change, and the other
  /// device has not seen it. The base moves on to what the server held, since
  /// that is what the two are now agreed to have started from, and the other
  /// version is dropped — the question has been answered.
  Future<void> settle(String personId, Map<String, Object?> chosen) async {
    final disagreement = await forPerson(personId);
    if (disagreement == null) return;
    if (disagreement.kind != Dispute.fields) return;

    final row = await (_db.select(
      _db.persons,
    )..where((p) => p.id.equals(personId))).getSingleOrNull();
    if (row == null) return;

    final settled = <String, Object?>{
      ...personFields(disagreement.mine),
      ...chosen,
    };

    await (_db.update(_db.persons)..where((p) => p.id.equals(personId))).write(
      personToRow(
        personFromFields(disagreement.mine, settled),
        updatedAt: _now().toUtc(),
      ).copyWith(
        unsent: const Value<bool>(true),
        // Non-null for a field disagreement, which is all this reaches: a
        // removal has no version of theirs and was returned above.
        baseFields: Value<String?>(
          jsonEncode(personFields(disagreement.theirs!)),
        ),
        theirsFields: const Value<String?>(null),
      ),
    );
  }

  /// Settles whether [personId] stays in the gia phả.
  ///
  /// The answer to both removal questions, because from here they are the same
  /// question — is this person in the gia phả or not — and only the bookkeeping
  /// afterwards differs.
  ///
  /// `unsent` is set only where this device's answer is news to the server:
  ///
  ///  * they removed them and the answer is **keep**, so the living row has to
  ///    go up and bring them back for everybody;
  ///  * this device removed them and the answer is **remove**, so the tombstone
  ///    has to go up and take them away for everybody.
  ///
  /// The other two answers agree with what the server already holds, and
  /// sending them would be a write with nothing in it.
  ///
  /// The base is cleared either way. A row settled by removal has no earlier
  /// version two sides started from, and one revived from theirs is now exactly
  /// what the server holds.
  Future<void> settleRemoval(String personId, {required bool remove}) async {
    final disagreement = await forPerson(personId);
    if (disagreement == null || disagreement.kind == Dispute.fields) return;

    final at = _now().toUtc();
    final theyRemoved = disagreement.kind == Dispute.theyRemoved;

    // Kept over this device's own edits when their version is the one taken:
    // choosing to keep somebody the other side was correcting means keeping
    // their correction, not a half-deleted copy of it.
    final revived = theyRemoved
        ? disagreement.mine
        : (disagreement.theirs ?? disagreement.mine);

    await (_db.update(_db.persons)..where((p) => p.id.equals(personId))).write(
      remove
          ? PersonsCompanion(
              deletedAt: Value<DateTime?>(at),
              updatedAt: Value<DateTime>(at),
              unsent: Value<bool>(!theyRemoved),
              baseFields: const Value<String?>(null),
              theirsFields: const Value<String?>(null),
              theirsDeleted: const Value<bool>(false),
            )
          : personToRow(revived, updatedAt: at).copyWith(
              // `personToRow` clears `deletedAt` on its own, which is what
              // brings the person back (§15.2).
              unsent: Value<bool>(theyRemoved),
              baseFields: const Value<String?>(null),
              theirsFields: const Value<String?>(null),
              theirsDeleted: const Value<bool>(false),
            ),
    );
  }
}
