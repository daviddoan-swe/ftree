/// A synthetic gia phả, large enough to look at (ROADMAP M6, T28).
///
/// Development scaffolding, not a product feature. Nothing under `lib/dev` is
/// reachable from `lib/main.dart`, so none of it is compiled into a release
/// build — there is no debug flag to remember to turn off.
///
/// Two properties matter more than realism:
///
/// * **Deterministic.** The same seed produces identical output, so a
///   screenshot can be compared against a later one and a measurement against a
///   later measurement. Ids come from [newId] with an injected clock and
///   generator rather than the real ones.
/// * **Clean.** Every person and every relationship passes the domain rules
///   with no issue at all, not merely no blocking error. Test data the
///   application itself would object to is worthless for judging the interface.
///
/// Pure Dart, like the domain it builds on: no Flutter, no database. Writing
/// the result somewhere is `installSyntheticFamily`'s job.
library;

import 'dart:math';

import '../domain/family.dart';
import '../domain/genealogical_date.dart';
import '../domain/ids.dart';
import '../domain/person.dart';
import '../domain/relationship.dart';

/// A generated family, ready to save or to inspect.
final class SyntheticFamily {
  const SyntheticFamily({
    required this.family,
    required this.persons,
    required this.relationships,
    required this.generationOf,
  });

  /// The dataset itself.
  final Family family;

  /// Everyone in it, eldest generation first.
  final List<Person> persons;

  /// Every parent-child and spouse edge between them.
  final List<Relationship> relationships;

  /// Which generation each person stands in, the progenitor being 0.
  ///
  /// Not part of the domain — descent is what the relationships say. This is
  /// the generator's own record of what it built, so a test can check the
  /// requested depth was reached without re-deriving it.
  final Map<String, int> generationOf;

  /// How many generations deep the tree runs.
  int get depth =>
      generationOf.values.fold<int>(0, (a, b) => b > a ? b : a) + 1;

  /// How many people stand in each generation, eldest first.
  List<int> get widths {
    final counts = List<int>.filled(depth, 0);
    for (final generation in generationOf.values) {
      counts[generation]++;
    }
    return counts;
  }

  /// The earliest and latest birth years recorded, for a one-line summary.
  (int, int) get birthYearRange {
    var earliest = 1 << 30;
    var latest = 0;
    for (final person in persons) {
      final year = person.birthDate?.year;
      if (year == null) continue;
      if (year < earliest) earliest = year;
      if (year > latest) latest = year;
    }
    return (earliest, latest);
  }
}

/// Builds a family of roughly [people] across exactly [generations].
///
/// ## Why the tree has to be given a shape
///
/// Thirty generations holding a thousand people averages thirty-three people
/// per generation. Nothing grown naturally lands there: three children a couple
/// puts sixty thousand people in generation ten. So width is allocated rather
/// than emergent — generation `g` is aimed at a share proportional to `g + 1`,
/// which gives a narrow trunk widening toward the present.
///
/// That is also the shape of a real gia phả. Branches are lost, one line
/// carries the record forward, and the last few generations are the ones anyone
/// still has names for.
///
/// [currentYear] decides who is still alive and is passed in rather than read
/// from a clock, for the same reason `ageInYears` takes it: a function that
/// reads the time cannot be tested twice with the same answer.
///
/// Throws [ArgumentError] for fewer than two generations, or for fewer than two
/// people per generation — a line needs a couple in every generation to reach
/// the next one.
SyntheticFamily generateSyntheticFamily({
  int generations = 12,
  int people = 300,
  int seed = 20260805,
  int currentYear = 2026,
  String name = 'Họ Nguyễn (dữ liệu thử)',
  String lineage = 'Nguyễn',
}) {
  if (generations < 2) {
    throw ArgumentError.value(
      generations,
      'generations',
      'a tree needs at least a progenitor and a child',
    );
  }
  if (people < generations * 2) {
    throw ArgumentError.value(
      people,
      'people',
      'needs at least two per generation — ${generations * 2} for '
          '$generations generations — or the line cannot reach the bottom',
    );
  }

  return _Builder(
    generations: generations,
    people: people,
    seed: seed,
    currentYear: currentYear,
    name: name,
    lineage: lineage,
  ).build();
}

