/// How old somebody was, or is.
library;

import 'genealogical_date.dart';

/// The age past which a life stops being believable.
///
/// The longest verified human life was 122 years (§9.2), so 120 leaves room
/// for a genuine outlier while still catching a transcription slip.
///
/// **One number, two jobs, and the second is a stand-in.** It marks a lifespan
/// as worth questioning, in `Person.validate`, which is what it is for. It also
/// decides whether somebody with no recorded death can still be alive — and
/// that is a guess standing where a living/deceased decision belongs
/// (ARCHITECTURE §11.1). Three screens now lean on it: the age under a
/// portrait, the grey on a person who has died, and the tinted border on the
/// chart. When the real decision arrives, this constant goes back to its first
/// job alone.
const int maximumPlausibleLifespanYears = 150;

/// Years lived, or null when it cannot be told.
///
/// Computed from the years alone. The dates are partial by design (§4) — most
/// of a gia phả records a year and nothing else — so an age is accurate to
/// about a year, which is what an age is used for.
///
/// * No birth: null. Nothing to count from.
/// * A death date: the age reached, however long ago that was.
/// * [deceased] with no death date: null. They died; when is not recorded, and
///   counting to today would age a dead man.
/// * Otherwise: the age today.
///
/// The last rule still has a guard on it. `!deceased` means nothing about a
/// death was written down, which is not the same as being alive — so an age
/// counted to today is only offered when it comes out plausible. Past
/// [maximumPlausibleLifespanYears] the record is simply silent about somebody
/// long dead, and a number there would be nonsense.
///
/// Also null when the arithmetic comes out negative. A death before a birth is
/// a warning the user may legitimately have overruled (§9.2), and a negative
/// age is not a fact worth printing.
int? ageInYears({
  required GenealogicalDate? birth,
  required GenealogicalDate? death,
  required int currentYear,
  bool deceased = false,
}) {
  if (birth == null) return null;
  if (death == null && deceased) return null;

  final until = death?.year ?? currentYear;
  final age = until - birth.year;
  if (age < 0) return null;
  if (death == null && age > maximumPlausibleLifespanYears) return null;
  return age;
}
