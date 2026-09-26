/// Asking somebody which version they want (ROADMAP M9, step 3b).
///
/// A pull merges what it can and keeps what it cannot, field by field. This is
/// where the rest is put to the person, because there is nothing else it could
/// be put to: a later `change_seq` says which write reached the server second,
/// not which reading of a hundred-year-old record is right.
///
/// ## Field by field, not record by record
///
/// Two relatives disagreeing about a name and agreeing about everything else
/// are asked about the name. Offering to replace the whole person would make
/// somebody choose between a correct birthplace and a correct name, and
/// whichever they picked the other would be lost — which is the outcome the
/// three-way merge exists to avoid.
///
/// ## The device's own version is selected to begin with
///
/// Doing nothing therefore keeps what its owner typed. The other version is
/// there to be read and taken deliberately; a screen that defaulted to the
/// server would settle disagreements for anybody who pressed on through.
///
/// ## A removal is not offered field by field
///
/// There is no version of a person who is both gone and corrected, so where one
/// side removed somebody the other was editing the question is the person, not
/// their fields: in the gia phả, or not (ROADMAP M9, step 4).
///
/// The same rule picks the answer that is already selected — whatever this
/// device holds. It holds them alive when the server removed them, and holds a
/// tombstone when this device's own owner pressed delete. So pressing on
/// through never reverses a decision somebody here took deliberately, in
/// either direction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../data/sync/conflicts.dart';
import '../../domain/merge.dart';
import '../../l10n/app_localizations.dart';

/// Opens the list of people waiting on a decision.
Future<void> showConflicts(BuildContext context, String familyId) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConflictsScreen(familyId: familyId),
      ),
    );

/// Everybody in one family with two versions.
class ConflictsScreen extends ConsumerStatefulWidget {
  const ConflictsScreen({required this.familyId, super.key});

  final String familyId;

  @override
  ConsumerState<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends ConsumerState<ConflictsScreen> {
  List<Disagreement> _waiting = const <Disagreement>[];
  bool _loading = true;

  /// What has been picked, by person and then by field.
  ///
  /// A field with no entry keeps this device's version, which is what makes
  /// doing nothing the safe answer.
  final Map<String, Map<String, Object?>> _chosen =
      <String, Map<String, Object?>>{};

  /// Whether each removal question has been answered with "remove".
  ///
  /// No entry means the answer this device already holds, which is what
  /// [_removingByDefault] works out.
  final Map<String, bool> _removing = <String, bool>{};

  /// What doing nothing means for [one], which is: leave things as they are.
  bool _removingByDefault(Disagreement one) => one.kind == Dispute.iRemoved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final waiting = await ref.read(conflictsProvider).inFamily(widget.familyId);
    if (!mounted) return;

    // Nothing left to decide is not a screen worth standing on. The questions
    // are the whole reason this was opened, so when the last one is answered
    // it takes itself away rather than making somebody press back to leave a
    // page that says there is nothing here.
    //
    // `maybePop` rather than `pop`, and its answer is used: pushed as the root
    // of a navigator — which is how the widget tests put it — there is nothing
    // to go back to, and the screen has to stay and say so instead.
    if (waiting.isEmpty) {
      if (await Navigator.of(context).maybePop()) return;
      if (!mounted) return;
    }

    setState(() {
      _waiting = waiting;
      _loading = false;
    });
  }

