/// The wiring between the interface and everything below it.
///
/// Riverpod notifiers are the application layer (ARCHITECTURE §5). There are no
/// separate application classes: with roughly nine use cases, one class per
/// action would be pass-through code and nothing else. A notifier appears when
/// an operation genuinely needs to coordinate something.
///
/// Screens never reach past these providers to the database (§4).
library;

// Riverpod exports a `Family` of its own — the provider-family base class —
// which collides with the domain entity. The entity is what this file is about.
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../data/database/app_database.dart';
import '../data/database/sharing_marks.dart';
import '../data/repositories/drift_family_repository.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';
import '../domain/person.dart';
import '../domain/relationship.dart';

/// The open database.
///
/// Overridden at startup with a real executor, and in tests with an in-memory
/// one. It throws rather than guessing, so a forgotten override fails loudly at
/// the first read instead of quietly opening a second database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError(
    'databaseProvider must be overridden with an AppDatabase',
  ),
);

/// Reads and writes families, people, and relationships.
final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => DriftFamilyRepository(ref.watch(databaseProvider)),
);

/// Reads and writes the mark of which families this device has shared.
///
/// Not part of [familyRepositoryProvider]. `FamilyRepository` has two
/// implementations and only one of them could answer this — a Postgres
/// repository is not a device and holds no marks — so it is its own small
/// thing (ARCHITECTURE §7).
final sharingMarksProvider = Provider<SharingMarks>(
  (ref) => SharingMarks(ref.watch(databaseProvider)),
);

/// The ids this device has sent to the cloud.
///
/// Watched by the family list to decide whether Chia sẻ is worth offering, so
/// it has to be a provider rather than a read: marking one family has to make
/// its button disappear without the screen being rebuilt by hand.
final sharedFamiliesProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(sharingMarksProvider).shared(),
);

/// Every family that has not been deleted.
///
/// An [AsyncNotifier] rather than a [FutureProvider] because the list changes
/// in response to the user creating a family, and the notifier is where that
/// action belongs.
final familyListProvider =
    AsyncNotifierProvider<FamilyListNotifier, List<Family>>(
      FamilyListNotifier.new,
    );

/// Loads the families and creates new ones.
final class FamilyListNotifier extends AsyncNotifier<List<Family>> {
  @override
  Future<List<Family>> build() =>
      ref.watch(familyRepositoryProvider).listFamilies();

  /// Saves [family] and reloads the list.
  ///
  /// Validation belongs to the caller: the screen shows the issues, and only
  /// the user can decide to proceed past a warning (DOMAIN.md §9).
  Future<void> save(Family family) async {
    final repository = ref.read(familyRepositoryProvider);
    state = const AsyncValue<List<Family>>.loading();
    state = await AsyncValue.guard(() async {
      await repository.saveFamily(family);
      return repository.listFamilies();
    });
  }

  /// Tombstones a family together with its people and their relationships.
  ///
  /// Also discards the cached snapshot. [familySnapshotProvider] is not
  /// autoDispose, so without this the deleted family's graph would sit in the
  /// cache for the lifetime of the application and be handed to anything that
  /// asked for it again.
  Future<void> removeFamily(String familyId) async {
    final repository = ref.read(familyRepositoryProvider);
    state = const AsyncValue<List<Family>>.loading();
    state = await AsyncValue.guard(() async {
      await repository.deleteFamily(familyId);
      return repository.listFamilies();
    });
    ref.invalidate(familySnapshotProvider(familyId));
  }
}

/// One family with its graph, or null if it is absent or deleted.
final familySnapshotProvider =
    AsyncNotifierProvider.family<
      FamilySnapshotNotifier,
      FamilySnapshot?,
      String
    >(FamilySnapshotNotifier.new);

/// Loads one family and rebuilds it after every write.
///
/// The graph is immutable, so a change means building a new one rather than
/// mutating in place. At this scale that costs milliseconds (§13.2).
final class FamilySnapshotNotifier
    extends FamilyAsyncNotifier<FamilySnapshot?, String> {
  @override
  Future<FamilySnapshot?> build(String familyId) =>
      ref.watch(familyRepositoryProvider).loadFamily(familyId);

  /// Re-reads the family from storage.
  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(familyRepositoryProvider).loadFamily(arg),
    );
  }

  /// Saves [person] and rebuilds the graph.
  ///
  /// Does not validate. The screen has already run the rules and, where they
  /// were only warnings, asked the user — a repository or notifier that
  /// silently refused data would be a second, invisible place where validation
  /// lives (DOMAIN.md §9).
  Future<void> savePerson(Person person) async {
    await ref.read(familyRepositoryProvider).savePerson(person);
    await reload();
  }

  /// Tombstones [personId] and rebuilds the graph.
  ///
  /// Every relationship naming them goes too, in one transaction — the
  /// repository's doing, not this notifier's (DOMAIN.md §15.1).
  Future<void> removePerson(String personId) async {
    await ref.read(familyRepositoryProvider).deletePerson(personId);
    await reload();
  }

  /// Saves [relationship] and rebuilds the graph.
  ///
  /// Does not validate, for the reason given on [savePerson]. A cycle check in
  /// particular needs the graph the caller already holds.
  Future<void> saveRelationship(Relationship relationship) async {
    await ref.read(familyRepositoryProvider).saveRelationship(relationship);
    await reload();
  }

  /// Removes one relationship, leaving both people in place.
  Future<void> removeRelationship(String relationshipId) async {
    await ref.read(familyRepositoryProvider).deleteRelationship(relationshipId);
    await reload();
  }
}
