/// Creating an account, and signing into one (ROADMAP M8, PRODUCT §4.1).
///
/// The first screen in the application that knows accounts exist. Everything
/// before it works with no account and no network, and that is not an accident
/// to be tidied away later: most people will only ever want that, so a wall
/// here would be a wall in front of the whole application.
///
/// ## It is not reachable yet
///
/// Nothing pushes this. The Chia sẻ action that will is the next step, and the
/// same arrangement as `SupabaseFamilyRepository` in M7: built and held to
/// tests first, wired second, so that a screen and an action are not being
/// debugged at the same time.
///
/// ## Email and a password, decided
///
/// Weighed against phone numbers, email codes and the nineteen OAuth
/// providers. Phone numbers lost to Decree 91/2020 — sending an OTP to a
/// Vietnamese number needs a brandname registered with Viettel, Vinaphone or
/// MobiFone, which a private family application has no way to obtain. Of what
/// remained, email and a password is the only one that depends on **nobody**:
/// no carrier, no Google, no Facebook. With two to five people ever needing an
/// account (§4.1), "has to remember a password" is a small price for that.
///
/// Adding a provider later breaks nothing: `auth.uid()` is the same value
/// whatever the person signed in with, so every policy, membership and trigger
/// underneath is untouched by the choice.
///
/// ## Why the attempt is a parameter
///
/// Not for tests, although tests use it. Signing up can **succeed without
/// producing a session**: where the server is set to confirm addresses, the
/// account is created and there is no token until a link is followed. So the
/// question "did that work" and the question "are we signed in" have different
/// answers, and the boolean is that distinction rather than a seam invented to
/// make something mockable.
///
/// It is also the only way to reach that path at all. The local stack runs with
/// `enable_confirmations = false`, so no live server available here produces
/// it, and the path that cannot be exercised is the one that will be met first
/// in production.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../app/grouped_list.dart';
import '../../data/cloud/cloud_session.dart';
import '../../l10n/app_localizations.dart';

/// Makes sure there is a session, asking for one if there is not.
///
/// True when signed in by the time it returns. False when the reader backed
/// out, which is an ordinary answer and not a failure.
Future<bool> ensureSignedIn(BuildContext context) async {
  // Opened here rather than at start-up, deliberately. `Supabase.initialize`
  // restores a stored session and may refresh its token, and a gia phả opens
  // on a train: paying for that on every cold start would buy nothing for the
  // majority who never sign in at all.
  await openCloud();
  if (isSignedIn) return true;

  if (!context.mounted) return false;
  final signedIn = await Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => const SignInScreen()));

  // Backing out pops null, and null is not a session.
  return signedIn ?? false;
}

/// Creates an account or enters one, and answers whether a session exists now.
typedef AccountAttempt =
    Future<bool> Function({
      required bool creating,
      required String email,
      required String password,
      required String name,
    });

/// The real one: the cloud session, and its own idea of whether we are in.
Future<bool> attemptWithCloud({
  required bool creating,
  required String email,
  required String password,
  required String name,
}) async {
  if (creating) {
    await signUp(email: email, password: password, name: name);
  } else {
    await signIn(email: email, password: password);
  }

  return isSignedIn;
}

/// Two fields and one button, in one of two moods.
class SignInScreen extends StatefulWidget {
  const SignInScreen({this.attempt = attemptWithCloud, super.key});

  final AccountAttempt attempt;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  /// Creating rather than entering, and the opening mood on purpose. Somebody
  /// who has arrived here from Chia sẻ has no account far more often than not;
  /// somebody who does have one knows the word for it and can switch.
  bool _creating = true;

  /// A request is in flight. Holds the button, so one tap is one account.
  bool _busy = false;

  /// What went wrong, in the reader's language, or null.
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// What is wrong before anybody is asked.
  ///
  /// Kept to what is certainly wrong. The length rule applies **only when
  /// creating**: an account made when the minimum was lower still has the
  /// password it has, and refusing to send it would lock its owner out over a
  /// rule that was never theirs.
  String? _localProblem(AppText text) {
    // Asked for only when creating, and required rather than optional: the
    // member list is how an owner decides who may change a gia phả, and a list
    // of addresses is a poor thing to decide from (PRODUCT §5.6).
    if (_creating && _name.text.trim().isEmpty) return text.accountNameMissing;

    final email = _email.text.trim();
    if (email.isEmpty) return text.accountEmailMissing;
    if (!_looksLikeEmail(email)) return text.accountEmailInvalid;

    if (_password.text.isEmpty) return text.accountPasswordMissing;
    if (_creating && _password.text.length < minimumPasswordLength) {
      return text.accountPasswordShort(minimumPasswordLength);
    }

    return null;
  }

