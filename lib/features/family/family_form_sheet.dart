/// Creating a family.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/issue_text.dart';
import '../../app/providers.dart';
import '../../domain/family.dart';
import '../../domain/ids.dart';
import '../../domain/validation.dart';
import '../../l10n/app_localizations.dart';

/// Opens the sheet for creating a family.
Future<void> showFamilyFormSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => const Padding(
    padding: EdgeInsets.all(16),
    child: _FamilyFormSheet(),
  ),
);

class _FamilyFormSheet extends ConsumerStatefulWidget {
  const _FamilyFormSheet();

  @override
  ConsumerState<_FamilyFormSheet> createState() => _FamilyFormSheetState();
}

class _FamilyFormSheetState extends ConsumerState<_FamilyFormSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _usesLunarCalendar = false;
  ValidationResult _result = const ValidationResult.ok();

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Family _buildFamily() => Family(
    id: newId(),
    name: _name.text.trim(),
    description: _description.text.trim().isEmpty
        ? null
        : _description.text.trim(),
    usesLunarCalendar: _usesLunarCalendar,
  );

  Future<void> _save() async {
    final family = _buildFamily();
    final result = family.validate();

    // Errors block; warnings do not. A family has no warnings today, but the
    // shape is the same everywhere so the rule stays visible (DOMAIN.md §9).
    if (result.hasErrors) {
      setState(() => _result = result);
      return;
    }

    await ref.read(familyListProvider.notifier).save(family);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            text.familyCreate,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: text.familyName,
              hintText: text.familyNameHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_result.hasIssues) {
                setState(() => _result = const ValidationResult.ok());
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: InputDecoration(
              labelText: text.familyDescription,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _usesLunarCalendar,
            onChanged: (value) =>
                setState(() => _usesLunarCalendar = value),
            title: Text(text.familyUsesLunarCalendar),
            subtitle: Text(text.familyUsesLunarCalendarHint),
          ),
          if (_result.hasIssues) ...<Widget>[
            const SizedBox(height: 8),
            _IssueList(result: _result),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(text.actionCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _save,
                child: Text(text.actionSave),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Shows what is wrong, distinguishing what blocks from what merely warns.
class _IssueList extends StatelessWidget {
  const _IssueList({required this.result});

  final ValidationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = AppText.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: result.hasErrors
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            result.hasErrors
                ? text.validationCannotSave
                : text.validationCheckBeforeSaving,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          for (final issue in result.issues)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${issueText(context, issue.code)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
