/// Bringing a family in from a file (PRODUCT.md §9.1).
///
/// Two things live here, and the split is deliberate.
///
/// [importFamilyFromText] is the whole act: decode, work out what would
/// change, show it, and — only if the reader agrees — write. It takes **text**
/// rather than a file, so the part that has to ask the operating system for a
/// file is the only part left to add, and everything before it can be tested
/// by handing it a string.
///
/// [ImportPreview] is a screen and nothing else. It is given a finished
/// [ImportPlan] and draws it. No repository, no decoding, nothing async — so
/// what it shows for a given plan can be checked without a database.
///
/// ## Shown before it happens, not reported after
///
/// An import is somebody handing their family's record to a piece of software.
/// The least that deserves is being told what will happen while there is still
/// a way to say no. So the plan is built first and applied second, with the
/// reader in between.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/issue_text.dart';
import '../../app/providers.dart';
import '../../data/database/family_roles.dart';
import '../../data/transfer/family_file.dart';
import '../../data/transfer/family_import.dart';
import '../../data/transfer/family_vault.dart';
import '../../l10n/app_localizations.dart';
import 'vault_password.dart';

/// Reads [text] as a family file and, if the reader agrees, writes it in.
///
/// Returns the plan that was applied, or null when nothing was — the file
/// could not be read, it held nothing new, or the reader declined.
Future<ImportPlan?> importFamilyFromText(
  BuildContext context,
  WidgetRef ref,
  String text,
) async {
  // Sealed files come in by the same door. Asked for the password only when
  // the file actually is one: an old plain export, or one somebody is
  // bringing in from elsewhere, should not be met with a password box for a
  // lock it does not have.
  if (looksSealed(text)) {
    final opened = await _openSealed(context, text);
    if (opened == null) return null;
    text = opened;
  }

  if (!context.mounted) return null;

  final FamilyFile file;
  try {
    file = decodeFamilyFile(text);
  } on FamilyFileException catch (e) {
    if (context.mounted) await showImportFailure(context, e.reason);
    return null;
  }

  // Decoding is synchronous, so nothing has moved — but the failure branch
  // above awaits, and the guard is cheaper than reasoning about which branch
  // a reader is in.
  if (!context.mounted) return null;

  return bringInFamily(context, ref, file);
}

/// Writes an incoming family in, whatever brought it.
///
/// A file and an invitation arrive by different routes and are the same thing
/// once decoded: a family, its people, their edges, and an id that may or may
/// not already be on this device. So the preview, the add-only merge, the
/// write and the sentence afterwards live here rather than twice.
///
/// Returns the plan that was applied, or null when nothing was.
Future<ImportPlan?> bringInFamily(
  BuildContext context,
  WidgetRef ref,
  FamilyFile file,
) async {
  final repository = ref.read(familyRepositoryProvider);

  // The family may be one this device has never seen, so it is looked for
  // rather than assumed. Null means it arrives whole.
  final here = await repository.loadFamily(file.family.id);

  // A viewer's copy is one to read. Merging into it would add people that can
  // never travel anywhere and would quietly put their copy out of step with
  // the one everybody else is reading (PRODUCT §5.0).
  // Awaited, not peeked at. `valueOrNull` is null while the answer is still
  // being read, and null here means "a family nobody else has a claim on" —
  // which is every right. Peeked at too early, a viewer's import was allowed
  // because the roles had not arrived yet.
  final roles = await ref.read(familyRoleMapProvider.future);
  if (!context.mounted) return null;
  final role = roles[file.family.id];
  if (!role.mayImportInto) {
    if (context.mounted) {
      await showImportFailure(context, AppText.of(context).importNotAllowed);
    }
    return null;
  }

  // A family the owner deleted stays deleted, and only they can undo it
  // (PRODUCT §5.10). `here` is null for a tombstoned family as well as an
  // absent one — `loadFamily` skips tombstones — so the row is looked at
  // directly: absent means the file arrives whole, tombstoned means somebody
  // decided this gia phả should not exist.
  //
  // The server refuses it either way, and silently: an editor's writes into a
  // deleted family match nothing. Saying so here is what turns "the button
  // did nothing" into an answer.
  if (here == null && !role.mayRestoreDeleted) {
    final deleted = await ref
        .read(familyRepositoryProvider)
        .wasDeleted(file.family.id);

    if (deleted) {
      if (context.mounted) {
        await showImportFailure(
          context,
          AppText.of(context).importDeletedByOwner,
        );
      }
      return null;
    }
  }
  final plan = planImport(
    file,
    existing: here == null
        ? null
        : SnapshotOfFamily(
            persons: here.graph.persons,
            relationships: here.graph.relationships,
          ),
  );

  if (!context.mounted) return null;
  final agreed = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => ImportPreview(plan: plan)),
  );
  if (agreed != true) return null;

  await repository.saveAll(
    // Only when it is new. The add-only rule covers the family's own name and
    // settings too: a file must not rename a family already on the device.
    family: plan.familyIsNew ? plan.family : null,
    persons: plan.newPersons,
    relationships: plan.newRelationships,
  );

  // Both lists can have changed: a new family belongs on the list of families,
  // and new people belong in the family that took them.
  ref.invalidate(familyListProvider);
  ref.invalidate(familySnapshotProvider(plan.family.id));

  // Said out loud, and said here rather than by whoever called: a write that
  // reports nothing leaves the reader on the screen they started from with no
  // way to tell whether three hundred people arrived or the tap was missed.
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppText.of(context).importDonePeople(plan.newPersons.length),
        ),
      ),
    );
  }

  return plan;
}

