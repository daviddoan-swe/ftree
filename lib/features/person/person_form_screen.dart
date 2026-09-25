/// Adding and editing a person.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/issue_text.dart';
import '../../app/providers.dart';
import '../../app/validation_prompts.dart';
import '../../domain/family_name.dart';
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
  required String familyName,
  required bool usesLunarCalendar,
  Person? editing,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => PersonFormScreen(
      familyId: familyId,
      familyName: familyName,
      usesLunarCalendar: usesLunarCalendar,
      editing: editing,
    ),
  ),
);

class PersonFormScreen extends ConsumerStatefulWidget {
  const PersonFormScreen({
    required this.familyId,
    required this.familyName,
    required this.usesLunarCalendar,
    this.editing,
    super.key,
  });

  final String familyId;

  /// What the family is called, for the surname a new person starts with.
  ///
  /// Passed in rather than looked up, the same as [usesLunarCalendar] and for
  /// the same reason: it is a property of the family, and both callers are
  /// already holding it.
  final String familyName;

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

  /// Each date box reports its own validity. One shared flag let a good death
  /// date unblock a nonsense birth date, because whichever changed last won.
  bool _birthUsable = true;
  bool _deathUsable = true;

  /// Whether this person has died, as far as the form is concerned.
  ///
  /// It reveals the death fields; it is not stored. Off means "no death
  /// information recorded", which is what an empty death date has always
  /// meant — **not** "this person is living". Nothing in the schema can say
  /// that yet (ARCHITECTURE §11.1), so the switch must not be read as saying
  /// it either.
  bool _hasDied = false;

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

    if (person == null) {
      // A new person in Họ Nguyễn is a Nguyễn far more often than not, and
      // typing it again for the thirtieth relative is the kind of work a
      // family record should not ask for. It is a starting value, not a rule:
      // somebody who married in changes it, and `birthFamilyName` is there for
      // what they changed it from.
      //
      // Only when adding. On an edit the field must show what is stored, even
      // where what is stored is nothing.
      _fields['familyName']!.text = familySurname(widget.familyName);
    }

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
      _hasDied = person.deathDate != null || person.deathPlace != null;
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
    // Switched off means nothing about a death is being recorded, so nothing
    // about a death is written — including anything typed before it was
    // switched off.
    deathDate: _hasDied ? _death : null,
    birthPlace: _optional('birthPlace'),
    deathPlace: _hasDied ? _optional('deathPlace') : null,
    biography: _optional('biography'),
  );

  Future<void> _save() async {
    if (!_birthUsable) return;
    if (_hasDied && !_deathUsable) return;

    final person = _buildPerson();

    // Saying somebody died has to be backed by something the record can hold:
    // a date, a place, or both. The domain derives death from those fields, so
    // an empty claim would simply vanish on save and the switch would be off
    // again next time it was opened.
    final result = person.validate().merge(
      _hasDied && !person.hasDied
          ? ValidationResult.single(
              ValidationIssue(
                IssueCode.deceasedWithoutDetail,
                involvedIds: <String>[person.id],
              ),
            )
          : const ValidationResult.ok(),
    );

    // Errors block. Warnings are the user's to overrule: genealogical records
    // contain entries that are implausible but genuine, and refusing them makes
    // the application useless on real documents (DOMAIN.md §9).
    if (result.hasErrors) {
      setState(() => _result = result);
      return;
    }
    if (result.hasIssues && !await confirmWarnings(context, result)) {
      setState(() => _result = result);
      return;
    }

    await ref
        .read(familySnapshotProvider(widget.familyId).notifier)
        .savePerson(person);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? text.personAdd : text.personEdit),
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
          _text(
            'displayName',
            text.personDisplayName,
            hint: text.personDisplayNameHint,
            autofocus: true,
          ),
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

          // Headed on its own line, like the sections above it. The heading
          // used to sit inside the field, sharing a row with the controls that
          // qualify the date — which left those controls no edge of their own.
          _heading(text.personBirth),
          PartialDateField(
            initial: _birth,
            allowLunar: widget.usesLunarCalendar,
            onChanged: (date, valid) {
              _birth = date;
              _birthUsable = valid;
            },
          ),
          const SizedBox(height: 8),
          _text('birthPlace', text.personBirthPlace),
          const SizedBox(height: 20),

          // One title for the whole group, on the row that reveals it. Most
          // people in a gia phả are dead, but most *records* carry no death
          // date — so the fields start folded away and the form is short.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hasDied,
            onChanged: (value) => setState(() => _hasDied = value),
            title: Text(
              text.personDeath,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            curve: Curves.easeOut,
            child: _hasDied
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      PartialDateField(
                        initial: _death,
                        allowLunar: widget.usesLunarCalendar,
                        onChanged: (date, valid) {
                          _death = date;
                          _deathUsable = valid;
                        },
                      ),
                      const SizedBox(height: 8),
                      _text('deathPlace', text.personDeathPlace),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
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