// ------------------------------------------------------------ the builder ---

/// A married pair, and the source of the next generation.
///
/// A man with two wives appears in two unions, which is how a second marriage
/// gets its own set of children.
final class _Union {
  const _Union({required this.husband, required this.wife});

  final _Draft husband;
  final _Draft wife;

  /// Whether this union's children continue the recorded line.
  ///
  /// A gia phả follows the sons. Daughters are entered with their husbands and
  /// the record stops there, because their children belong to another family's
  /// book. So a union whose line member is the wife bears nobody here.
  bool get continuesTheLine => !husband.marriedIn;
}

/// A person under construction.
///
/// Mutable, unlike [Person], because a death cannot be decided until every
/// birth is known: nobody may die more than a year before their last child is
/// born, or `childBornLongAfterParentDeath` fires (`relationship_rules.dart`).
final class _Draft {
  _Draft({
    required this.id,
    required this.generation,
    required this.sex,
    required this.surname,
    required this.middle,
    required this.given,
    required this.birthYear,
    required this.birthDate,
    required this.marriedIn,
    required this.birthPlace,
    required this.biography,
  });

  final String id;
  final int generation;
  final Sex sex;
  final String surname;
  final String? middle;
  final String given;

  /// The year every date rule is derived from, whatever precision
  /// [birthDate] ends up carrying.
  final int birthYear;

  final GenealogicalDate birthDate;

  /// Whether this person married into the line rather than being born into it.
  final bool marriedIn;

  final String? birthPlace;
  final String? biography;

  /// The last year in which this person had a child, or null if they had none.
  int? lastChildBirthYear;

  /// Filled in by the death pass. Both may stay null: most of a gia phả records
  /// nothing about a death, which is not the same as a claim of life.
  GenealogicalDate? deathDate;
  String? deathPlace;

  /// Set for a few childless people, to exercise the missing-date paths.
  bool birthDateHidden = false;
}

final class _Builder {
  _Builder({
    required this.generations,
    required this.people,
    required this.seed,
    required this.currentYear,
    required this.name,
    required this.lineage,
  }) : rng = Random(seed) {
    // Drawn before anything else, so the family's id depends on the seed alone.
    // It must not move when [currentYear] does: the development entry point
    // uses it to tell whether this family has already been installed, and a
    // year rolling over would otherwise install a second copy.
    familyId = _nextId();
  }

  final int generations;
  final int people;
  final int seed;
  final int currentYear;
  final String name;
  final String lineage;
  final Random rng;

  /// The year the progenitor was born, chosen so the youngest generation lands
  /// twenty years short of [currentYear] — old enough that nobody is born in
  /// the future, young enough that the last generation is still alive.
  late final int founderYear =
      currentYear - 20 - (generations - 1) * _meanGenerationYears;

  /// The clock [newId] is handed, so that ids are reproducible and still sort
  /// in creation order the way UUID v7 promises.
  static final DateTime _idEpoch = DateTime.utc(2026, 1, 1);
  int _idTick = 0;

  late final String familyId;

  final List<_Draft> _drafts = <_Draft>[];
  final List<Relationship> _relationships = <Relationship>[];

  String _nextId() => newId(
    at: _idEpoch.add(Duration(milliseconds: _idTick++)),
    random: rng,
  );

  /// True [percent] of the time.
  bool _chance(int percent) => rng.nextInt(100) < percent;

  T _pick<T>(List<T> from) => from[rng.nextInt(from.length)];

  SyntheticFamily build() {
    final targets = _generationTargets();

    var unions = _foundingGeneration(targets[0]);
    var carry = targets[0] - (1 + unions.length);

    for (var generation = 1; generation < generations; generation++) {
      final grown = _growGeneration(
        generation: generation,
        unions: unions,
        target: targets[generation] + carry,
        isLast: generation == generations - 1,
      );
      unions = grown.unions;
      carry = grown.carry;
    }

    _assignDeaths();
    _hideAFewBirthDates();

    return SyntheticFamily(
      family: Family(
        id: familyId,
        name: name,
        description:
            'Dữ liệu tổng hợp: $generations đời, ${_drafts.length} người, '
            'seed $seed. Không phải người thật.',
        // A Vietnamese family keeps its anniversaries by the lunar calendar, so
        // the flag is on. No lunar date is fabricated on any record: an invented
        // conversion would later be indistinguishable from a conversion bug.
        usesLunarCalendar: true,
      ),
      persons: <Person>[for (final draft in _drafts) _toPerson(draft)],
      relationships: List<Relationship>.unmodifiable(_relationships),
      generationOf: <String, int>{
        for (final draft in _drafts) draft.id: draft.generation,
      },
    );
  }

