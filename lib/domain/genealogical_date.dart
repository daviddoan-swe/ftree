/// Partial dates for genealogical records (DOMAIN.md §4).
///
/// Genealogical sources routinely give a year and nothing more. Storing a plain
/// exact date forces the user to invent a day and month, and after that the
/// invention is indistinguishable from a real 1 January — a loss no later
/// schema change can undo (§4.2).
///
/// A [GenealogicalDate] therefore records only what is known. Precision is
/// derived from which components are present, so it can never contradict the
/// value. An entirely unknown date is simply `null`.
library;

/// How much of a date is known. Derived, never stored.
enum DatePrecision {
  /// Only the year is known.
  year,

  /// Year and month are known.
  month,

  /// The full date is known.
  day,
}

/// The possible range of elapsed time between two partial dates.
///
/// Because partial dates denote intervals rather than instants, the time
/// between two of them is itself a range. `1887` to `1888` could be as little
/// as one day or as much as two years less a day.
///
/// A negative bound means [other] may fall before the starting date.
final class DateSpan {
  const DateSpan({required this.minimumDays, required this.maximumDays});

  /// The smallest possible gap, in days. Negative if the end may precede the
  /// start.
  final int minimumDays;

  /// The largest possible gap, in days.
  final int maximumDays;

  /// Mean Gregorian year length, so that year-based thresholds behave sanely
  /// across leap years.
  static const double _daysPerYear = 365.2425;

  /// The smallest possible gap, in years.
  double get minimumYears => minimumDays / _daysPerYear;

  /// The largest possible gap, in years.
  double get maximumYears => maximumDays / _daysPerYear;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateSpan &&
          other.minimumDays == minimumDays &&
          other.maximumDays == maximumDays;

  @override
  int get hashCode => Object.hash(minimumDays, maximumDays);

  @override
  String toString() => 'DateSpan($minimumDays..$maximumDays days)';
}

/// A date known to year, month, or day precision.
///
/// Deliberately does **not** implement [Comparable]. Ordering partial dates is
/// a partial order: `1887` and `1887-03-15` cannot be ranked, because the first
/// may fall before, after, or on the second. A `compareTo` returning -1, 0, or
/// 1 would have to invent an answer. Use [definitelyBefore], [definitelyAfter],
/// or [spanTo], all of which can express "unknown".
final class GenealogicalDate {
  /// Creates a date from the components that are known.
  ///
  /// Throws [ArgumentError] for values that cannot describe any real date: a
  /// [day] without a [month], a month outside 1-12, 31 April, 29 February in a
  /// common year, or a non-positive [year].
  ///
  /// Missing components are not an error — they are the normal case, and the
  /// whole reason this type exists.
  GenealogicalDate({
    required this.year,
    this.month,
    this.day,
    this.isApproximate = false,
  }) {
    if (year < 1) {
      throw ArgumentError.value(
        year,
        'year',
        'must be positive; BC dates are out of scope (DOMAIN.md §4.3)',
      );
    }
    if (month != null && (month! < 1 || month! > 12)) {
      throw ArgumentError.value(month, 'month', 'must be between 1 and 12');
    }
    if (day != null) {
      if (month == null) {
        throw ArgumentError.value(
          day,
          'day',
          'cannot be known while the month is unknown',
        );
      }
      final maximum = _daysInMonth(year, month!);
      if (day! < 1 || day! > maximum) {
        throw ArgumentError.value(
          day,
          'day',
          'must be between 1 and $maximum for $year-$month',
        );
      }
    }
  }

  /// Parses the ISO-prefix form: `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`.
  ///
  /// [isApproximate] is not part of the string. It is carried alongside, which
  /// keeps the text sortable and matches the storage shape in §4.1.
  ///
  /// Throws [FormatException] if [text] is not one of the three forms, and
  /// [ArgumentError] if it parses but describes no real date.
  factory GenealogicalDate.parseIso(String text, {bool isApproximate = false}) {
    final match = _isoPattern.firstMatch(text);
    if (match == null) {
      throw FormatException('Expected YYYY, YYYY-MM, or YYYY-MM-DD', text);
    }
    final monthText = match.group(2);
    final dayText = match.group(3);
    return GenealogicalDate(
      year: int.parse(match.group(1)!),
      month: monthText == null ? null : int.parse(monthText),
      day: dayText == null ? null : int.parse(dayText),
      isApproximate: isApproximate,
    );
  }

  static final RegExp _isoPattern = RegExp(
    r'^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?$',
  );

  /// The year. Always known — a date with no year at all is `null` instead.
  final int year;

  /// The month, 1-12, or null when unknown.
  final int? month;

  /// The day of month, or null when unknown.
  final int? day;

  /// Whether the source recorded this as approximate ("about 1887").
  ///
  /// This flag does **not** widen the interval used for comparison. Recording
  /// uncertainty about a value is not permission to ignore contradictions the
  /// value produces; a parent born "about 1910" with a child born 1920 should
  /// still be questioned. The false-warning problem §4.3 guards against comes
  /// from missing precision, which [earliest]/[latest] already model.
  final bool isApproximate;

  /// How much of this date is known. Derived from the components present.
  DatePrecision get precision {
    if (day != null) return DatePrecision.day;
    if (month != null) return DatePrecision.month;
    return DatePrecision.year;
  }

  /// The earliest instant this date could refer to.
  ///
  /// UTC throughout: local time would let a timezone or DST shift move a
  /// comparison across a day boundary.
  DateTime get earliest => DateTime.utc(year, month ?? 1, day ?? 1);

  /// The latest instant this date could refer to.
  DateTime get latest {
    final lastMonth = month ?? 12;
    return DateTime.utc(year, lastMonth, day ?? _daysInMonth(year, lastMonth));
  }

  /// The range of elapsed time from this date to [other].
  ///
  /// The gap is a range, not a number, because both endpoints may be intervals.
  DateSpan spanTo(GenealogicalDate other) => DateSpan(
    minimumDays: other.earliest.difference(latest).inDays,
    maximumDays: other.latest.difference(earliest).inDays,
  );

  /// Whether this date certainly falls before [other].
  ///
  /// False when the two intervals overlap — that is "we cannot tell", not "no".
  bool definitelyBefore(GenealogicalDate other) => latest.isBefore(other.earliest);

  /// Whether this date certainly falls after [other].
  bool definitelyAfter(GenealogicalDate other) => other.definitelyBefore(this);

  /// Whether the two dates overlap, leaving their order undecidable.
  bool isIndeterminateAgainst(GenealogicalDate other) =>
      !definitelyBefore(other) && !definitelyAfter(other);

  /// The ISO-prefix form, carrying exactly the precision that is known.
  ///
  /// Sorts correctly as text, and is unchanged by SQLite or PostgreSQL.
  String toIso() {
    final buffer = StringBuffer(year.toString().padLeft(4, '0'));
    if (month != null) {
      buffer.write('-${month!.toString().padLeft(2, '0')}');
      if (day != null) {
        buffer.write('-${day!.toString().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenealogicalDate &&
          other.year == year &&
          other.month == month &&
          other.day == day &&
          other.isApproximate == isApproximate;

  @override
  int get hashCode => Object.hash(year, month, day, isApproximate);

  @override
  String toString() => isApproximate ? 'about ${toIso()}' : toIso();

  static int _daysInMonth(int year, int month) {
    const lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) return 29;
    return lengths[month - 1];
  }

  static bool _isLeapYear(int year) =>
      year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}
