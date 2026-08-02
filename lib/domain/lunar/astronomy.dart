/// Astronomical primitives the Vietnamese lunar calendar is built on.
///
/// The lunar calendar is not arithmetic. A lunar month begins at the instant of
/// a new moon and runs 29 or 30 days depending on when the next one falls;
/// month 11 is whichever lunar month contains the winter solstice. Both of
/// those are astronomical events, so converting a date means computing them.
///
/// Everything here is expressed in Julian Day Numbers — a continuous count of
/// days that avoids calendar irregularities entirely — and everything is pure
/// arithmetic on doubles, with no clock, no locale, and no I/O.
///
/// The formulae follow Jean Meeus, *Astronomical Algorithms*, in the form used
/// by Hồ Ngọc Đức's widely-published Vietnamese calendar implementation.
///
/// Time zone matters and is never assumed. A new moon at 23:30 in UTC+7 has
/// already fallen on the next day in UTC+8, which is why the Vietnamese and
/// Chinese calendars disagree by a day in some years. Callers pass the zone
/// explicitly; see [vietnamTimeZone].
library;

import 'dart:math';

/// Vietnam's offset from UTC, in hours.
///
/// The value that makes this the Vietnamese rather than the Chinese calendar.
/// Chinese implementations use 8 and are not interchangeable.
const double vietnamTimeZone = 7;

/// Mean length of a synodic month, in days.
const double synodicMonth = 29.530588853;

/// Julian Day Number of 1900-01-01.
const int julianDay1900 = 2415021;

/// The precise Julian Day the new-moon index is measured from.
///
/// Not the integer 1900-01-01: new moon zero falls a fraction of a day later,
/// and rounding that away shifts the index by one for dates near a month
/// boundary — which then reports a lunar day of zero.
const double newMoonEpoch = 2415021.076998695;

const double _degreesToRadians = pi / 180;

/// The Julian Day Number of a Gregorian calendar date.
///
/// Handles the Julian-to-Gregorian changeover in October 1582, so dates far
/// enough back to matter for genealogy stay correct.
int julianDayFromDate(int day, int month, int year) {
  final a = (14 - month) ~/ 12;
  final y = year + 4800 - a;
  final m = month + 12 * a - 3;

  final gregorian =
      day +
      (153 * m + 2) ~/ 5 +
      365 * y +
      y ~/ 4 -
      y ~/ 100 +
      y ~/ 400 -
      32045;

  if (gregorian < 2299161) {
    // Before 15 October 1582 the Julian calendar was in force.
    return day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - 32083;
  }
  return gregorian;
}

/// The Gregorian date of a Julian Day Number, as `(day, month, year)`.
(int day, int month, int year) dateFromJulianDay(int julianDay) {
  final int b;
  final int c;
  if (julianDay > 2299160) {
    final a = julianDay + 32044;
    b = (4 * a + 3) ~/ 146097;
    c = a - (b * 146097) ~/ 4;
  } else {
    b = 0;
    c = julianDay + 32082;
  }

  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;

  final day = e - (153 * m + 2) ~/ 5 + 1;
  final month = m + 3 - 12 * (m ~/ 10);
  final year = b * 100 + d - 4800 + m ~/ 10;

  return (day, month, year);
}