  // ------------------------------------------------------------- the shape ---

  /// How many people each generation should hold.
  ///
  /// Weighted by `g + 1` so the tree widens toward the present, and allocated
  /// from a running cumulative total so the rounding errors cancel instead of
  /// accumulating — the parts add up to [people] exactly.
  List<int> _generationTargets() {
    final totalWeight = generations * (generations + 1) ~/ 2;
    final targets = <int>[];

    var assigned = 0;
    var cumulativeWeight = 0;
    for (var generation = 0; generation < generations; generation++) {
      cumulativeWeight += generation + 1;
      final upTo = (people * cumulativeWeight / totalWeight).round();
      targets.add(upTo - assigned);
      assigned = upTo;
    }

    // A generation of one cannot marry and the line stops there. Two is the
    // least that carries it forward, so thin generations borrow from the widest
    // — which the `people >= generations * 2` check guarantees is possible.
    for (var generation = 0; generation < generations; generation++) {
      while (targets[generation] < 2) {
        final donor = _widestIndex(targets);
        if (targets[donor] <= 2) break;
        targets[donor]--;
        targets[generation]++;
      }
    }

    return targets;
  }

  static int _widestIndex(List<int> targets) {
    var best = 0;
    for (var i = 1; i < targets.length; i++) {
      if (targets[i] > targets[best]) best = i;
    }
    return best;
  }

  // ------------------------------------------------------- the generations ---

  /// The progenitor and his wife, plus a second wife if the budget allows.
  ///
  /// Putting a remarriage at the very top is deliberate: it is the most visible
  /// place in the chart, and the layout draws two marriages differently from
  /// one.
  List<_Union> _foundingGeneration(int target) {
    final founder = _bornIntoLine(generation: 0, sex: Sex.male);

    final unions = <_Union>[_union(founder, _marryIn(founder, 0))];
    if (target >= 4) {
      unions.add(_union(founder, _marryIn(founder, 0)));
    }
    return unions;
  }

  /// Fills one generation from the previous generation's unions.
  ///
  /// The budget covers both the children born and the spouses who marry in, so
  /// that the generation ends up the width [_generationTargets] asked for.
  /// Anything it could not place — too few couples to carry that many children
  /// — is carried into the next generation rather than lost.
  ({List<_Union> unions, int carry}) _growGeneration({
    required int generation,
    required List<_Union> unions,
    required int target,
    required bool isLast,
  }) {
    if (unions.isEmpty) return (unions: unions, carry: target);

    // The youngest generation still holds a few young couples — they simply
    // have no children yet — but most of it is unmarried.
    final marriageShare = isLast ? 0.15 : 0.45;

    // Never ask more of the couples than [_maximumChildren] each. Early
    // generations are the ones that ask: a tree of eight generations holding
    // five hundred people wants forty in generation one, and one couple cannot
    // plausibly supply that. The surplus is carried rather than forced, which
    // pushes the width down the tree — where a real family's width is anyway.
    final capacity = unions.length * _maximumChildren;
    final childBudget = min(
      max(1, (target / (1 + marriageShare)).round()),
      capacity,
    );

    final born = _bearChildren(
      generation: generation,
      unions: unions,
      budget: childBudget,
    );

    final wanted = target - born.length;
    var marriages = wanted.clamp(0, born.length);
    if (!isLast && marriages < 1 && born.isNotEmpty) marriages = 1;

    final married = _marryOff(
      generation: generation,
      born: born,
      marriages: marriages,
    );

    var fertile = <_Union>[
      for (final union in married)
        if (union.continuesTheLine) union,
    ];
    if (fertile.isEmpty && married.isNotEmpty && !isLast) {
      // A generation that produced no sons. The record follows a daughter
      // rather than stopping short of the depth that was asked for.
      fertile = <_Union>[married.first];
    }

    return (unions: fertile, carry: target - born.length - marriages);
  }

