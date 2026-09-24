/// A gia phả as a file somebody can keep, send, and read (PRODUCT.md §9.1).
///
/// The application stores everything in one SQLite file inside its own private
/// directory, which both platforms delete when the application is uninstalled.
/// Until cloud synchronisation exists, this is the only way a family's record
/// survives a reinstall or reaches a relative.
///
/// **JSON rather than a copy of the database file.** Copying `ftree.sqlite`
/// would be less work and exact, but it can only ever *replace* what the
/// receiving device holds — two relatives could not each contribute. JSON can
/// be merged, and merging is the whole point: the ids in it are globally
/// unique (DOMAIN.md §14.1), so two people's exports never collide.
///
/// **JSON rather than GEDCOM, for this job.** GEDCOM is the international
/// interchange format — written by genealogists in 1984 and read by every
/// serious program since — and a GEDCOM export is worth adding. It is not what
/// this file is for, and two reasons keep it from being:
///
/// * **No lunar calendar.** The version everything actually supports names
///   Gregorian, Julian, Hebrew, French Republican and Roman. There is no
///   Chinese or Vietnamese lunisolar calendar in it, and a giỗ is kept by the
///   lunar date (DOMAIN.md §4.4).
/// * **Its identifiers are local to the file.** `@I1@` means "the first
///   individual in *this* file" — so merging two exports is exactly the
///   collision problem UUID v7 exists to avoid (§14.1). GEDCOM 7 adds a stable
///   `UID`, but the format in universal use does not have one.
///
/// What GEDCOM handles *well* is the thing this comment previously and wrongly
/// said it could not: partial and approximate dates are native to it — `1887`,
/// `MAR 1887`, `ABT 1890`, `BET 1880 AND 1890`. It was designed by people with
/// the same problem.
///
/// The two formats do different jobs. GEDCOM takes a family *out* to other
/// software; this file backs one up and merges it between two copies of this
/// application. Neither replaces the other.
///
/// ## The format
///
/// ```json
/// {
///   "format": "ftree.family",
///   "version": 1,
///   "exportedAt": "2026-09-23T10:00:00.000Z",
///   "family": { "id": "...", "name": "Họ Nguyễn" },
///   "persons": [ { "id": "...", "displayName": "Nguyễn Văn Cả", ... } ],
///   "relationships": [ { "id": "...", "type": "parentChild", ... } ]
/// }
/// ```
///
/// `version` is not decoration. A file outlives the application that wrote it,
/// and a reader that guesses at a shape it does not know will write nonsense
/// into somebody's family record. An unrecognised version is refused by name.
///
/// Fields that are null are left out, so a file stays readable by eye — which
/// matters for something a person may have to inspect or repair by hand.
///
/// ## What the file deliberately does not carry
///
/// **No tombstones.** The repository filters deleted rows on read, so an export
/// holds only what is live. The consequence is worth stating: importing an old
/// file can bring back somebody deleted since it was written. Carrying
/// tombstones would fix that, but `deletedAt` belongs to the persistence layer
/// and the domain entities do not have it (DOMAIN.md §15.2) — exposing it here
/// would push a persistence concern into a format relatives exchange. Revisit
/// when synchronisation arrives and the question has to be answered properly.
///
/// **No `updatedAt`.** It is metadata, never a conflict resolver (§15.3), and
/// the merge here does not resolve conflicts at all — it only adds what is
/// missing.
library;

import 'dart:convert';

import '../../domain/family.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';

/// What every file of this kind says it is.
const String familyFileFormat = 'ftree.family';

/// The format this build writes, and the only one it reads.
const int familyFileVersion = 1;

/// A decoded file, before anything has been done with it.
final class FamilyFile {
  const FamilyFile({
    required this.family,
    required this.persons,
    required this.relationships,
    this.exportedAt,
  });

  final Family family;
  final List<Person> persons;
  final List<Relationship> relationships;

  /// When the file was written, if it said.
  ///
  /// Shown to the reader so they can tell an old export from a recent one. It
  /// decides nothing: it is a clock reading from somebody else's device.
  final DateTime? exportedAt;
}

/// A file that cannot be read, with a reason fit to show somebody.
///
/// Not an [ArgumentError]: a malformed file is an ordinary thing that happens
/// to users — the wrong file picked, a truncated download, an edit by hand —
/// rather than a defect in the calling code.
final class FamilyFileException implements Exception {
  const FamilyFileException(this.reason);

  final String reason;

  @override
  String toString() => 'FamilyFileException: $reason';
}

