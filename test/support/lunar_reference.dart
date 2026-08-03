/// The only external calibration in the suite.
///
/// Every lunar test outside this file checks a self-consistency or structural
/// property — that a month has 29 or 30 days, that a round trip returns what
/// it was given, that an intercalary month lands where the algorithm says.
/// Those hold whatever the algorithm computes. **These two tables are the only
/// place where the code is measured against the outside world**, so if a value
/// here is wrong the tests confirm a wrong implementation rather than catch
/// it, which is worse than having no reference at all.
///
/// ## ⚠️ PROVISIONAL
///
/// Written from memory. **Not** checked against a published Vietnamese
/// almanac. Nobody should rely on a computed giỗ date until this is replaced.
///
/// ## Replacing it
///
/// Both tables live here so the swap is one file. What is needed:
///
/// * an authoritative Vietnamese almanac — the calendar is based on UTC+7, so
///   a Chinese table cannot be used without checking every date: the two
///   differ by a day where a new moon falls in the hour between the zones
///   (DOMAIN.md §4.4);
/// * a wider span than the handful of years below, ideally reaching back into
///   the nineteenth century, where the gia phả this application is for
///   actually begins;
/// * the source named in [source] so the next reader knows what was trusted.
library;

/// Where the tables below came from. Update this when they are replaced.
const String source = 'From memory — provisional, unverified.';

/// Gregorian dates of Tết — lunar 1 January — by lunar year.
const Map<int, (int day, int month)> tetDates = <int, (int, int)>{
  2020: (25, 1),
  2021: (12, 2),
  2022: (1, 2),
  2023: (22, 1),
  2024: (10, 2),
  2025: (29, 1),
  2026: (17, 2),
};

/// Lunar years whose can-chi names are widely known.
///
/// 2024 as Giáp Thìn and 1968 as Mậu Thân are the two easiest to check
/// independently.
const Map<int, String> canChiNames = <int, String>{
  1945: 'Ất Dậu',
  1968: 'Mậu Thân',
  1975: 'Ất Mão',
  2000: 'Canh Thìn',
  2020: 'Canh Tý',
  2024: 'Giáp Thìn',
  2025: 'Ất Tỵ',
  2026: 'Bính Ngọ',
};