  /// Distributes [budget] children across [unions].
  ///
  /// Family size is drawn uniformly around the average each union would need to
  /// carry, rather than fixed at it. A generation of eleven identical families
  /// of three would tell nothing about how the chart copes with an only child
  /// beside a family of nine.
  List<_Draft> _bearChildren({
    required int generation,
    required List<_Union> unions,
    required int budget,
  }) {
    final born = <_Draft>[];
    final order = List<_Union>.of(unions)..shuffle(rng);
    final counts = List<int>.filled(order.length, 0);
    final average = (budget / order.length).ceil();

    for (var i = 0; i < order.length && born.length < budget; i++) {
      final size = min(1 + rng.nextInt(max(1, average * 2)), _maximumChildren);
      for (var k = 0; k < size && born.length < budget; k++) {
        born.add(_beget(order[i], generation));
        counts[i]++;
      }
    }

    // A short pass: family sizes drawn low can leave the budget unfilled. One
    // child at a time, and only to a union with room left — the cap has to hold
    // here too, or it is merely a suggestion the first pass follows.
    while (born.length < budget) {
      final withRoom = <int>[
        for (var i = 0; i < order.length; i++)
          if (counts[i] < _maximumChildren) i,
      ];
      if (withRoom.isEmpty) break;

      final at = _pick(withRoom);
      born.add(_beget(order[at], generation));
      counts[at]++;
    }

    return born;
  }

  /// Marries [marriages] of the newly born, bringing a spouse in for each.
  ///
  /// Sons are married off first, because only their unions carry the record
  /// forward and a generation of married daughters would end the tree. Some
  /// daughters marry too — they belong in the book with their husbands, and a
  /// branch that visibly stops is part of what a gia phả looks like.
  ///
  /// A small share are second wives of a man already married in this same pass,
  /// which is what puts two marriages side by side in the chart.
  List<_Union> _marryOff({
    required int generation,
    required List<_Draft> born,
    required int marriages,
  }) {
    if (marriages == 0) return const <_Union>[];

    final remarriages = (marriages * 0.12).round();
    final firstMarriages = max(1, marriages - remarriages);

    final sons = <_Draft>[
      for (final person in born)
        if (person.sex != Sex.female) person,
    ]..shuffle(rng);
    final daughters = <_Draft>[
      for (final person in born)
        if (person.sex == Sex.female) person,
    ]..shuffle(rng);

    final sonQuota = min(
      sons.length,
      max(1, (firstMarriages * 0.75).round()),
    );
    final chosen = <_Draft>[
      ...sons.take(sonQuota),
      ...daughters.take(firstMarriages - sonQuota),
    ];
    // Whichever side ran short, fill from the other so the budget is met.
    for (final person in <_Draft>[...sons.skip(sonQuota), ...daughters]) {
      if (chosen.length >= firstMarriages) break;
      if (!chosen.contains(person)) chosen.add(person);
    }

    final unions = <_Union>[
      for (final person in chosen) _union(person, _marryIn(person, generation)),
    ];

    // Only a line member takes a second spouse. Modelling the reverse would be
    // just as valid for the schema, but it is not what a gia phả records, and
    // the point of this data is to look like one.
    // Each man appears here once and is removed when chosen, so nobody takes a
    // third wife. Two marriages is the case the chart has to draw; three would
    // only widen a node nothing else tests.
    final remarrying = <_Draft>[
      for (final union in unions)
        if (union.continuesTheLine) union.husband,
    ]..shuffle(rng);

    for (var i = 0; i < marriages - firstMarriages; i++) {
      if (remarrying.isEmpty) break;
      final husband = remarrying.removeLast();
      unions.add(_union(husband, _marryIn(husband, generation)));
    }

    return unions;
  }

  /// Pairs two people and records the marriage.
  _Union _union(_Draft a, _Draft b) {
    _relationships.add(
      Relationship.spouse(
        id: _nextId(),
        familyId: familyId,
        personA: a.id,
        personB: b.id,
      ),
    );
    return a.sex == Sex.female
        ? _Union(husband: b, wife: a)
        : _Union(husband: a, wife: b);
  }

