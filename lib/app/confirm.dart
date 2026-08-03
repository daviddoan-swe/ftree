/// Asking before something is destroyed.
///
/// Two prompts, because the friction should be proportional to the damage.
/// Removing one relationship or one person is a dialog. Deleting a whole family
/// — years of transcription, with no undo anywhere in the application — asks
/// for the name to be typed.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Asks whether to go ahead. False if the user declines or dismisses.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final text = AppText.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(text.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// The same, but the confirming button stays disabled until [expected] has been
/// typed back exactly.
///
/// Compared after trimming the ends, and otherwise exactly: a Vietnamese family
/// name differing only in its diacritics is a different family name.
Future<bool> confirmByTyping(
  BuildContext context, {
  required String title,
  required String body,
  required String expected,
  required String fieldLabel,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => _TypeToConfirm(
      title: title,
      body: body,
      expected: expected,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
    ),
  );
  return confirmed ?? false;
}

class _TypeToConfirm extends StatefulWidget {
  const _TypeToConfirm({
    required this.title,
    required this.body,
    required this.expected,
    required this.fieldLabel,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String expected;
  final String fieldLabel;
  final String confirmLabel;

  @override
  State<_TypeToConfirm> createState() => _TypeToConfirmState();
}

class _TypeToConfirmState extends State<_TypeToConfirm> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _matches => _typed.text.trim() == widget.expected.trim();

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.body),
          const SizedBox(height: 16),
          TextField(
            controller: _typed,
            autofocus: true,
            decoration: InputDecoration(
              labelText: widget.fieldLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(text.actionCancel),
        ),
        FilledButton(
          // Disabled, not merely warned against: the point is that the name
          // cannot be typed by accident.
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