  Future<void> _submit() async {
    final text = AppText.of(context);

    final local = _localProblem(text);
    if (local != null) {
      setState(() => _problem = local);
      return;
    }

    setState(() {
      _busy = true;
      _problem = null;
    });

    try {
      final signedIn = await widget.attempt(
        creating: _creating,
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
      );
      if (!mounted) return;

      if (signedIn) {
        Navigator.of(context).pop(true);
        return;
      }

      // Created, and no session: the server wants the address confirmed first.
      // Left on this screen, switched to signing in, because that is the next
      // thing to do once the link has been followed.
      setState(() {
        _busy = false;
        _creating = false;
        _problem = text.accountConfirmEmail;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = _messageFor(text, error);
      });
    }
  }

  /// The server's refusals in words somebody can act on.
  ///
  /// Matched on `code` rather than on `message`: the codes are part of the auth
  /// API, the sentences are English prose that can be reworded at any time.
  /// Every code below was read off the running server rather than taken from
  /// documentation.
  ///
  /// `invalid_credentials` covers a wrong password **and** an address with no
  /// account — one code for both, which is the server declining to say whether
  /// somebody is registered. The wording keeps that: naming the password as the
  /// wrong one would leak exactly what the server took care not to.
  String _messageFor(AppText text, Object error) {
    if (error is AuthException) {
      return switch (error.code) {
        'invalid_credentials' => text.accountWrongCredentials,
        'user_already_exists' || 'email_exists' => text.accountEmailTaken,
        'weak_password' => text.accountPasswordShort(minimumPasswordLength),
        // Anything else in the server's own words. They may be English, and
        // that is still worth more than silence — the same judgement as
        // `showImportFailure`: somebody who sees nothing has nothing to report.
        _ => text.accountRefused(error.message),
      };
    }

    // No network, a dead host, a certificate. Not an AuthException, and not
    // worth guessing between.
    return text.accountRefused('$error');
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);
    final problem = _problem;

    return Scaffold(
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(text.accountTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SegmentedButton<bool>(
            segments: <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text(text.accountCreate)),
              ButtonSegment<bool>(
                value: false,
                label: Text(text.accountSignIn),
              ),
            ],
            selected: <bool>{_creating},
            onSelectionChanged: _busy
                ? null
                : (Set<bool> chosen) => setState(() {
                    _creating = chosen.first;
                    // The old complaint belonged to the old mood.
                    _problem = null;
                  }),
          ),

          const SizedBox(height: 16),

          // Said on the screen, not only in the documentation. Somebody met
          // with a sign-in box assumes the application now needs one (§4.1).
          Text(
            text.accountWhy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: GroupedColors.secondaryLabel(context),
            ),
          ),

          const SizedBox(height: 24),

          if (_creating) ...<Widget>[
            TextField(
              controller: _name,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              decoration: InputDecoration(
                labelText: text.accountName,
                helperText: text.accountNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: text.accountEmail,
              border: const OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: text.accountPassword,
              // The rule, where it applies. Stated up front rather than after
              // a refusal.
              helperText: _creating
                  ? text.accountPasswordHint(minimumPasswordLength)
                  : null,
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
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_creating ? text.accountCreate : text.accountSignIn),
          ),
        ],
      ),
    );
  }
}

/// Whether [value] is shaped like an email address.
///
/// Deliberately loose. An address is valid if the server says so — it answers
/// `validation_failed` when it disagrees — and a stricter rule here would
/// refuse real addresses to save a round trip. This catches the typo, not the
/// edge case.
bool _looksLikeEmail(String value) {
  if (value.contains(' ')) return false;

  final at = value.indexOf('@');
  if (at <= 0 || at != value.lastIndexOf('@')) return false;

  final domain = value.substring(at + 1);
  return domain.contains('.') &&
      !domain.startsWith('.') &&
      !domain.endsWith('.');
}
