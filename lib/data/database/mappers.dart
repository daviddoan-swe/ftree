/// Translation between database rows and domain entities.
///
/// Kept as plain functions rather than methods on either side: the domain must
/// not know Drift exists, and the tables are generated. Being pure also means
/// the round-trip tests need no database at all.
///
/// Dates are the delicate part. A [GenealogicalDate] carries precision in which
/// components are present, and that precision is what §4.2 says can never be
/// recovered once lost. Every function here is written so that what goes in
/// comes back identical, and the tests assert exactly that.
library;

import 'package:drift/drift.dart';

import '../../domain/family.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import 'app_database.dart';

// ---------------------------------------------------------------- Family ---

/// Reads a [Family] from its row.
Family familyFromRow(FamilyRow row) => Family(
  id: row.id,
  name: row.name,
  description: row.description,
  usesLunarCalendar: row.usesLunarCalendar,
);

/// Writes a [Family] for insert or update.
///
/// [updatedAt] is supplied rather than read from a clock so that callers stay
/// testable, and because the domain entity deliberately carries no timestamp
/// (§15.2).
FamiliesCompanion familyToRow(Family family, {required DateTime updatedAt}) =>
    FamiliesCompanion.insert(
      id: family.id,
      name: family.name,
      description: Value<String?>(family.description),
      usesLunarCalendar: Value<bool>(family.usesLunarCalendar),
      updatedAt: updatedAt,
    );

// ---------------------------------------------------------------- Person ---

/// Reads a [Person] from its row.
Person personFromRow(PersonRow row) => Person(
  id: row.id,
  familyId: row.familyId,
  displayName: row.displayName,
  givenName: row.givenName,
  additionalNames: row.additionalNames,
  familyName: row.familyName,
  birthFamilyName: row.birthFamilyName,
  sex: row.sex,
  birthDate: _dateFrom(
    iso: row.birthDateIso,
    approximate: row.birthDateApproximate,
    lunarYear: row.birthLunarYear,
    lunarMonth: row.birthLunarMonth,
    lunarDay: row.birthLunarDay,
    lunarIsLeapMonth: row.birthLunarIsLeapMonth,
  ),
  deathDate: _dateFrom(
    iso: row.deathDateIso,
    approximate: row.deathDateApproximate,
    lunarYear: row.deathLunarYear,
    lunarMonth: row.deathLunarMonth,
    lunarDay: row.deathLunarDay,
    lunarIsLeapMonth: row.deathLunarIsLeapMonth,
  ),
  birthPlace: row.birthPlace,
  deathPlace: row.deathPlace,
  biography: row.biography,
  profileMediaRef: row.profileMediaRef,
);

/// Writes a [Person] for insert or update.
PersonsCompanion personToRow(Person person, {required DateTime updatedAt}) {
  final birth = person.birthDate;
  final death = person.deathDate;

  return PersonsCompanion.insert(
    id: person.id,
    familyId: person.familyId,
    displayName: person.displayName,
    givenName: Value<String?>(person.givenName),
    additionalNames: Value<String?>(person.additionalNames),
    familyName: Value<String?>(person.familyName),
    birthFamilyName: Value<String?>(person.birthFamilyName),
    sex: person.sex,
    birthDateIso: Value<String?>(birth?.toIso()),
    birthDateApproximate: Value<bool>(birth?.isApproximate ?? false),
    birthLunarYear: Value<int?>(birth?.lunar?.year),
    birthLunarMonth: Value<int?>(birth?.lunar?.month),
    birthLunarDay: Value<int?>(birth?.lunar?.day),
    birthLunarIsLeapMonth: Value<bool>(birth?.lunar?.isLeapMonth ?? false),
    deathDateIso: Value<String?>(death?.toIso()),
    deathDateApproximate: Value<bool>(death?.isApproximate ?? false),
    deathLunarYear: Value<int?>(death?.lunar?.year),
    deathLunarMonth: Value<int?>(death?.lunar?.month),
    deathLunarDay: Value<int?>(death?.lunar?.day),
    deathLunarIsLeapMonth: Value<bool>(death?.lunar?.isLeapMonth ?? false),
    birthPlace: Value<String?>(person.birthPlace),
    deathPlace: Value<String?>(person.deathPlace),
    biography: Value<String?>(person.biography),
    profileMediaRef: Value<String?>(person.profileMediaRef),
    updatedAt: updatedAt,
  );
}

// ---------------------------------------------------------- Relationship ---

/// Reads a [Relationship] from its row.
///
/// Rebuilds through the named factories rather than a general constructor, so
/// the endpoint columns are interpreted by type: directional for parentChild,
/// canonically ordered for spouse (§5.1). Re-sorting an already-sorted spouse
/// pair changes nothing.
Relationship relationshipFromRow(RelationshipRow row) => switch (row.type) {
  RelationshipType.parentChild => Relationship.parentChild(
    id: row.id,
    familyId: row.familyId,
    parent: row.personAId,
    child: row.personBId,
  ),
  RelationshipType.spouse => Relationship.spouse(
    id: row.id,
    familyId: row.familyId,
    personA: row.personAId,
    personB: row.personBId,
  ),
};

/// Writes a [Relationship] for insert or update.
RelationshipsCompanion relationshipToRow(
  Relationship relationship, {
  required DateTime updatedAt,
}) => RelationshipsCompanion.insert(
  id: relationship.id,
  familyId: relationship.familyId,
  type: relationship.type,
  personAId: relationship.personAId,
  personBId: relationship.personBId,
  updatedAt: updatedAt,
);

// ------------------------------------------------------------------ dates ---

/// Rebuilds a date from its six columns, or null when no date was recorded.
///
/// The ISO text decides whether there is a date at all. A lunar reading without
/// a Gregorian one cannot be stored, because the Gregorian value is mandatory
/// and the lunar one is an annotation on it (§4.4).
GenealogicalDate? _dateFrom({
  required String? iso,
  required bool approximate,
  required int? lunarYear,
  required int? lunarMonth,
  required int? lunarDay,
  required bool lunarIsLeapMonth,
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
            isLeapMonth: lunarIsLeapMonth,
          ),
  );
}
