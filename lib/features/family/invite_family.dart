/// Who is in a family, and who has been asked (PRODUCT.md §5.1).
///
/// Reached from **Mời**, which stands where Chia sẻ stood before the family
/// went up. Once a family is shared, the thing left to do to it is let
/// somebody else in — and, when that turns out to have been a mistake, put
/// them out again.
///
/// ## Two lists, on purpose
///
/// Members first, invitations under them. The order is the question somebody
/// opens this screen to answer: *who can read my gia phả?* An invitation that
/// nobody has used yet is a smaller fact than a person who is already in.
///
/// ## There is no approval step, and this screen is why
///
/// Entering a valid code lets somebody straight in (§5.1). The owner already
/// decided twice — when they made the code, and when they chose who to send it
/// to — and a third decision taken later, against an address they may never
/// have seen, would be a gate clicked through rather than a gate.
///
/// What replaces it is here: the owner can see every member and remove any of
/// them. A door that opens and cannot close would be worse than a slow lock,
/// so the remove button is not a nicety on this screen. It is the other half
/// of the decision.
library;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../data/cloud/cloud_session.dart';
import '../../data/cloud/family_invitations.dart';
import '../../domain/family.dart';
import '../../l10n/app_localizations.dart';
import '../account/sign_in.dart';

/// Everything this screen needs from outside the device.
///
/// Behind a provider rather than constructed here, for the same reason
/// `SharingCloud` is: nothing may touch `Supabase.instance` before
/// `openCloud()` has run, and that happens inside [signIn].
abstract interface class FamilyCircle {
  Future<bool> signIn(BuildContext context);

  /// The signed-in account, so the list can say which row is you.
  String? get meId;

  /// What the signed-in account may do here, or null if it may do nothing.
  ///
  /// Asked separately rather than worked out from the member list, because an
  /// empty list has two meanings — not the owner, or nothing loaded — and a
  /// screen that cannot tell them apart shows the wrong thing for one of them.
  Future<String?> myRoleIn(String familyId);

  Future<List<Member>> members(String familyId);
  Future<void> changeRole({
    required String familyId,
    required String userId,
    required String role,
  });
  Future<void> remove({required String familyId, required String userId});

  Future<List<Invitation>> invitations(String familyId);
  Future<Invitation> invite({required String familyId, required String role});
  Future<void> revoke(String invitationId);
}

final class LiveFamilyCircle implements FamilyCircle {
  const LiveFamilyCircle();

  @override
  Future<bool> signIn(BuildContext context) => ensureSignedIn(context);

  @override
  String? get meId => signedInUserId;

  @override
  Future<String?> myRoleIn(String familyId) async => await Supabase
      .instance
      .client
      .rpc<String?>('my_role', params: <String, Object?>{'target': familyId});

  @override
  Future<List<Member>> members(String familyId) => _api.members(familyId);

  @override
  Future<void> changeRole({
    required String familyId,
    required String userId,
    required String role,
  }) => _api.changeRole(familyId: familyId, userId: userId, role: role);

  @override
  Future<void> remove({required String familyId, required String userId}) =>
      _api.remove(familyId: familyId, userId: userId);

  @override
  Future<List<Invitation>> invitations(String familyId) =>
      _api.forFamily(familyId);

  @override
  Future<Invitation> invite({required String familyId, required String role}) =>
      _api.create(familyId: familyId, role: role);

  @override
  Future<void> revoke(String invitationId) => _api.revoke(invitationId);

  FamilyInvitations get _api => FamilyInvitations(Supabase.instance.client);
}

/// Overridden in tests. Nothing else overrides it.
final familyCircleProvider = Provider<FamilyCircle>(
  (ref) => const LiveFamilyCircle(),
);

/// Opens the screen, signing in first if this device is not.
Future<void> showFamilyCircle(
  BuildContext context,
  WidgetRef ref,
  Family family,
) async {
  if (!await ref.read(familyCircleProvider).signIn(context)) return;
  if (!context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => InvitationsScreen(family: family)),
  );
}

/// The members of one family and the invitations standing against it.
class InvitationsScreen extends ConsumerStatefulWidget {
  const InvitationsScreen({required this.family, super.key});

  final Family family;

  @override
  ConsumerState<InvitationsScreen> createState() => _InvitationsScreenState();
}

class _InvitationsScreenState extends ConsumerState<InvitationsScreen> {
  String? _myRole;
  List<Member> _members = const <Member>[];
  List<Invitation> _invitations = const <Invitation>[];

  /// The plaintext this device still holds, by invitation id. Absent for one
  /// issued from another phone, or from this one before it was reinstalled.
  Map<String, String> _codes = const <String, String>{};

  bool _loading = true;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final circle = ref.read(familyCircleProvider);
    final store = ref.read(invitationCodeStoreProvider);

