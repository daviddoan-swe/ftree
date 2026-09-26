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
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../data/database/app_database.dart';
import '../data/cloud/cloud_session.dart';
import '../data/cloud/family_invitations.dart';
import '../data/database/family_roles.dart';
import '../data/database/invitation_codes.dart';
import '../data/sync/cloud_changes.dart';
import '../data/sync/cloud_push.dart';
import '../data/sync/conflicts.dart';
import '../data/sync/family_pull.dart';
import '../data/sync/family_push.dart';
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

/// Whether there is a cloud session, and whether there still is.
///
/// A stream rather than one answer, because the question has one: somebody
/// signs in, signs out, and signs in again without the application restarting,
/// and an answer computed once is wrong from the first of those onwards. Asked
/// as a future it took a sign-out to notice — that path invalidated it by hand
/// — and never noticed a sign-in at all, because the screen that signs
/// somebody in holds no `ref` to invalidate anything with. Three call sites
/// could have remembered to; the fourth would not have.
///
/// `openCloud` is not called here. It belongs in `main`, because initialising
/// starts a token-refresh timer and a timer started inside a widget test
/// outlives the test that started it.
///
/// False where the cloud was never opened at all. That is every test process,
/// and an interface that cannot tell whether somebody is signed in should say
/// no rather than guess yes.
final signedInProvider = StreamProvider<bool>((ref) async* {
  try {
    yield isSignedIn;
    yield* Supabase.instance.client.auth.onAuthStateChange.map(
      (_) => isSignedIn,
    );
  } catch (_) {
    yield false;
  }
});

/// Reads and writes the codes of invitations this device issued.
///
/// Local by nature, like [sharingMarksProvider]: the server keeps only a hash,
/// and this is the copy that lets an invitation be sent a second time after
/// the message carrying it was closed (PRODUCT §5.1).
final invitationCodeStoreProvider = Provider<InvitationCodeStore>(
  (ref) => InvitationCodeStore(ref.watch(databaseProvider)),
);

/// Reads and writes the role each copy of a family arrived with.
final familyRolesProvider = Provider<FamilyRoles>(
  (ref) => FamilyRoles(ref.watch(databaseProvider)),
);

/// What this device may do with each family, by id (PRODUCT §5.0).
///
/// Watched by every screen that draws a control, so a family whose role has
/// just been learned redraws without anybody rebuilding it by hand. A family
/// missing from the map has no role and every right.
///
/// Answers from the device and asks the server behind it. The local answer is
/// what a screen gets, immediately and offline; the request that follows is
/// how a promotion, a demotion or a removal reaches a phone at all, since
/// nothing else synchronises yet. It redraws only when something actually
/// changed, which is also what keeps it from asking itself in a circle.
final familyRoleMapProvider = FutureProvider<Map<String, FamilyRole>>((
  ref,
) async {
  final roles = ref.watch(familyRolesProvider);

  var disposed = false;
  ref.onDispose(() => disposed = true);

  unawaited(
    _refreshRoles(roles).then((changed) {
      if (changed && !disposed) ref.invalidateSelf();
    }),
  );

  return roles.all();
});

/// Asks the server again what this account may do.
///
/// [familyRoleMapProvider] asks once, when it is first built, and never again:
/// it is not `autoDispose`, so the answer is cached for as long as the
/// application is running. A demotion made on another device therefore never
/// reached this one until it was restarted, and the controls an editor had
/// stayed where they were — which is the shape of failure §5.0 exists to
/// prevent, an interface promising something the server will refuse.
///
/// Returns the roles as they now stand locally, read from the store rather
/// than from the provider: invalidating it leaves it loading for a moment, and
/// a role read as null in that moment means "a family nobody else has a claim
/// on", which is every right rather than none.
/// Takes a [ProviderContainer] rather than a `WidgetRef` because one caller is
/// a screen on its way out: a `WidgetRef` stops working the moment its widget
/// is disposed, and the container belongs to the scope above it, which
/// outlives every screen.
Future<Map<String, FamilyRole>> refreshedRoles(
  ProviderContainer container,
) async {
  final roles = container.read(familyRolesProvider);
  if (await _refreshRoles(roles)) container.invalidate(familyRoleMapProvider);
  return roles.all();
}

