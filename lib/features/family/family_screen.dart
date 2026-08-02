/// One family: the people in it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';
import '../../l10n/app_localizations.dart';
import '../person/person_form_screen.dart';

/// Opens the screen for [family].
Future<void> showFamilyScreen(BuildContext context, Family family) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyScreen(familyId: family.id),
      ),
    );

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({required this.familyId, super.key});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final snapshot = ref.watch(familySnapshotProvider(familyId));

    return Scaffold(
      appBar: AppBar(
        title: Text(snapshot.valueOrNull?.family.name ?? ''),
      ),
      floatingActionButton: snapshot.valueOrNull == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showPersonForm(
                context,
                familyId: familyId,
                usesLunarCalendar:
                    snapshot.valueOrNull!.family.usesLunarCalendar,
              ),
              icon: const Icon(Icons.person_add_outlined),
              label: Text(text.personAdd),
            ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          if (data == null) return const SizedBox.shrink();
          final people = data.graph.persons;
          if (people.isEmpty) return const _NoPeopleYet();

          return ListView.separated(
            itemCount: people.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _PersonTile(
              person: people[index],
              usesLunarCalendar: data.family.usesLunarCalendar,
            ),
          );
        },
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.usesLunarCalendar});

  final Person person;
  final bool usesLunarCalendar;

  @override
  Widget build(BuildContext context) {
    final lifespan = _lifespan(person);

    return ListTile(
      leading: CircleAvatar(
        child: Text(
          person.displayName.characters.firstOrNull ?? '?',
        ),
      ),
      title: Text(person.displayName),
      subtitle: lifespan == null ? null : Text(lifespan),
      onTap: () => showPersonForm(
        context,
        familyId: person.familyId,
        usesLunarCalendar: usesLunarCalendar,
        editing: person,
      ),
    );
  }

  /// `1887 – 1960`, with whichever end is known.
  ///
  /// Shows the ISO-prefix form rather than a formatted date, so a year-only
  /// record reads as a year rather than as an invented January.
  static String? _lifespan(Person person) {
    String? show(GenealogicalDate? date) =>
        date == null ? null : (date.isApproximate ? '~' : '') + date.toIso();

    final born = show(person.birthDate);
    final died = show(person.deathDate);
    if (born == null && died == null) return null;
    return '${born ?? ''} – ${died ?? ''}';
  }
}

class _NoPeopleYet extends StatelessWidget {
  const _NoPeopleYet();

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
              Icons.people_outline,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              text.peopleEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text.peopleEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
