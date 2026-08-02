/// Showing a genealogical date to a reader.
library;

import 'package:flutter/widgets.dart';

import '../../domain/genealogical_date.dart';
import '../../domain/lunar/lunar_date_entry.dart';
import '../../l10n/app_localizations.dart';

/// The Gregorian date as text, at the precision it is actually known to.
///
/// ISO-prefix form rather than a locale-formatted date: `1887` has to read as a
/// year, not as a January the record never claimed (DOMAIN.md §4.2). A
/// formatter given a partial date would have to invent the missing parts.
String formatDate(BuildContext context, GenealogicalDate? date) {
  if (date == null) return AppText.of(context).dateUnknown;
  final iso = date.toIso();
  return date.isApproximate
      ? '${AppText.of(context).dateApproximatePrefix} $iso'
      : iso;
}

/// The lunar reading to show beside it, or null when there is none.
///
/// Only shown for a family that keeps the lunar calendar — the setting travels
/// with the tree, so a relative reading in another language still sees it
/// (DOMAIN.md §4.4).
String? formatLunar(
  BuildContext context,
  GenealogicalDate? date, {
  required bool usesLunarCalendar,
}) {
  if (date == null || !usesLunarCalendar) return null;

  final lunar = lunarReadingOf(date);
  if (lunar == null) return null;

  final parts = StringBuffer(lunar.year.toString());
  if (lunar.month != null) {
    parts.write('-${lunar.month.toString().padLeft(2, '0')}');
    if (lunar.isLeapMonth) parts.write('N');
    if (lunar.day != null) {
      parts.write('-${lunar.day.toString().padLeft(2, '0')}');
    }
  }
  return '$parts ${AppText.of(context).dateLunarSuffix}';
}