/// Writes [family] and its people and edges as the text of a file.
///
/// [at] is passed rather than read from a clock so callers stay testable, the
/// same reason `updatedAt` is passed into the row mappers.
String encodeFamilyFile({
  required Family family,
  required Iterable<Person> persons,
  required Iterable<Relationship> relationships,
  DateTime? at,
}) {
  final document = <String, Object?>{
    'format': familyFileFormat,
    'version': familyFileVersion,
    if (at != null) 'exportedAt': at.toUtc().toIso8601String(),
    'family': _familyToJson(family),
    'persons': <Object?>[for (final person in persons) _personToJson(person)],
    'relationships': <Object?>[
      for (final relationship in relationships) _relationshipToJson(relationship),
    ],
  };

  // Indented, because a file a person may have to open and look at is worth
  // two spaces per level. It roughly doubles the size of a large export and
  // costs nothing that matters for a file sent once.
  return const JsonEncoder.withIndent('  ').convert(document);
}

/// Reads a file written by [encodeFamilyFile].
///
/// Throws [FamilyFileException] for anything that is not one: text that is not
/// JSON, a document of another kind, a version this build does not know, or a
/// field that is missing or of the wrong type.
///
/// Nothing here checks whether the *contents* make sense as a family — that a
/// relationship's people exist, that no edge closes an ancestor cycle. Those
/// are graph questions, and they are asked where the file meets the family it
/// is being merged into.
FamilyFile decodeFamilyFile(String text) {
  final Object? parsed;
  try {
    parsed = jsonDecode(text);
  } on FormatException catch (e) {
    throw FamilyFileException('không phải JSON hợp lệ: ${e.message}');
  }

  if (parsed is! Map<String, Object?>) {
    throw const FamilyFileException('nội dung không phải một đối tượng JSON');
  }

  if (parsed['format'] != familyFileFormat) {
    throw FamilyFileException(
      'không phải file gia phả của ứng dụng này '
      '(format: ${parsed['format'] ?? 'không có'})',
    );
  }

  final version = parsed['version'];
  if (version != familyFileVersion) {
    // Named rather than glossed over. A newer file read by an older build is
    // the case that matters, and guessing at it would write a family record
    // that is quietly wrong.
    throw FamilyFileException(
      'file thuộc phiên bản định dạng $version, '
      'bản này chỉ đọc được phiên bản $familyFileVersion',
    );
  }

  final family = _familyFromJson(_object(parsed['family'], 'family'));

  return FamilyFile(
    family: family,
    exportedAt: DateTime.tryParse(_string(parsed['exportedAt']) ?? ''),
    persons: <Person>[
      for (final entry in _list(parsed['persons'], 'persons'))
        _personFromJson(_object(entry, 'persons[]'), family.id),
    ],
    relationships: <Relationship>[
      for (final entry in _list(parsed['relationships'], 'relationships'))
        _relationshipFromJson(_object(entry, 'relationships[]'), family.id),
    ],
  );
}

// ---------------------------------------------------------------- Family ---

Map<String, Object?> _familyToJson(Family family) => <String, Object?>{
  'id': family.id,
  'name': family.name,
  if (family.description != null) 'description': family.description,
  'usesLunarCalendar': family.usesLunarCalendar,
};

Family _familyFromJson(Map<String, Object?> json) => Family(
  id: _required(_string(json['id']), 'family.id'),
  name: _required(_string(json['name']), 'family.name'),
  description: _string(json['description']),
  usesLunarCalendar: _bool(json['usesLunarCalendar']) ?? false,
);

// ---------------------------------------------------------------- Person ---

Map<String, Object?> _personToJson(Person person) => <String, Object?>{
  'id': person.id,
  'displayName': person.displayName,
  if (person.givenName != null) 'givenName': person.givenName,
  if (person.additionalNames != null)
    'additionalNames': person.additionalNames,
  if (person.familyName != null) 'familyName': person.familyName,
  if (person.birthFamilyName != null)
    'birthFamilyName': person.birthFamilyName,
  'sex': person.sex.name,
  if (person.birthDate != null) 'birthDate': _dateToJson(person.birthDate!),
  if (person.deathDate != null) 'deathDate': _dateToJson(person.deathDate!),
  if (person.birthPlace != null) 'birthPlace': person.birthPlace,
  if (person.deathPlace != null) 'deathPlace': person.deathPlace,
  if (person.biography != null) 'biography': person.biography,
  if (person.profileMediaRef != null)
    'profileMediaRef': person.profileMediaRef,
};

