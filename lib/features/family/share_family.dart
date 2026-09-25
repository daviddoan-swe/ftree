/// Sending one family to the cloud (ROADMAP M8, PRODUCT §4.2, §4.3).
///
/// The act an account exists for. Everything before it works with nobody signed
/// in; this is the one button that needs one, and it needs one because a record
/// kept by more than one person needs to know who those people are.
///
/// ## One family, and only the one
///
/// [shareFamily] sends the family it is given. Every other family on the device
/// is untouched and stays unknown to the server, including afterwards (§4.2).
/// Signing in is not a statement about everything on the device.
///
/// ## Offered once, and why that matters
///
/// The list offers this only for a family with no mark. A member pressing it a
/// second time would take the update branch of `save_family_all`, which upserts
/// the people and the edges too — putting this device's copy on top of the
/// shared one. That is "my copy wins", the conflict resolution that cannot be
/// done without an ordering nobody has yet (§15.3). Once a family is shared,
/// the action on it is to invite somebody.
///
/// ## Three things can be true when the button is pressed
///
/// Worked out by asking the server rather than by trusting the local mark,
/// because the mark records what *this device* did and a file puts the same
/// family, keeping the same id, onto somebody else's device (§4.3).
///
/// 1. **Nobody has it.** It goes up, and whoever pressed becomes the owner.
/// 2. **We have it, and this device forgot.** The mark was lost — a reinstall,
///    a restore from an exported file. The family is already ours, so the mark
///    is *recovered* rather than the family re-sent, and the button stops being
///    offered. Nothing is written, so nothing lands on top of the shared copy.
/// 3. **Somebody else has it.** They pressed first, and there is no fairer rule
///    available: a file carries no proof of who made it (§4.3). Said plainly,
///    with the way in — an invitation from them.
///
/// Cases 2 and 3 are told apart by whether this account can *see* the family.
/// A family somebody else owns is absent rather than forbidden, so being able
/// to read it is exactly the same question as being a member of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../app/confirm.dart';
import '../../app/providers.dart';
import '../../data/cloud/family_claims.dart';
import '../../data/cloud/supabase_family_repository.dart';
import '../../data/database/family_roles.dart';
import '../../domain/family.dart';
import '../../domain/family_repository.dart';
import '../../l10n/app_localizations.dart';
import '../account/sign_in.dart';

/// Everything sharing needs from outside the device.
///
/// One thing rather than four loose calls, and behind a provider rather than
/// behind parameters, because of *when* it can be built: none of it may touch
/// `Supabase.instance` until `openCloud()` has run, and `openCloud()` runs
/// inside [SharingCloud.signIn]. A field initialised when the screen is built
/// would throw on a device that has never signed in — which is every device,
/// the first time.
///
/// It lives in the presentation layer on purpose. Composing a sign-in screen
/// with a cloud repository is a presentation job, and only here is a
/// [BuildContext] an ordinary thing to hold.
abstract interface class SharingCloud {
  /// Makes sure there is a session. False if the reader backed out.
  Future<bool> signIn(BuildContext context);

  /// Whether any account already holds this family's id.
  Future<bool> isClaimed(String familyId);

  /// Whether *this* account can read it, which is whether it is a member.
  Future<bool> canSee(String familyId);

  /// Sends the family, its people and their relationships, together.
  Future<void> send(FamilySnapshot snapshot);
}

/// The real one.
final class LiveSharingCloud implements SharingCloud {
  const LiveSharingCloud();

  @override
  Future<bool> signIn(BuildContext context) => ensureSignedIn(context);

  @override
  Future<bool> isClaimed(String familyId) =>
      FamilyClaims(Supabase.instance.client).isClaimed(familyId);

  @override
  Future<bool> canSee(String familyId) async =>
      await _repository.loadFamily(familyId) != null;

  @override
  Future<void> send(FamilySnapshot snapshot) => _repository.saveAll(
    family: snapshot.family,
    persons: snapshot.graph.persons,
    relationships: snapshot.graph.relationships,
  );

  SupabaseFamilyRepository get _repository =>
      SupabaseFamilyRepository(Supabase.instance.client);
}

/// Overridden in tests. Nothing else overrides it.
final sharingCloudProvider = Provider<SharingCloud>(
  (ref) => const LiveSharingCloud(),
);

/// Sends [family] to the cloud, asking first. True only if it went up.
///
/// False covers every other ending, and none of them is an error: the reader
/// declined, backed out of signing in, or the family was up there already.
Future<bool> shareFamily(
  BuildContext context,
  WidgetRef ref,
  Family family,
) async {
  final text = AppText.of(context);

  // Read whole from the device first. There is nothing to ask about sending a
  // family that is not here, and the send wants all of it in one call anyway.
  final snapshot = await ref
      .read(familyRepositoryProvider)
      .loadFamily(family.id);
  if (snapshot == null || !context.mounted) return false;

  // Asked before anything at all, including before signing in. Sending a
  // family out of the device cannot be undone (§10), and neither can creating
  // an account somebody did not want.
  final agreed = await confirmIrreversible(
    context,
    title: text.shareConfirmTitle,
    body: text.shareConfirmBody,
    confirmLabel: text.shareAction,
  );
  if (!agreed || !context.mounted) return false;

  final cloud = ref.read(sharingCloudProvider);
  if (!await cloud.signIn(context)) return false;

  try {
    if (await cloud.isClaimed(family.id)) {
      final mine = await cloud.canSee(family.id);

      if (mine) {
        // Ours already, and this device had forgotten. Recover the mark; send
        // nothing. Sending would put this copy on top of the shared one.
        await _remember(ref, family.id);
        if (context.mounted) {
          _say(context, text.shareAlreadyShared(family.name));
        }
      } else if (context.mounted) {
        _say(context, text.shareClaimedByOther);
      }

      return false;
    }

    await cloud.send(snapshot);
  } catch (error) {
    // Asking and sending are two requests, so two devices can fall between
    // them. The server names that case, and it is the same news as case 3
    // above rather than a fault worth showing raw.
    if (context.mounted) {
      await showShareFailure(
        context,
        FamilyClaims.wasAlreadyClaimed(error)
            ? text.shareClaimedByOther
            : text.accountRefused('$error'),
      );
    }
    return false;
  }

  // Marked after the send, never before: a mark written first would survive a
  // failure and hide the button that would have tried again.
  await _remember(ref, family.id);

  // Whoever creates a family on the server owns it — `owner_on_create` reads
  // the token of whoever inserted — so this device may do anything with this
  // copy (PRODUCT §5.0).
  await ref.read(familyRolesProvider).remember(family.id, FamilyRole.owner);
  ref.invalidate(familyRoleMapProvider);
  if (context.mounted) _say(context, text.shareDone(family.name));

  return true;
}

/// Writes the mark and makes the list notice.
Future<void> _remember(WidgetRef ref, String familyId) async {
  await ref.read(sharingMarksProvider).markShared(familyId);
  ref.invalidate(sharedFamiliesProvider);
}

/// One message at a time, and it names its family.
///
/// Cleared rather than queued: sharing several families in a row otherwise
/// leaves each announcement waiting behind the last, so they arrive after the
/// act they belong to and read as though every family were announcing itself
/// at once. The newest is the one somebody is looking for.
void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Tells the reader why sharing stopped.
///
/// A dialog rather than a snack bar, and for the same reason an import failure
/// gets one: this is the end of something somebody chose to do, and a message
/// that slides away on its own is a message they may never have read.
Future<void> showShareFailure(BuildContext context, String reason) {
  final text = AppText.of(context);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.shareFailed),
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
