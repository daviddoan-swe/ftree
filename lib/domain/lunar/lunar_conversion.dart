/// Conversion between the Gregorian and Vietnamese lunar calendars
/// (DOMAIN.md §4.4).
///
/// A lunar year runs from the new moon that starts month 1 — Tết — to the day
/// before the next one. Month 11 is defined as whichever lunar month contains
/// the winter solstice, and everything else is counted from there. When
/// thirteen new moons fall between two consecutive month 11s, one of the
/// intervening months is intercalary (tháng nhuận) and repeats its
/// predecessor's number.
///
/// The Vietnamese calendar is computed at UTC+7. The Chinese calendar uses
/// UTC+8 and produces a different result for some dates, so the two are not
/// interchangeable.
library;

import 'astronomy.dart';

/// A date in the Vietnamese lunar calendar.
///
/// Deliberately separate from `LunarDate` in the domain entities: that type
/// records what a source document said and may be partial, whereas this one is
/// always a complete, computed date.
final class LunarDay {
  const LunarDay({
    required this.day,
    required this.month,
    required this.year,
    required this.isLeapMonth,
  });

  /// Day of the lunar month, 1-30.
  final int day;

  /// Lunar month, 1-12. An intercalary month repeats the previous month's
  /// number and is distinguished by [isLeapMonth].
  final int month;

  /// Lunar year.
  final int year;

  /// Whether this falls in an intercalary month.
  final bool isLeapMonth;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LunarDay &&
          other.day == day &&
          other.month == month &&
          other.year == year &&
          other.isLeapMonth == isLeapMonth;

  @override
  int get hashCode => Object.hash(day, month, year, isLeapMonth);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}'
      '${isLeapMonth ? 'L' : ''}-${day.toString().padLeft(2, '0')} lunar';
}

/// The Julian Day Number on which lunar month 11 of [year] begins.
///
/// Month 11 is the lunar month containing the winter solstice, which is where
/// the sun enters longitude sector 9.
int lunarMonth11Start(int year, {double timeZone = vietnamTimeZone}) {
  // Measured from the integer 1900-01-01 rather than the precise new-moon
  // epoch. The two differ by a fraction of a day, and here that fraction must
  // round the other way: this needs the month containing 31 December, not the
  // last one to have started before it.
  final k =
      ((julianDayFromDate(31, 12, year) - julianDay1900) / synodicMonth)
          .floor();
  final candidate = newMoonDay(k, timeZone: timeZone);

  if (sunLongitudeSectorOnDay(candidate, timeZone: timeZone) >= 9) {
    // The new moon already fell past the solstice, so month 11 began a month
    // earlier.
    return newMoonDay(k - 1, timeZone: timeZone);
  }
  return candidate;
}

/// Which month after [month11Start] is intercalary, as an offset in months.
///
/// Only meaningful when the lunar year actually has thirteen months. A leap
/// month is one during which the sun does not enter a new longitude sector.
int leapMonthOffset(int month11Start, {double timeZone = vietnamTimeZone}) {
  final k = newMoonIndexNearest(month11Start);

  var i = 1;
  var previous = 0;
  var sector = sunLongitudeSectorOnDay(
    newMoonDay(k + i, timeZone: timeZone),
    timeZone: timeZone,
  );

  do {
    previous = sector;
    i++;
    sector = sunLongitudeSectorOnDay(
      newMoonDay(k + i, timeZone: timeZone),
      timeZone: timeZone,
    );
  } while (sector != previous && i < 14);

  return i - 1;
}

/// Converts a Gregorian date to its Vietnamese lunar equivalent.
LunarDay solarToLunar(
  int day,
  int month,
  int year, {
  double timeZone = vietnamTimeZone,
}) {
  final dayNumber = julianDayFromDate(day, month, year);

  final k = newMoonIndexBefore(dayNumber);
  var monthStart = newMoonDay(k + 1, timeZone: timeZone);
  if (monthStart > dayNumber) {
    monthStart = newMoonDay(k, timeZone: timeZone);
  }

  var a11 = lunarMonth11Start(year, timeZone: timeZone);
  var b11 = a11;

  final int lunarYear;
  if (a11 >= monthStart) {
    lunarYear = year;
    a11 = lunarMonth11Start(year - 1, timeZone: timeZone);
  } else {
    lunarYear = year + 1;
    b11 = lunarMonth11Start(year + 1, timeZone: timeZone);
  }

  final lunarDay = dayNumber - monthStart + 1;
  final diff = (monthStart - a11) ~/ 29;

  var lunarMonth = diff + 11;
  var isLeap = false;

  if (b11 - a11 > 365) {
    // Thirteen new moons between the two month 11s: this lunar year has an
    // intercalary month, and every month from it onward shifts back by one.
    final leapOffset = leapMonthOffset(a11, timeZone: timeZone);
    if (diff >= leapOffset) {
      lunarMonth = diff + 10;
      if (diff == leapOffset) isLeap = true;
    }
  }

  if (lunarMonth > 12) lunarMonth -= 12;
  // Months 11 and 12 belong to the previous lunar year.
  final resolvedYear = lunarMonth >= 11 && diff < 4 ? lunarYear - 1 : lunarYear;

  return LunarDay(
    day: lunarDay,
    month: lunarMonth,
    year: resolvedYear,
    isLeapMonth: isLeap,
  );
}

