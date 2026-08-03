import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/age.dart';
import 'package:ftree/domain/genealogical_date.dart';

void main() {
  int? age(int? born, int? died, {int now = 2026}) => ageInYears(
    birth: born == null ? null : GenealogicalDate(year: born),
    death: died == null ? null : GenealogicalDate(year: died),
    currentYear: now,
  );

  test('a life with both ends is the span between them', () {
    expect(age(1808, 1874), 66);
    expect(age(1912, 1988), 76);
  });

  test('no death date counts to today', () {
    expect(age(1978, null), 48);
    expect(age(2008, null), 18);
  });

  test('no birth date gives nothing to count from', () {
    expect(age(null, 1874), isNull);
    expect(age(null, null), isNull);
  });

  test('an implausible age today is not shown at all', () {
    // A missing death date does not mean living — most recorded ancestors have
    // none (ARCHITECTURE §11.1). Somebody born in 1782 is not 244; printing
    // that would be worse than printing nothing.
    expect(age(1782, null), isNull);
    expect(age(1900, null), isNull, reason: '126 today');
    expect(age(1910, null), 116, reason: 'old, but possible');
  });

  test('a recorded death is trusted however long the life', () {
    // The user may have overruled the implausible-lifespan warning on purpose
    // (§9.2); the age is what the record says.
    expect(age(1700, 1900), 200);
  });

  test('a death before a birth yields nothing rather than a negative', () {
    expect(age(1900, 1880), isNull);
  });

  test('the same year at both ends is zero, not nothing', () {
    // An infant who did not survive the year is a real and common record.
    expect(age(1901, 1901), 0);
  });

  test('a fuller date still answers in years', () {
    expect(
      ageInYears(
        birth: GenealogicalDate(year: 1890, month: 2, day: 14),
        death: GenealogicalDate(year: 1962, month: 9, day: 3),
        currentYear: 2026,
      ),
      72,
    );
  });
}
