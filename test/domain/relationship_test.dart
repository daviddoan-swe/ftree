import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/relationship.dart';
import 'package:ftree/domain/validation.dart';

void main() {
  // Fixed ids in known alphabetical order, so canonical ordering is observable.
  const familyId = 'family-1';
  const alice = 'aaaa-person';
  const bob = 'bbbb-person';
  const carol = 'cccc-person';

  group('parentChild direction', () {
    test('keeps the direction it was given', () {
      final rel = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: bob,
        child: alice,
      );

      // bob sorts after alice, so a canonical sort would have swapped them.
      // Direction must survive that.
      expect(rel.personAId, bob);
      expect(rel.personBId, alice);
      expect(rel.parentId, bob);
      expect(rel.childId, alice);
    });

    test('reversing the roles is a different relationship', () {
      final forward = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: alice,
        child: bob,
      );
      final reversed = Relationship.parentChild(
        id: 'r2',
        familyId: familyId,
        parent: bob,
        child: alice,
      );

      expect(forward.key, isNot(reversed.key));
    });
  });

  group('spouse symmetry', () {
    test('orders the ids canonically whichever way they are passed', () {
      final forward = Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: alice,
        personB: bob,
      );
      final reversed = Relationship.spouse(
        id: 'r2',
        familyId: familyId,
        personA: bob,
        personB: alice,
      );

      expect(forward.personAId, alice);
      expect(forward.personBId, bob);
      expect(reversed.personAId, alice);
      expect(reversed.personBId, bob);
    });

    test('the reversed pair produces the same key', () {
      // This is what makes UNIQUE (familyId, type, personAId, personBId)
      // actually reject a duplicate spouse record. Without the ordering the
      // database would see two distinct rows.
      final forward = Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: alice,
        personB: bob,
      );
      final reversed = Relationship.spouse(
        id: 'r2',
        familyId: familyId,
        personA: bob,
        personB: alice,
      );

      expect(forward.key, reversed.key);
      expect(forward.key.hashCode, reversed.key.hashCode);
    });

    test('the type reports itself as symmetric', () {
      expect(RelationshipType.spouse.isSymmetric, isTrue);
      expect(RelationshipType.parentChild.isSymmetric, isFalse);
    });
  });

  group('role accessors', () {
    test('refuse to read a spouse edge as if it had roles', () {
      // For a spouse, personAId is whichever id sorts first. Reading it as a
      // parent would be silently wrong, so it fails loudly instead.
      final spouse = Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: alice,
        personB: bob,
      );

      expect(() => spouse.parentId, throwsStateError);
      expect(() => spouse.childId, throwsStateError);
    });
  });

  group('endpoint helpers', () {
    final rel = Relationship.parentChild(
      id: 'r1',
      familyId: familyId,
      parent: alice,
      child: bob,
    );

    test('involves recognises both endpoints and nobody else', () {
      expect(rel.involves(alice), isTrue);
      expect(rel.involves(bob), isTrue);
      expect(rel.involves(carol), isFalse);
    });

    test('otherThan returns the opposite endpoint', () {
      expect(rel.otherThan(alice), bob);
      expect(rel.otherThan(bob), alice);
    });

    test('otherThan returns null for someone not involved', () {
      expect(rel.otherThan(carol), isNull);
    });
  });

  group('self reference', () {
    test('a person cannot be their own parent', () {
      final result = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: alice,
        child: alice,
      ).validate();

      expect(result.hasErrors, isTrue);
      expect(result.issues.single.code, IssueCode.relationshipSelfReference);
    });

    test('a person cannot be their own spouse', () {
      final result = Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: alice,
        personB: alice,
      ).validate();

      expect(result.hasErrors, isTrue);
    });

    test('the issue names both the edge and the person', () {
      final result = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: alice,
        child: alice,
      ).validate();

      expect(result.issues.single.involvedIds, <String>['r1', alice]);
    });

    test('a valid edge reports nothing', () {
      expect(
        Relationship.parentChild(
          id: 'r1',
          familyId: familyId,
          parent: alice,
          child: bob,
        ).validate().hasIssues,
        isFalse,
      );
    });

    test('an invalid edge can still be built', () {
      expect(
        () => Relationship.spouse(
          id: 'r1',
          familyId: familyId,
          personA: alice,
          personB: alice,
        ),
        returnsNormally,
      );
    });
  });

  group('RelationshipKey', () {
    test('separates the same pair by type', () {
      final parent = Relationship.parentChild(
        id: 'r1',
        familyId: familyId,
        parent: alice,
        child: bob,
      );
      final spouse = Relationship.spouse(
        id: 'r2',
        familyId: familyId,
        personA: alice,
        personB: bob,
      );

      expect(parent.key, isNot(spouse.key));
    });

    test('separates the same pair by family', () {
      final here = Relationship.spouse(
        id: 'r1',
        familyId: 'family-1',
        personA: alice,
        personB: bob,
      );
      final elsewhere = Relationship.spouse(
        id: 'r2',
        familyId: 'family-2',
        personA: alice,
        personB: bob,
      );

      expect(here.key, isNot(elsewhere.key));
    });

    test('two edges with different ids can share a key', () {
      // Precisely what a duplicate is, and the basis for detecting one in T7.
      final first = Relationship.spouse(
        id: 'r1',
        familyId: familyId,
        personA: alice,
        personB: bob,
      );
      final second = Relationship.spouse(
        id: 'r2',
        familyId: familyId,
        personA: bob,
        personB: alice,
      );

      expect(first, isNot(second));
      expect(first.key, second.key);
    });

    test('deduplicates inside a Set', () {
      final keys = <RelationshipKey>{
        Relationship.spouse(
          id: 'r1',
          familyId: familyId,
          personA: alice,
          personB: bob,
        ).key,
        Relationship.spouse(
          id: 'r2',
          familyId: familyId,
          personA: bob,
          personB: alice,
        ).key,
        Relationship.parentChild(
          id: 'r3',
          familyId: familyId,
          parent: alice,
          child: bob,
        ).key,
      };

      expect(keys.length, 2);
    });
  });

  group('equality', () {
    test('compares every field', () {
      Relationship make(String id) => Relationship.parentChild(
        id: id,
        familyId: familyId,
        parent: alice,
        child: bob,
      );

      expect(make('r1'), make('r1'));
      expect(make('r1').hashCode, make('r1').hashCode);
      expect(make('r1'), isNot(make('r2')));
    });
  });
}
