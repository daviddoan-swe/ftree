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
import '../data/repositories/drift_family_repository.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

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
}
