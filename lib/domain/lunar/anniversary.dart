/// Death anniversaries — giỗ (PRODUCT.md §6.1).
///
/// A giỗ is kept on the lunar date of the death, so its Gregorian date moves
/// every year. Working out when this year's falls is the calculation a family
/// actually opens the application for.
///
/// Everything here is pure: no clock is read. Callers supply the year they are
/// asking about, which keeps the results testable and lets the UI ask about
/// past years just as easily.
library;

import 'astronomy.dart';
import 'lunar_conversion.dart';

/// How a requested lunar date had to be adjusted to land in a given year.
enum AnniversaryAdjustment {
  /// The lunar date exists in that year and was used as recorded.
  none,

  /// The death fell in an intercalary month that the year in question does not
  /// have, so the ordinary month of the same number was used.
  ///
  /// This is what families do: a year without the leap month simply keeps the
  /// rite in the ordinary one.
  leapMonthUnavailable,

  /// The lunar month is short that year and has no 30th day, so the 29th — its
  /// last day — was used.
  monthTooShort,
}

/// When a giỗ falls, and whether the lunar date needed adjusting to get there.
final class Anniversary {
  const Anniversary({
    required this.day,
    required this.month,
    required this.year,
    required this.adjustment,
  });

  /// Gregorian day of month.
  final int day;

  /// Gregorian month.
  final int month;

  /// Gregorian year.
  final int year;

  /// What, if anything, had to give.
  final AnniversaryAdjustment adjustment;

  /// The Julian Day Number this falls on.
  int get julianDay => julianDayFromDate(day, month, year);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Anniversary &&
          other.day == day &&
          other.month == month &&
          other.year == year &&
          other.adjustment == adjustment;

  @override
  int get hashCode => Object.hash(day, month, year, adjustment);

  @override
  String toString() =>
      '${day.toString().padLeft(2, '0')}/'
      '${month.toString().padLeft(2, '0')}/$year'
      '${adjustment == AnniversaryAdjustment.none ? '' : ' (${adjustment.name})'}';
}

/// The Gregorian date on which a lunar anniversary falls in [inLunarYear].
///
/// Two things can go wrong with a date recorded in one year and observed in
/// another, and neither is an error:
///
/// * the year may not have the intercalary month the death fell in, in which
///   case the ordinary month of that number is used;
/// * the lunar month may be 29 days that year while the death was on the 30th,
///   in which case the 29th is used.
///
/// Both are reported through [Anniversary.adjustment] rather than hidden, so
/// the UI can say why the date is not exactly what was recorded.
Anniversary anniversaryIn({
  required int lunarDay,
  required int lunarMonth,
  required bool isLeapMonth,
  required int inLunarYear,
  double timeZone = vietnamTimeZone,
}) {
  if (lunarDay < 1 || lunarDay > 30) {
    throw ArgumentError.value(lunarDay, 'lunarDay', 'must be between 1 and 30');
  }
  if (lunarMonth < 1 || lunarMonth > 12) {
    throw ArgumentError.value(
      lunarMonth,
      'lunarMonth',
      'must be between 1 and 12',
    );
  }

  var adjustment = AnniversaryAdjustment.none;

  var useLeap = isLeapMonth;
  if (useLeap && !hasLeapMonth(inLunarYear, lunarMonth, timeZone: timeZone)) {
    useLeap = false;
    adjustment = AnniversaryAdjustment.leapMonthUnavailable;
  }

  var day = lunarDay;
  if (day == 30 &&
      !_hasThirtiethDay(
        lunarMonth,
        inLunarYear,
        isLeapMonth: useLeap,
        timeZone: timeZone,
      )) {
    day = 29;
    if (adjustment == AnniversaryAdjustment.none) {
      adjustment = AnniversaryAdjustment.monthTooShort;
    }
  }

  final (gregorianDay, gregorianMonth, gregorianYear) = lunarToSolar(
    day,
    lunarMonth,
    inLunarYear,
    isLeapMonth: useLeap,
    timeZone: timeZone,
  );

  return Anniversary(
    day: gregorianDay,
    month: gregorianMonth,
    year: gregorianYear,
    adjustment: adjustment,
  );
}

/// The anniversary of the death recorded on [deathDay] of the Gregorian
/// calendar, observed during lunar year [inLunarYear].
///
/// Converts the death to its lunar date first, which is what the rite is fixed
/// to.
Anniversary anniversaryOfDeath({
  required int deathDay,
  required int deathMonth,
  required int deathYear,
  required int inLunarYear,
  double timeZone = vietnamTimeZone,
}) {
  final lunar = solarToLunar(
    deathDay,
    deathMonth,
    deathYear,
    timeZone: timeZone,
  );
  return anniversaryIn(
    lunarDay: lunar.day,
    lunarMonth: lunar.month,
    isLeapMonth: lunar.isLeapMonth,
    inLunarYear: inLunarYear,
    timeZone: timeZone,
  );
}

/// Whether the given lunar month runs to a 30th day.
///
/// Decided by converting the day 29 slots after the month's first and asking
/// what it turns out to be. Comparing month numbers alone is not enough: an
/// intercalary month repeats its predecessor's number, so in a year with a leap
/// month 6 the day after ordinary 6/29 is leap 6/1 — still "month 6", but a
/// different month.
bool _hasThirtiethDay(
  int lunarMonth,
  int lunarYear, {
  required bool isLeapMonth,
  required double timeZone,
}) {
  final start = lunarToSolar(
    1,
    lunarMonth,
    lunarYear,
    isLeapMonth: isLeapMonth,
    timeZone: timeZone,
  );
  final startJulianDay = julianDayFromDate(start.$1, start.$2, start.$3);

  final (day, month, year) = dateFromJulianDay(startJulianDay + 29);
  final candidate = solarToLunar(day, month, year, timeZone: timeZone);

  return candidate.day == 30 &&
      candidate.month == lunarMonth &&
      candidate.isLeapMonth == isLeapMonth;
}
