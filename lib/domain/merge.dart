/// Merging two edits of the same record (ROADMAP M9, step 3).
///
/// ## Why three versions and not two
///
/// Given only two versions of a person there is no way to tell an edit from an
/// absence of one. If mine says *Hải* and theirs says *Hai*, which of us typed
/// it? Both look like a value. With the version we both started from the
/// question answers itself: whichever side differs from it is the side that
/// changed.
///
/// So a device keeps the row exactly as the server last gave it, from the
/// moment it first edits that row until the edit has gone. That copy is the
/// base, and this is what it is for.
///
/// ## The rule, per field
///
/// * neither side moved it — it stays
/// * one side moved it — that side wins, whichever side it is
/// * both moved it to the same value — they agree; no conflict
/// * both moved it differently — **a conflict**, and nothing is chosen
///
/// Nothing is chosen because there is nothing to choose it by. A later
/// `change_seq` says which write reached the server second, not which reading
/// of a hundred-year-old record is right. Picking one silently would throw
/// away a relative's work to save asking them a question, and this is a
/// document where the answer matters more than the convenience.
///
/// ## What it deliberately does not do
///
/// It does not compare within a field. Two people rewriting one biography are
/// in conflict over the biography, not over a sentence in it. Merging prose is
/// a different problem and a worse one to get wrong.
library;

/// One field both sides changed, and disagreed about.
final class FieldConflict {
  const FieldConflict({
    required this.field,
    required this.base,
    required this.mine,
    required this.theirs,
  });

  /// The name the field is stored under, which is also what a screen shows.
  final String field;

  final Object? base;
  final Object? mine;
  final Object? theirs;
}

/// Merges [mine] and [theirs] against the [base] they both started from.
///
/// All three are the same record as flat fields: a name to a value, with
/// values that compare by equality. Dates arrive already reduced to strings by
/// the caller, because two `GenealogicalDate`s that mean the same thing must
/// compare equal here and reducing them once, outside, is simpler than
/// teaching this about them.
///
/// Keys missing from [base] are treated as absent rather than as an error: a
/// record may gain a field between one version of the application and another,
/// and a merge that refused to run would be worse than one that treats the
/// new field as something neither side had.
MergeResult merge3({
  required Map<String, Object?> base,
  required Map<String, Object?> mine,
  required Map<String, Object?> theirs,
}) {
  final fields = <String, Object?>{};
  final conflicts = <FieldConflict>[];
  var took = false;

  final names = <String>{...base.keys, ...mine.keys, ...theirs.keys};

  for (final name in names) {
    final was = base[name];
    final ours = mine[name];
    final other = theirs[name];

    final weMoved = ours != was;
    final theyMoved = other != was;

    if (!weMoved && !theyMoved) {
      fields[name] = was;
      continue;
    }

    if (weMoved && !theyMoved) {
      fields[name] = ours;
      continue;
    }

    if (!weMoved && theyMoved) {
      fields[name] = other;
      took = true;
      continue;
    }

    if (ours == other) {
      // Both of us, and we agree. Two people typing the same correction is
      // not a disagreement, and asking about it would be asking about nothing.
      fields[name] = ours;
      continue;
    }

    // Left as ours until somebody decides. See the note on [Merge.fields].
    fields[name] = ours;
    conflicts.add(
      FieldConflict(field: name, base: was, mine: ours, theirs: other),
    );
  }

  return MergeResult(fields: fields, conflicts: conflicts, tookAnything: took);
}

/// What came of merging, and what could not be.
final class MergeResult {
  const MergeResult({
    required this.fields,
    required this.conflicts,
    required this.tookAnything,
  });

  /// The merged record, field by field. A field in conflict holds **mine**.
  final Map<String, Object?> fields;

  /// Fields both sides changed and disagreed about.
  final List<FieldConflict> conflicts;

  /// Whether anything was taken from the other side.
  ///
  /// False where every difference was this device's own — there is then
  /// nothing new to write, and the row can be left exactly as it is.
  final bool tookAnything;

  bool get isClean => conflicts.isEmpty;
}
