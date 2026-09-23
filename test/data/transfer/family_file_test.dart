/// The file a family's record leaves the application in.
///
/// Everything here is ultimately one question: **does what goes in come back
/// identical?** A gia phả that loses a detail on the way out loses it where
/// nobody is looking — the record on the device is still right, and the file
/// somebody keeps as their backup is quietly wrong.
///
/// The delicate part is dates, for the reason DOMAIN.md §4.2 gives: precision
/// lives in which components are present, and once a year-only date has been
/// written out as a full one there is nothing left to recover it from.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/transfer/family_file.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  const familyId = 'f0000000-0000-7000-8000-000000000000';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  const family = Family(
    id: familyId,
    name: 'Họ Nguyễn',
    description: 'Gia phả tám đời',
    usesLunarCalendar: true,
  );

  Person personOf(int n, {GenealogicalDate? birth, GenealogicalDate? death}) =>
      Person(
        id: personId(n),
        familyId: familyId,
        displayName: 'Nguyễn Văn $n',
        birthDate: birth,
        deathDate: death,
      );

  /// Writes then reads, which is the only round trip that matters.
  FamilyFile through({
    Family of = family,
    List<Person> persons = const <Person>[],
    List<Relationship> relationships = const <Relationship>[],
    DateTime? at,
  }) => decodeFamilyFile(
    encodeFamilyFile(
      family: of,
      persons: persons,
      relationships: relationships,
      at: at,
    ),
  );

  group('a family comes back as it went', () {
    test('its name, notes, and whether it keeps the lunar calendar', () {
      final read = through().family;

      expect(read.id, family.id);
      expect(read.name, family.name);
      expect(read.description, family.description);
      expect(read.usesLunarCalendar, isTrue);
    });

    test('a family with nothing optional filled in', () {
      final read = through(
        of: const Family(id: familyId, name: 'Họ Trần'),
      ).family;

      expect(read.description, isNull);
      expect(read.usesLunarCalendar, isFalse);
    });

    test('when it was written, if it said', () {
      final at = DateTime.utc(2026, 9, 23, 10);

      expect(through(at: at).exportedAt, at);
      expect(through().exportedAt, isNull);
    });
  });

  group('a person comes back as they went', () {
    test('every field, including the ones rarely filled in', () {
      final full = Person(
        id: personId(1),
        familyId: familyId,
        displayName: 'Nguyễn Văn Cả',
        givenName: 'Cả',
        additionalNames: 'Văn',
        familyName: 'Nguyễn',
        birthFamilyName: 'Trần',
        sex: Sex.male,
        birthDate: GenealogicalDate(year: 1887, month: 3, day: 5),
        deathDate: GenealogicalDate(year: 1950),
        birthPlace: 'Nam Định',
        deathPlace: 'Hà Nội',
        biography: 'Cụ tổ đời thứ nhất.',
        profileMediaRef: 'media/abc',
      );

      final read = through(persons: <Person>[full]).persons.single;

      expect(read.id, full.id);
      expect(read.familyId, familyId);
      expect(read.displayName, full.displayName);
      expect(read.givenName, full.givenName);
      expect(read.additionalNames, full.additionalNames);
      expect(read.familyName, full.familyName);
      expect(read.birthFamilyName, full.birthFamilyName);
      expect(read.sex, Sex.male);
      expect(read.birthDate, full.birthDate);
      expect(read.deathDate, full.deathDate);
      expect(read.birthPlace, full.birthPlace);
      expect(read.deathPlace, full.deathPlace);
      expect(read.biography, full.biography);
      expect(read.profileMediaRef, full.profileMediaRef);
    });

    test('a person with only a name', () {
      final read = through(persons: <Person>[personOf(1)]).persons.single;

      expect(read.displayName, 'Nguyễn Văn 1');
      expect(read.givenName, isNull);
      expect(read.birthDate, isNull);
      expect(read.sex, Sex.unknown);
    });

    test('their family id comes from the document, not from each row', () {
      // Written once, so a file cannot disagree with itself about which
      // family it holds.
      final encoded = encodeFamilyFile(
        family: family,
        persons: <Person>[personOf(1)],
        relationships: const <Relationship>[],
      );

      expect(encoded, isNot(contains('"familyId"')));
      expect(decodeFamilyFile(encoded).persons.single.familyId, familyId);
    });
  });

  group('dates keep the precision they were recorded at', () {
    for (final (name, date) in <(String, GenealogicalDate)>[
      ('a year alone', GenealogicalDate(year: 1887)),
      ('a year and a month', GenealogicalDate(year: 1887, month: 3)),
      ('a full date', GenealogicalDate(year: 1887, month: 3, day: 5)),
      (
        'an approximate year',
        GenealogicalDate(year: 1890, isApproximate: true),
      ),
      (
        'a date with a lunar reading',
        GenealogicalDate(
          year: 1887,
          month: 3,
          day: 5,
          lunar: LunarDate(year: 1887, month: 2, day: 11),
        ),
      ),
      (
        'a lunar reading in a leap month',
        GenealogicalDate(
          year: 1887,
          month: 5,
          day: 23,
          lunar: LunarDate(year: 1887, month: 4, day: 2, isLeapMonth: true),
        ),
      ),
      (
        'a lunar reading known only to the year',
        GenealogicalDate(year: 1887, lunar: LunarDate(year: 1886)),
      ),
    ]) {
      test(name, () {
        final read = through(
          persons: <Person>[personOf(1, birth: date)],
        ).persons.single;

        expect(read.birthDate, date, reason: 'the date itself');
        expect(
          read.birthDate!.toIso(),
          date.toIso(),
          reason: 'and the precision it is written at',
        );
        expect(read.birthDate!.isApproximate, date.isApproximate);
        expect(read.birthDate!.lunar, date.lunar);
      });
    }

    test('a year-only date is not written out as a full one', () {
      // The failure this whole file exists to prevent, stated directly.
      final encoded = encodeFamilyFile(
        family: family,
        persons: <Person>[personOf(1, birth: GenealogicalDate(year: 1887))],
        relationships: const <Relationship>[],
      );

      expect(encoded, contains('"1887"'));
      expect(encoded, isNot(contains('1887-01-01')));
    });
  });

  group('relationships keep their meaning', () {
    test('a parent-child edge keeps its direction', () {
      final edge = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: personId(1),
        child: personId(2),
      );

      final read = through(relationships: <Relationship>[edge])
          .relationships
          .single;

      expect(read.type, RelationshipType.parentChild);
      expect(read.parentId, personId(1));
      expect(read.personBId, personId(2));
    });

    test('a spouse edge is put back in canonical order', () {
      // Read through the factory rather than assigned straight across: the
      // same marriage written by two devices must produce the same two
      // columns, or the uniqueness constraint lets a duplicate through.
      final encoded = encodeFamilyFile(
        family: family,
        persons: const <Person>[],
        relationships: <Relationship>[
          Relationship.spouse(
            id: 'r1',
            familyId: familyId,
            personA: personId(9),
            personB: personId(2),
          ),
        ],
      );

      final read = decodeFamilyFile(encoded).relationships.single;

      expect(read.personAId, personId(2), reason: 'the lower id first');
      expect(read.personBId, personId(9));
    });

    test('their family id also comes from the document', () {
      final read = through(
        relationships: <Relationship>[
          Relationship.spouse(
            id: 'r1',
            familyId: familyId,
            personA: personId(1),
            personB: personId(2),
          ),
        ],
      ).relationships.single;

      expect(read.familyId, familyId);
    });
  });

  group('a file that cannot be trusted is refused by name', () {
    /// The reason a refusal gives, which a screen will show to somebody.
    String reasonFor(String text) {
      try {
        decodeFamilyFile(text);
      } on FamilyFileException catch (e) {
        return e.reason;
      }
      fail('nothing was thrown');
    }

    test('text that is not JSON at all', () {
      expect(reasonFor('xin chào'), contains('JSON'));
    });

    test('JSON that is not an object', () {
      expect(reasonFor('[1, 2, 3]'), contains('đối tượng JSON'));
    });

    test('a document of some other kind', () {
      expect(
        reasonFor('{"format": "something.else", "version": 1}'),
        contains('không phải file gia phả'),
      );
    });

    test('a version this build does not know, named rather than guessed at', () {
      // The case that matters: a newer file opened by an older build. Reading
      // it on a best-effort basis would write a family record that is quietly
      // wrong, which is worse than refusing.
      final reason = reasonFor(
        '{"format": "$familyFileFormat", "version": 99}',
      );

      expect(reason, contains('99'));
      expect(reason, contains('$familyFileVersion'));
    });

    test('a missing required field', () {
      expect(
        reasonFor(
          jsonEncode(<String, Object?>{
            'format': familyFileFormat,
            'version': familyFileVersion,
            'family': <String, Object?>{'id': familyId},
            'persons': <Object?>[],
            'relationships': <Object?>[],
          }),
        ),
        contains('family.name'),
      );
    });

    test('a field of the wrong type', () {
      expect(
        reasonFor(
          jsonEncode(<String, Object?>{
            'format': familyFileFormat,
            'version': familyFileVersion,
            'family': <String, Object?>{'id': familyId, 'name': 'Họ Nguyễn'},
            'persons': 'không phải danh sách',
            'relationships': <Object?>[],
          }),
        ),
        contains('persons'),
      );
    });

    test('a relationship of a kind it does not know', () {
      expect(
        reasonFor(
          jsonEncode(<String, Object?>{
            'format': familyFileFormat,
            'version': familyFileVersion,
            'family': <String, Object?>{'id': familyId, 'name': 'Họ Nguyễn'},
            'persons': <Object?>[],
            'relationships': <Object?>[
              <String, Object?>{
                'id': 'r1',
                'type': 'godparent',
                'personAId': personId(1),
                'personBId': personId(2),
              },
            ],
          }),
        ),
        contains('godparent'),
      );
    });

    test('a date that describes no real day', () {
      expect(
        reasonFor(
          jsonEncode(<String, Object?>{
            'format': familyFileFormat,
            'version': familyFileVersion,
            'family': <String, Object?>{'id': familyId, 'name': 'Họ Nguyễn'},
            'persons': <Object?>[
              <String, Object?>{
                'id': personId(1),
                'displayName': 'Nguyễn Văn Cả',
                'birthDate': <String, Object?>{'iso': '1887-02-30'},
              },
            ],
            'relationships': <Object?>[],
          }),
        ),
        contains('birthDate'),
      );
    });

    test('a sex it does not recognise keeps the person', () {
      // The one place leniency is right: an unfamiliar value is far likelier
      // to be a newer build's vocabulary than corruption, and losing a whole
      // ancestor over one field would be the worse outcome. `unknown` is a
      // first-class value, so there is somewhere honest to put it.
      final read = decodeFamilyFile(
        jsonEncode(<String, Object?>{
          'format': familyFileFormat,
          'version': familyFileVersion,
          'family': <String, Object?>{'id': familyId, 'name': 'Họ Nguyễn'},
          'persons': <Object?>[
            <String, Object?>{
              'id': personId(1),
              'displayName': 'Nguyễn Văn Cả',
              'sex': 'notRecorded',
            },
          ],
          'relationships': <Object?>[],
        }),
      );

      expect(read.persons.single.displayName, 'Nguyễn Văn Cả');
      expect(read.persons.single.sex, Sex.unknown);
    });
  });

  test('a whole family survives the trip', () {
    // Not a unit of anything — the shape a real export has, checked end to
    // end, because the units passing separately has never been the claim.
    final people = <Person>[
      personOf(1, birth: GenealogicalDate(year: 1887)),
      personOf(2, birth: GenealogicalDate(year: 1890, isApproximate: true)),
      personOf(3, birth: GenealogicalDate(year: 1915, month: 6)),
    ];
    final edges = <Relationship>[
      Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: personId(1),
        personB: personId(2),
      ),
      Relationship.parentChild(
        id: 'r2',
        familyId: familyId,
        parent: personId(1),
        child: personId(3),
      ),
    ];

    final read = through(persons: people, relationships: edges);

    expect(read.persons.map((p) => p.id), people.map((p) => p.id));
    expect(read.persons.map((p) => p.birthDate), people.map((p) => p.birthDate));
    expect(read.relationships.map((r) => r.id), <String>['r1', 'r2']);
    expect(read.relationships.map((r) => r.type), edges.map((r) => r.type));
  });
}
