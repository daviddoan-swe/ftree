import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family_graph.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  const familyId = 'family-1';

  // Fixed ids in known alphabetical order, so canonical spouse ordering is
  // observable rather than accidental.
  const aliceId = 'aaaa';
  const bobId = 'bbbb';
  const carolId = 'cccc';
  const daveId = 'dddd';
  const eveId = 'eeee';

  Person personOf(String id) =>
      Person(id: id, familyId: familyId, displayName: 'Person $id');

  Relationship parentOf(String parent, String child, {String? id}) =>
      Relationship.parentChild(
        id: id ?? 'pc-$parent-$child',
        familyId: familyId,
        parent: parent,
        child: child,
      );

  Relationship spouseOf(String a, String b, {String? id}) =>
      Relationship.spouse(
        id: id ?? 'sp-$a-$b',
        familyId: familyId,
        personA: a,
        personB: b,
      );

  List<String> idsOf(List<Person> people) => people.map((p) => p.id).toList();

  group('construction', () {
    test('an empty graph answers every query with nothing', () {
      final graph = FamilyGraph(
        persons: const <Person>[],
        relationships: const <Relationship>[],
      );

      expect(graph.persons, isEmpty);
      expect(graph.relationships, isEmpty);
      expect(graph.parents(aliceId), isEmpty);
      expect(graph.children(aliceId), isEmpty);
      expect(graph.spouses(aliceId), isEmpty);
      expect(graph.personById(aliceId), isNull);
    });

    test('exposes its contents but does not let them be modified', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId)],
        relationships: <Relationship>[],
      );

      expect(
        () => graph.persons.add(personOf(bobId)),
        throwsUnsupportedError,
      );
      expect(
        () => graph.relationships.add(parentOf(aliceId, bobId)),
        throwsUnsupportedError,
      );
    });

    test('later changes to the source lists do not reach the graph', () {
      final people = <Person>[personOf(aliceId)];
      final edges = <Relationship>[];
      final graph = FamilyGraph(persons: people, relationships: edges);

      people.add(personOf(bobId));
      edges.add(parentOf(aliceId, bobId));

      expect(graph.persons.length, 1);
      expect(graph.relationships, isEmpty);
      expect(graph.children(aliceId), isEmpty);
    });

    test('refuses to build when two people share an id', () {
      // Ids are UUIDs, so a collision is a defect. Silently keeping one of the
      // two would lose a person.
      expect(
        () => FamilyGraph(
          persons: <Person>[personOf(aliceId), personOf(aliceId)],
          relationships: const <Relationship>[],
        ),
        throwsArgumentError,
      );
    });
  });

  group('parents', () {
    test('are empty for someone with none recorded', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId)],
        relationships: const <Relationship>[],
      );

      expect(graph.parents(aliceId), isEmpty);
    });

    test('can be a single recorded parent', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[parentOf(aliceId, bobId)],
      );

      expect(idsOf(graph.parents(bobId)), <String>[aliceId]);
    });

    test('can be a couple', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(bobId, carolId),
        ],
      );

      expect(idsOf(graph.parents(carolId)), <String>[aliceId, bobId]);
    });

    test('are not capped at two', () {
      // DOMAIN.md §17.3 states this affirmatively: biological plus adoptive
      // parents exceed two routinely.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
          personOf(eveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, eveId),
          parentOf(bobId, eveId),
          parentOf(carolId, eveId),
          parentOf(daveId, eveId),
        ],
      );

      expect(graph.parents(eveId).length, 4);
    });

    test('do not confuse direction with children', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[parentOf(aliceId, bobId)],
      );

      expect(graph.parents(aliceId), isEmpty);
      expect(idsOf(graph.children(aliceId)), <String>[bobId]);
    });

    test('do not include spouses', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          spouseOf(aliceId, bobId),
          parentOf(aliceId, carolId),
        ],
      );

      expect(graph.parents(aliceId), isEmpty);
      expect(idsOf(graph.parents(carolId)), <String>[aliceId]);
    });
  });

  group('children', () {
    test('come back in the order their relationships were supplied', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(carolId),
          personOf(bobId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(aliceId, bobId),
          parentOf(aliceId, daveId),
        ],
      );

      expect(idsOf(graph.children(aliceId)), <String>[
        carolId,
        bobId,
        daveId,
      ]);
    });

    test('are empty for someone with none', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[parentOf(aliceId, bobId)],
      );

      expect(graph.children(bobId), isEmpty);
    });
  });

  group('spouses', () {
    test('are found whichever way the ids sort', () {
      // Spouse endpoints are stored in canonical order, so reading personAId
      // directly would return the person themselves half the time. Both pairs
      // here sort in opposite directions relative to their subject.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          spouseOf(aliceId, bobId),
          spouseOf(carolId, bobId),
        ],
      );

      expect(idsOf(graph.spouses(aliceId)), <String>[bobId]);
      expect(idsOf(graph.spouses(carolId)), <String>[bobId]);
      expect(idsOf(graph.spouses(bobId)), <String>[aliceId, carolId]);
    });

    test('cover a whole lifetime, not one marriage', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          spouseOf(aliceId, bobId),
          spouseOf(aliceId, carolId),
          spouseOf(aliceId, daveId),
        ],
      );

      expect(idsOf(graph.spouses(aliceId)), <String>[bobId, carolId, daveId]);
    });

    test('do not include parents or children', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, carolId),
        ],
      );

      expect(graph.spouses(bobId), isEmpty);
    });
  });

  group('siblings', () {
    /// Two parents with three children between them.
    FamilyGraph twoParentFamily() => FamilyGraph(
      persons: <Person>[
        personOf(aliceId),
        personOf(bobId),
        personOf(carolId),
        personOf(daveId),
        personOf(eveId),
      ],
      relationships: <Relationship>[
        parentOf(aliceId, carolId),
        parentOf(bobId, carolId),
        parentOf(aliceId, daveId),
        parentOf(bobId, daveId),
        parentOf(aliceId, eveId),
      ],
    );

    test('sharing both parents counts two, and appears only once', () {
      final graph = twoParentFamily();
      final found = graph.siblings(carolId);

      final dave = found.singleWhere((s) => s.person.id == daveId);
      expect(dave.sharedParentCount, 2);
      expect(found.where((s) => s.person.id == daveId).length, 1);
    });

    test('sharing one parent counts one', () {
      final graph = twoParentFamily();
      final eve = graph.siblings(carolId).singleWhere(
        (s) => s.person.id == eveId,
      );

      expect(eve.sharedParentCount, 1);
    });

    test('never includes the subject', () {
      final graph = twoParentFamily();
      for (final id in <String>[carolId, daveId, eveId]) {
        expect(
          graph.siblings(id).map((s) => s.person.id),
          isNot(contains(id)),
          reason: id,
        );
      }
    });

    test('each of three children sees the other two', () {
      final graph = twoParentFamily();
      expect(graph.siblings(carolId).length, 2);
      expect(graph.siblings(daveId).length, 2);
      expect(graph.siblings(eveId).length, 2);
    });

    test('excludes step-siblings, who share no parent', () {
      // alice and bob have carol. alice remarries dave, who already has eve by
      // someone else. carol and eve are step-siblings and share nobody.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
          personOf(eveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(bobId, carolId),
          spouseOf(aliceId, daveId),
          parentOf(daveId, eveId),
        ],
      );

      expect(graph.siblings(carolId), isEmpty);
      expect(graph.siblings(eveId), isEmpty);
    });

    test('an only child has none', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[parentOf(aliceId, bobId)],
      );

      expect(graph.siblings(bobId), isEmpty);
    });

    test('someone with no recorded parent has none', () {
      // Not "no siblings in the world" — nothing in the data connects them.
      final graph = twoParentFamily();
      expect(graph.siblings(aliceId), isEmpty);
    });

    test('with one recorded parent, full and half look alike', () {
      // A limit of the data rather than of the query: if only the father is
      // recorded, nothing says whether the mother is shared.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(carolId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(aliceId, daveId),
        ],
      );

      expect(graph.siblings(carolId).single.sharedParentCount, 1);
    });

    test('a duplicated parent edge does not inflate the count', () {
      // Corrupt data a merge could produce. Validation rejects it, but the
      // graph must not double-count if it arrives anyway.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(carolId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(aliceId, daveId),
          parentOf(aliceId, daveId, id: 'duplicate'),
        ],
      );

      expect(graph.siblings(carolId).single.sharedParentCount, 1);
    });

    test('an unresolvable sibling is skipped', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(carolId)],
        relationships: <Relationship>[
          parentOf(aliceId, carolId),
          parentOf(aliceId, 'ghost'),
        ],
      );

      expect(graph.siblings(carolId), isEmpty);
    });
  });

  group('ancestors and descendants', () {
    /// A single line: alice -> bob -> carol -> dave.
    FamilyGraph fourGenerations() => FamilyGraph(
      persons: <Person>[
        personOf(aliceId),
        personOf(bobId),
        personOf(carolId),
        personOf(daveId),
      ],
      relationships: <Relationship>[
        parentOf(aliceId, bobId),
        parentOf(bobId, carolId),
        parentOf(carolId, daveId),
      ],
    );

    test('reach the whole line upwards', () {
      expect(idsOf(fourGenerations().ancestors(daveId)), <String>[
        carolId,
        bobId,
        aliceId,
      ]);
    });

    test('reach the whole line downwards', () {
      expect(idsOf(fourGenerations().descendants(aliceId)), <String>[
        bobId,
        carolId,
        daveId,
      ]);
    });

    test('exclude the subject', () {
      final graph = fourGenerations();
      expect(idsOf(graph.ancestors(daveId)), isNot(contains(daveId)));
      expect(idsOf(graph.descendants(aliceId)), isNot(contains(aliceId)));
    });

    test('come back nearest generation first', () {
      // Breadth-first, so a layout can read generations straight off.
      final graph = fourGenerations();
      expect(idsOf(graph.ancestors(daveId)).first, carolId);
      expect(idsOf(graph.ancestors(daveId)).last, aliceId);
    });

    test('follow every branch, not just one', () {
      // dave has two parents, each with a parent of their own.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
          personOf(eveId),
        ],
        relationships: <Relationship>[
          parentOf(bobId, daveId),
          parentOf(carolId, daveId),
          parentOf(aliceId, bobId),
          parentOf(eveId, carolId),
        ],
      );

      expect(idsOf(graph.ancestors(daveId)), <String>[
        bobId,
        carolId,
        aliceId,
        eveId,
      ]);
    });

    test('list a shared ancestor once, not once per route', () {
      // alice reaches dave through both bob and carol.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(aliceId, carolId),
          parentOf(bobId, daveId),
          parentOf(carolId, daveId),
        ],
      );

      expect(
        idsOf(graph.ancestors(daveId)).where((id) => id == aliceId).length,
        1,
      );
      expect(
        idsOf(graph.descendants(aliceId)).where((id) => id == daveId).length,
        1,
      );
    });

    test('are empty for someone unconnected', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId)],
        relationships: const <Relationship>[],
      );

      expect(graph.ancestors(aliceId), isEmpty);
      expect(graph.descendants(aliceId), isEmpty);
    });

    test('skip endpoints the family does not contain', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf('ghost', aliceId),
        ],
      );

      expect(idsOf(graph.ancestors(bobId)), <String>[aliceId]);
    });
  });

  group('a graph containing a cycle', () {
    // Acyclicity cannot be guaranteed once two devices edit offline: each may
    // add a valid edge that together close a loop (§6.2). These graphs are
    // invalid, and every traversal must still finish.

    test('a three-person loop does not hang going up', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, carolId),
          parentOf(carolId, aliceId),
        ],
      );

      expect(idsOf(graph.ancestors(aliceId)), <String>[carolId, bobId]);
    });

    test('a three-person loop does not hang going down', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, carolId),
          parentOf(carolId, aliceId),
        ],
      );

      expect(idsOf(graph.descendants(aliceId)), <String>[bobId, carolId]);
    });

    test('someone recorded as their own parent does not hang', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId)],
        relationships: <Relationship>[parentOf(aliceId, aliceId)],
      );

      expect(graph.ancestors(aliceId), isEmpty);
      expect(graph.descendants(aliceId), isEmpty);
    });

    test('a two-person loop does not hang', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, aliceId),
        ],
      );

      expect(idsOf(graph.ancestors(aliceId)), <String>[bobId]);
      expect(idsOf(graph.descendants(aliceId)), <String>[bobId]);
    });

    test('a clean branch hanging off a loop is still reported', () {
      // Corruption in one place must not blind the query everywhere else.
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
          personOf(daveId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, aliceId),
          parentOf(bobId, carolId),
          parentOf(carolId, daveId),
        ],
      );

      expect(idsOf(graph.descendants(aliceId)), containsAll(<String>[
        bobId,
        carolId,
        daveId,
      ]));
    });

    test('siblings survive a loop too', () {
      final graph = FamilyGraph(
        persons: <Person>[
          personOf(aliceId),
          personOf(bobId),
          personOf(carolId),
        ],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf(bobId, aliceId),
          parentOf(aliceId, carolId),
        ],
      );

      expect(
        graph.siblings(bobId).map((s) => s.person.id),
        contains(carolId),
      );
    });
  });

  group('validateAddition', () {
    /// alice -> bob -> carol, three generations in a line.
    FamilyGraph threeGenerations() => FamilyGraph(
      persons: <Person>[
        personOf(aliceId),
        personOf(bobId),
        personOf(carolId),
      ],
      relationships: <Relationship>[
        parentOf(aliceId, bobId),
        parentOf(bobId, carolId),
      ],
    );

    group('cycles', () {
      test('an edge closing a loop is refused', () {
        final result = threeGenerations().validateAddition(
          parentOf(carolId, aliceId, id: 'new'),
        );

        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.relationshipCreatesCycle),
        );
        expect(result.hasErrors, isTrue);
      });

      test('reversing an existing edge is refused', () {
        final result = threeGenerations().validateAddition(
          parentOf(bobId, aliceId, id: 'new'),
        );

        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.relationshipCreatesCycle),
        );
      });

      test('a new leaf on a deep line is accepted', () {
        final graph = FamilyGraph(
          persons: <Person>[
            personOf(aliceId),
            personOf(bobId),
            personOf(carolId),
            personOf(daveId),
          ],
          relationships: <Relationship>[
            parentOf(aliceId, bobId),
            parentOf(bobId, carolId),
          ],
        );

        expect(
          graph.validateAddition(parentOf(carolId, daveId, id: 'new')).hasIssues,
          isFalse,
        );
      });

      test('a second parent is not mistaken for a cycle', () {
        final graph = FamilyGraph(
          persons: <Person>[
            personOf(aliceId),
            personOf(bobId),
            personOf(carolId),
          ],
          relationships: <Relationship>[parentOf(aliceId, carolId)],
        );

        expect(
          graph.validateAddition(parentOf(bobId, carolId, id: 'new')).hasIssues,
          isFalse,
        );
      });

      test('validating against an already-looped graph does not hang', () {
        final looped = FamilyGraph(
          persons: <Person>[
            personOf(aliceId),
            personOf(bobId),
            personOf(carolId),
          ],
          relationships: <Relationship>[
            parentOf(aliceId, bobId),
            parentOf(bobId, aliceId),
          ],
        );

        expect(
          () => looped.validateAddition(parentOf(bobId, carolId, id: 'new')),
          returnsNormally,
        );
      });

      test('spouse edges are not cycle-checked', () {
        expect(
          threeGenerations()
              .validateAddition(spouseOf(aliceId, bobId, id: 'new'))
              .issues
              .map((i) => i.code),
          isNot(contains(IssueCode.relationshipCreatesCycle)),
        );
      });
    });

    group('missing endpoints', () {
      test('an unknown person is an error', () {
        final result = threeGenerations().validateAddition(
          parentOf(aliceId, 'ghost', id: 'new'),
        );

        expect(result.issues.single.code, IssueCode.relationshipEndpointMissing);
        expect(result.hasErrors, isTrue);
      });

      test('stops there rather than guessing at the rest', () {
        // Every other check needs both people, so continuing would only
        // produce noise about a person who is not there.
        final result = threeGenerations().validateAddition(
          parentOf('ghost-a', 'ghost-b', id: 'new'),
        );

        expect(result.issues.length, 1);
        expect(
          result.issues.single.involvedIds,
          containsAll(<String>['ghost-a', 'ghost-b']),
        );
      });
    });

    group('spouse who is also a blood relative', () {
      test('an ancestor marrying a descendant is a warning, not an error', () {
        // Almost always a transcription mistake, but the record is the user's.
        final result = threeGenerations().validateAddition(
          spouseOf(aliceId, carolId, id: 'new'),
        );

        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.spouseIsAncestorOrDescendant),
        );
        expect(result.hasErrors, isFalse);
      });

      test('it is reported whichever way round the pair is given', () {
        for (final pair in <List<String>>[
          <String>[aliceId, carolId],
          <String>[carolId, aliceId],
        ]) {
          final result = threeGenerations().validateAddition(
            spouseOf(pair[0], pair[1], id: 'new'),
          );
          expect(
            result.issues.map((i) => i.code),
            contains(IssueCode.spouseIsAncestorOrDescendant),
            reason: '${pair[0]} + ${pair[1]}',
          );
        }
      });

      test('cousins raise nothing — historically ordinary', () {
        // alice has two children; their children are cousins to each other.
        const eveChildId = 'ffff';
        final graph = FamilyGraph(
          persons: <Person>[
            personOf(aliceId),
            personOf(bobId),
            personOf(carolId),
            personOf(daveId),
            personOf(eveChildId),
          ],
          relationships: <Relationship>[
            parentOf(aliceId, bobId),
            parentOf(aliceId, carolId),
            parentOf(bobId, daveId),
            parentOf(carolId, eveChildId),
          ],
        );

        expect(
          graph.validateAddition(spouseOf(daveId, eveChildId, id: 'new')).hasIssues,
          isFalse,
        );
      });

      test('unrelated spouses raise nothing', () {
        final graph = FamilyGraph(
          persons: <Person>[personOf(aliceId), personOf(bobId)],
          relationships: const <Relationship>[],
        );

        expect(
          graph.validateAddition(spouseOf(aliceId, bobId, id: 'new')).hasIssues,
          isFalse,
        );
      });
    });

    group('rules delegated to the pair-level checks', () {
      test('a duplicate is caught', () {
        final result = threeGenerations().validateAddition(
          parentOf(aliceId, bobId, id: 'new'),
        );

        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.relationshipDuplicate),
        );
      });

      test('a reversed duplicate spouse is caught', () {
        final graph = FamilyGraph(
          persons: <Person>[personOf(aliceId), personOf(bobId)],
          relationships: <Relationship>[spouseOf(aliceId, bobId)],
        );

        expect(
          graph
              .validateAddition(spouseOf(bobId, aliceId, id: 'new'))
              .issues
              .map((i) => i.code),
          contains(IssueCode.relationshipDuplicate),
        );
      });

      test('an edge is not reported as a duplicate of itself', () {
        // Revalidating something already stored must stay clean.
        final graph = threeGenerations();
        final existing = graph.relationships.first;

        expect(
          graph.validateAddition(existing).issues.map((i) => i.code),
          isNot(contains(IssueCode.relationshipDuplicate)),
        );
      });

      test('self-reference is caught', () {
        expect(
          threeGenerations()
              .validateAddition(parentOf(aliceId, aliceId, id: 'new'))
              .issues
              .map((i) => i.code),
          contains(IssueCode.relationshipSelfReference),
        );
      });

      test('a parent born after the child still warns', () {
        final graph = FamilyGraph(
          persons: <Person>[
            Person(
              id: aliceId,
              familyId: familyId,
              displayName: 'alice',
              birthDate: GenealogicalDate(year: 1950),
            ),
            Person(
              id: bobId,
              familyId: familyId,
              displayName: 'bob',
              birthDate: GenealogicalDate(year: 1900),
            ),
          ],
          relationships: const <Relationship>[],
        );

        final result = graph.validateAddition(
          parentOf(aliceId, bobId, id: 'new'),
        );

        expect(
          result.issues.map((i) => i.code),
          contains(IssueCode.parentBornAfterChild),
        );
        expect(result.hasErrors, isFalse);
      });
    });
  });

  group('damaged data', () {
    test('an edge naming someone absent is skipped, not fatal', () {
      // Offline edits on two devices can produce this. The graph reports what
      // it can rather than refusing to answer.
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId), personOf(bobId)],
        relationships: <Relationship>[
          parentOf(aliceId, bobId),
          parentOf('ghost', bobId),
        ],
      );

      expect(idsOf(graph.parents(bobId)), <String>[aliceId]);
      expect(graph.relationships.length, 2, reason: 'kept for validation');
    });

    test('queries about an unknown person are empty rather than an error', () {
      final graph = FamilyGraph(
        persons: <Person>[personOf(aliceId)],
        relationships: const <Relationship>[],
      );

      expect(graph.personById('ghost'), isNull);
      expect(graph.parents('ghost'), isEmpty);
      expect(graph.children('ghost'), isEmpty);
      expect(graph.spouses('ghost'), isEmpty);
    });
  });
}