  /// A child of [union], linked to its parents.
  ///
  /// One in twelve is linked to the father alone. Records where the mother went
  /// unnamed are ordinary in an old gia phả, and a person with one known parent
  /// is a case the sibling and layout code has to handle.
  _Draft _beget(_Union union, int generation) {
    final child = _bornIntoLine(generation: generation, sex: _childSex());

    final parents = _chance(8)
        ? <_Draft>[union.husband]
        : <_Draft>[union.husband, union.wife];

    for (final parent in parents) {
      _relationships.add(
        Relationship.parentChild(
          id: _nextId(),
          familyId: familyId,
          parent: parent.id,
          child: child.id,
        ),
      );
      final last = parent.lastChildBirthYear;
      if (last == null || child.birthYear > last) {
        parent.lastChildBirthYear = child.birthYear;
      }
    }

    return child;
  }

  /// Where a generation's births fall.
  ///
  /// Read from the generation index rather than from the parents, which is the
  /// one decision here that matters. Deriving each birth from its parent's makes
  /// the error compound: eleven generations of "twenty-two to thirty-four years
  /// later" wander by over a decade, branch by branch, and the youngest
  /// generation ends up born after [currentYear]. Clamping it back then squeezes
  /// the last parent-child gap to nothing and every one of those edges earns an
  /// implausible-parent-age warning.
  ///
  /// A fixed window per generation cannot drift. Twenty-eight years apart with
  /// four years of play at each end puts every parent-child gap between sixteen
  /// and forty — a spouse adds at most four more — which sits inside the
  /// twelve-to-seventy band `relationship_rules.dart` warns outside of, at both
  /// ends, for every generated edge.
  int _birthYearIn(int generation) =>
      founderYear + generation * _meanGenerationYears + _play();

  /// A few years either side, so siblings are not all born in one year.
  int _play() => rng.nextInt(_playYears * 2 + 1) - _playYears;

  Sex _childSex() {
    if (_chance(2)) return Sex.unknown;
    return _chance(52) ? Sex.male : Sex.female;
  }

  // ------------------------------------------------------------ the people ---

  /// Somebody born into this line, carrying its surname.
  _Draft _bornIntoLine({required int generation, required Sex sex}) => _record(
    generation: generation,
    sex: sex,
    surname: lineage,
    birthYear: _birthYearIn(generation),
    marriedIn: false,
  );

  /// Somebody who married [partner], from another surname.
  ///
  /// Born within a few years of their partner rather than from the generation
  /// window, because a couple born a decade apart reads as an error even when
  /// no rule objects.
  _Draft _marryIn(_Draft partner, int generation) {
    final sex = switch (partner.sex) {
      Sex.male => Sex.female,
      Sex.female => Sex.male,
      Sex.unknown => Sex.female,
    };
    var surname = _pick(_surnames);
    while (surname == lineage) {
      surname = _pick(_surnames);
    }

    return _record(
      generation: generation,
      sex: sex,
      surname: surname,
      birthYear: partner.birthYear + _play(),
      marriedIn: true,
    );
  }

  _Draft _record({
    required int generation,
    required Sex sex,
    required String surname,
    required int birthYear,
    required bool marriedIn,
  }) {
    final draft = _Draft(
      id: _nextId(),
      generation: generation,
      sex: sex,
      surname: surname,
      // An unknown sex gets no middle name: every one of them would otherwise
      // say Văn or Thị, contradicting the field beside it.
      middle: switch (sex) {
        Sex.male => _pick(_maleMiddleNames),
        Sex.female => _pick(_femaleMiddleNames),
        Sex.unknown => null,
      },
      given: sex == Sex.female ? _pick(_femaleNames) : _pick(_maleNames),
      birthYear: birthYear,
      birthDate: _dateIn(birthYear, allowApproximate: true),
      marriedIn: marriedIn,
      birthPlace: _chance(65) ? _pick(_places) : null,
      biography: _chance(14) ? _pick(_notes) : null,
    );
    _drafts.add(draft);
    return draft;
  }

  // ------------------------------------------------------------ the deaths ---

