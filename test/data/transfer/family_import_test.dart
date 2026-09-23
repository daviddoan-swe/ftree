/// What a file would add to a family already on the device.
///
/// The claim being tested is narrow and absolute: **an import never loses
/// anything that is already here.** Everything else — counts, rejections,
/// which edges arrive — is secondary to that, because a merge that overwrites
/// is a merge that can destroy a record nobody has another copy of.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/transfer/family_file.dart';
import 'package:ftree/data/transfer/family_import.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  const familyId = 'f0000000-0000-7000-8000-000000000000';

  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  const family = Family(id: familyId, name: 'Họ Nguyễn');

  Person personOf(int n, {String? name, GenealogicalDate? birth}) => Person(
    id: personId(n),
    familyId: familyId,
    displayName: name ?? 'Nguyễn Văn $n',
    birthDate: birth,
  );

  Relationship childOf(int parent, int child, {String? id}) =>
      Relationship.parentChild(
        id: id ?? 'r-$parent-$child',
        familyId: familyId,
        parent: personId(parent),
        child: personId(child),
      );

  Relationship marriage(int a, int b, {String? id}) => Relationship.spouse(
    id: id ?? 'r-$a-$b',
    familyId: familyId,
    personA: personId(a),
    personB: personId(b),
  );

  FamilyFile fileOf({
    List<Person> persons = const <Person>[],
    List<Relationship> relationships = const <Relationship>[],
  }) => FamilyFile(
    family: family,
    persons: persons,
    relationships: relationships,
  );

  FamilySnapshotLike here({
    List<Person> persons = const <Person>[],
    List<Relationship> relationships = const <Relationship>[],
  }) => SnapshotOfFamily(persons: persons, relationships: relationships);

  group('a family that is not here yet', () {
    test('arrives whole', () {
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2)],
        ),
      );

      expect(plan.familyIsNew, isTrue);
      expect(plan.newPersons, hasLength(2));
      expect(plan.newRelationships, hasLength(1));
      expect(plan.rejected, isEmpty);
      expect(plan.changesSomething, isTrue);
    });

    test('an empty file changes nothing but the family itself', () {
      final plan = planImport(fileOf());

      expect(plan.newPersons, isEmpty);
      expect(plan.changesSomething, isTrue, reason: 'the family is created');
    });
  });

  group('nothing already here is touched', () {
    test('a person already here is skipped, not overwritten', () {
      // The rule the whole feature rests on. The file's version of this person
      // has a different name and a birth date; neither may reach the device,
      // because deciding which is newer needs a clock nobody can trust
      // (DOMAIN.md §15.3).
      final plan = planImport(
        fileOf(
          persons: <Person>[
            personOf(1, name: 'Tên khác', birth: GenealogicalDate(year: 1900)),
          ],
        ),
        existing: here(persons: <Person>[personOf(1, name: 'Nguyễn Văn Cả')]),
      );

      expect(plan.newPersons, isEmpty);
      expect(plan.personsAlreadyHere, 1);
      expect(plan.changesSomething, isFalse);
    });

    test('only the people who are missing arrive', () {
      final plan = planImport(
        fileOf(persons: <Person>[personOf(1), personOf(2), personOf(3)]),
        existing: here(persons: <Person>[personOf(2)]),
      );

      expect(plan.newPersons.map((p) => p.id), <String>[
        personId(1),
        personId(3),
      ]);
      expect(plan.personsAlreadyHere, 1);
    });

    test('the family here keeps its own name and settings', () {
      // The file describes the family too, and by the add-only rule that
      // description is not applied to one that already exists.
      final plan = planImport(
        fileOf(),
        existing: here(persons: <Person>[personOf(1)]),
      );

      expect(plan.familyIsNew, isFalse);
    });

    test('importing the same file twice adds nothing the second time', () {
      // A reader who imports twice must be told "nothing new", not "done", or
      // they cannot tell whether the first time worked.
      final file = fileOf(
        persons: <Person>[personOf(1), personOf(2)],
        relationships: <Relationship>[marriage(1, 2)],
      );
      final first = planImport(file);

      final second = planImport(
        file,
        existing: here(
          persons: first.newPersons,
          relationships: first.newRelationships,
        ),
      );

      expect(second.changesSomething, isFalse);
      expect(second.personsAlreadyHere, 2);
      expect(second.relationshipsAlreadyHere, 1);
    });
  });

  group('an edge that is already here in substance is skipped', () {
    test('when it carries the same id', () {
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2, id: 'same')],
        ),
        existing: here(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2, id: 'same')],
        ),
      );

      expect(plan.newRelationships, isEmpty);
      expect(plan.relationshipsAlreadyHere, 1);
    });

    test('and when it carries a different id for the same marriage', () {
      // Two devices each record the same marriage, each minting its own id.
      // Matching on ids alone would let a duplicate through, and the database
      // would then refuse the whole import with nothing useful to say.
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2, id: 'theirs')],
        ),
        existing: here(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2, id: 'ours')],
        ),
      );

      expect(plan.newRelationships, isEmpty);
      expect(plan.relationshipsAlreadyHere, 1);
      expect(plan.rejected, isEmpty, reason: 'recognised, not refused');
    });

    test('a marriage written the other way round is still the same marriage', () {
      // Asserting on the count, not only on nothing being added: the graph's
      // own duplicate rule would also stop this edge, but it would stop it as
      // a *rejection*. A reader must be told their marriage was already here,
      // never that it was refused.
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[
            Relationship.spouse(
              id: 'theirs',
              familyId: familyId,
              personA: personId(2),
              personB: personId(1),
            ),
          ],
        ),
        existing: here(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[marriage(1, 2, id: 'ours')],
        ),
      );

      expect(plan.newRelationships, isEmpty);
      expect(plan.relationshipsAlreadyHere, 1);
      expect(plan.rejected, isEmpty, reason: 'recognised, not refused');
    });
  });

  group('an edge the family’s rules refuse is left out, not written', () {
    test('one pointing at somebody nobody has', () {
      // The file names a parent it did not bring. Written through, this is a
      // dangling edge: reads skip it, and it would still be carried to other
      // devices as a real relationship to somebody who is not there.
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(2)],
          relationships: <Relationship>[childOf(1, 2)],
        ),
      );

      expect(plan.newRelationships, isEmpty);
      expect(plan.rejected, hasLength(1));
      expect(plan.rejected.single.code, IssueCode.relationshipEndpointMissing);
    });

    test('one joining a person to themselves', () {
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1)],
          relationships: <Relationship>[childOf(1, 1)],
        ),
      );

      expect(plan.newRelationships, isEmpty);
      expect(
        plan.rejected.single.code,
        IssueCode.relationshipSelfReference,
      );
    });

    test('a rejection names the people, not just an id', () {
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1, name: 'Nguyễn Văn Cả')],
          relationships: <Relationship>[childOf(1, 1)],
        ),
      );

      expect(plan.rejected.single.describe, contains('Nguyễn Văn Cả'));
    });

    test('the rest of the file still arrives', () {
      // One bad edge must not cost somebody their whole import.
      final plan = planImport(
        fileOf(
          persons: <Person>[personOf(1), personOf(2)],
          relationships: <Relationship>[childOf(1, 2), childOf(9, 2)],
        ),
      );

      expect(plan.newPersons, hasLength(2));
      expect(plan.newRelationships.map((r) => r.id), <String>['r-1-2']);
      expect(plan.rejected, hasLength(1));
    });
  });

  test('a cycle closed by the file itself is caught', () {
    // The case ARCHITECTURE §3.3 ③ describes, arriving all at once: three
    // parent-child edges, each perfectly valid on its own, which together make
    // somebody their own ancestor. Judging them all against the starting graph
    // would let the third one through, and a cycle in the graph hangs the tree
    // screen forever.
    final plan = planImport(
      fileOf(
        persons: <Person>[personOf(1), personOf(2), personOf(3)],
        relationships: <Relationship>[
          childOf(1, 2),
          childOf(2, 3),
          childOf(3, 1),
        ],
      ),
    );

    expect(plan.newRelationships, hasLength(2));
    expect(plan.rejected, hasLength(1));
    expect(plan.rejected.single.code, IssueCode.relationshipCreatesCycle);
  });

  test('a cycle closed against what is already here is caught', () {
    final plan = planImport(
      fileOf(
        persons: <Person>[personOf(1), personOf(2)],
        relationships: <Relationship>[childOf(2, 1)],
      ),
      existing: here(
        persons: <Person>[personOf(1), personOf(2)],
        relationships: <Relationship>[childOf(1, 2)],
      ),
    );

    expect(plan.newRelationships, isEmpty);
    expect(plan.rejected.single.code, IssueCode.relationshipCreatesCycle);
  });

  test('an edge between two people the file brings is accepted', () {
    // Both endpoints arrive in the same file, so judging the edge before the
    // people were added would reject it as dangling.
    final plan = planImport(
      fileOf(
        persons: <Person>[personOf(1), personOf(2)],
        relationships: <Relationship>[childOf(1, 2)],
      ),
    );

    expect(plan.newRelationships, hasLength(1));
    expect(plan.rejected, isEmpty);
  });

  test('an edge joining a newcomer to somebody already here is accepted', () {
    // The case that makes exchanging files worth anything: a relative sends
    // the branch they recorded, and it attaches to the tree already on this
    // device.
    final plan = planImport(
      fileOf(
        persons: <Person>[personOf(2)],
        relationships: <Relationship>[childOf(1, 2)],
      ),
      existing: here(persons: <Person>[personOf(1)]),
    );

    expect(plan.newPersons.map((p) => p.id), <String>[personId(2)]);
    expect(plan.newRelationships, hasLength(1));
    expect(plan.rejected, isEmpty);
  });
}
