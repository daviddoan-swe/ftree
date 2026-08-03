/// How old somebody was, or is.
library;

import 'genealogical_date.dart';

/// Beyond this, nobody is still living. The longest verified human life was
/// 122 years (§9.2).
const int _impossibleAge = 120;

/// Years lived, or null when it cannot be told.
///
/// Computed from the years alone. The dates are partial by design (§4) — most
/// of a gia phả records a year and nothing else — so an age is accurate to
/// about a year, which is what an age is used for.
///
/// * No birth: null. Nothing to count from.
/// * A death date: the age reached, however long ago that was.
/// * No death date: the age today.
///
/// **The last rule is a heuristic, and a temporary one.** `deathDate == null`
/// does not mean living — most recorded ancestors have no death date at all
/// (ARCHITECTURE §11.1). So an age counted to today is only offered when it
/// comes out plausible; beyond [_impossibleAge] the person is certainly dead
/// and the number would be nonsense, so nothing is shown. A real
/// living/deceased decision replaces this.
///
/// Also null when the arithmetic comes out negative. A death before a birth is
/// a warning the user may legitimately have overruled (§9.2), and a negative
/// age is not a fact worth printing.
int? ageInYears({
  required GenealogicalDate? birth,
  required GenealogicalDate? death,
  required int currentYear,
}) {
  if (birth == null) return null;

  final until = death?.year ?? currentYear;
  final age = until - birth.year;
  if (age < 0) return null;
  if (death == null && age > _impossibleAge) return null;
  return age;
}
