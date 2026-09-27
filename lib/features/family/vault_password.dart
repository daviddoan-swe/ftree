/// Asking for the password a backup is sealed with (PRODUCT.md §9.2).
///
/// Two shapes of the same screen, because the two moments are not the same.
///
/// **Setting one** asks twice. A typo here cannot be found out later: there is
/// nothing to check the password against, and the file it seals is the only
/// copy of a hundred years of transcription. Typing it a second time is the
/// only check there is.
///
/// **Entering one** asks once. The file itself is the check — right opens it,
/// wrong says so — and asking for a sixteen-character passphrase twice every
/// time somebody opens a backup buys nothing the file does not already give.
///
/// ## The sentence that decides whether any of this works
///
/// Setting a password says, in plain words, to send it by another route. A
/// password pasted into the same Zalo message as the file protects nothing at
/// all, and that is what most people will do unless the screen says otherwise.
/// It is the one line here that is not about cryptography and the one that
/// decides whether the cryptography matters.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/grouped_list.dart';
import '../../data/transfer/family_vault.dart';
import '../../l10n/app_localizations.dart';

/// Runs the slow half off the interface thread.
///
/// `compute` in the application: Argon2id has no native path on either
/// platform and costs about a second on a development machine, several on a
/// phone. On the interface thread that is the application frozen, with no
/// frame drawn to say it is working.
///
/// A variable rather than a direct call because a widget test cannot use it.
/// `compute` starts a second isolate, and a test's clock is fake, so the
/// result never arrives — the test hangs for its full timeout and reports
/// three minutes of nothing instead of a red line. Tests put the work inline.
Future<R> Function<M, R>(ComputeCallback<M, R> work, M message) runOffThread =
    compute;

/// Runs [work] behind a message, so the wait is a wait and not a freeze.
///
/// Argon2id costs about a second on a development machine and several on a
/// phone. [runOffThread] keeps the interface drawing during it, which is the
/// difference between an application that is busy and one that has hung — but
/// a screen that draws and does nothing looks exactly like a missed tap. This
/// says which it is.
///
/// Not dismissible. There is nothing to cancel: the work is in another
/// isolate and stopping it half way would leave the file half written.
Future<T> whileWorking<T>(
  BuildContext context,
  String message,
  Future<T> Function() work,
) async {
  final navigator = Navigator.of(context);
  var showing = true;

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await work();
  } finally {
    // In a finally, because the work throwing is exactly when a dialog left
    // standing would trap somebody on a screen with no way out.
    if (showing) {
      showing = false;
      navigator.pop();
    }
  }
}

/// Asks for a new password, twice. Null if the reader backed out.
Future<String?> askForNewPassword(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _VaultPasswordScreen(confirming: true),
      ),
    );

/// Asks for the password a sealed file was made with. Null if they backed out.
Future<String?> askForPassword(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const _VaultPasswordScreen(confirming: false),
      ),
    );

class _VaultPasswordScreen extends StatefulWidget {
  const _VaultPasswordScreen({required this.confirming});

  final bool confirming;

  @override
  State<_VaultPasswordScreen> createState() => _VaultPasswordScreenState();
}

class _VaultPasswordScreenState extends State<_VaultPasswordScreen> {
  final TextEditingController _first = TextEditingController();
  final TextEditingController _again = TextEditingController();
  String? _problem;
  bool _hidden = true;

  @override
  void dispose() {
    _first.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    final text = AppText.of(context);
    final typed = _first.text;

    // Length before the second field is even looked at. Telling somebody the
    // two match and *then* that it is too short makes them type it twice for
    // nothing.
    if (widget.confirming && typed.length < minimumVaultPassword) {
      setState(() => _problem = text.vaultTooShort(minimumVaultPassword));
      return;
    }
    if (widget.confirming && typed != _again.text) {
      setState(() => _problem = text.vaultMismatch);
      return;
    }
    if (typed.isEmpty) {
      setState(() => _problem = text.vaultTooShort(minimumVaultPassword));
      return;
    }

    Navigator.of(context).pop(typed);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final setting = widget.confirming;

    return Scaffold(
      backgroundColor: GroupedColors.page(context),
      appBar: AppBar(
        leading: circleBackButton(context),
        title: Text(setting ? text.vaultSetTitle : text.vaultOpenTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              setting ? text.vaultSetWhy : text.vaultOpenWhy,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GroupedColors.secondaryLabel(context),
              ),
            ),
          ),

          GroupedSection(
            children: <Widget>[
              _field(
                controller: _first,
                label: text.vaultSetLabel,
                autofocus: true,
                onSubmitted: setting ? null : (_) => _submit(),
              ),
              if (setting)
                _field(
                  controller: _again,
                  label: text.vaultSetAgain,
                  onSubmitted: (_) => _submit(),
                ),
            ],
          ),

          if (_problem case final said?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                said,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: GroupedColors.red),
              ),
            ),

          // Said where the password is being made, not in a note somewhere
          // afterwards. Nothing else on this screen matters if it goes in the
          // same message as the file.
          if (setting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: GroupedColors.secondaryLabel(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text.vaultSendApart,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: GroupedColors.secondaryLabel(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(setting ? text.vaultSetAction : text.vaultOpenAction),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    ValueChanged<String>? onSubmitted,
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    child: TextField(
      controller: controller,
      obscureText: _hidden,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      onChanged: (_) {
        if (_problem != null) setState(() => _problem = null);
      },
      // Off, all of it. A passphrase is not a sentence, and a keyboard that
      // capitalises it or corrects a word into another word makes a password
      // somebody cannot type the same way twice.
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
            _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
    ),
  );
}
