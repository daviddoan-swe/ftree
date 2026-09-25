/// The first screen: the families recorded on this device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import 'package:file_selector/file_selector.dart';

import '../../l10n/app_localizations.dart';
import 'export_family.dart';
import 'family_form_sheet.dart';
import 'import_family.dart';
import 'invite_family.dart';
import 'join_family.dart';
import 'share_family.dart';
import 'family_screen.dart';

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final families = ref.watch(familyListProvider);

    return Scaffold(
      appBar: AppBar(
        // Opposite the import button, and on the bar for the same reason it
        // is: a code belongs to no family on this device, because the family
        // it opens is not here yet.
        // An envelope, padded to mirror the import button opposite it.
        //
        // Weight decided this rather than meaning. A key is drawn as a solid
        // silhouette and sits far heavier than anything else on the bar. An
        // arrow reads well but is horizontal, so it spans half again the width
        // of the vertical import arrow — checked by putting the two side by
        // side, where no `size` brings them into line, because the mismatch is
        // in the glyphs rather than in the slot. An envelope is the same
        // compact mass, and is already what an invitation is drawn as on the
        // Lời mời screen.
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: text.inviteEnterTitle,
            onPressed: () => joinFamilyWithCode(context, ref),
          ),
        ),
        title: Text(text.familiesTitle),
        actions: <Widget>[
          // On the bar rather than on a row: an import belongs to no family
          // in particular, and the file may bring one this device has never
          // seen.
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: text.importTitle,
              onPressed: () => _pickAndImport(context, ref),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        onPressed: () => showFamilyFormSheet(context),
        tooltip: text.familyCreate,
        child: const Icon(Icons.add),
      ),
      body: families.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _LoadFailed(error: error),
        data: (list) =>
            list.isEmpty ? const _NoFamiliesYet() : _FamilyList(families: list),
      ),
    );
  }
}

/// The families, each swipeable to reveal what can be done to it.
///
/// Managed from the list rather than from inside the family: editing or
/// deleting a thing from within itself reads oddly, and the delete confirmation
/// has to survive the screen it was started from disappearing.
///
/// No full-swipe shortcut. The gesture only reveals the buttons; deleting still
/// takes a deliberate tap, and then the confirmation. A swipe is easy to make by
/// accident and must never be the last step before losing a family.
class _FamilyList extends ConsumerWidget {
  const _FamilyList({required this.families});

