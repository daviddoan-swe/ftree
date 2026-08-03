import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/validation.dart';

/// Every code DOMAIN.md §9.1 lists as blocking.
const List<IssueCode> _blockingCodes = <IssueCode>[
  IssueCode.familyNameEmpty,
  IssueCode.displayNameEmpty,
  IssueCode.relationshipSelfReference,
  IssueCode.relationshipDuplicate,
  IssueCode.relationshipFamilyIdMismatch,
  IssueCode.deceasedWithoutDetail,
  IssueCode.personsInDifferentFamilies,
  IssueCode.relationshipEndpointMissing,
  IssueCode.relationshipCreatesCycle,
];

/// Every code DOMAIN.md §9.2 lists as advisory.
const List<IssueCode> _advisoryCodes = <IssueCode>[
  IssueCode.deathBeforeBirth,
  IssueCode.implausibleLifespan,
  IssueCode.parentBornAfterChild,
  IssueCode.childBornLongAfterParentDeath,
  IssueCode.implausibleParentAge,
  IssueCode.spouseIsAncestorOrDescendant,
];

void main() {
  group('IssueCode', () {
    test('severity is a property of the code, not of the issue', () {
      // The point of putting severity on the code: the same condition can
      // never be raised as an error in one place and a warning in another.
      expect(IssueCode.displayNameEmpty.severity, ValidationSeverity.error);
      expect(IssueCode.deathBeforeBirth.severity, ValidationSeverity.warning);
    });

    test('every code declared in DOMAIN.md §9.1 is an error', () {
      for (final code in _blockingCodes) {
        expect(
          code.severity,
          ValidationSeverity.error,
          reason: '${code.name} must block the write',
        );
      }
    });

    test('every code declared in DOMAIN.md §9.2 is a warning', () {
      // Posthumous birth and teenage parenthood are real. Refusing them would
      // make the app unusable on genuine family records.
      for (final code in _advisoryCodes) {
        expect(
          code.severity,
          ValidationSeverity.warning,
          reason: '${code.name} must not block the write',
        );
      }
    });

    test('no code escapes the two lists above', () {
      // Without this, adding a code and forgetting to categorise it would leave
      // the two tests above silently claiming a coverage they no longer have.
      final categorised = <IssueCode>{..._blockingCodes, ..._advisoryCodes};
      expect(
        IssueCode.values.toSet().difference(categorised),
        isEmpty,
        reason: 'add the new code to §9.1 or §9.2 and to the list here',
      );
    });
  });

  group('ValidationIssue', () {
    test('reads its severity through its code', () {
      const issue = ValidationIssue(IssueCode.deathBeforeBirth);
      expect(issue.severity, ValidationSeverity.warning);
    });

    test('defaults to no involved ids', () {
      const issue = ValidationIssue(IssueCode.familyNameEmpty);
      expect(issue.involvedIds, isEmpty);
    });

    test('compares by value, including involved ids', () {
      const a = ValidationIssue(
        IssueCode.deathBeforeBirth,
        involvedIds: <String>['p1'],
      );
      const b = ValidationIssue(
        IssueCode.deathBeforeBirth,
        involvedIds: <String>['p1'],
      );
      const differentId = ValidationIssue(
        IssueCode.deathBeforeBirth,
        involvedIds: <String>['p2'],
      );
      const differentCode = ValidationIssue(
        IssueCode.implausibleLifespan,
        involvedIds: <String>['p1'],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differentId));
      expect(a, isNot(differentCode));
    });
  });

  group('ValidationResult', () {
    const nameEmpty = ValidationIssue(IssueCode.displayNameEmpty);
    const deathFirst = ValidationIssue(IssueCode.deathBeforeBirth);
    const longLife = ValidationIssue(IssueCode.implausibleLifespan);

    test('ok() is clean', () {
      const result = ValidationResult.ok();
      expect(result.issues, isEmpty);
      expect(result.hasIssues, isFalse);
      expect(result.hasErrors, isFalse);
    });

    test('warnings alone do not block the write', () {
      // The central rule of DOMAIN.md §9 — this is what distinguishes the
      // design from a plain bool.
      final result = ValidationResult(<ValidationIssue>[deathFirst, longLife]);
      expect(result.hasIssues, isTrue);
      expect(result.hasErrors, isFalse);
    });

    test('a single error among warnings blocks the write', () {
      final result = ValidationResult(<ValidationIssue>[
        deathFirst,
        nameEmpty,
        longLife,
      ]);
      expect(result.hasErrors, isTrue);
    });

    test('errors and warnings are reported separately', () {
      final result = ValidationResult(<ValidationIssue>[
        deathFirst,
        nameEmpty,
        longLife,
      ]);
      expect(result.errors, <ValidationIssue>[nameEmpty]);
      expect(result.warnings, <ValidationIssue>[deathFirst, longLife]);
    });

    test('single() carries exactly one issue', () {
      final result = ValidationResult.single(nameEmpty);
      expect(result.issues, <ValidationIssue>[nameEmpty]);
      expect(result.hasErrors, isTrue);
    });

    test('merge concatenates and preserves order', () {
      final first = ValidationResult.single(nameEmpty);
      final second = ValidationResult(<ValidationIssue>[deathFirst, longLife]);

      expect(first.merge(second).issues, <ValidationIssue>[
        nameEmpty,
        deathFirst,
        longLife,
      ]);
    });

    test('merging with a clean result changes nothing', () {
      final result = ValidationResult.single(nameEmpty);
      const clean = ValidationResult.ok();

      expect(result.merge(clean).issues, <ValidationIssue>[nameEmpty]);
      expect(clean.merge(result).issues, <ValidationIssue>[nameEmpty]);
    });

    test('combine flattens several results in order', () {
      final combined = ValidationResult.combine(<ValidationResult>[
        ValidationResult.single(nameEmpty),
        const ValidationResult.ok(),
        ValidationResult.single(deathFirst),
      ]);

      expect(combined.issues, <ValidationIssue>[nameEmpty, deathFirst]);
      expect(combined.hasErrors, isTrue);
    });

    test('combine of nothing is clean', () {
      final combined = ValidationResult.combine(const <ValidationResult>[]);
      expect(combined.hasIssues, isFalse);
    });

    test('issues cannot be modified after construction', () {
      final result = ValidationResult(<ValidationIssue>[nameEmpty]);
      expect(
        () => result.issues.add(deathFirst),
        throwsUnsupportedError,
      );
    });

    test('mutating the source list does not affect the result', () {
      final source = <ValidationIssue>[nameEmpty];
      final result = ValidationResult(source);
      source.add(deathFirst);

      expect(result.issues, <ValidationIssue>[nameEmpty]);
    });
  });
}
