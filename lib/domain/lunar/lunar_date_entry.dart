/// Turning a lunar date somebody typed into the Gregorian date that gets
/// stored (DOMAIN.md §4.4).
///
/// The Gregorian value is mandatory and the lunar one is an annotation on it,
/// so a lunar entry has to produce both. Conversion needs a complete date,
/// while gia phả routinely give only a year — *năm Đinh Hợi* — so the partial
/// cases need a rule rather than a refusal.
library;

import '../genealogical_date.dart';
import 'astronomy.dart';
import 'lunar_conversion.dart';

/// Builds the date to store from a lunar date as entered.
///
/// * A complete lunar date converts exactly, and the result is as precise as
///   what was typed.
/// * A lunar year and month convert through the first of that month, and the
///   result keeps year and month precision, marked approximate.
/// * A lunar year alone becomes the Gregorian year of its Tết, marked
///   approximate. A lunar year overlaps two Gregorian ones, so this is a
///   judgement rather than a fact — hence the flag.
///
/// [lunar] is carried through untouched in every case: it records what the
/// source actually said, and nothing derived should overwrite it.
///
/// [isApproximate] from the caller is kept as well; a date can be approximate
/// because the source said "about", because it was converted from a partial
/// lunar date, or both.
GenealogicalDate gregorianFromLunarEntry(
  LunarDate lunar, {
  bool isApproximate = false,
  double timeZone = vietnamTimeZone,
}) {
  // A leap month the year does not have cannot be converted. Falling back to
  // the ordinary month matches what families do when the intercalary month is
  // absent, and the lunar annotation still records what was entered.
  final useLeap =
      lunar.isLeapMonth &&
      lunar.month != null &&
      hasLeapMonth(lunar.year, lunar.month!, timeZone: timeZone);

  if (lunar.month != null && lunar.day != null) {
    final (day, month, year) = lunarToSolar(
      lunar.day!,
      lunar.month!,
      lunar.year,
      isLeapMonth: useLeap,
      timeZone: timeZone,
    );
    return GenealogicalDate(
      year: year,
      month: month,
      day: day,
      isApproximate: isApproximate,
      lunar: lunar,
    );
  }

  if (lunar.month != null) {
    final (_, month, year) = lunarToSolar(
      1,
      lunar.month!,
      lunar.year,
      isLeapMonth: useLeap,
      timeZone: timeZone,
    );
    return GenealogicalDate(
      year: year,
      month: month,
      // Approximate whatever the caller said: the day is unknown and the month
      // itself only roughly lines up with the Gregorian one.
      isApproximate: true,
      lunar: lunar,
    );
  }

  final (_, _, year) = lunarNewYear(lunar.year, timeZone: timeZone);
  return GenealogicalDate(
    year: year,
    isApproximate: true,
    lunar: lunar,
  );
}

/// The lunar reading to show for [date], or null if there is none to show.
///
/// A recorded reading wins: it says what the source said, and a computed one
/// must never quietly replace it.
///
/// Otherwise the reading is derived, but only from a complete date. Converting
/// a partial one would mean inventing the missing parts, which is the same
/// mistake as storing a year-only date as 1 January (§4.2). A year-only record
/// simply has no lunar reading to show.
LunarDate? lunarReadingOf(
  GenealogicalDate date, {
  double timeZone = vietnamTimeZone,
}) {
  final recorded = date.lunar;
  if (recorded != null) return recorded;
  if (date.precision != DatePrecision.day) return null;

  final converted = solarToLunar(
    date.day!,
    date.month!,
    date.year,
    timeZone: timeZone,
  );
  return LunarDate(
    year: converted.year,
    month: converted.month,
    day: converted.day,
    isLeapMonth: converted.isLeapMonth,
  );
}
