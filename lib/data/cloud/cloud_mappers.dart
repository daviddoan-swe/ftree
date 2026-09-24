/// Translation between Postgres rows and domain entities.
///
/// The counterpart of `data/database/mappers.dart`, which does the same job for
/// SQLite. Two mappers rather than one because the two stores spell their
/// columns differently — `display_name` against `displayName` — and a single
/// mapper would have to know both and choose.
///
/// Plain functions, as the other one is: the domain must not know either store
/// exists, and pure functions mean the round trip can be checked without a
/// server.
///
/// Dates are the delicate part, for the reason DOMAIN §4.2 gives: precision
/// lives in which components are present, and a date written back fuller than
/// it went in is a date the family never recorded. Every function here is
/// written so what goes in comes back identical.
library;

import '../../domain/family.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';

/// A row as PostgREST hands it over.
typedef Row = Map<String, dynamic>;

// ---------------------------------------------------------------- Family ---

Family familyFromRow(Row row) => Family(
  id: row['id'] as String,
  name: row['name'] as String,
  description: row['description'] as String?,
  usesLunarCalendar: row['uses_lunar_calendar'] as bool? ?? false,
);

/// [updatedAt] is passed rather than read from a clock, the same reason the
/// SQLite mapper takes it: a function that reads the time cannot be tested
/// twice with the same answer.
///
/// `deleted_at` is always null. Writing a row asserts that it exists, and a
/// tombstone asserts that it does not (§15.2). Omitted, an upsert over a
/// tombstoned row would land in the table and stay invisible.
Row familyToRow(Family family, {required DateTime updatedAt}) => <String, Object?>{
  'id': family.id,
  'name': family.name,
  'description': family.description,
  'uses_lunar_calendar': family.usesLunarCalendar,
  'updated_at': updatedAt.toUtc().toIso8601String(),
  'deleted_at': null,
};

// ---------------------------------------------------------------- Person ---

Person personFromRow(Row row) => Person(
  id: row['id'] as String,
  familyId: row['family_id'] as String,
  displayName: row['display_name'] as String,
  givenName: row['given_name'] as String?,
  additionalNames: row['additional_names'] as String?,
  familyName: row['family_name'] as String?,
  birthFamilyName: row['birth_family_name'] as String?,
  sex: _sexFrom(row['sex'] as String?),
  birthDate: _dateFrom(
    iso: row['birth_date_iso'] as String?,
    approximate: row['birth_date_approximate'] as bool? ?? false,
    lunarYear: row['birth_lunar_year'] as int?,
    lunarMonth: row['birth_lunar_month'] as int?,
    lunarDay: row['birth_lunar_day'] as int?,
    lunarIsLeap: row['birth_lunar_is_leap_month'] as bool? ?? false,
  ),
  deathDate: _dateFrom(
    iso: row['death_date_iso'] as String?,
    approximate: row['death_date_approximate'] as bool? ?? false,
    lunarYear: row['death_lunar_year'] as int?,
    lunarMonth: row['death_lunar_month'] as int?,
    lunarDay: row['death_lunar_day'] as int?,
    lunarIsLeap: row['death_lunar_is_leap_month'] as bool? ?? false,
  ),
  birthPlace: row['birth_place'] as String?,
  deathPlace: row['death_place'] as String?,
  biography: row['biography'] as String?,
  profileMediaRef: row['profile_media_ref'] as String?,
);

Row personToRow(Person person, {required DateTime updatedAt}) {
  final birth = person.birthDate;
  final death = person.deathDate;

  return <String, Object?>{
    'id': person.id,
    'family_id': person.familyId,
    'display_name': person.displayName,
    'given_name': person.givenName,
    'additional_names': person.additionalNames,
    'family_name': person.familyName,
    'birth_family_name': person.birthFamilyName,
    'sex': person.sex.name,

    'birth_date_iso': birth?.toIso(),
    'birth_date_approximate': birth?.isApproximate ?? false,
    'birth_lunar_year': birth?.lunar?.year,
    'birth_lunar_month': birth?.lunar?.month,
    'birth_lunar_day': birth?.lunar?.day,
    'birth_lunar_is_leap_month': birth?.lunar?.isLeapMonth ?? false,

    'death_date_iso': death?.toIso(),
    'death_date_approximate': death?.isApproximate ?? false,
    'death_lunar_year': death?.lunar?.year,
    'death_lunar_month': death?.lunar?.month,
    'death_lunar_day': death?.lunar?.day,
    'death_lunar_is_leap_month': death?.lunar?.isLeapMonth ?? false,

    'birth_place': person.birthPlace,
    'death_place': person.deathPlace,
    'biography': person.biography,
    'profile_media_ref': person.profileMediaRef,

    'updated_at': updatedAt.toUtc().toIso8601String(),
    'deleted_at': null,
  };
}

/// A value the enum does not know becomes [Sex.unknown] rather than an error.
///
/// `unknown` is a first-class value here (§3.2), so there is somewhere honest
/// to put a newer build's vocabulary, and losing a whole ancestor over one
/// field would be the worse outcome.
Sex _sexFrom(String? name) {
  for (final sex in Sex.values) {
    if (sex.name == name) return sex;
  }
  return Sex.unknown;
}

// ---------------------------------------------------------- Relationship ---

/// Rebuilt through the factories, never assigned across.
///
/// [Relationship.spouse] orders the two ids, which is what makes the
/// uniqueness constraint able to see that (B, A) is the marriage already
/// stored as (A, B) — §5.1.
Relationship relationshipFromRow(Row row) {
  final id = row['id'] as String;
  final familyId = row['family_id'] as String;
  final a = row['person_a_id'] as String;
  final b = row['person_b_id'] as String;

  return switch (row['type'] as String) {
    'parentChild' => Relationship.parentChild(
      id: id,
      familyId: familyId,
      parent: a,
      child: b,
    ),
    'spouse' => Relationship.spouse(
      id: id,
      familyId: familyId,
      personA: a,
      personB: b,
    ),
    final other => throw StateError('unknown relationship type: $other'),
  };
}

Row relationshipToRow(
  Relationship relationship, {
  required DateTime updatedAt,
}) => <String, Object?>{
  'id': relationship.id,
  'family_id': relationship.familyId,
  'type': relationship.type.name,
  'person_a_id': relationship.personAId,
  'person_b_id': relationship.personBId,
  'updated_at': updatedAt.toUtc().toIso8601String(),
  'deleted_at': null,
};

// ------------------------------------------------------------------ Date ---

GenealogicalDate? _dateFrom({
  required String? iso,
  required bool approximate,
  required int? lunarYear,
  required int? lunarMonth,
  required int? lunarDay,
  required bool lunarIsLeap,
}) {
  if (iso == null) return null;

  return GenealogicalDate.parseIso(
    iso,
    isApproximate: approximate,
    lunar: lunarYear == null
        ? null
        : LunarDate(
            year: lunarYear,
            month: lunarMonth,
            day: lunarDay,
            isLeapMonth: lunarIsLeap,
          ),
  );
}