/// Asks the server what this account may do, and writes it down.
///
/// Every failure is silence: no session, no network, a cloud never opened at
/// all in a test process. That is deliberate and it is the important part —
/// "the server named nothing" and "the server could not be reached" look
/// identical from here, and one of them would mark every family removed.
Future<bool> _refreshRoles(FamilyRoles roles) async {
  try {
    if (!isSignedIn) return false;

    final named = await FamilyInvitations(Supabase.instance.client).myRoles();

    final fromServer = <String, FamilyRole>{};
    for (final entry in named.entries) {
      final role = FamilyRole.from(entry.value);
      if (role != null) fromServer[entry.key] = role;
    }

    return roles.reconcile(fromServer);
  } catch (_) {
    return false;
  }
}

/// The ids this device has sent to the cloud.
///
/// Watched by the family list to decide whether Chia sẻ is worth offering, so
/// it has to be a provider rather than a read: marking one family has to make
/// its button disappear without the screen being rebuilt by hand.
final sharedFamiliesProvider = FutureProvider<Set<String>>(
  (ref) => ref.watch(sharingMarksProvider).shared(),
);

/// Writes what the server sent into the local database (ROADMAP M9).
final familyPullProvider = Provider<FamilyPull>(
  (ref) => FamilyPull(ref.watch(databaseProvider)),
);

/// Where those changes come from. Overridden in tests; nothing else overrides
/// it. Built on use rather than held, because it may not touch
/// `Supabase.instance` before `main` has opened the cloud.
final changeSourceProvider = Provider<ChangeSource>(
  (ref) => CloudChanges(Supabase.instance.client),
);

/// Reads the disagreements a pull could not settle, and records the answers.
final conflictsProvider = Provider<Conflicts>(
  (ref) => Conflicts(ref.watch(databaseProvider)),
);

/// How many people in a family are waiting on a decision (PRODUCT §5.0).
final conflictCountProvider = FutureProvider.family<int, String>(
  (ref, familyId) => ref.watch(conflictsProvider).countIn(familyId),
);

/// Reads what is waiting to go up, and records what has gone (ROADMAP M9).
final familyPushProvider = Provider<FamilyPush>(
  (ref) => FamilyPush(ref.watch(databaseProvider)),
);

/// Where those changes go. Overridden in tests; nothing else overrides it.
final changeSinkProvider = Provider<ChangeSink>(
  (ref) => CloudPush(Supabase.instance.client),
);

/// Sends this device's changes for [familyId], and pulls afterwards.
///
/// Push first, then pull, and in that order for a reason: a pull holds every
/// row this device has not sent rather than landing on it, so pushing first is
/// what lets those rows stop being held and start being merged.
///
/// Best effort and silent, like the pull. Rows the server did not take stay
/// flagged and go again next time.
/// Down first, then up.
///
/// The order is load-bearing, not a matter of taste. A merge needs three
/// versions — what this device typed, what the server last gave it, and what
/// the other side typed — and `markSent` clears the second along with the
/// flag, because once the server holds this version there is no earlier one
/// the two sides started from.
///
/// So a push that ran first left the pull behind it with two versions where it
/// needed three. It could not tell an edit from an absence of one, landed the
/// server's row outright, and the work this device had done went with it: no
/// merge, no disagreement, nobody asked. The whole of steps 3 and 3b was
/// unreachable through the interface, and the way it failed was the silent
/// one.
///
/// Pulling first, an unsent row meets the other side's version while it still
/// remembers what the two started from. What fits together is merged and stays
/// unsent, so the push behind it carries the merged result up. What does not
/// is kept as a question and held back from that push, which is what stops it
/// being settled in this device's favour with nobody asked
/// (`test/data/sync/sync_order_test.dart`).
Future<void> syncFamily(ProviderContainer container, String familyId) async {
  await pullFamily(container, familyId);
  await pushFamily(container, familyId);
}

