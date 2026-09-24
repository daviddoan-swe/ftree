/// What any [FamilyRepository] has to do, whoever is storing it.
///
/// One set of checks, run against every implementation. SQLite passes them in
/// the ordinary suite; Postgres passes them in `test/cloud/`, deliberately,
/// against a running stack.
///
/// This is the whole point of the repository being an interface rather than a
/// class (ARCHITECTURE §7). "Both work" is not a claim the two sides can make
/// separately — they have to answer the *same* questions the *same* way, or
/// swapping one for the other at M7 changes behaviour nobody asked to change.
///
/// ## What belongs here, and what does not
///
/// Here: everything the contract promises. A family comes back as it went, a
/// partial date keeps its precision, deletion hides a row without erasing it,
/// deleting a person takes their edges with them, `saveAll` is all or nothing.
///
/// Not here: how any of that is done. Drift's own tests still cover reopening
/// a file, storing timestamps as UTC text, and the schema's migrations. Those
/// are true of SQLite and meaningless to Postgres.
///
/// ## Ids are generated, not written down
///
/// Fixed ids would collide on a server that keeps what previous runs left. Ids
/// are globally unique by design (DOMAIN §14.1), and this leans on that rather
/// than working around it.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/family_repository.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/ids.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';

/// Runs the contract against whatever [open] hands back.
///
/// [open] returns a repository with nothing in it yet. For SQLite that is a
/// fresh in-memory database; for Postgres it is a fresh account, since a
/// family belongs to whoever made it and a new user can see none of the old
/// ones.
///
/// [close] releases it afterwards, where there is anything to release.
void runFamilyRepositoryContract({
  required String named,
  required Future<FamilyRepository> Function() open,
  Future<void> Function()? close,
}) {
  group('the repository contract, on $named', () {
    late FamilyRepository repository;
    late String familyId;

    setUp(() async {
      repository = await open();
      familyId = newId();
    });

    tearDown(() async {
      if (close != null) await close();
    });

    Family aFamily({String? name}) =>
        Family(id: familyId, name: name ?? 'Họ Nguyễn');

    Person aPerson(String id, {String? name, GenealogicalDate? birth}) =>
        Person(
          id: id,
          familyId: familyId,
          displayName: name ?? 'Nguyễn Văn Cả',
          birthDate: birth,
        );

    // ------------------------------------------------------- round trip ---

    test('a family written can be read back', () async {
      await repository.saveFamily(aFamily());

      final stored = await repository.loadFamily(familyId);

      expect(stored, isNotNull);
      expect(stored!.family.name, 'Họ Nguyễn');
      expect(stored.graph.persons, isEmpty);
    });

    test('people and edges come back as a graph that answers questions',
        () async {
      // Not a list of rows — the thing the tree screen draws from.
      final parent = newId();
      final child = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(parent), aPerson(child, name: 'Con Cả')],
        relationships: <Relationship>[
          Relationship.parentChild(
            id: newId(),
            familyId: familyId,
            parent: parent,
            child: child,
          ),
        ],
      );

      final graph = (await repository.loadFamily(familyId))!.graph;

      expect(graph.children(parent).map((p) => p.id), <String>[child]);
      expect(graph.parents(child).map((p) => p.id), <String>[parent]);
    });

    test('a partial date keeps the precision it was written at', () async {
      // The loss DOMAIN §4.2 exists to prevent, checked at the boundary where
      // it would happen. A year written back as a full date is a date the
      // family never recorded.
      final id = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(id, birth: GenealogicalDate(year: 1887))],
      );

      final stored = await repository.loadFamily(familyId);

      expect(stored!.graph.personById(id)!.birthDate!.toIso(), '1887');
    });

    test('an approximate date and a lunar reading survive too', () async {
      final id = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[
          Person(
            id: id,
            familyId: familyId,
            displayName: 'Nguyễn Văn Cả',
            sex: Sex.male,
            birthDate: GenealogicalDate(year: 1890, isApproximate: true),
            deathDate: GenealogicalDate(
              year: 1950,
              month: 3,
              day: 5,
              lunar: LunarDate(year: 1950, month: 1, day: 17),
            ),
          ),
        ],
      );

      final person = (await repository.loadFamily(familyId))!
          .graph
          .personById(id)!;

      expect(person.sex, Sex.male);
      expect(person.birthDate!.isApproximate, isTrue);
      expect(person.deathDate!.lunar, LunarDate(year: 1950, month: 1, day: 17));
    });

    test('a family that is not there reads as null, not as an error',
        () async {
      expect(await repository.loadFamily(newId()), isNull);
    });

    test('listFamilies returns what was saved', () async {
      await repository.saveFamily(aFamily());

      final listed = await repository.listFamilies();

      expect(listed.map((f) => f.id), contains(familyId));
    });

    test('saving the same id twice updates rather than duplicating', () async {
      final id = newId();
      await repository.saveFamily(aFamily());
      await repository.savePerson(aPerson(id, name: 'Trước'));
      await repository.savePerson(aPerson(id, name: 'Sau'));

      final graph = (await repository.loadFamily(familyId))!.graph;

      expect(graph.persons, hasLength(1));
      expect(graph.personById(id)!.displayName, 'Sau');
    });

    // --------------------------------------------------------- deletion ---

    test('a deleted person disappears from reads', () async {
      final id = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(id)],
      );

      await repository.deletePerson(id);

      expect((await repository.loadFamily(familyId))!.graph.persons, isEmpty);
    });

    test('deleting a person takes their edges with them', () async {
      // Left behind, those edges name somebody the family no longer has —
      // the corruption §15.1 is about.
      final parent = newId();
      final child = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(parent), aPerson(child)],
        relationships: <Relationship>[
          Relationship.parentChild(
            id: newId(),
            familyId: familyId,
            parent: parent,
            child: child,
          ),
        ],
      );

      await repository.deletePerson(parent);

      final graph = (await repository.loadFamily(familyId))!.graph;
      expect(graph.persons.map((p) => p.id), <String>[child]);
      expect(graph.relationships, isEmpty);
    });

    test('deleting one edge leaves both people alone', () async {
      final a = newId();
      final b = newId();
      final edge = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(a), aPerson(b)],
        relationships: <Relationship>[
          Relationship.spouse(
            id: edge,
            familyId: familyId,
            personA: a,
            personB: b,
          ),
        ],
      );

      await repository.deleteRelationship(edge);

      final graph = (await repository.loadFamily(familyId))!.graph;
      expect(graph.persons, hasLength(2));
      expect(graph.relationships, isEmpty);
    });

    test('deleting a family hides it and everything in it', () async {
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(newId())],
      );

      await repository.deleteFamily(familyId);

      expect(await repository.loadFamily(familyId), isNull);
      expect(
        (await repository.listFamilies()).map((f) => f.id),
        isNot(contains(familyId)),
      );
    });

    test('one family being deleted does not touch another', () async {
      final other = newId();
      await repository.saveFamily(aFamily());
      await repository.saveFamily(Family(id: other, name: 'Họ Trần'));

      await repository.deleteFamily(familyId);

      expect(await repository.loadFamily(other), isNotNull);
    });

    // --------------------------------------------------- writing at once ---

    test('saveAll writes the family, its people and their edges', () async {
      final a = newId();
      final b = newId();
      await repository.saveAll(
        family: aFamily(),
        persons: <Person>[aPerson(a), aPerson(b)],
        relationships: <Relationship>[
          Relationship.spouse(
            id: newId(),
            familyId: familyId,
            personA: a,
            personB: b,
          ),
        ],
      );

      final stored = await repository.loadFamily(familyId);

      expect(stored!.graph.persons, hasLength(2));
      expect(stored.graph.relationships, hasLength(1));
    });

    test('saveAll leaves nothing behind when part of it cannot be written',
        () async {
      // The reason the method exists. One edge names somebody nobody has, so
      // it is refused — after the people have been sent. Written one row at a
      // time those people would stay, leaving a family half entered.
      await expectLater(
        repository.saveAll(
          family: aFamily(),
          persons: <Person>[aPerson(newId())],
          relationships: <Relationship>[
            Relationship.parentChild(
              id: newId(),
              familyId: familyId,
              parent: newId(),
              child: newId(),
            ),
          ],
        ),
        throwsA(anything),
      );

      expect(await repository.loadFamily(familyId), isNull);
    });

    test('saveAll writes into a family already stored', () async {
      await repository.saveFamily(aFamily());

      await repository.saveAll(persons: <Person>[aPerson(newId())]);

      expect(
        (await repository.loadFamily(familyId))!.graph.persons,
        hasLength(1),
      );
    });

    test('a write clears the tombstone it lands on', () async {
      // Writing a row asserts it exists; a tombstone asserts it does not.
      // Without this an import into a deleted family writes every row and
      // shows none of them.
      final id = newId();
      final people = <Person>[aPerson(id)];
      await repository.saveAll(family: aFamily(), persons: people);
      await repository.deleteFamily(familyId);

      await repository.saveAll(family: aFamily(), persons: people);

      final stored = await repository.loadFamily(familyId);
      expect(stored, isNotNull);
      expect(stored!.graph.persons, hasLength(1));
    });
  });
}
