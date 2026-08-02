/// Sexagenary year names — can chi (DOMAIN.md §4.4).
///
/// Vietnamese family records name a year rather than numbering it: *năm Đinh
/// Hợi*, not *1887*. The name pairs one of ten heavenly stems (thiên can) with
/// one of twelve earthly branches (địa chi), and because ten and twelve share a
/// factor of two only half the sixty combinations occur — the cycle repeats
/// every sixty years, not a hundred and twenty.
///
/// That period is the practical difficulty. A source giving only "năm Đinh Hợi"
/// does not say which Đinh Hợi, so [lunarYearsNamed] returns every candidate in
/// a range and leaves the choice to whoever has the surrounding context.
///
/// Pure arithmetic on the lunar year number. Nothing here touches the calendar
/// conversion.
library;

/// The ten heavenly stems, in order.
const List<String> heavenlyStems = <String>[
  'Giáp',
  'Ất',
  'Bính',
  'Đinh',
  'Mậu',
  'Kỷ',
  'Canh',
  'Tân',
  'Nhâm',
  'Quý',
];

/// The twelve earthly branches, in order.
const List<String> earthlyBranches = <String>[
  'Tý',
  'Sửu',
  'Dần',
  'Mão',
  'Thìn',
  'Tỵ',
  'Ngọ',
  'Mùi',
  'Thân',
  'Dậu',
  'Tuất',
  'Hợi',
];

/// The length of the full cycle: the least common multiple of 10 and 12.
const int sexagenaryCycle = 60;

/// The name of a lunar year, such as `Bính Ngọ`.
final class CanChi {
  const CanChi(this.stem, this.branch);

  /// Derives the name of [lunarYear].
  factory CanChi.ofLunarYear(int lunarYear) => CanChi(
    heavenlyStems[(lunarYear + 6) % 10],
    earthlyBranches[(lunarYear + 8) % 12],
  );

  /// Parses a name such as `Bính Ngọ`.
  ///
  /// Throws [ArgumentError] if either half is not a recognised stem or branch,
  /// or if the pair is one of the sixty that cannot occur.
  factory CanChi.parse(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) {
      throw ArgumentError.value(
        name,
        'name',
        'must be a stem and a branch separated by a space',
      );
    }
    final canChi = CanChi(parts[0], parts[1]);
    if (!heavenlyStems.contains(canChi.stem)) {
      throw ArgumentError.value(parts[0], 'stem', 'is not a heavenly stem');
    }
    if (!earthlyBranches.contains(canChi.branch)) {
      throw ArgumentError.value(parts[1], 'branch', 'is not an earthly branch');
    }
    if (!canChi.isPossible) {
      throw ArgumentError.value(
        name,
        'name',
        'is not one of the sixty combinations that occur',
      );
    }
    return canChi;
  }

  /// The heavenly stem, for example `Bính`.
  final String stem;

  /// The earthly branch, for example `Ngọ`.
  final String branch;

  /// Whether this pairing can occur at all.
  ///
  /// Stems advance in tens and branches in twelves, so a stem at an even index
  /// only ever meets a branch at an even index. Half of the hundred and twenty
  /// possible pairs never happen.
  bool get isPossible {
    final stemIndex = heavenlyStems.indexOf(stem);
    final branchIndex = earthlyBranches.indexOf(branch);
    if (stemIndex < 0 || branchIndex < 0) return false;
    return stemIndex.isEven == branchIndex.isEven;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanChi && other.stem == stem && other.branch == branch;

  @override
  int get hashCode => Object.hash(stem, branch);

  @override
  String toString() => '$stem $branch';
}

/// Every lunar year in `[from, to]` that carries the name [canChi].
///
/// A source that names a year without numbering it is ambiguous by sixty
/// years, so this returns all the candidates rather than guessing. Data entry
/// is expected to narrow it with a century or a known relative.
List<int> lunarYearsNamed(CanChi canChi, {required int from, required int to}) {
  if (from > to) {
    throw ArgumentError.value(from, 'from', 'must not be later than $to');
  }
  return <int>[
    for (var year = from; year <= to; year++)
      if (CanChi.ofLunarYear(year) == canChi) year,
  ];
}
