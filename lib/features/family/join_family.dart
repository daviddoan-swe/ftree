/// Joining a family somebody invited you to (PRODUCT.md §5.1).
///
/// The other end of Mời. Somebody was sent a code through Zalo or a message,
/// and this is where it turns into a gia phả on their phone.
///
/// ## The code comes first, the account second
///
/// Accepting needs an account — the server writes the membership against
/// `auth.uid()`, and there is nobody to write otherwise. But asking for the
/// account first would mean signing somebody up before they have shown they
/// have anything to join, so the code is typed first and the sign-in screen
/// appears as the step that finishes the job.
///
/// The code cannot be checked before the account exists either way: `anon`
/// holds no EXECUTE on `accept_invitation`, deliberately.
///
/// ## What arriving actually means, and what it does not
///
/// The family is **downloaded once**, here, into this device's SQLite. It is
/// not synchronisation: afterwards the two copies drift, and nothing either
/// side changes reaches the other until M9. Being invited today buys the gia
/// phả and a membership waiting for the day synchronising exists.
///
/// It comes in through the same add-only merge a file does, and that is not
/// tidiness. Somebody may have been sent the exported file first, imported it,
/// and added their own branch before the invitation arrived. The file and the
/// server hold the same family id, so a straight overwrite would land on top
/// of their work and take it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../data/cloud/family_invitations.dart';
import '../../data/cloud/supabase_family_repository.dart';
import '../../data/database/family_roles.dart';
import '../../data/transfer/family_file.dart';
import '../../domain/family_repository.dart';
import '../../l10n/app_localizations.dart';
import '../account/sign_in.dart';
import 'import_family.dart';

/// What joining needs from outside the device.
abstract interface class JoiningCloud {
  Future<bool> signIn(BuildContext context);

  /// Redeems the code and answers which family it opened.
  Future<String> accept(String code);

  /// Reads the family whole, now that there is a membership to read it with.
  Future<FamilySnapshot?> download(String familyId);

  /// What the invitation just granted.
  ///
  /// Asked rather than returned by `accept_invitation`, which answers with the
  /// family and nothing else. One more request, against a function that
  /// already exists, in exchange for leaving a working signature alone.
  Future<String?> roleIn(String familyId);
}

final class LiveJoiningCloud implements JoiningCloud {
  const LiveJoiningCloud();

  @override
  Future<bool> signIn(BuildContext context) => ensureSignedIn(context);

  @override
  Future<String> accept(String code) =>
      FamilyInvitations(Supabase.instance.client).accept(code);

  @override
  Future<FamilySnapshot?> download(String familyId) =>
      SupabaseFamilyRepository(Supabase.instance.client).loadFamily(familyId);

  @override
  Future<String?> roleIn(String familyId) async => await Supabase
      .instance
      .client
      .rpc<String?>('my_role', params: <String, Object?>{'target': familyId});
}

/// Overridden in tests. Nothing else overrides it.
final joiningCloudProvider = Provider<JoiningCloud>(
  (ref) => const LiveJoiningCloud(),
);

/// Opens the code box.
Future<void> joinFamilyWithCode(BuildContext context, WidgetRef ref) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const JoinFamilyScreen()),
    );

/// One field and one button.
class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final TextEditingController _code = TextEditingController();

  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// The server's refusals in words somebody can act on.
  ///
  /// Every one of these is a sentence the person can do something with, which
  /// is why they are not collapsed into "that did not work". *Already used* in
  /// particular is the one that matters: it is how the owner finds out that
  /// somebody reached the code first.
  String _messageFor(AppText text, Object error) =>
      switch (invitationRefusal(error)) {
        InvitationRefusal.notFound => text.inviteNotFound,
        InvitationRefusal.alreadyUsed => text.inviteAlreadyUsed,
        InvitationRefusal.revoked => text.inviteWasRevoked,
        InvitationRefusal.expired => text.inviteHasExpired,
        InvitationRefusal.needsAnAccount => text.inviteNotFound,
        null => text.accountRefused('$error'),
      };

  Future<void> _join() async {
    final text = AppText.of(context);

    if (_code.text.trim().isEmpty) {
      setState(() => _problem = text.inviteCodeMissing);
      return;
    }

    final cloud = ref.read(joiningCloudProvider);
    if (!await cloud.signIn(context)) return;
    if (!mounted) return;

    setState(() {
      _busy = true;
      _problem = null;
    });

    final String familyId;
    final FamilySnapshot? snapshot;
    final String? role;
    try {
      // Whatever was pasted: the phone's Copy button hands over the whole
      // message, and so does a forwarded one.
      familyId = await cloud.accept(invitationCodeIn(_code.text));
      snapshot = await cloud.download(familyId);
      role = await cloud.roleIn(familyId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = _messageFor(text, error);
      });
      return;
    }

    if (!mounted) return;
    if (snapshot == null) {
      // Accepted, and nothing came back. Not worth inventing a sentence for:
      // the membership exists, so trying again will work.
      setState(() {
        _busy = false;
        _problem = text.accountRefused('');
      });
      return;
    }

    // Through the same path a file takes: preview, add-only merge, write.
    final plan = await bringInFamily(
      context,
      ref,
      FamilyFile(
        family: snapshot.family,
        persons: snapshot.graph.persons.toList(),
        relationships: snapshot.graph.relationships.toList(),
      ),
    );

    if (plan == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    // The family is on the server and this account can see it, so the mark
    // belongs here too — otherwise the list would offer Chia sẻ on a family
    // that is already shared (PRODUCT §4.2).
    await ref.read(sharingMarksProvider).markShared(familyId);

    // What this copy arrived as, so the interface offers only what it allows,
    // and can do so with no network afterwards (PRODUCT §5.0).
    final granted = FamilyRole.from(role);
    if (granted != null) {
      await ref.read(familyRolesProvider).remember(familyId, granted);
    }

    ref
      ..invalidate(sharedFamiliesProvider)
      ..invalidate(familyRoleMapProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);
    final problem = _problem;

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(text.inviteEnterTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            text.inviteEnterWhy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: GroupedColors.secondaryLabel(context),
            ),
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _code,
            enabled: !_busy,
            autocorrect: false,
            // Codes are drawn from an alphabet with no lower case in it, and
            // the server folds what arrives anyway. This only saves the reader
            // a shift key.
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _join(),
            decoration: InputDecoration(
              labelText: text.inviteEnterLabel,
              border: const OutlineInputBorder(),
            ),
          ),

          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                problem,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: GroupedColors.red,
                ),
              ),
            ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: _busy ? null : _join,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(text.inviteEnterAction),
          ),
        ],
      ),
    );
  }
}