  Future<void> _settle(Disagreement one) async {
    final conflicts = ref.read(conflictsProvider);

    if (one.kind == Dispute.fields) {
      await conflicts.settle(
        one.mine.id,
        _chosen[one.mine.id] ?? const <String, Object?>{},
      );
    } else {
      await conflicts.settleRemoval(
        one.mine.id,
        remove: _removing[one.mine.id] ?? _removingByDefault(one),
      );
    }

    _chosen.remove(one.mine.id);
    _removing.remove(one.mine.id);
    ref.invalidate(familySnapshotProvider(widget.familyId));
    // The banner on the family screen reads the count, and it is the only thing
    // that says a decision is outstanding. Left alone it would go on naming a
    // number that has just been answered down.
    ref.invalidate(conflictCountProvider(widget.familyId));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return Scaffold(
      backgroundColor: GroupedColors.page(context),
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(text.conflictsTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _waiting.isEmpty
          ? Center(
              child: Text(
                text.conflictsNone,
                style: TextStyle(color: GroupedColors.secondaryLabel(context)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: <Widget>[
                for (final one in _waiting) ..._person(text, one),
              ],
            ),
    );
  }

  List<Widget> _person(AppText text, Disagreement one) => <Widget>[
    GroupedSection(
      header: one.mine.displayName,
      footer: switch (one.kind) {
        Dispute.fields => null,
        Dispute.theyRemoved => text.conflictRemovedByThem,
        Dispute.iRemoved => text.conflictRemovedByMe,
      },
      children: <Widget>[
        if (one.kind == Dispute.fields)
          for (final field in one.fields) ..._field(text, one, field)
        else
          ..._removal(text, one),
      ],
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: FilledButton(
        onPressed: () => _settle(one),
        child: Text(
          one.kind == Dispute.fields ? text.conflictKeep : text.conflictDecide,
        ),
      ),
    ),
  ];

  /// The two answers to "is this person in the gia phả".
  ///
  /// Ordered with the standing answer first, so the row that changes nothing is
  /// the one already selected and the one read first.
  List<Widget> _removal(AppText text, Disagreement one) {
    final removing = _removing[one.mine.id] ?? _removingByDefault(one);

    void choose(bool value) => setState(() {
      _removing[one.mine.id] = value;
    });

    Widget row({
      required bool remove,
      required String title,
      required String subtitle,
    }) => GroupedRow(
      icon: Icons.check_circle,
      iconColor: removing == remove
          ? GroupedColors.primary(context)
          : GroupedColors.grey,
      title: title,
      subtitle: subtitle,
      showChevron: false,
      onTap: () => choose(remove),
    );

    final keep = row(
      remove: false,
      title: text.conflictKeepPerson,
      // Which version comes back differs, and it matters. Where they removed
      // somebody this device was editing, keeping means this device's copy —
      // there is no other. Where this device removed somebody they were
      // editing, keeping means *their* copy, because taking somebody back who
      // was being corrected means taking the correction with them.
      subtitle: one.kind == Dispute.theyRemoved
          ? text.conflictForEverybody
          : text.conflictAsServerHas(
              one.theirs?.displayName ?? one.mine.displayName,
            ),
    );

    final remove = row(
      remove: true,
      title: text.conflictRemovePerson,
      subtitle: one.kind == Dispute.theyRemoved
          ? text.conflictDropsMine
          : text.conflictForEverybody,
    );

    return one.kind == Dispute.iRemoved
        ? <Widget>[remove, keep]
        : <Widget>[keep, remove];
  }

  List<Widget> _field(AppText text, Disagreement one, FieldConflict field) {
    final picked = _chosen[one.mine.id]?[field.field];
    final takingTheirs = picked == field.theirs && picked != field.mine;

    void choose(Object? value) => setState(() {
      (_chosen[one.mine.id] ??= <String, Object?>{})[field.field] = value;
    });

    return <Widget>[
      GroupedRow(
        icon: Icons.check_circle,
        iconColor: takingTheirs
            ? GroupedColors.grey
            : GroupedColors.primary(context),
        title: _label(text, field.field),
        subtitle: '${text.conflictMine}: ${_show(text, field.mine)}',
        showChevron: false,
        onTap: () => choose(field.mine),
      ),
      GroupedRow(
        icon: Icons.check_circle,
        iconColor: takingTheirs
            ? GroupedColors.primary(context)
            : GroupedColors.grey,
        title: text.conflictTheirs,
        // What both sides started from, so somebody can see which way each of
        // them moved rather than guessing from two values.
        subtitle:
            '${_show(text, field.theirs)}\n'
            '${text.conflictWas(_show(text, field.base))}',
        showChevron: false,
        onTap: () => choose(field.theirs),
      ),
    ];
  }

  /// A field's name in the reader's language.
  ///
  /// The names are the ones a record is stored under, and a screen must not
  /// show those. Anything unmapped falls back to its own name rather than to
  /// nothing: a field added later should read oddly, not vanish.
  String _label(AppText text, String field) => switch (field) {
    'displayName' => text.personDisplayName,
    'givenName' => text.personGivenName,
    'additionalNames' => text.personAdditionalNames,
    'familyName' => text.personFamilyName,
    'birthFamilyName' => text.personBirthFamilyName,
    'sex' => text.personSex,
    'birthDateIso' => text.conflictBirthDate,
    'birthDateApproximate' => text.conflictBirthApproximate,
    'deathDateIso' => text.conflictDeathDate,
    'deathDateApproximate' => text.conflictDeathApproximate,
    'birthPlace' => text.personBirthPlace,
    'deathPlace' => text.personDeathPlace,
    'biography' => text.personBiography,
    'profileMediaRef' => text.conflictMedia,
    _ when field.startsWith('birthLunar') => text.conflictBirthLunar,
    _ when field.startsWith('deathLunar') => text.conflictDeathLunar,
    _ => field,
  };

  /// A value as words.
  ///
  /// Emptiness is said rather than left blank. A row showing nothing beside a
  /// row showing a name reads as the screen failing to load one of them, when
  /// what it means is that somebody cleared the field on purpose.
  String _show(AppText text, Object? value) => switch (value) {
    null => text.conflictEmpty,
    final bool yes => yes ? text.conflictYes : text.conflictNo,
    _ => '$value',
  };
}
