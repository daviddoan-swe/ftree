/// The first screen: the families recorded on this device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../l10n/app_localizations.dart';
import 'family_form_sheet.dart';
import 'family_screen.dart';

class FamilyListScreen extends ConsumerWidget {
  const FamilyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final families = ref.watch(familyListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(text.familiesTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFamilyFormSheet(context),
        icon: const Icon(Icons.add),
        label: Text(text.familyCreate),
      ),
      body: families.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _LoadFailed(error: error),
        data: (list) => list.isEmpty
            ? const _NoFamiliesYet()
            : _FamilyList(families: list),
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
      // One card holding every family, not a card each: a device holds a
      // handful of trees, and the list is short enough to build at once.
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: <Widget>[
          const AvatarHeader(initials: 'FTree'),
          GroupedSection(
            children: <Widget>[
              for (final family in families) _familyRow(context, ref, family),
            ],
          ),
        ],
      ),
    );
  }

  Widget _familyRow(BuildContext context, WidgetRef ref, Family family) {
    final text = AppText.of(context);
    final colors = Theme.of(context).colorScheme;

    return Slidable(
      // Keyed by id so an open pane follows its family when the list is
      // reordered or one above it is removed.
      key: ValueKey<String>(family.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: <Widget>[
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
        iconColor: GroupedColors.green,
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
      ? await confirmDestructive(
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
