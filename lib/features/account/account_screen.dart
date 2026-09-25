/// The account this device is signed in to, and the way out of it
/// (PRODUCT.md §5.9).
///
/// Reached from a button that appears only while signed in. Most people never
/// sign in at all (§4.1), and a permanent account button would be advertising
/// an account to people who have no use for one — as well as offering to
/// manage something that is not there.
///
/// ## Signing out takes the local marks with it
///
/// Two facts on this device belong to the account that is leaving, not to the
/// device:
///
/// * `sharedAt` — *this device sent that family up*
/// * the invitation codes — *this account issued these*
///
/// Left behind, the first would lie to whoever signs in next, and the second
/// would hand them somebody else's live codes. So both go.
///
/// Clearing them is safe because it heals itself. A family with no mark offers
/// Chia sẻ again; pressing it asks the server, which answers that the family
/// is claimed — and then, if this is still the same account, that we can see
/// it, which is case 2 of §4.3: the mark is *recovered* and nothing is sent.
/// Signed in as somebody else, the same press is told plainly that another
/// account holds it, which is the truth.
///
/// What is genuinely lost is the codes. An invitation still standing cannot be
/// sent from here again, and the confirmation says so rather than letting
/// somebody discover it later.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../app/confirm.dart';
import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../data/cloud/cloud_session.dart' as cloud;
import '../../l10n/app_localizations.dart';

/// What this screen needs from outside the device.
abstract interface class AccountSession {
  String? get email;
  String? get name;
  Future<void> signOut();
}

final class LiveAccountSession implements AccountSession {
  const LiveAccountSession();

  @override
  String? get email => Supabase.instance.client.auth.currentUser?.email;

  /// The name carried in the account's own metadata, set when it was created.
  @override
  String? get name {
    final value =
        Supabase.instance.client.auth.currentUser?.userMetadata?['name'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  @override
  Future<void> signOut() => cloud.signOut();
}

/// Overridden in tests. Nothing else overrides it.
final accountSessionProvider = Provider<AccountSession>(
  (ref) => const LiveAccountSession(),
);

/// Opens it.
Future<void> showAccount(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const AccountScreen()));

/// Who you are here, and how to stop being them.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    final text = AppText.of(context);

    final agreed = await confirmIrreversible(
      context,
      title: text.accountSignOutTitle,
      body: text.accountSignOutBody,
      confirmLabel: text.accountSignOut,
    );
    if (!agreed || !mounted) return;

    setState(() => _busy = true);

    await ref.read(accountSessionProvider).signOut();

    // The order matters only in that the session goes first: a mark cleared
    // while still signed in would be recovered by the very next press.
    await ref.read(sharingMarksProvider).forgetAll();
    await ref.read(invitationCodeStoreProvider).forgetEverything();

    // Only the family list is invalidated by hand. Whether anybody is signed
    // in is a stream now, and it hears about this from the auth client itself
    // — which is what makes signing back in show the button again.
    ref.invalidate(sharedFamiliesProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final session = ref.read(accountSessionProvider);

    return Scaffold(
      backgroundColor: GroupedColors.page(context),
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(text.accountTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          GroupedSection(
            children: <Widget>[
              GroupedRow(
                icon: Icons.person_outline,
                iconColor: GroupedColors.primary(context),
                title: text.accountName,
                value: session.name ?? text.memberNoName,
                showChevron: false,
              ),
              GroupedRow(
                icon: Icons.alternate_email,
                title: text.accountEmail,
                value: session.email ?? '',
                showChevron: false,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Centred, in the application's own language for an action that
          // undoes something — the same shape as Delete this person on a
          // profile. A grouped row would read as a setting to inspect; this
          // reads as a thing to do, which is what it is.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: GroupedColors.red),
              icon: const Icon(Icons.logout),
              label: Text(text.accountSignOut),
              onPressed: _busy ? null : _signOut,
            ),
          ),

          const SizedBox(height: 8),

          // Said here as well as in the confirmation. Somebody deciding
          // whether to press it should not have to press it to find out.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text.accountSignOutBody,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: GroupedColors.secondaryLabel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
