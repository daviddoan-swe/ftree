/// The first screen: the families recorded on this device.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../data/database/family_roles.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import 'package:file_selector/file_selector.dart';

import '../../l10n/app_localizations.dart';
import 'export_family.dart';
import 'family_form_sheet.dart';
import 'import_family.dart';
import '../account/account_screen.dart';
import 'invite_family.dart';
import 'join_family.dart';
import 'share_family.dart';
import 'family_screen.dart';

class FamilyListScreen extends ConsumerStatefulWidget {
  const FamilyListScreen({super.key});

  @override
  ConsumerState<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends ConsumerState<FamilyListScreen> {
  /// Asks the server what this account may do, whenever the application comes
  /// back to the front.
  ///
  /// The role map is cached for as long as the process lives, so without this
  /// a demotion made on another device reached the device only when somebody
  /// opened a family — and until they did, the swipe actions went on offering
  /// Sửa and Xoá to somebody the server would refuse (PRODUCT §5.0).
  ///
  /// This screen rather than somewhere more central because it is the one that
  /// is always mounted, and because the rights it draws are exactly the ones
  /// that go stale. Putting down the phone and picking it up again is how a
  /// change made elsewhere is normally noticed.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final container = ProviderScope.containerOf(context, listen: false);

    // This screen is the only one a deleted family's owner will ever be on
    // again, so it is the only place a tombstone that failed to send can be
    // picked up. Usually there is nothing waiting.
    unawaited(pushStuckDeletions(container));

    _lifecycle = AppLifecycleListener(
      onResume: () {
        // Told here too, for the same reason as on the pull: this screen is up,
        // so somebody is looking at the list a family is about to leave.
        unawaited(
          refreshedRoles(container).then((answer) {
            if (mounted) _sayWhatWent(context, answer.gone);
          }),
        );
        unawaited(pushStuckDeletions(container));
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          // Only while signed in. Most people never do (§4.1), and a permanent
          // account button would be advertising an account to somebody with no
          // use for one — and offering to manage something that is not there.
          if (ref.watch(signedInProvider).valueOrNull ?? false)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: text.accountTitle,
              onPressed: () => showAccount(context),
            ),
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
      // Pulling the list down sends what is still waiting to go.
      //
      // It runs on opening the application too, but that is once a session.
      // This screen is the only one a deleted family's owner ever comes back
      // to, so it is the only place a tombstone that failed to send can be
      // picked up — and somebody who has just deleted something and wants to
      // know it went reaches for exactly this gesture.
      child: RefreshIndicator(
        onRefresh: () => _refresh(context, ref),
        child: CustomScrollView(
          // Or a device with two families is one the gesture does not work
          // on, the list being shorter than the screen.
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
      ),
    );
  }

  Widget _familyRow(BuildContext context, WidgetRef ref, Family family) {
    final text = AppText.of(context);
    final colors = Theme.of(context).colorScheme;

    // One slot, two jobs, and which one depends on whether this family is
    // already up there. Before it is shared the action is Chia sẻ; afterwards
    // it is Thành viên, because a family already on the server cannot be sent
    // again — a second press would put this device's copy on top of the shared
    // one (PRODUCT §4.2) — and what is left to do to it is manage who is in.
    //
    // While the marks are still loading neither is offered. Guessing wrong in
    // the Chia sẻ direction is the expensive mistake.
    final shared = ref.watch(sharedFamiliesProvider).valueOrNull;
    final offerSharing = shared != null && !shared.contains(family.id);
    final offerInviting = shared != null && shared.contains(family.id);

    // What this copy arrived as. Absent means nobody else has a claim on it —
    // made here, or brought in as a file — and every right follows (§5.0).
    final role = ref.watch(familyRoleMapProvider).valueOrNull?[family.id];

    final actions = <Widget>[
      // What is exported is one family, so the action belongs to its own row.
      // Before Edit, so that Delete keeps the outermost place a practised
      // swipe already reaches for.
      //
      // The one control here with no policy behind it: an export never reaches
      // the server, so hiding it is the whole of the enforcement (§5.0).
      if (role.mayExport)
        SlidableAction(
          onPressed: (_) => _export(context, ref, family),
          icon: Icons.ios_share,
          label: text.exportAction,
          backgroundColor: colors.surfaceContainerHighest,
          foregroundColor: colors.onSurfaceVariant,
        ),

      // Beside Xuất, because the two are the same thought: a family leaving
      // the device. A file goes to one person and can only ever grow a record;
      // this goes to a server and lets two people keep the same one
      // (PRODUCT §9.1, §4.2).
      if (offerSharing && role.mayShare)
        SlidableAction(
          onPressed: (_) => shareFamily(context, ref, family),
          icon: Icons.cloud_upload_outlined,
          label: text.shareAction,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),

      if (offerInviting && role.mayManageMembers)
        SlidableAction(
          onPressed: (_) => showFamilyCircle(context, ref, family),
          icon: Icons.people_outline,
          // "Thành viên", not "Mời". Pressing it opens the room where members
          // are listed, roles changed and people removed — and inviting is a
          // button inside. A label promising an invitation would be describing
          // one thing the screen also happens to do.
          label: text.membersAction,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),

      if (role.mayRenameFamily)
        SlidableAction(
          onPressed: (_) => _renameAndSend(context, family),
          icon: Icons.edit_outlined,
          label: text.actionEdit,
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
        ),

      if (role.mayDeleteFamily)
        SlidableAction(
          onPressed: (_) => _confirmAndDelete(context, ref, family),
          icon: Icons.delete_outline,
          label: text.actionDelete,
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.onErrorContainer,
        ),
    ];

    return Slidable(
      // Keyed by id so an open pane follows its family when the list is
      // reordered or one above it is removed.
      key: ValueKey<String>(family.id),
      // A viewer has nothing to do to a family, so the gesture does nothing
      // rather than opening an empty drawer.
      enabled: actions.isNotEmpty,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        // A sixth of the width each, so the buttons keep their size as their
        // number changes and "Chia sẻ" never has to fit in a third of what it
        // needs. Capped, because a pane wider than the row cannot be drawn.
        extentRatio: (actions.length * 0.165).clamp(0.2, 0.9),
        children: actions,
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
  const backup = XTypeGroup(
    label: 'ftree',
    // `.ftree` is what this application writes now; `.json` is what it wrote
    // before backups were sealed, and a file somebody already has should not
    // stop being openable because the extension changed.
    extensions: <String>['ftree', 'json'],
    // iOS filters by uniform type rather than by extension, and a file that
    // arrived through a chat application often carries no useful type at all.
    // `public.data` is the catch-all a `.ftree` falls under, since the system
    // knows nothing else about it.
    uniformTypeIdentifiers: <String>[
      'public.data',
      'public.json',
      'public.plain-text',
    ],
  );

  // Everything here is guarded, because nothing awaits this function: it is
  // started by a tap and its future is dropped. An unguarded throw would
  // vanish into the zone and leave the reader looking at a screen that did
  // nothing, with no idea whether the file was wrong or the tap was missed.
  //
  // readAsString is the likely one: pick something that is not UTF-8 text —
  // a photo, a PDF — and it throws rather than returning nonsense.
  try {
    final picked = await openFile(acceptedTypeGroups: <XTypeGroup>[backup]);
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
/// Sends whatever is still waiting, and asks again what this account may do.
///
/// What the pull gesture does on this screen. Both are cheap and both are
/// things somebody standing here might be waiting on: a deletion that has not
/// reached the server, and a role somebody changed elsewhere.
///
/// The second answers a third question as well. A family somebody else deleted,
/// or one this account was put out of, goes from the list here — so the gesture
/// is the way to find out, and the only way that does not involve opening the
/// family and watching it vanish underneath.
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  final container = ProviderScope.containerOf(context, listen: false);
  await pushStuckDeletions(container);
  final gone = (await refreshedRoles(container)).gone;
  if (context.mounted) _sayWhatWent(context, gone);
}

/// Says which family disappeared, because the list simply being shorter is not
/// an explanation.
///
/// Nothing is said when nothing went, which is almost every refresh.
void _sayWhatWent(BuildContext context, List<GoneFamily> gone) {
  if (gone.isEmpty) return;
  final text = AppText.of(context);

  // Named one at a time, counted beyond that: a toast is one line, and the
  // usual case is one family.
  final message = gone.length == 1
      ? (gone.single.deleted
            ? text.familyGoneDeleted(gone.single.name)
            : text.familyGoneRemoved(gone.single.name))
      : text.familiesGone(gone.length);

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Opens the form, and sends what it changed.
///
/// Renaming used to wait for somebody to open the family and leave it again,
/// which is the only other moment anything is sent. A gia phả nobody returns to
/// therefore kept the old name on every other device indefinitely — and this is
/// the screen where renaming is done.
Future<void> _renameAndSend(BuildContext context, Family family) async {
  final container = ProviderScope.containerOf(context, listen: false);

  await showFamilyFormSheet(context, editing: family);

  // Asked locally first, because the sheet does not say whether it saved or was
  // dismissed, and a dismissal must not spend a request finding that out.
  final waiting = await container.read(familyPushProvider).pending(family.id);
  if (waiting.isEmpty) return;

  unawaited(pushFamily(container, family.id));
}

Future<void> _confirmAndDelete(
  BuildContext context,
  WidgetRef ref,
  Family family,
) async {
  final text = AppText.of(context);

  // Taken now, while there is certainly a widget to take it from. This runs
  // from a row of the list, and the row is gone the moment the family is — so
  // by the end of this function `context` may belong to nothing.
  final container = ProviderScope.containerOf(context, listen: false);

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

  // Sent from here, because nothing else ever will. A synchronisation runs
  // when a family is opened and when it is left, and a family that has just
  // been deleted cannot be opened again — so the tombstone would sit on this
  // device for ever while every other copy went on showing the gia phả.
  //
  // Not gated on `context.mounted`, and that was a real defect rather than a
  // tidiness point. The context here belongs to the row that drew this family,
  // and deleting the family unmounts the row — so the check was asking "does
  // the thing I have just destroyed still exist?" and usually getting no. It
  // raced: sometimes the check ran before the rebuild and the tombstone went,
  // sometimes after and it sat here for ever while every other device went on
  // showing the gia phả. Deleting the *last* family loses the race every time,
  // because the empty state replaces the whole section.
  //
  // Not awaited either: the row is gone from the list already, and what this
  // does is tell the server. Anything it fails to get away stays flagged.
  unawaited(pushFamily(container, family.id));
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
