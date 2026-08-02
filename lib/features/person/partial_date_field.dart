/// Entering a date that may be only partly known.
///
/// Three separate boxes rather than a date picker. A picker forces a complete
/// date, and forcing one is exactly how a year-only record becomes an invented
/// 1 January — the loss DOMAIN.md §4.2 exists to prevent. Leaving month and day
/// empty has to be as easy as filling them in.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/genealogical_date.dart';
import '../../domain/lunar/lunar_date_entry.dart';
import '../../l10n/app_localizations.dart';

/// A date the user is part way through typing.
///
/// [date] is null while the boxes are empty *or* while they describe something
/// impossible; [error] tells the two apart.
typedef PartialDateChanged = void Function(GenealogicalDate? date, bool valid);

class PartialDateField extends StatefulWidget {
  const PartialDateField({
    required this.label,
    required this.onChanged,
    this.initial,
    this.allowLunar = false,
    super.key,
  });

  /// What this date is — born, died.
  final String label;

  /// Called whenever the boxes change.
  final PartialDateChanged onChanged;

  /// The date to start from, when editing.
  final GenealogicalDate? initial;

  /// Whether to offer lunar entry. Follows the family, not the reader
  /// (DOMAIN.md §4.4).
  final bool allowLunar;

  @override
  State<PartialDateField> createState() => _PartialDateFieldState();
}

class _PartialDateFieldState extends State<PartialDateField> {
  late final TextEditingController _year;
  late final TextEditingController _month;
  late final TextEditingController _day;

  bool _approximate = false;
  bool _leapMonth = false;
  bool _lunarEntry = false;

  String? _error;
  GenealogicalDate? _result;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _year = TextEditingController(text: initial?.year.toString() ?? '');
    _month = TextEditingController(text: initial?.month?.toString() ?? '');
    _day = TextEditingController(text: initial?.day?.toString() ?? '');
    _approximate = initial?.isApproximate ?? false;
    _result = initial;
  }

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    super.dispose();
  }

  int? _read(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  void _recompute() {
    final text = AppText.of(context);
    final year = _read(_year);
    final month = _read(_month);
    final day = _read(_day);

    // Nothing typed at all is a perfectly good answer: most people in an old
    // record have no dates.
    if (year == null && month == null && day == null) {
      _publish(null, null);
      return;
    }
    if (year == null) {
      _publish(null, text.dateNeedsYear);
      return;
    }
    if (day != null && month == null) {
      _publish(null, text.dateNeedsMonth);
      return;
    }

    try {
      final date = _lunarEntry
          ? gregorianFromLunarEntry(
              LunarDate(
                year: year,
                month: month,
                day: day,
                isLeapMonth: _leapMonth && month != null,
              ),
              isApproximate: _approximate,
            )
          : GenealogicalDate(
              year: year,
              month: month,
              day: day,
              isApproximate: _approximate,
            );
      _publish(date, null);
    } on ArgumentError {
      // 31 April, 29 February in a common year, a month of 13. Impossible
      // rather than merely incomplete, so it is refused (§4.1).
      _publish(null, text.dateImpossible);
    }
  }

  void _publish(GenealogicalDate? date, String? error) {
    setState(() {
      _result = date;
      _error = error;
    });
    widget.onChanged(date, error == null);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppText.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(widget.label, style: theme.textTheme.titleSmall),
            const Spacer(),
            if (widget.allowLunar)
              SegmentedButton<bool>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(text.dateCalendarGregorian),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(text.dateCalendarLunar),
                  ),
                ],
                selected: <bool>{_lunarEntry},
                onSelectionChanged: (selection) {
                  _lunarEntry = selection.first;
                  _recompute();
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 3, child: _box(_year, text.dateYear, 4)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _box(_month, text.dateMonth, 2)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _box(_day, text.dateDay, 2)),
          ],
        ),
        Row(
          children: <Widget>[
            _toggle(
              label: text.dateApproximate,
              value: _approximate,
              onChanged: (value) {
                _approximate = value;
                _recompute();
              },
            ),
            if (_lunarEntry)
              _toggle(
                label: text.dateLeapMonth,
                value: _leapMonth,
                onChanged: (value) {
                  _leapMonth = value;
                  _recompute();
                },
              ),
          ],
        ),
        if (_error != null)
          Text(
            _error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else if (_lunarEntry && _result != null)
          // Show what will actually be stored, so a conversion is never a
          // surprise after the fact.
          Text(
            text.dateLunarStored(_result!.toIso()),
            style: theme.textTheme.bodySmall,
          )
        else
          Text(text.dateYearOnlyIsFine, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _box(TextEditingController controller, String label, int maxLength) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          counterText: '',
        ),
        onChanged: (_) => _recompute(),
      );

  Widget _toggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Checkbox(
        visualDensity: VisualDensity.compact,
        value: value,
        onChanged: (v) => onChanged(v ?? false),
      ),
      Text(label),
      const SizedBox(width: 8),
    ],
  );
}