  final List<Family> families;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SlidableAutoCloseBehavior(
      // One card holding every family, not a card each, and built row by row
      // as it scrolls — the same treatment the people list gets, so the two
      // do not diverge as this one grows.
      child: CustomScrollView(
        slivers: <Widget>[
          const SliverToBoxAdapter(child: AvatarHeader(initials: 'FTree')),
          GroupedSliverSection(
            itemCount: families.length,
            itemBuilder: (context, index) =>
                _familyRow(context, ref, families[index]),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Widget _familyRow(BuildContext context, WidgetRef ref, Family family) {
    final text = AppText.of(context);
    final colors = Theme.of(context).colorScheme;

    // One slot, two jobs, and which one depends on whether this family is
    // already up there. Before it is shared the action is Chia sẻ; afterwards
    // it is Mời, because a family already on the server cannot be sent again —
    // a second press would put this device's copy on top of the shared one
    // (PRODUCT §4.2) — and what is left to do to it is let somebody in.
    //
    // While the marks are still loading neither is offered. Guessing wrong in
    // the Chia sẻ direction is the expensive mistake.
    final shared = ref.watch(sharedFamiliesProvider).valueOrNull;
    final offerSharing = shared != null && !shared.contains(family.id);
    final offerInviting = shared != null && shared.contains(family.id);

    return Slidable(
      // Keyed by id so an open pane follows its family when the list is
      // reordered or one above it is removed.
      key: ValueKey<String>(family.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        // Grown by one button's worth rather than squeezing four into three
        // buttons' room, which would leave "Chia sẻ" too narrow to read.
        extentRatio: shared == null ? 0.5 : 0.66,
        children: <Widget>[
          // What is exported is one family, so the action belongs to its own
          // row. Before Edit, so that Delete keeps the outermost place a
          // practised swipe already reaches for.
          SlidableAction(
            onPressed: (_) => _export(context, ref, family),
            icon: Icons.ios_share,
            label: text.exportAction,
            backgroundColor: colors.surfaceContainerHighest,
            foregroundColor: colors.onSurfaceVariant,
          ),
          // Beside Xuất, because the two are the same thought: a family
          // leaving the device. A file goes to one person and can only ever
          // grow a record; this goes to a server and lets two people keep the
          // same one (PRODUCT §9.1, §4.2).
          if (offerSharing)
            SlidableAction(
              onPressed: (_) => shareFamily(context, ref, family),
              icon: Icons.cloud_upload_outlined,
              label: text.shareAction,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
          if (offerInviting)
            SlidableAction(
              onPressed: (_) => showFamilyCircle(context, ref, family),
              icon: Icons.person_add_alt,
              label: text.inviteAction,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
          SlidableAction(
            onPressed: (_) => showFamilyFormSheet(context, editing: family),
            icon: Icons.edit_outlined,
            label: text.actionEdit,
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
          ),
          SlidableAction(
            onPressed: (_) => _confirmAndDelete(context, ref, family),
            icon: Icons.delete_outline,
            label: text.actionDelete,
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
          ),
        ],
      ),
      child: GroupedRow(
        icon: Icons.account_tree,
        // The application's own colour, the same one that fills a chosen đời
        // chip. A family is what the application is about, so its glyph
        // carries the brand rather than one of the incidental row tints.
        iconColor: GroupedColors.primary(context),
        title: family.name,
        subtitle: family.description,
        // The moon says this family keeps the lunar calendar, which changes
        // what its dates mean.
        trailing: family.usesLunarCalendar
            ? Icon(
                Icons.brightness_2_outlined,
                size: 16,
                color: GroupedColors.secondaryLabel(context),
              )
            : null,
        onTap: () => showFamilyScreen(context, family),
      ),
    );
  }
}

/// Picks a file and, if the reader agrees to what it would do, imports it.
///
/// The picker is the only part that needs the operating system; everything
/// after it runs on the text and is covered by `import_family_test`.
Future<void> _pickAndImport(BuildContext context, WidgetRef ref) async {
  const json = XTypeGroup(
    label: 'JSON',
    extensions: <String>['json'],
    // iOS filters by uniform type rather than by extension, and a file that
    // arrived through a chat application often carries no useful type at all —
    // so the export's own type and plain text are both allowed through.
    uniformTypeIdentifiers: <String>['public.json', 'public.plain-text'],
  );

  // Everything here is guarded, because nothing awaits this function: it is
  // started by a tap and its future is dropped. An unguarded throw would
  // vanish into the zone and leave the reader looking at a screen that did
  // nothing, with no idea whether the file was wrong or the tap was missed.
  //
  // readAsString is the likely one: pick something that is not UTF-8 text —
  // a photo, a PDF — and it throws rather than returning nonsense.
  try {
    final picked = await openFile(acceptedTypeGroups: <XTypeGroup>[json]);
    if (picked == null) return;

    // Read before the check, not inside the call: reading is itself an await,
    // and a screen can go away during it.
    final text = await picked.readAsString();
    if (!context.mounted) return;

    await importFamilyFromText(context, ref, text);
  } on Object catch (e) {
    if (context.mounted) await showImportFailure(context, '$e');
  }
}

/// Writes a family out and hands it to the share sheet.
Future<void> _export(BuildContext context, WidgetRef ref, Family family) async {
  final hadSomething = await exportFamily(context, ref, family.id);
  if (hadSomething || !context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(exportEmptyMessage(context))));
}

/// Asks before tombstoning a family, its people, and their relationships.
///
/// A family with people in it asks for its name to be typed back. That is years
/// of transcription and the application has no way to restore it; a dialog with
/// two buttons is not proportional to that. An empty family — the create-by-
/// mistake case — asks once, because there is nothing to lose.
Future<void> _confirmAndDelete(
  BuildContext context,
  WidgetRef ref,
  Family family,
) async {
  final text = AppText.of(context);

  // The list holds families, not graphs, so the sizes are read here. It is a
  // full load to count two numbers — the same load opening the family would do,
  // and the numbers are the point of asking.
  final snapshot = await ref
      .read(familyRepositoryProvider)
      .loadFamily(family.id);
  if (snapshot == null || !context.mounted) return;

  final people = snapshot.graph.persons.length;
  final confirmed = people == 0
      ? await confirmIrreversible(
          context,
          title: text.deleteTitle(family.name),
          body: text.familyDeleteEmptyBody,
          confirmLabel: text.actionDelete,
        )
      : await confirmByTyping(
          context,
          title: text.deleteTitle(family.name),
          body: text.familyDeleteBody(
            text.familyPersonCount(people),
            text.familyRelationshipCount(snapshot.graph.relationships.length),
          ),
          expected: family.name,
          fieldLabel: text.familyDeleteTypeName,
          confirmLabel: text.actionDelete,
        );
  if (!confirmed) return;

  await ref.read(familyListProvider.notifier).removeFamily(family.id);
}

class _NoFamiliesYet extends StatelessWidget {
  const _NoFamiliesYet();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.account_tree_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              text.familiesEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text.familiesEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text('$error', textAlign: TextAlign.center),
    ),
  );
}
