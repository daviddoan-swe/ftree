/// Putting validation issues in front of the user (DOMAIN.md §9).
///
/// Two prompts, because there are two severities and they mean different
/// things. An error is the application refusing; a warning is the application
/// asking. Both live here so that every screen refuses and asks the same way.
library;

import 'package:flutter/material.dart';

import '../domain/validation.dart';
import '../l10n/app_localizations.dart';
import 'issue_text.dart';

/// Asks whether to proceed despite [result]'s warnings.
///
/// Returns false if the user declines or dismisses the dialog. Warnings are the
/// user's to overrule: genealogical records contain entries that are
/// implausible but genuine, and refusing them makes the application useless on
/// real documents.
Future<bool> confirmWarnings(
  BuildContext context,
  ValidationResult result,
) async {
  final text = AppText.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.validationCheckBeforeSaving),
      content: _IssueList(issues: result.warnings),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(text.actionReview),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(text.actionSaveAnyway),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Reports [result]'s errors. There is nothing to decide: they block.
Future<void> showBlockingIssues(
  BuildContext context,
  ValidationResult result,
) {
  final text = AppText.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(text.validationCannotSave),
      content: _IssueList(issues: result.errors),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(text.actionClose),
        ),
      ],
    ),
  );
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});

  final Iterable<ValidationIssue> issues;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      for (final issue in issues)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('• ${issueText(context, issue.code)}'),
        ),
    ],
  );
}