  /// Decides who has died, once every birth is known.
  ///
  /// Two constraints hold for everyone: a death never precedes the birth of
  /// their last child, and no life runs past a hundred years. Both keep the
  /// data free of validation warnings whatever the lifespan threshold is set
  /// to.
  void _assignDeaths() {
    for (final draft in _drafts) {
      final age = currentYear - draft.birthYear;
      final died = switch (age) {
        > 95 => true,
        > 60 => _chance(55),
        _ => _chance(3),
      };
      if (!died) continue;

      // A death known only by where it happened. `Person.hasDied` reads a place
      // as proof of death just as it reads a date, and this is the case that
      // separates the two — no age can be worked out from it.
      if (_chance(15)) {
        draft.deathPlace = _pick(_places);
        continue;
      }

      final childless = draft.lastChildBirthYear == null;
      final lifespan = childless && _chance(12)
          ? rng.nextInt(12) // an infant, or a child who did not grow up
          : 48 + rng.nextInt(41);

      // Order matters. Nobody dies in the future, so that cap comes first; the
      // floor is applied after it, because raising a death to meet a child's
      // birth must not be undone. A lifespan cap cannot then breach the floor:
      // the floor is at most forty years past the birth.
      var deathYear = min(draft.birthYear + lifespan, currentYear);
      final floor = draft.lastChildBirthYear ?? draft.birthYear;
      if (deathYear < floor) deathYear = floor;
      if (deathYear - draft.birthYear > _maximumGeneratedLifespan) {
        deathYear = draft.birthYear + _maximumGeneratedLifespan;
      }

      draft.deathDate = _dateIn(deathYear, allowApproximate: true);
      if (_chance(35)) draft.deathPlace = _pick(_places);
    }
  }

  /// Drops the birth date of a few childless people.
  ///
  /// Childless on purpose: a missing date is a case the profile and the list
  /// both have to render, but removing a parent's would also remove what the
  /// sibling ordering reads.
  void _hideAFewBirthDates() {
    for (final draft in _drafts) {
      if (draft.lastChildBirthYear != null) continue;
      if (_chance(7)) draft.birthDateHidden = true;
    }
  }

  /// A date at whatever precision that era's records would plausibly carry.
  ///
  /// Old entries are a bare year, often approximate; recent ones are complete.
  /// The day never exceeds 28, which is valid in every month of every year, so
  /// the constructor's calendar check can never be tripped.
  GenealogicalDate _dateIn(int year, {required bool allowApproximate}) {
    if (year < 1900) {
      return GenealogicalDate(
        year: year,
        month: _chance(20) ? 1 + rng.nextInt(12) : null,
        isApproximate: allowApproximate && _chance(30),
      );
    }
    if (year < 1975) {
      if (_chance(45)) {
        return GenealogicalDate(
          year: year,
          month: 1 + rng.nextInt(12),
          day: 1 + rng.nextInt(28),
        );
      }
      return GenealogicalDate(
        year: year,
        month: _chance(55) ? 1 + rng.nextInt(12) : null,
      );
    }
    return _chance(85)
        ? GenealogicalDate(
            year: year,
            month: 1 + rng.nextInt(12),
            day: 1 + rng.nextInt(28),
          )
        : GenealogicalDate(year: year);
  }

  // ------------------------------------------------------------ the result ---

  Person _toPerson(_Draft draft) {
    final middle = draft.middle;
    final displayName = middle == null
        ? '${draft.surname} ${draft.given}'
        : '${draft.surname} $middle ${draft.given}';

    return Person(
      id: draft.id,
      familyId: familyId,
      displayName: displayName,
      givenName: draft.given,
      additionalNames: middle,
      familyName: draft.surname,
      // A Vietnamese woman keeps her own surname on marriage, so both fields
      // hold the same họ. Recording it anyway is what a gia phả does: it is how
      // her own branch is named.
      birthFamilyName: draft.marriedIn ? draft.surname : null,
      sex: draft.sex,
      birthDate: draft.birthDateHidden ? null : draft.birthDate,
      deathDate: draft.deathDate,
      birthPlace: draft.birthPlace,
      deathPlace: draft.deathPlace,
      biography: draft.biography,
    );
  }
}

/// Years between one generation's births and the next, which puts twelve
/// generations across three centuries — the span a well-kept gia phả covers.
const int _meanGenerationYears = 28;

