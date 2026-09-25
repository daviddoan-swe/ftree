/// A record flattened to named fields, for merging (ROADMAP M9, step 3).
///
/// Merging works a field at a time, so it needs a record as a map of names to
/// values that compare by equality — not as an object whose parts are objects.
/// A partial date is three numbers and a flag and possibly a lunar reading,
/// and two of them that mean the same thing have to be equal *here* or the
/// merge would see a disagreement where there is none.
///
/// The names are the ones the local database stores, so a base kept from one
/// version of the application still lines up with a record read by the next.
///
/// In the domain because merging is a rule about records rather than about
/// storage, and because it has to be testable without Flutter (CLAUDE §5).
library;

import 'genealogical_date.dart';
import 'person.dart';

/// [person] as flat fields.
///
/// `id` and `familyId` are left out on purpose. They are what says *which*
/// record this is; merging them would be merging two different people into
/// one, which is not a disagreement but a mistake.
Map<String, Object?> personFields(Person person) => <String, Object?>{
  'displayName': person.displayName,
  'givenName': person.givenName,
  'additionalNames': person.additionalNames,
  'familyName': person.familyName,
  'birthFamilyName': person.birthFamilyName,
  'sex': person.sex.name,
  ..._dateFields('birth', person.birthDate),
  ..._dateFields('death', person.deathDate),
  'birthPlace': person.birthPlace,
  'deathPlace': person.deathPlace,
  'biography': person.biography,
  'profileMediaRef': person.profileMediaRef,
};

/// Rebuilds a person from [fields], keeping [id] and [familyId] from [like].
///
/// Whatever a field is missing from, the value on [like] stands. A merge
/// produces every field it was given, so that only arises where a record has
/// grown one between versions.
Person personFromFields(Person like, Map<String, Object?> fields) {
  T pick<T>(String name, T fallback) =>
      fields.containsKey(name) ? fields[name] as T : fallback;

  return Person(
    id: like.id,
    familyId: like.familyId,
    displayName: pick<String>('displayName', like.displayName),
    givenName: pick<String?>('givenName', like.givenName),
    additionalNames: pick<String?>('additionalNames', like.additionalNames),
    familyName: pick<String?>('familyName', like.familyName),
    birthFamilyName: pick<String?>('birthFamilyName', like.birthFamilyName),
    sex: Sex.values.firstWhere(
      (s) => s.name == pick<String>('sex', like.sex.name),
      orElse: () => like.sex,
    ),
    birthDate: _dateFrom('birth', fields, like.birthDate),
    deathDate: _dateFrom('death', fields, like.deathDate),
    birthPlace: pick<String?>('birthPlace', like.birthPlace),
    deathPlace: pick<String?>('deathPlace', like.deathPlace),
    biography: pick<String?>('biography', like.biography),
    profileMediaRef: pick<String?>('profileMediaRef', like.profileMediaRef),
  );
}

/// A date as the fields it is stored as.
///
/// The ISO form carries its own precision — `1887`, `1887-03`, `1887-03-12` —
/// so a year-only date and a full one are different values rather than a full
/// one with holes, and comparing them is comparing strings (§4).
///
/// Split into parts rather than kept whole because the parts are edited
/// separately: somebody adding a lunar reading to a date whose Gregorian
/// reading is already right has changed one of these and not the other.
Map<String, Object?> _dateFields(String prefix, GenealogicalDate? date) =>
    <String, Object?>{
      '${prefix}DateIso': date?.toIso(),
      '${prefix}DateApproximate': date?.isApproximate,
      '${prefix}LunarYear': date?.lunar?.year,
      '${prefix}LunarMonth': date?.lunar?.month,
      '${prefix}LunarDay': date?.lunar?.day,
      '${prefix}LunarIsLeapMonth': date?.lunar?.isLeapMonth,
    };

GenealogicalDate? _dateFrom(
  String prefix,
  Map<String, Object?> fields,
  GenealogicalDate? fallback,
) {
  if (!fields.containsKey('${prefix}DateIso')) return fallback;

  final iso = fields['${prefix}DateIso'] as String?;

  // No Gregorian reading, no date — the same rule the storage mapper keeps.
  // A year is required (§4), so a lunar reading alone has nothing to hang on.
  if (iso == null) return null;

  final lunarYear = fields['${prefix}LunarYear'] as int?;

  return GenealogicalDate.parseIso(
    iso,
    isApproximate: (fields['${prefix}DateApproximate'] as bool?) ?? false,
    lunar: lunarYear == null
        ? null
        : LunarDate(
            year: lunarYear,
            month: fields['${prefix}LunarMonth'] as int?,
            day: fields['${prefix}LunarDay'] as int?,
            isLeapMonth:
                (fields['${prefix}LunarIsLeapMonth'] as bool?) ?? false,
          ),
  );
}