/// Tells the reader why an import stopped, in the words of whatever stopped it.
///
/// Public because the part that fetches the file is somewhere else and can
/// fail in its own ways — an unreadable file, a picker that refuses — and
/// silence is the worst of the possible answers: somebody who taps Import and
/// sees nothing has nothing to report and no reason to try again.
Future<void> showImportFailure(BuildContext context, String reason) {
  final text = AppText.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.importFailed),
      // The decoder's own words. It knows which field was wrong or which
      // version it met; a generic "invalid file" would throw that away.
      content: Text(reason),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(text.actionClose),
        ),
      ],
    ),
  );
}

/// What a file would add, shown before anything is written.
class ImportPreview extends StatelessWidget {
  const ImportPreview({required this.plan, super.key});

  final ImportPlan plan;

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);
    final written = plan.exportedAt;

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(text.importTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(plan.family.name, style: theme.textTheme.titleLarge),
          if (written != null)
            Text(
              text.importFrom(_day(written)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: GroupedColors.secondaryLabel(context),
              ),
            ),
          if (plan.familyIsNew)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text.importNewFamily,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GroupedColors.secondaryLabel(context),
                ),
              ),
            ),
          const SizedBox(height: 20),

          // What arrives, then what was already here, then what is refused.
          // Counts that are zero are left out rather than shown as nothing:
          // a list of absences is not information.
          if (plan.newPersons.isNotEmpty)
            _Line(
              icon: Icons.add_circle_outline,
              tint: GroupedColors.green,
              label: text.importAddsPeople(plan.newPersons.length),
            ),
          if (plan.newRelationships.isNotEmpty)
            _Line(
              icon: Icons.add_circle_outline,
              tint: GroupedColors.green,
              label: text.importAddsRelationships(plan.newRelationships.length),
            ),
          if (plan.personsAlreadyHere > 0)
            _Line(
              icon: Icons.check_circle_outline,
              tint: GroupedColors.grey,
              label: text.importAlreadyHerePeople(plan.personsAlreadyHere),
            ),
          if (plan.relationshipsAlreadyHere > 0)
            _Line(
              icon: Icons.check_circle_outline,
              tint: GroupedColors.grey,
              label: text.importAlreadyHereRelationships(
                plan.relationshipsAlreadyHere,
              ),
            ),

          if (plan.rejected.isNotEmpty) ...<Widget>[
            _Line(
              icon: Icons.error_outline,
              tint: GroupedColors.red,
              label: text.importRejected(plan.rejected.length),
            ),
            // Each one named, with the family's own reason for refusing it.
            // A count alone tells somebody their record lost something and
            // not what.
            for (final entry in plan.rejected)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 6),
                child: Text(
                  '${entry.describe}\n${issueText(context, entry.code)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: GroupedColors.secondaryLabel(context),
                  ),
                ),
              ),
          ],

          if (!plan.changesSomething)
            _Line(
              icon: Icons.info_outline,
              tint: GroupedColors.grey,
              label: text.importNothingNew,
            ),

          const SizedBox(height: 20),
          // Not a footnote. PRODUCT §9.1 requires the limit of merging by file
          // to be stated in the interface rather than discovered later.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GroupedColors.card(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(text.importAddOnly, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(text.actionCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                // Nothing to do is not an action. A button that writes no rows
                // would still report success, and the reader would not know
                // whether it had worked.
                onPressed: plan.changesSomething
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(text.importAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The day a file was written, to the day.
  ///
  /// No time of day: it is a clock reading from somebody else's device, and
  /// showing minutes would lend it a precision it has not got (§15.3).
  static String _day(DateTime at) {
    final local = at.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.tint, required this.label});

  final IconData icon;
  final Color tint;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: tint),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}

/// Asks for the password and opens [sealed], or null if it was not opened.
///
/// Asked once, not twice. The file is the check: right opens it, wrong says
/// so — and asking for a sixteen-character passphrase a second time every
/// time somebody restores a backup buys nothing the file does not give.
///
/// Wrong and damaged are reported as one thing because they are one thing
/// from here: authentication fails identically, and guessing between them
/// would be the screen inventing a diagnosis.
Future<String?> _openSealed(BuildContext context, String sealed) async {
  final text = AppText.of(context);
  final password = await askForPassword(context);
  if (password == null) return null;

  try {
    // In an isolate, for the reason the export gives: Argon2id runs in Dart
    // and costs seconds on a phone.
    if (!context.mounted) return null;
    return await whileWorking(
      context,
      text.vaultOpening,
      () => runOffThread(_unsealIt, (sealed: sealed, password: password)),
    );
  } on VaultException catch (e) {
    if (!context.mounted) return null;
    await showImportFailure(context, switch (e.refusal) {
      VaultRefusal.tooNew => text.vaultTooNew,
      VaultRefusal.notAVault => text.vaultWrong,
      VaultRefusal.wrongPasswordOrDamaged => text.vaultWrong,
    });
    return null;
  }
}

/// Opening, in whatever isolate `compute` gives it.
Future<String> _unsealIt(({String sealed, String password}) work) =>
    unseal(sealed: work.sealed, password: work.password);