    try {
      final role = await circle.myRoleIn(widget.family.id);

      // Nothing below this is readable by anybody else, so nothing below it is
      // asked for. An editor opening this screen sends one request, not four.
      final members = role == 'owner'
          ? await circle.members(widget.family.id)
          : const <Member>[];
      final invitations = role == 'owner'
          ? await circle.invitations(widget.family.id)
          : const <Invitation>[];
      final codes = await store.forFamily(widget.family.id);
      if (!mounted) return;

      setState(() {
        _myRole = role;
        _members = members;
        _invitations = invitations;
        _codes = codes;
        _loading = false;
        _problem = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _problem = AppText.of(context).accountRefused('$error');
      });
    }
  }

  /// The role names, in one place so the list and the picker agree.
  String _roleName(AppText text, String role) => switch (role) {
    'owner' => text.roleOwner,
    'editor' => text.roleEditor,
    _ => text.roleViewer,
  };

  Future<void> _invite() async {
    final text = AppText.of(context);
    final role = await _pickRole(context, text);
    if (role == null || !mounted) return;

    // Only this one asks. An owner can delete the family and can make further
    // owners, and there is no walking either back (§5.1).
    if (role == 'owner') {
      final agreed = await confirmIrreversible(
        context,
        title: text.inviteOwnerWarningTitle,
        body: text.inviteOwnerWarningBody,
        confirmLabel: text.inviteAction,
      );
      if (!agreed || !mounted) return;
    }

    final String code;
    try {
      final invitation = await ref
          .read(familyCircleProvider)
          .invite(familyId: widget.family.id, role: role);
      code = invitation.code!;

      // Kept before anything else is done with it. The code exists in exactly
      // one other place — the message about to be sent — and a message is easy
      // to close by accident.
      await ref
          .read(invitationCodeStoreProvider)
          .remember(
            id: invitation.id,
            familyId: widget.family.id,
            code: invitation.code!,
          );

      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _problem = AppText.of(context).accountRefused('$error'));
      return;
    }

    // Sent outside the try on purpose. By here the invitation exists and is
    // listed; a share sheet that refuses to open is a different failure, and
    // reporting it as "could not invite" would send somebody to make a second
    // invitation they do not need. The Gửi button on the row is the retry.
    if (mounted) await _send(code);
  }

  /// Hands the code to whatever the phone uses to send messages.
  ///
  /// A failure here says so and leaves the invitation standing, because it is
  /// standing: the row keeps its Gửi button and pressing it tries again.
  Future<void> _send(String code) async {
    final text = AppText.of(context);

    try {
      await SharePlus.instance.share(
        ShareParams(text: text.inviteMessage(widget.family.name, code)),
      );
    } catch (error) {
      if (mounted) setState(() => _problem = text.accountRefused('$error'));
    }
  }

  Future<void> _revoke(Invitation invitation) async {
    final text = AppText.of(context);

    final agreed = await confirmIrreversible(
      context,
      title: text.inviteRevokeTitle,
      body: text.inviteRevokeBody,
      confirmLabel: text.inviteRevoke,
    );
    if (!agreed || !mounted) return;

    await ref.read(familyCircleProvider).revoke(invitation.id);

    // A revoked code is dead on the server, so a readable copy would only
    // offer a Gửi button that sends something nobody can redeem.
    await ref.read(invitationCodeStoreProvider).forget(invitation.id);
    await _load();
  }

  /// Offers the three roles and applies the one chosen.
  ///
  /// The same sheet an invitation uses, so promoting somebody already here and
  /// inviting somebody at that role read as one idea rather than two.
  Future<void> _changeRole(Member member) async {
    final text = AppText.of(context);
    final role = await _pickRole(context, text);
    if (role == null || role == member.role || !mounted) return;

    if (role == 'owner') {
      final agreed = await confirmIrreversible(
        context,
        title: text.inviteOwnerWarningTitle,
        body: text.inviteOwnerWarningBody,
        confirmLabel: text.memberChangeRole,
      );
      if (!agreed || !mounted) return;
    }

    try {
      await ref
          .read(familyCircleProvider)
          .changeRole(
            familyId: widget.family.id,
            userId: member.userId,
            role: role,
          );
      await _load();
    } catch (error) {
      if (!mounted) return;
      // `keep_an_owner` refusing to let the last owner be demoted is the one
      // failure here that deserves its own sentence.
      setState(() => _problem = text.memberRemoveLastOwner);
    }
  }

  Future<void> _remove(Member member) async {
    final text = AppText.of(context);

    final agreed = await confirmIrreversible(
      context,
      title: text.memberRemoveTitle,
      body: text.memberRemoveBody,
      confirmLabel: text.memberRemove,
    );
    if (!agreed || !mounted) return;

    try {
      await ref
          .read(familyCircleProvider)
          .remove(familyId: widget.family.id, userId: member.userId);
      await _load();
    } catch (error) {
      if (!mounted) return;
      // The one refusal worth its own sentence: the trigger that keeps a
      // family from having nobody to manage it.
      setState(() => _problem = text.memberRemoveLastOwner);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);
    final circle = ref.read(familyCircleProvider);
    final me = circle.meId;
    final iAmOwner = _myRole == 'owner';
    final problem = _problem;

    return Scaffold(
      backgroundColor: GroupedColors.page(context),
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(widget.family.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SlidableAutoCloseBehavior(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: <Widget>[
                  if (problem != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(
                        problem,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: GroupedColors.red,
                        ),
                      ),
                    ),

                  if (!iAmOwner)
                    GroupedSection(
                      footer: text.membersOwnerOnly,
                      children: <Widget>[
                        GroupedRow(
                          icon: Icons.lock_outline,
                          title: text.membersTitle,
                          value: _myRole == null
                              ? ''
                              : _roleName(text, _myRole!),
                          showChevron: false,
                        ),
                      ],
                    ),

                  if (iAmOwner) ...<Widget>[
                    GroupedSection(
                      header: text.membersTitle,
                      children: <Widget>[
                        for (final member in _members)
                          _memberRow(text, member, me),
                      ],
                    ),

                    const SizedBox(height: 24),

                    GroupedSection(
                      header: text.inviteTitle,
                      footer: _invitations.isEmpty ? text.inviteNone : null,
                      children: <Widget>[
                        for (final invitation in _invitations)
                          _invitationRow(text, invitation),
                        GroupedRow(
                          icon: Icons.person_add_alt,
                          iconColor: GroupedColors.primary(context),
                          title: text.inviteNew,
                          showChevron: false,
                          onTap: _invite,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// One member: what they are called, how to reach them, and what they may
  /// do — and nothing to press.
  ///
  /// The actions are behind a swipe, as they are on the family list, because a
  /// row is for reading. Demoting somebody or putting them out are not things
  /// to leave under a thumb while scrolling a list of relatives.
  Widget _memberRow(AppText text, Member member, String? me) {
    final isMe = member.userId == me;
    final colors = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey<String>(member.userId),
      // Yourself is not somebody you manage here. Demoting or removing your own
      // account is leaving a family, which is a different act from running one,
      // and this screen is reached by whoever runs it.
      enabled: !isMe,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => _changeRole(member),
            icon: Icons.edit_outlined,
            label: text.actionEdit,
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
          ),
          SlidableAction(
            onPressed: (_) => _remove(member),
            icon: Icons.delete_outline,
            label: text.actionDelete,
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
          ),
        ],
      ),
      child: GroupedRow(
        icon: Icons.person_outline,
        iconColor: member.role == 'owner'
            ? GroupedColors.primary(context)
            : GroupedColors.grey,
        // The name is the title, the address the line under it. An account made
        // before names were asked for has none, and says so rather than wearing
        // its address as one.
        title: isMe
            ? '${member.name ?? text.memberNoName} (${text.membersYou})'
            : (member.name ?? text.memberNoName),
        subtitle: member.email,
        value: _roleName(text, member.role),
        showChevron: false,
      ),
    );
  }

  Widget _invitationRow(AppText text, Invitation invitation) {
    final now = DateTime.now().toUtc();
    final code = _codes[invitation.id];
    final live = invitation.isLiveAt(now);

    // The end states are read in the order the server decides them, so a
    // revoked invitation that has also expired reads the same in both places.
    final state = invitation.isAccepted
        ? text.inviteUsed
        : invitation.isRevoked
        ? text.inviteRevoked
        : invitation.isExpiredAt(now)
        ? text.inviteExpired
        : text.inviteExpiresIn(invitation.expiresAt.difference(now).inDays);

    return GroupedRow(
      icon: Icons.mail_outline,
      iconColor: live ? GroupedColors.teal : GroupedColors.grey,
      // A code this device no longer holds is still listed: it is still
      // standing, and still worth revoking. There is simply nothing to send.
      title: live
          ? (code ?? text.inviteNoCode)
          : _roleName(text, invitation.role),
      subtitle: live ? '${_roleName(text, invitation.role)} · $state' : state,
      showChevron: false,
      trailing: live
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (code != null)
                  TextButton(
                    onPressed: () => _send(code),
                    child: Text(text.inviteSend),
                  ),
                TextButton(
                  onPressed: () => _revoke(invitation),
                  child: Text(text.inviteRevoke),
                ),
              ],
            )
          : null,
    );
  }
}

/// Asks which role the invitation is for.
Future<String?> _pickRole(BuildContext context, AppText text) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Viewer first, owner last: the list runs from the smallest thing
            // somebody can be given to the largest, so the heaviest choice is
            // never the one under a thumb by accident.
            for (final role in <String>['viewer', 'editor', 'owner'])
              ListTile(
                title: Text(switch (role) {
                  'owner' => text.roleOwner,
                  'editor' => text.roleEditor,
                  _ => text.roleViewer,
                }),
                onTap: () => Navigator.of(sheetContext).pop(role),
              ),
          ],
        ),
      ),
    );