/// How far either side of its generation's year a birth may fall.
///
/// Small on purpose. Widening it to eight would let a parent's play and a
/// spouse's stack up to twenty years, closing on the twelve-year floor
/// `relationship_rules.dart` warns below. Four keeps every gap between sixteen
/// and forty whatever the draws are.
const int _playYears = 4;

/// Nine children in one family is a lot and does happen; more usually means a
/// record that has merged two families.
const int _maximumChildren = 9;

/// No generated life runs longer than this.
///
/// Comfortably under `maximumPlausibleLifespanYears` so that the data stays
/// warning-free even if that threshold is lowered.
const int _maximumGeneratedLifespan = 100;

// ------------------------------------------------------------------ names ---

const List<String> _surnames = <String>[
  'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ',
  'Võ', 'Đặng', 'Bùi', 'Đỗ', 'Hồ', 'Ngô', 'Dương', 'Lý',
  'Đinh', 'Tô', 'Trịnh', 'Đoàn', 'Mai', 'Cao', 'Lưu', 'Chu',
];

const List<String> _maleMiddleNames = <String>[
  'Văn', 'Hữu', 'Đức', 'Quang', 'Xuân', 'Bá', 'Đình', 'Công',
  'Mạnh', 'Thế', 'Trọng', 'Duy', 'Tiến', 'Khắc', 'Ngọc', 'Danh',
];

const List<String> _femaleMiddleNames = <String>[
  'Thị', 'Ngọc', 'Thu', 'Kim', 'Thanh', 'Bích', 'Diệu', 'Phương',
  'Mỹ', 'Hồng', 'Lan', 'Tuyết', 'Xuân', 'Hải',
];

const List<String> _maleNames = <String>[
  'An', 'Bình', 'Cường', 'Dũng', 'Đạt', 'Giang', 'Hải', 'Hùng',
  'Khang', 'Khoa', 'Lâm', 'Long', 'Minh', 'Nam', 'Ninh', 'Phong',
  'Phúc', 'Quân', 'Sơn', 'Tâm', 'Thành', 'Thắng', 'Tiến', 'Toàn',
  'Trung', 'Tuấn', 'Vinh', 'Vượng', 'Bảo', 'Chương', 'Hoà', 'Kiên',
];

const List<String> _femaleNames = <String>[
  'Ánh', 'Bích', 'Chi', 'Dung', 'Duyên', 'Hà', 'Hạnh', 'Hoa',
  'Hương', 'Lan', 'Liên', 'Linh', 'Mai', 'Nga', 'Ngân', 'Nhung',
  'Oanh', 'Phượng', 'Quỳnh', 'Thảo', 'Thu', 'Thuỷ', 'Trang', 'Tuyết',
  'Vân', 'Yến', 'Đào', 'Hiền', 'Loan', 'Nhàn',
];

const List<String> _places = <String>[
  'Làng Đông Ngạc, Từ Liêm, Hà Nội',
  'Kim Bảng, Hà Nam',
  'Thanh Oai, Hà Đông',
  'Làng Hành Thiện, Xuân Trường, Nam Định',
  'Quỳnh Đôi, Quỳnh Lưu, Nghệ An',
  'Tiên Điền, Nghi Xuân, Hà Tĩnh',
  'Vĩnh Bảo, Hải Phòng',
  'Đường Lâm, Sơn Tây',
  'Bát Tràng, Gia Lâm',
  'Kiến Xương, Thái Bình',
  'Duy Xuyên, Quảng Nam',
  'Chợ Lách, Bến Tre',
  'Cai Lậy, Tiền Giang',
  'Phú Vang, Thừa Thiên Huế',
];

const List<String> _notes = <String>[
  'Đỗ tú tài, dạy học trong làng.',
  'Làm nghề thuốc bắc, chữa bệnh cho cả tổng.',
  'Di cư vào Nam năm 1954.',
  'Trông coi từ đường của chi.',
  'Đi lính, không rõ ngày về.',
  'Nghề mộc, dựng đình làng năm Tân Mão.',
  'Buôn tơ lụa ngược sông Hồng.',
  'Là con nuôi, gia phả cũ chép là con thứ.',
  'Không có con, hương hoả giao cho cháu gọi bằng bác.',
  'Bản gia phả gốc chép tên khác, chưa rõ đúng sai.',
];
