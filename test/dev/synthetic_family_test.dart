// The generator exists to produce data worth looking at, so what is tested here
// is what would make a screenshot misleading: a tree shallower than asked for, a
// record the application itself would reject, or output that changes between two
// runs and so cannot be compared with itself.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/dev/dev_database.dart';
import 'package:ftree/dev/synthetic_family.dart';
import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/ids.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

void main() {
  // The size the development entry point runs by default. Pinning the year as
  // well as the seed is what makes every expectation below reproducible.
  SyntheticFamily generate({int generations = 12, int people = 300, int seed = 1}) =>
      generateSyntheticFamily(
        generations: generations,
        people: people,
        seed: seed,
        currentYear: 2026,
      );

  FamilyGraph graphOf(SyntheticFamily data) => FamilyGraph(
    persons: data.persons,
    relationships: data.relationships,
  );

  group('shape', () {
    test('reaches exactly the depth asked for', () {
      expect(generate().depth, 12);
      expect(generate(generations: 25, people: 1000).depth, 25);
      expect(generate(generations: 30, people: 1000).depth, 30);
    });

    test('lands within a few people of the size asked for', () {
      // Not exact: a generation with too few couples to carry its whole share
      // passes the remainder on, and the last generation has nowhere to pass it.
      for (final size in <int>[300, 1000]) {
        final data = generate(generations: 12, people: size);
        expect(
          data.persons.length,
          closeTo(size, size * 0.02),
          reason: 'asked for $size',
        );
      }
    });

    test('widens toward the present', () {
      // The claim the whole allocation makes. A tree of uniform width would say
      // nothing about how the chart copes with a wide bottom row.
      final widths = generate().widths;

      expect(widths.first, lessThan(widths.last));
      expect(widths.every((w) => w > 0), isTrue, reason: 'no empty generation');
    });

    test('refuses parameters that cannot describe a tree', () {
      expect(() => generate(generations: 1), throwsArgumentError);
      expect(
        () => generate(generations: 12, people: 20),
        throwsArgumentError,
        reason: 'twelve generations need at least twenty-four people',
      );
    });

    test('no family is larger than a family can be', () {
      // The shape can demand more than the couples available can plausibly
      // supply — eight generations holding five hundred people wants forty in
      // generation one, from a single couple. The surplus must be carried down
      // the tree, not forced onto one father as twenty-seven children.
      //
      // Nine each, and at most two wives, so eighteen is the ceiling. No domain
      // rule enforces this; that is exactly why it needs a test.
      for (final generations in <int>[8, 12, 30]) {
        final data = generate(generations: generations, people: 500);
        final graph = graphOf(data);

        for (final person in data.persons) {
          expect(
            graph.children(person.id).length,
            lessThanOrEqualTo(18),
            reason: '${person.displayName} across $generations generations',
          );
          expect(
            graph.spouses(person.id).length,
            lessThanOrEqualTo(2),
            reason: '${person.displayName} took a third spouse',
          );
        }
      }
    });

    test('everyone is connected to the line', () {
      // Either descended from the progenitor or married to somebody who is.
      // An unreachable island would draw as a second tree and look like a bug.
      final data = generate();
      final graph = graphOf(data);

      final founder = data.persons.firstWhere(
        (p) => data.generationOf[p.id] == 0 && graph.children(p.id).isNotEmpty,
      );
      final line = <String>{
        founder.id,
        for (final person in graph.descendants(founder.id)) person.id,
      };

      final stranded = <Person>[
        for (final person in data.persons)
          if (!line.contains(person.id) &&
              !graph.spouses(person.id).any((s) => line.contains(s.id)))
            person,
      ];

      expect(stranded, isEmpty);
    });
  });

  group('the data passes the rules it will be shown under', () {
    test('no person carries an issue of any severity', () {
      final data = generate();

      final complaints = <String>[
        for (final person in data.persons)
          for (final issue in person.validate().issues)
            '${person.displayName}: ${issue.code.name}',
      ];

      // Errors would make it unusable; warnings would make every screen a wall
      // of yellow and hide a real one.
      expect(complaints, isEmpty);
    });

    test('no relationship carries an issue of any severity', () {
      final data = generate();
      final graph = graphOf(data);

      final complaints = <String>[
        for (final relationship in data.relationships)
          for (final issue in graph.validateAddition(relationship).issues)
            '${relationship.type.name}: ${issue.code.name}',
      ];

      expect(complaints, isEmpty);
    });

    test('the rules would have caught a bad generation', () {
      // Test-the-test: the two checks above are only worth having if a broken
      // generator would fail them. A parent-child edge pointing the other way
      // round is exactly what a mistake in `_beget` would produce.
      final data = generate();
      final graph = graphOf(data);
      final edge = data.relationships.firstWhere(
        (r) => r.type == RelationshipType.parentChild,
      );

      final reversed = Relationship.parentChild(
        id: edge.id,
        familyId: edge.familyId,
        parent: edge.childId,
        child: edge.parentId,
      );

      expect(graph.validateAddition(reversed).issues, isNotEmpty);
    });

    test('every edge names people the family holds', () {
      final data = generate();
      final ids = <String>{for (final person in data.persons) person.id};

      for (final relationship in data.relationships) {
        expect(ids, contains(relationship.personAId));
        expect(ids, contains(relationship.personBId));
        expect(relationship.familyId, data.family.id);
      }
      for (final person in data.persons) {
        expect(person.familyId, data.family.id);
      }
    });

    test('no relationship is recorded twice', () {
      final data = generate();
      final keys = <RelationshipKey>{};

      for (final relationship in data.relationships) {
        expect(
          keys.add(relationship.key),
          isTrue,
          reason: 'duplicate ${relationship.key}',
        );
      }
    });

    test('ids are unique version 7 uuids', () {
      final data = generate();
      final seen = <String>{data.family.id};

      for (final id in <String>[
        for (final person in data.persons) person.id,
        for (final relationship in data.relationships) relationship.id,
      ]) {
        expect(isValidId(id), isTrue, reason: id);
        expect(seen.add(id), isTrue, reason: 'duplicate $id');
      }
    });
  });

  group('determinism', () {
    test('the same seed produces the same family', () {
      final first = generate(seed: 7);
      final second = generate(seed: 7);

      expect(first.family, second.family);
      expect(first.persons, second.persons);
      expect(first.relationships, second.relationships);
    });

    test('a different seed produces a different family', () {
      expect(generate(seed: 7).persons, isNot(generate(seed: 8).persons));
    });

    test("the family's id does not move with the calendar", () {
      // The development entry point passes the real year, and uses this id to
      // decide whether the family is already installed. If the id drifted, a
      // second copy would appear on 1 January.
      String idIn(int year) => generateSyntheticFamily(
        generations: 12,
        people: 300,
        seed: 3,
        currentYear: year,
      ).family.id;

      expect(idIn(2026), idIn(2031));
    });
  });

  group('variety worth looking at', () {
    late SyntheticFamily data;
    late FamilyGraph graph;

    setUp(() {
      data = generate();
      graph = graphOf(data);
    });

    test('somebody died with only a place recorded', () {
      // The case that separates `hasDied` from a death date, and the one where
      // no age can be worked out.
      final placeOnly = data.persons.where(
        (p) => p.deathPlace != null && p.deathDate == null,
      );

      expect(placeOnly, isNotEmpty);
      expect(placeOnly.every((p) => p.hasDied), isTrue);
    });

    test('some have no death recorded at all', () {
      expect(data.persons.where((p) => !p.hasDied), isNotEmpty);
    });

    test('somebody married twice', () {
      // Two marriages is where the layout was wrong until M5, so the data has
      // to contain one.
      expect(
        data.persons.where((p) => graph.spouses(p.id).length >= 2),
        isNotEmpty,
      );
    });

    test('dates come at every precision, and some are approximate', () {
      final birthDates = <Person>[
        for (final person in data.persons)
          if (person.birthDate != null) person,
      ];

      expect(
        birthDates.where((p) => p.birthDate!.isApproximate),
        isNotEmpty,
        reason: 'the ~ prefix has to appear somewhere',
      );
      for (final precision in DatePrecision.values) {
        expect(
          birthDates.where((p) => p.birthDate!.precision == precision),
          isNotEmpty,
          reason: 'no ${precision.name}-precision birth date',
        );
      }
    });

    test('some records are incomplete, as real ones are', () {
      expect(
        data.persons.where((p) => p.birthDate == null),
        isNotEmpty,
        reason: 'an unknown birth date',
      );
      expect(
        data.persons.where((p) => p.sex == Sex.unknown),
        isNotEmpty,
        reason: 'an unknown sex',
      );
      expect(
        data.persons.where((p) => graph.parents(p.id).length == 1),
        isNotEmpty,
        reason: 'a person with only one recorded parent',
      );
      expect(
        data.persons.where((p) => p.biography != null),
        isNotEmpty,
        reason: 'a biography note',
      );
    });

    test('names differ from each other', () {
      // Duplicates are realistic and not a failure. A generator that produced
      // one name over and over would be, and it would make the search useless
      // to look at.
      final names = <String>{for (final person in data.persons) person.displayName};

      expect(names.length, greaterThan(data.persons.length * 0.8));
    });
  });

  group('installing it', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('writes and reads back everything, in one transaction', () async {
      final data = generate();

      expect(await holdsFamily(db, data.family.id), isFalse);
      await installSyntheticFamily(db, data);
      expect(await holdsFamily(db, data.family.id), isTrue);

      final snapshot = await DriftFamilyRepository(
        db,
      ).loadFamily(data.family.id);

      expect(snapshot, isNotNull);
      expect(snapshot!.graph.persons.length, data.persons.length);
      expect(snapshot.graph.relationships.length, data.relationships.length);
      // Set equality, because a person carries every field into the comparison:
      // a date that lost its precision on the way through SQLite would fail here.
      expect(snapshot.graph.persons.toSet(), data.persons.toSet());
      expect(snapshot.graph.relationships.toSet(), data.relationships.toSet());
    });

    test('erasing leaves nothing behind, not even a tombstone', () async {
      final data = generate();
      await installSyntheticFamily(db, data);

      await eraseFamily(db, data.family.id);

      // `holdsFamily` sees through tombstones, so a false here means the row is
      // really gone — which is what lets a reset install the same seed again.
      expect(await holdsFamily(db, data.family.id), isFalse);
    });

    test('erasing one family does not touch another', () async {
      // The generated data shares a database with the real gia phả. A reset has
      // to be surgical, or `--dart-define=RESET=true` becomes a way to lose a
      // hundred years of somebody's family history in one keystroke.
      final synthetic = generate(seed: 1);
      final real = generate(seed: 2);
      await installSyntheticFamily(db, synthetic);
      await installSyntheticFamily(db, real);

      await eraseFamily(db, synthetic.family.id);

      final survivor = await DriftFamilyRepository(db).loadFamily(
        real.family.id,
      );
      expect(survivor, isNotNull);
      expect(survivor!.graph.persons.length, real.persons.length);
      expect(survivor.graph.relationships.length, real.relationships.length);
    });
  });
}