/// The instant of the [k]th new moon after 1900-01-01, as a fractional Julian
/// Day in Universal Time.
///
/// k = 0 is the new moon of 1900-01-13.
double newMoonInstant(int k) {
  final t = k / 1236.85; // Julian centuries since 1900 January 0.5
  final t2 = t * t;
  final t3 = t2 * t;

  var jd =
      2415020.75933 +
      synodicMonth * k +
      0.0001178 * t2 -
      0.000000155 * t3;
  jd += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * _degreesToRadians);

  // Mean anomaly of the sun.
  final sunAnomaly =
      359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
  // Mean anomaly of the moon.
  final moonAnomaly =
      306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
  // Moon's argument of latitude.
  final latitudeArgument =
      21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;

  double rad(double degrees) => degrees * _degreesToRadians;

  var correction =
      (0.1734 - 0.000393 * t) * sin(rad(sunAnomaly)) +
      0.0021 * sin(rad(2 * sunAnomaly));
  correction -= 0.4068 * sin(rad(moonAnomaly));
  correction += 0.0161 * sin(rad(2 * moonAnomaly));
  correction -= 0.0004 * sin(rad(3 * moonAnomaly));
  correction += 0.0104 * sin(rad(2 * latitudeArgument));
  correction -= 0.0051 * sin(rad(sunAnomaly + moonAnomaly));
  correction -= 0.0074 * sin(rad(sunAnomaly - moonAnomaly));
  correction += 0.0004 * sin(rad(2 * latitudeArgument + sunAnomaly));
  correction -= 0.0004 * sin(rad(2 * latitudeArgument - sunAnomaly));
  correction -= 0.0006 * sin(rad(2 * latitudeArgument + moonAnomaly));
  correction += 0.0010 * sin(rad(2 * latitudeArgument - moonAnomaly));
  correction += 0.0005 * sin(rad(2 * moonAnomaly + sunAnomaly));

  final double deltaT;
  if (t < -11) {
    deltaT =
        0.001 +
        0.000839 * t +
        0.0002261 * t2 -
        0.00000845 * t3 -
        0.000000081 * t * t3;
  } else {
    deltaT = -0.000278 + 0.000265 * t + 0.000262 * t2;
  }

  return jd + correction - deltaT;
}

/// The local day on which the [k]th new moon falls, as a Julian Day Number.
///
/// This is where the time zone decides the answer: a new moon late in the
/// evening belongs to one day in UTC+7 and the next in UTC+8.
int newMoonDay(int k, {double timeZone = vietnamTimeZone}) =>
    (newMoonInstant(k) + 0.5 + timeZone / 24).floor();

/// The index of the last new moon falling at or before [julianDay].
int newMoonIndexBefore(num julianDay) =>
    ((julianDay - newMoonEpoch) / synodicMonth).floor();

/// The index of the new moon nearest [julianDay], rounding to the closest.
///
/// Used when [julianDay] is already known to be a month start, where rounding
/// to the nearest avoids a boundary landing on the previous month.
int newMoonIndexNearest(num julianDay) =>
    ((julianDay - newMoonEpoch) / synodicMonth + 0.5).floor();

/// The sun's ecliptic longitude, expressed as one of twelve 30° sectors.
///
/// Sectors run 0-11 from the March equinox. The lunar calendar only ever needs
/// to know which sector a day falls in, never the exact angle: month 11 is the
/// lunar month containing the winter solstice, which is the start of sector 9.
int sunLongitudeSector(double julianDay) {
  final t = (julianDay - 2451545.0) / 36525; // Julian centuries since J2000.0
  final t2 = t * t;

  final meanAnomaly =
      357.52910 + 35999.05030 * t - 0.0001559 * t2 - 0.00000048 * t * t2;
  final meanLongitude = 280.46645 + 36000.76983 * t + 0.0003032 * t2;

  var correction =
      (1.914600 - 0.004817 * t - 0.000014 * t2) *
      sin(_degreesToRadians * meanAnomaly);
  correction +=
      (0.019993 - 0.000101 * t) * sin(_degreesToRadians * 2 * meanAnomaly);
  correction += 0.000290 * sin(_degreesToRadians * 3 * meanAnomaly);

  var longitude = (meanLongitude + correction) * _degreesToRadians;
  // Normalise into [0, 2π).
  longitude -= pi * 2 * (longitude / (pi * 2)).floor();

  return (longitude / pi * 6).floor();
}

/// The sun's longitude sector at the start of a local day.
int sunLongitudeSectorOnDay(
  int julianDay, {
  double timeZone = vietnamTimeZone,
}) => sunLongitudeSector(julianDay - 0.5 - timeZone / 24);
