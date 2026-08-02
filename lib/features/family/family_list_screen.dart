/// The first screen: the families recorded on this device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

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

class _FamilyList extends StatelessWidget {
  const _FamilyList({required this.families});

  final List<Family> families;

  @override
  Widget build(BuildContext context) => ListView.separated(
    itemCount: families.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final family = families[index];
      return ListTile(
        leading: const Icon(Icons.account_tree_outlined),
        title: Text(family.name),
        subtitle: family.description == null ? null : Text(family.description!),
        trailing: family.usesLunarCalendar
            ? const Icon(Icons.brightness_2_outlined, size: 18)
            : null,
        onTap: () => showFamilyScreen(context, family),
      );
    },
  );
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