/// Converts a Vietnamese lunar date to its Gregorian equivalent, as
/// `(day, month, year)`.
///
/// Throws [ArgumentError] if [isLeapMonth] is set for a month that is not
/// intercalary in that lunar year — callers that want a graceful fallback
/// should check with [hasLeapMonth] first.
(int day, int month, int year) lunarToSolar(
  int lunarDay,
  int lunarMonth,
  int lunarYear, {
  bool isLeapMonth = false,
  double timeZone = vietnamTimeZone,
}) {
  final int a11;
  final int b11;
  if (lunarMonth < 11) {
    a11 = lunarMonth11Start(lunarYear - 1, timeZone: timeZone);
    b11 = lunarMonth11Start(lunarYear, timeZone: timeZone);
  } else {
    a11 = lunarMonth11Start(lunarYear, timeZone: timeZone);
    b11 = lunarMonth11Start(lunarYear + 1, timeZone: timeZone);
  }

  var offset = lunarMonth - 11;
  if (offset < 0) offset += 12;

  if (b11 - a11 > 365) {
    final leapOffset = leapMonthOffset(a11, timeZone: timeZone);
    var leapMonthNumber = leapOffset - 2;
    if (leapMonthNumber < 0) leapMonthNumber += 12;

    if (isLeapMonth && lunarMonth != leapMonthNumber) {
      throw ArgumentError.value(
        lunarMonth,
        'lunarMonth',
        'is not the intercalary month of lunar year $lunarYear '
            '(that is month $leapMonthNumber)',
      );
    }
    if (isLeapMonth || offset >= leapOffset) {
      offset += 1;
    }
  } else if (isLeapMonth) {
    throw ArgumentError.value(
      lunarYear,
      'lunarYear',
      'has no intercalary month',
    );
  }

  final k = newMoonIndexNearest(a11);
  final monthStart = newMoonDay(k + offset, timeZone: timeZone);

  return dateFromJulianDay(monthStart + lunarDay - 1);
}

/// The intercalary month of [lunarYear], or null if it has none.
///
/// Two windows have to be checked, because [lunarToSolar] anchors months 1-10
/// to the previous year's month 11 and months 11-12 to this year's. A leap
/// month 11 or 12 falls in the second window, and looking only at the first
/// would report the year as ordinary while [lunarToSolar] disagreed.
int? leapMonthOf(int lunarYear, {double timeZone = vietnamTimeZone}) {
  for (final anchor in <int>[lunarYear - 1, lunarYear]) {
    final a11 = lunarMonth11Start(anchor, timeZone: timeZone);
    final b11 = lunarMonth11Start(anchor + 1, timeZone: timeZone);
    if (b11 - a11 <= 365) continue;

    var month = leapMonthOffset(a11, timeZone: timeZone) - 2;
    if (month < 0) month += 12;

    final belongsToThisYear = anchor == lunarYear - 1 ? month < 11 : month >= 11;
    if (belongsToThisYear) return month;
  }
  return null;
}

/// Whether [lunarYear] has an intercalary month at [lunarMonth].
bool hasLeapMonth(
  int lunarYear,
  int lunarMonth, {
  double timeZone = vietnamTimeZone,
}) => leapMonthOf(lunarYear, timeZone: timeZone) == lunarMonth;

/// The Gregorian date of Tết — lunar 1/1 — in [lunarYear].
(int day, int month, int year) lunarNewYear(
  int lunarYear, {
  double timeZone = vietnamTimeZone,
}) => lunarToSolar(1, 1, lunarYear, timeZone: timeZone);