/// Sends what [familyId] is holding, and brings nothing back.
///
/// Called when somebody leaves a family, which is the moment they have
/// finished writing in it. Opening one is the right moment to *read* the
/// server and the wrong moment to send: by then the work has been sitting here
/// since the last visit, and a person added to a family nobody opened again
/// stayed on one phone and reached nobody.
///
/// Leaving is a boundary rather than a rule. Work not sent — because the
/// application was killed on the screen, or there was no network — stays
/// flagged and goes on the next visit, which is the whole point of the flag.
Future<void> pushFamily(ProviderContainer container, String familyId) async {
  try {
    if (!isSignedIn) return;

    final shared = container.read(sharedFamiliesProvider).valueOrNull;
    if (shared == null || !shared.contains(familyId)) return;

    // Only where this copy is allowed to write at all. A viewer's push would
    // be refused row by row and silently, and the read-back would come back
    // empty — correct, but a request spent to learn what the device already
    // knew (PRODUCT §5.0).
    //
    // Asked afresh, and before the decision rather than after it. Opening a
    // family is already the moment this code spends a request on, and the role
    // is the thing most likely to have changed since the last one: somebody
    // demoted on another device would otherwise go on being offered the
    // controls of the role they used to have.
    final role = (await refreshedRoles(container))[familyId];
    if (role.mayEditPeople) {
      final push = container.read(familyPushProvider);
      final outgoing = await push.pending(familyId);
      if (!outgoing.isEmpty) {
        await push.markSent(
          await container.read(changeSinkProvider).send(familyId, outgoing),
        );
      }
    }
  } catch (_) {
    // Offline, signed out, or a cloud never opened. What was waiting is still
    // waiting, which is what the flag is for.
  }
}

/// Brings [familyId] up to date with the server, if that is possible at all.
///
/// Best effort, and silent when it is not: no session, no network, a family
/// this device never put on a server. None of those is a failure — the
/// application has always worked with none of them.
///
/// Rows this device has changed and not sent are held rather than overwritten,
/// which [FamilyPull] decides and this only passes on.
Future<void> pullFamily(ProviderContainer container, String familyId) async {
  try {
    if (!isSignedIn) return;

    // A family this device never sent up has nothing on the server to ask
    // about, and asking would spend a request to be told so.
    final shared = container.read(sharedFamiliesProvider).valueOrNull;
    if (shared == null || !shared.contains(familyId)) return;

    final pull = container.read(familyPullProvider);
    final changes = await container
        .read(changeSourceProvider)
        .since(familyId, await pull.lastSeen(familyId));

    final result = await pull.apply(familyId, changes);
    if (result.applied > 0 || result.merged > 0) {
      container.invalidate(familySnapshotProvider(familyId));
    }
    if (result.conflicted.isNotEmpty) {
      container.invalidate(conflictCountProvider(familyId));
    }
    if (result.familyChanged) {
      // The list reads the repository, not the snapshot, so a rename arriving
      // from another device reached every screen that draws from
      // [familySnapshotProvider] and none that draws from here — the family
      // called one thing inside and another in the list of families.
      container.invalidate(familyListProvider);
    }
    if (result.familyDeleted) {
      // The owner deleted it for everybody (ROADMAP M9, step 4). The list is
      // the only place that would still be showing it, and it reads the
      // repository rather than this result, so it has to be told.
      container.invalidate(familyListProvider);
      container.invalidate(sharedFamiliesProvider);
    }
  } catch (_) {
    // Offline, signed out, or a cloud never opened. The copy on the device is
    // what it was, which is the whole point of holding one.
  }
}

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
