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
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, Supabase;

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
import '../data/database/sync_marks.dart';
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

/// When each family was last brought level with the server (ROADMAP M9,
/// step 5).
final syncMarksProvider = Provider<SyncMarks>(
  (ref) => SyncMarks(ref.watch(databaseProvider)),
);

/// When [familyId] was last brought level, or null if it never has been.
final syncedAtProvider = FutureProvider.family<DateTime?, String>(
  (ref, familyId) => ref.watch(syncMarksProvider).forFamily(familyId),
);

/// How many rows in [familyId] are still waiting to go up.
final waitingProvider = FutureProvider.family<int, String>(
  (ref, familyId) => ref.watch(familyPushProvider).waiting(familyId),
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
/// Whether this device holds a session, asked through the provider graph.
///
/// The same answer as the global [isSignedIn], reachable by a test. The
/// global reads `Supabase.instance`, which throws in a process that never
/// called `openCloud` — so a guard written on it short-circuits, and every
/// test of the code behind that guard passes whether the code is right or
/// wrong. Three things fixed in one day had no test for that reason.
///
/// It is **not** a network call. `currentUser` is restored from the device's
/// own storage when Supabase starts, so this answers offline exactly as it
/// answers on: it says "there is a session here", never "the server agrees".
abstract interface class CloudSession {
  bool get isSignedIn;
}

final class LiveCloudSession implements CloudSession {
  const LiveCloudSession();

  @override
  bool get isSignedIn {
    try {
      return signedInUserId != null;
    } catch (_) {
      // No cloud was ever opened. Not signed in is the honest reading.
      return false;
    }
  }
}

final cloudSessionProvider = Provider<CloudSession>(
  (ref) => const LiveCloudSession(),
);

/// Where this account's roles are read from.
///
/// Its own provider for the same reason as [CloudSession]: `_refreshRoles`
/// reached straight for `Supabase.instance`, so nothing could answer for it
/// in a test and the demotion path it exists for had no cover at all.
///
/// Declared here rather than reusing `FamilyCircle`, which is the same idea
/// one layer up: `lib/features` depends on `lib/app`, and importing it back
/// the other way would turn that dependency into a circle (ARCHITECTURE §3).
abstract interface class RolesSource {
  /// Every family this account is in, by id, with the role it holds there.
  Future<Map<String, String>> myRoles();
}

final class CloudRoles implements RolesSource {
  const CloudRoles();

  @override
  Future<Map<String, String>> myRoles() =>
      FamilyInvitations(Supabase.instance.client).myRoles();
}

final rolesSourceProvider = Provider<RolesSource>((ref) => const CloudRoles());

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
    _refreshRoles(roles, const CloudRoles(), const LiveCloudSession()).then((
      changed,
    ) {
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
  final source = container.read(rolesSourceProvider);
  final session = container.read(cloudSessionProvider);

  if (await _refreshRoles(roles, source, session)) {
    container.invalidate(familyRoleMapProvider);
  }
  return roles.all();
}

/// Asks the server what this account may do, and writes it down.
///
/// Every failure is silence: no session, no network, a cloud never opened at
/// all in a test process. That is deliberate and it is the important part —
/// "the server named nothing" and "the server could not be reached" look
/// identical from here, and one of them would mark every family removed.
Future<bool> _refreshRoles(
  FamilyRoles roles,
  RolesSource source,
  CloudSession session,
) async {
  try {
    if (!session.isSignedIn) return false;

    final named = await source.myRoles();

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
/// What became of a synchronisation.
///
/// Reported rather than swallowed, because until now every failure looked
/// exactly like a success: the whole of `syncFamily` sat in one `catch (_)`,
/// so pulling the gia phả down while offline spun a wheel, stopped, and said
/// nothing. A wheel that stops means "it finished", not "it worked".
///
/// The catch itself was never carelessness and is not being removed. "The
/// server could not be reached" and "the server says you may do nothing" must
/// never be confused: read the second into the first and every family on a
/// phone that went into a lift is marked removed. What changes is that the two
/// are now told apart and named.
enum SyncTrouble {
  /// The server was not reachable at all.
  offline,

  /// It answered, and refused. A viewer's writes, or an editor's in a family
  /// they have been put out of.
  refused,
}

final class SyncResult {
  const SyncResult({
    this.broughtDown = 0,
    this.sentUp = 0,
    this.conflicted = 0,
    this.waiting = 0,
    this.reached = false,
    this.trouble,
  });

  /// Nothing was attempted: not signed in, or a family never shared. Not a
  /// failure — there was no server in the picture to begin with.
  static const SyncResult idle = SyncResult();

  final int broughtDown;
  final int sentUp;
  final int conflicted;

  /// Rows still carrying work this device has not managed to send.
  final int waiting;

  /// Whether the server was actually spoken to.
  ///
  /// False for [idle], and the distinction is load-bearing: no trouble is not
  /// the same as success. A family nobody ever shared returns no trouble
  /// because nothing was attempted, and counting that as a synchronisation
  /// made the status line say "a moment ago" about a server it had never
  /// touched.
  final bool reached;

  final SyncTrouble? trouble;

  bool get isQuiet =>
      trouble == null && broughtDown == 0 && sentUp == 0 && conflicted == 0;
}

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
Future<SyncResult> syncFamily(
  ProviderContainer container,
  String familyId,
) async {
  final down = await pullFamily(container, familyId);
  final up = await pushFamily(container, familyId);

  final trouble = down.trouble ?? up.trouble;
  var waiting = 0;

  // Everything past here runs after two round trips, and the scope this reads
  // from may be gone by then: leaving a family starts a synchronisation and
  // then takes the screen down. In the application the container belongs to
  // the root and outlives it; under a test the whole tree goes at once, and
  // reading a disposed container throws.
  //
  // What is lost by catching is the note and the count, and neither is worth
  // an error on the way out. The two halves above have already done their
  // work, and the flags they left are what the next visit reads.
  try {
    waiting = await container.read(familyPushProvider).waiting(familyId);

    // Only where it actually worked. "Three hours ago" has to mean the last
    // time the server was reached, or the line says something untrue at the
    // one moment somebody is reading it to find out whether to worry.
    if (trouble == null && down.reached) {
      await container.read(syncMarksProvider).mark(familyId);
      container.invalidate(syncedAtProvider(familyId));
    }

    // Whether it worked or not: a failed send leaves more waiting, and that
    // number is the whole of what the line has to say when it did not.
    container.invalidate(waitingProvider(familyId));
  } catch (_) {
    // The scope has gone. Nothing above it needed doing twice.
  }

  return SyncResult(
    broughtDown: down.broughtDown,
    sentUp: up.sentUp,
    conflicted: down.conflicted,
    waiting: waiting,
    reached: down.reached || up.reached,
    trouble: trouble,
  );
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
Future<SyncResult> pushFamily(
  ProviderContainer container,
  String familyId,
) async {
  try {
    if (!container.read(cloudSessionProvider).isSignedIn) {
      return SyncResult.idle;
    }

    final shared = container.read(sharedFamiliesProvider).valueOrNull;
    if (shared == null || !shared.contains(familyId)) return SyncResult.idle;

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
      if (outgoing.isEmpty) return SyncResult.idle;

      final held = await container
          .read(changeSinkProvider)
          .send(familyId, outgoing);
      await push.markSent(held);

      // Fewer back than went is the silent refusal this whole read-back
      // exists to catch: an UPDATE a policy forbids changes nothing and
      // reports success. Named here so somebody can be told, rather than left
      // to wonder why the number waiting never goes down.
      return SyncResult(
        sentUp: held.length,
        reached: true,
        trouble: held.length < outgoing.ids.length ? SyncTrouble.refused : null,
      );
    }

    // A viewer, or somebody put out of the family. Nothing was attempted, so
    // nothing was refused.
    return SyncResult.idle;
  } on PostgrestException catch (_) {
    // The server answered, and said no.
    return const SyncResult(trouble: SyncTrouble.refused);
  } catch (_) {
    // It could not be reached at all. What was waiting is still waiting,
    // which is what the flag is for.
    return const SyncResult(trouble: SyncTrouble.offline);
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
Future<SyncResult> pullFamily(
  ProviderContainer container,
  String familyId,
) async {
  try {
    if (!container.read(cloudSessionProvider).isSignedIn) {
      return SyncResult.idle;
    }

    // A family this device never sent up has nothing on the server to ask
    // about, and asking would spend a request to be told so.
    final shared = container.read(sharedFamiliesProvider).valueOrNull;
    if (shared == null || !shared.contains(familyId)) return SyncResult.idle;

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

    return SyncResult(
      broughtDown: result.applied + result.merged,
      conflicted: result.conflicted.length,
      reached: true,
    );
  } on PostgrestException catch (_) {
    // It answered and refused: a family this account is no longer in.
    return const SyncResult(trouble: SyncTrouble.refused);
  } catch (_) {
    // It could not be reached. The copy on the device is what it was, which
    // is the whole point of holding one.
    return const SyncResult(trouble: SyncTrouble.offline);
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