/// [familyId] comes from the document rather than from each person.
///
/// Writing it once removes a way for a file to disagree with itself, and a
/// person carrying a different family id than the file they arrived in is a
/// question nothing here could answer.
Person _personFromJson(Map<String, Object?> json, String familyId) => Person(
  id: _required(_string(json['id']), 'person.id'),
  familyId: familyId,
  displayName: _required(_string(json['displayName']), 'person.displayName'),
  givenName: _string(json['givenName']),
  additionalNames: _string(json['additionalNames']),
  familyName: _string(json['familyName']),
  birthFamilyName: _string(json['birthFamilyName']),
  sex: _sexFromJson(json['sex']),
  birthDate: _dateFromJson(json['birthDate'], 'birthDate'),
  deathDate: _dateFromJson(json['deathDate'], 'deathDate'),
  birthPlace: _string(json['birthPlace']),
  deathPlace: _string(json['deathPlace']),
  biography: _string(json['biography']),
  profileMediaRef: _string(json['profileMediaRef']),
);

Sex _sexFromJson(Object? value) {
  final name = _string(value);
  if (name == null) return Sex.unknown;
  for (final sex in Sex.values) {
    if (sex.name == name) return sex;
  }
  // Not refused: an unfamiliar value is far more likely to be a newer build's
  // vocabulary than corruption, and losing a whole person over one field would
  // be the worse outcome. `unknown` is a first-class value here (DOMAIN.md
  // §3.2), so there is somewhere honest to put it.
  return Sex.unknown;
}

// ---------------------------------------------------------- Relationship ---

Map<String, Object?> _relationshipToJson(Relationship relationship) =>
    <String, Object?>{
      'id': relationship.id,
      'type': relationship.type.name,
      'personAId': relationship.personAId,
      'personBId': relationship.personBId,
    };

Relationship _relationshipFromJson(
  Map<String, Object?> json,
  String familyId,
) {
  final id = _required(_string(json['id']), 'relationship.id');
  final a = _required(_string(json['personAId']), 'relationship.personAId');
  final b = _required(_string(json['personBId']), 'relationship.personBId');
  final type = _string(json['type']);

  // The factories, not a general constructor: they are what keeps a spouse
  // edge's ids in canonical order, without which the same marriage written by
  // two devices would pass the uniqueness constraint twice (§5.1).
  return switch (type) {
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
    _ => throw FamilyFileException(
      'quan hệ "$id" mang loại không đọc được: ${type ?? 'không có'}',
    ),
  };
}

// ------------------------------------------------------------------ Date ---

/// The ISO-prefix form, exactly as the database stores it (DOMAIN.md §4.1).
///
/// `1887`, `1887-03`, `1887-03-05` — the precision lives in which components
/// are present, and that is the thing §4.2 says can never be recovered once
/// lost. A formatter that filled in the missing parts would lose it here, on
/// the way out of the application, where nobody would ever see it happen.
Map<String, Object?> _dateToJson(GenealogicalDate date) => <String, Object?>{
  'iso': date.toIso(),
  if (date.isApproximate) 'approximate': true,
  if (date.lunar != null) 'lunar': _lunarToJson(date.lunar!),
};

GenealogicalDate? _dateFromJson(Object? value, String field) {
  if (value == null) return null;
  final json = _object(value, field);
  final iso = _required(_string(json['iso']), '$field.iso');

  try {
    return GenealogicalDate.parseIso(
      iso,
      isApproximate: _bool(json['approximate']) ?? false,
      lunar: _lunarFromJson(json['lunar'], '$field.lunar'),
    );
  } on FormatException {
    throw FamilyFileException('$field không đúng dạng ngày: "$iso"');
  } on ArgumentError catch (e) {
    throw FamilyFileException('$field không phải ngày có thật: ${e.message}');
  }
}

Map<String, Object?> _lunarToJson(LunarDate lunar) => <String, Object?>{
  'year': lunar.year,
  if (lunar.month != null) 'month': lunar.month,
  if (lunar.day != null) 'day': lunar.day,
  if (lunar.isLeapMonth) 'leapMonth': true,
};

LunarDate? _lunarFromJson(Object? value, String field) {
  if (value == null) return null;
  final json = _object(value, field);

  try {
    return LunarDate(
      year: _required(_int(json['year']), '$field.year'),
      month: _int(json['month']),
      day: _int(json['day']),
      isLeapMonth: _bool(json['leapMonth']) ?? false,
    );
  } on ArgumentError catch (e) {
    throw FamilyFileException('$field không phải ngày âm có thật: ${e.message}');
  }
}

// ----------------------------------------------------------------- Types ---
//
// Read leniently, fail by name. A file arrives from outside the application,
// so every access has to survive the wrong type rather than throwing a
// TypeError the caller cannot explain to anybody.

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

Map<String, Object?> _object(Object? value, String field) =>
    value is Map<String, Object?>
    ? value
    : throw FamilyFileException('$field không phải một đối tượng JSON');

List<Object?> _list(Object? value, String field) => value is List<Object?>
    ? value
    : throw FamilyFileException('$field không phải một danh sách');

T _required<T>(T? value, String field) =>
    value ?? (throw FamilyFileException('thiếu trường bắt buộc: $field'));
