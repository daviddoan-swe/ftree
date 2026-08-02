/// Adding and editing a person.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/issue_text.dart';
import '../../app/providers.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/ids.dart';
import '../../domain/person.dart';
import '../../domain/validation.dart';
import '../../l10n/app_localizations.dart';
import 'partial_date_field.dart';

/// Opens the form, either empty or on an existing person.
Future<void> showPersonForm(
  BuildContext context, {
  required String familyId,
  required bool usesLunarCalendar,
  Person? editing,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PersonFormScreen(
      familyId: familyId,
      usesLunarCalendar: usesLunarCalendar,
      editing: editing,
    ),
  ),
);

class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({
    required this.familyId,
    required this.usesLunarCalendar,
    this.editing,
    super.key,
  });

  final String familyId;

  /// Whether to offer lunar date entry. A property of the family, not of the
  /// reader (DOMAIN.md §4.4).
  final bool usesLunarCalendar;

  /// The person being edited, or null when adding.
  final Person? editing;

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  late final Map<String, TextEditingController> _fields;

  Sex _sex = Sex.unknown;
  GenealogicalDate? _birth;
  GenealogicalDate? _death;
  bool _datesUsable = true;
  ValidationResult _result = const ValidationResult.ok();

  @override
  void initState() {
    super.initState();
    final person = widget.editing;
    _fields = <String, TextEditingController>{
      for (final name in <String>[
        'displayName',
        'givenName',
        'additionalNames',
        'familyName',
        'birthFamilyName',
        'birthPlace',
        'deathPlace',
        'biography',
      ])
        name: TextEditingController(),
    };

    if (person != null) {
      _fields['displayName']!.text = person.displayName;
      _fields['givenName']!.text = person.givenName ?? '';
      _fields['additionalNames']!.text = person.additionalNames ?? '';
      _fields['familyName']!.text = person.familyName ?? '';
      _fields['birthFamilyName']!.text = person.birthFamilyName ?? '';
      _fields['birthPlace']!.text = person.birthPlace ?? '';
      _fields['deathPlace']!.text = person.deathPlace ?? '';
      _fields['biography']!.text = person.biography ?? '';
      _sex = person.sex;
      _birth = person.birthDate;
      _death = person.deathDate;
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(String name) {
    final value = _fields[name]!.text.trim();
    return value.isEmpty ? null : value;
  }

  Person _buildPerson() => Person(
    id: widget.editing?.id ?? newId(),
    familyId: widget.familyId,
    displayName: _fields['displayName']!.text.trim(),
    givenName: _optional('givenName'),
    additionalNames: _optional('additionalNames'),
    familyName: _optional('familyName'),
    birthFamilyName: _optional('birthFamilyName'),
    sex: _sex,
    birthDate: _birth,
    deathDate: _death,
    birthPlace: _optional('birthPlace'),
    deathPlace: _optional('deathPlace'),
    biography: _optional('biography'),
  );

  Future<void> _save() async {
    if (!_datesUsable) return;

    final person = _buildPerson();
    final result = person.validate();

    // Errors block. Warnings are the user's to overrule: genealogical records
    // contain entries that are implausible but genuine, and refusing them makes
    // the application useless on real documents (DOMAIN.md §9).
    if (result.hasErrors) {
      setState(() => _result = result);
      return;
    }
    if (result.hasIssues && !await _confirmWarnings(result)) {
      setState(() => _result = result);
      return;
    }

    await ref
        .read(familySnapshotProvider(widget.familyId).notifier)
        .savePerson(person);
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmWarnings(ValidationResult result) async {
    final text = AppText.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.validationCheckBeforeSaving),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (final issue in result.warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${issueText(dialogContext, issue.code)}'),
              ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing == null ? text.personAdd : text.personEdit,
        ),
        actions: <Widget>[
          TextButton(onPressed: _save, child: Text(text.actionSave)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // At the top, not the bottom: on a form this long, a message below
          // the fold is a message nobody reads.
          if (_result.hasIssues) ...<Widget>[
            _IssueBanner(result: _result),
            const SizedBox(height: 16),
          ],
          _text('displayName', text.personDisplayName,
              hint: text.personDisplayNameHint, autofocus: true),
          const SizedBox(height: 20),

          _heading(text.personNameParts),
          _text('givenName', text.personGivenName),
          const SizedBox(height: 8),
          _text('additionalNames', text.personAdditionalNames),
          const SizedBox(height: 8),
          _text('familyName', text.personFamilyName),
          const SizedBox(height: 8),
          _text('birthFamilyName', text.personBirthFamilyName),
          const SizedBox(height: 20),

          _heading(text.personSex),
          SegmentedButton<Sex>(
            segments: <ButtonSegment<Sex>>[
              ButtonSegment<Sex>(value: Sex.male, label: Text(text.sexMale)),
              ButtonSegment<Sex>(
                value: Sex.female,
                label: Text(text.sexFemale),
              ),
              ButtonSegment<Sex>(
                value: Sex.unknown,
                label: Text(text.sexUnknown),
              ),
            ],
            selected: <Sex>{_sex},
            onSelectionChanged: (selection) =>
                setState(() => _sex = selection.first),
          ),
          const SizedBox(height: 20),

          PartialDateField(
            label: text.personBirth,
            initial: _birth,
            allowLunar: widget.usesLunarCalendar,
            onChanged: (date, valid) {
              _birth = date;
              _datesUsable = valid;
            },
          ),
          const SizedBox(height: 8),
          _text('birthPlace', text.personBirthPlace),
          const SizedBox(height: 20),

          PartialDateField(
            label: text.personDeath,
            initial: _death,
            allowLunar: widget.usesLunarCalendar,
            onChanged: (date, valid) {
              _death = date;
              _datesUsable = valid;
            },
          ),
          const SizedBox(height: 8),
          _text('deathPlace', text.personDeathPlace),
          const SizedBox(height: 20),

          _text('biography', text.personBiography, lines: 4),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _heading(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _text(
    String name,
    String label, {
    String? hint,
    bool autofocus = false,
    int lines = 1,
  }) => TextField(
    controller: _fields[name],
    autofocus: autofocus,
    maxLines: lines,
    textCapitalization: TextCapitalization.words,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    onChanged: (_) {
      if (_result.hasIssues) {
        setState(() => _result = const ValidationResult.ok());
      }
    },
  );
}

/// What is wrong, and whether it blocks saving.
class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.result});

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
            Text('• ${issueText(context, issue.code)}'),
        ],
      ),
    );
  }
}
