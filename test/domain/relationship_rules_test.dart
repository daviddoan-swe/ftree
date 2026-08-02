import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/domain/relationship_rules.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  const familyId = 'family-1';
  const aliceId = 'aaaa-person';
  const bobId = 'bbbb-person';

  Person personOf(
    String id, {
    String family = familyId,
    GenealogicalDate? birth,
    GenealogicalDate? death,
  }) => Person(
    id: id,
    familyId: family,
    displayName: 'Person $id',
    birthDate: birth,
    deathDate: death,
  );

  Relationship parentChildOf({String id = 'r1'}) =>
      Relationship.parentChild(
        id: id,
        familyId: familyId,
        parent: aliceId,
        child: bobId,
      );

  Relationship spouseOf({String id = 'r1'}) => Relationship.spouse(
    id: id,
    familyId: familyId,
    personA: aliceId,
    personB: bobId,
  );

  ValidationResult check(
    Relationship relationship, {
    Person? a,
    Person? b,
    Set<RelationshipKey> existing = const <RelationshipKey>{},
  }) => validateRelationship(
    relationship: relationship,
    personA: a ?? personOf(relationship.personAId),
    personB: b ?? personOf(relationship.personBId),
    existingKeys: existing,
  );

  group('argument guard', () {
    test('rejects people that do not match the endpoints', () {
      // Passing them the other way round is a programming error, not messy
      // data, so it throws rather than producing an issue.
      expect(
        () => validateRelationship(
          relationship: parentChildOf(),
          personA: personOf(bobId),
          personB: personOf(aliceId),
        ),
        throwsArgumentError,
      );
    });
  });

  group('duplicates', () {
    test('an unseen relationship is clean', () {
      expect(check(parentChildOf()).hasIssues, isFalse);
    });

    test('a repeated parent-child edge is an error', () {
      final existing = <RelationshipKey>{parentChildOf(id: 'other').key};
      final result = check(parentChildOf(), existing: existing);

      expect(result.hasErrors, isTrue);
      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.relationshipDuplicate),
      );
    });

    test('a reversed spouse pair is recognised as the same relationship', () {
      // The payoff of canonical ordering in T6: without it the database would
      // see (B, A) as a different row from (A, B) and let the duplicate in.
      final existing = <RelationshipKey>{
        Relationship.spouse(
          id: 'other',
          familyId: familyId,
          personA: bobId,
          personB: aliceId,
        ).key,
      };

      expect(check(spouseOf(), existing: existing).hasErrors, isTrue);
    });

    test('the same pair with a different type is not a duplicate', () {
      final existing = <RelationshipKey>{spouseOf(id: 'other').key};
      expect(check(parentChildOf(), existing: existing).hasIssues, isFalse);
    });
  });

  group('family consistency', () {
    test('people in different families cannot be related', () {
      final result = check(
        parentChildOf(),
        a: personOf(aliceId),
        b: personOf(bobId, family: 'family-2'),
      );

      expect(
        result.issues.single.code,
        IssueCode.personsInDifferentFamilies,
      );
    });

    test('a cross-family pair reports the cause, not the consequence', () {
      // The edge cannot possibly match both families, but saying so as well
      // would name a consequence of the real problem.
      final result = check(
        parentChildOf(),
        a: personOf(aliceId),
        b: personOf(bobId, family: 'family-2'),
      );

      expect(
        result.issues.map((i) => i.code),
        isNot(contains(IssueCode.relationshipFamilyIdMismatch)),
      );
    });

    test('an edge filed under the wrong family is an error', () {
      final result = validateRelationship(
        relationship: Relationship.parentChild(
          id: 'r1',
          familyId: 'family-elsewhere',
          parent: aliceId,
          child: bobId,
        ),
        personA: personOf(aliceId),
        personB: personOf(bobId),
      );

      expect(
        result.issues.single.code,
        IssueCode.relationshipFamilyIdMismatch,
      );
    });
  });

  group('parentBornAfterChild', () {
    test('warns when the parent is certainly younger', () {
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1890)),
      );

      expect(result.issues.single.code, IssueCode.parentBornAfterChild);
      expect(result.hasErrors, isFalse);
    });

    test('stays silent when the order cannot be determined', () {
      // 1900 may fall before or after May 1900, so nothing can be said about
      // which came first.
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1900, month: 5)),
      );

      expect(
        result.issues.map((i) => i.code),
        isNot(contains(IssueCode.parentBornAfterChild)),
      );
    });

    test('an undecidable order still leaves the age check to speak', () {
      // Same dates as above. The order is genuinely unknown, but every reading
      // of them makes the parent at most a few months older than the child,
      // which is its own problem and is reported as one. The two rules are
      // independent.
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1900, month: 5)),
      );

      expect(result.issues.single.code, IssueCode.implausibleParentAge);
    });

    test('suppresses the age warning it would otherwise imply', () {
      // A negative age is certainly under 12, but one contradiction should
      // produce one message.
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1950)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1900)),
      );

      expect(result.issues.length, 1);
      expect(result.issues.single.code, IssueCode.parentBornAfterChild);
    });
  });

  group('implausibleParentAge', () {
    ValidationResult withAges(int parentYear, int childYear) => check(
      parentChildOf(),
      a: personOf(
        aliceId,
        birth: GenealogicalDate(year: parentYear, month: 1, day: 1),
      ),
      b: personOf(
        bobId,
        birth: GenealogicalDate(year: childYear, month: 1, day: 1),
      ),
    );

    test('warns about a parent aged eight', () {
      expect(
        withAges(1900, 1908).issues.single.code,
        IssueCode.implausibleParentAge,
      );
    });

    test('warns about a parent aged eighty-five', () {
      expect(
        withAges(1900, 1985).issues.single.code,
        IssueCode.implausibleParentAge,
      );
    });

    test('accepts the ordinary range', () {
      // Kept clear of the bounds on purpose. DOMAIN.md §9.2 gives them as
      // approximate, and a mean-year conversion makes behaviour exactly on the
      // boundary a matter of rounding rather than of domain meaning.
      expect(withAges(1900, 1925).hasIssues, isFalse);
      expect(withAges(1900, 1965).hasIssues, isFalse);
      expect(withAges(1900, 1915).hasIssues, isFalse);
    });

    test('stays silent when the age is merely possibly implausible', () {
      // Year precision on both sides puts the age between 69 and 71; only part
      // of that range is out of bounds.
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1970)),
      );

      expect(result.hasIssues, isFalse);
    });

    test('needs both birth dates', () {
      final result = check(
        parentChildOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
      );
      expect(result.hasIssues, isFalse);
    });
  });

  group('childBornLongAfterParentDeath', () {
    test('accepts a birth within a pregnancy of the death', () {
      // Posthumous birth is real, which is why this is never an error.
      final result = check(
        parentChildOf(),
        a: personOf(
          aliceId,
          birth: GenealogicalDate(year: 1900, month: 1, day: 1),
          death: GenealogicalDate(year: 1930, month: 1, day: 1),
        ),
        b: personOf(
          bobId,
          birth: GenealogicalDate(year: 1930, month: 6, day: 1),
        ),
      );

      expect(result.hasIssues, isFalse);
    });

    test('warns when the birth is years after the death', () {
      final result = check(
        parentChildOf(),
        a: personOf(
          aliceId,
          birth: GenealogicalDate(year: 1900, month: 1, day: 1),
          death: GenealogicalDate(year: 1930, month: 1, day: 1),
        ),
        b: personOf(
          bobId,
          birth: GenealogicalDate(year: 1933, month: 1, day: 1),
        ),
      );

      expect(
        result.issues.map((i) => i.code),
        contains(IssueCode.childBornLongAfterParentDeath),
      );
      expect(result.hasErrors, isFalse);
    });

    test('stays silent when the gap is indeterminate', () {
      // Death in 1930 and birth in 1931 could be days apart or nearly two
      // years apart.
      final result = check(
        parentChildOf(),
        a: personOf(
          aliceId,
          birth: GenealogicalDate(year: 1900),
          death: GenealogicalDate(year: 1930),
        ),
        b: personOf(bobId, birth: GenealogicalDate(year: 1931)),
      );

      expect(
        result.issues.map((i) => i.code),
        isNot(contains(IssueCode.childBornLongAfterParentDeath)),
      );
    });
  });

  group('self reference', () {
    test('reports only the self reference and stops', () {
      final self = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: aliceId,
        child: aliceId,
      );
      final person = personOf(aliceId);

      final result = validateRelationship(
        relationship: self,
        personA: person,
        personB: person,
        existingKeys: <RelationshipKey>{self.key},
      );

      // The duplicate key was supplied too, but a self-relationship makes every
      // later check meaningless.
      expect(result.issues.length, 1);
      expect(result.issues.single.code, IssueCode.relationshipSelfReference);
    });
  });

  group('spouse edges', () {
    test('carry no date warnings at this milestone', () {
      // Spouse-is-also-an-ancestor needs the graph and arrives at M2.
      final result = check(
        spouseOf(),
        a: personOf(aliceId, birth: GenealogicalDate(year: 1900)),
        b: personOf(bobId, birth: GenealogicalDate(year: 1800)),
      );

      expect(result.hasIssues, isFalse);
    });

    test('are still checked for duplicates and family consistency', () {
      final result = check(
        spouseOf(),
        b: personOf(bobId, family: 'family-2'),
      );

      expect(
        result.issues.single.code,
        IssueCode.personsInDifferentFamilies,
      );
    });
  });

  group('combined results', () {
    test('an edge can be both duplicated and misfiled', () {
      final result = validateRelationship(
        relationship: Relationship.parentChild(
          id: 'r1',
          familyId: 'family-elsewhere',
          parent: aliceId,
          child: bobId,
        ),
        personA: personOf(aliceId),
        personB: personOf(bobId),
        existingKeys: <RelationshipKey>{
          Relationship.parentChild(
            id: 'other',
            familyId: 'family-elsewhere',
            parent: aliceId,
            child: bobId,
          ).key,
        },
      );

      expect(
        result.issues.map((i) => i.code),
        containsAll(<IssueCode>[
          IssueCode.relationshipFamilyIdMismatch,
          IssueCode.relationshipDuplicate,
        ]),
      );
    });

    test('errors and warnings appear together', () {
      final result = validateRelationship(
        relationship: Relationship.parentChild(
          id: 'r1',
          familyId: 'family-elsewhere',
          parent: aliceId,
          child: bobId,
        ),
        personA: personOf(aliceId, birth: GenealogicalDate(year: 1950)),
        personB: personOf(bobId, birth: GenealogicalDate(year: 1900)),
      );

      expect(result.hasErrors, isTrue);
      expect(result.warnings, isNotEmpty);
    });
  });
}
