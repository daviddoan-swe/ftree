/// Turns validation codes into words a person can read.
///
/// The domain deliberately carries no messages: it must run without Flutter,
/// and the words need translating (DOMAIN.md §9). This is where the two meet,
/// and it is the only place that knows both.
library;

import 'package:flutter/widgets.dart';

import '../domain/validation.dart';
import '../l10n/app_localizations.dart';

/// The message for [code] in the reader's language.
///
/// The switch is exhaustive on purpose: adding a code without a message
/// becomes a compile error rather than an untranslated string appearing in
/// front of a user.
String issueText(BuildContext context, IssueCode code) {
  final text = AppText.of(context);

  return switch (code) {
    IssueCode.familyNameEmpty => text.issueFamilyNameEmpty,
    IssueCode.displayNameEmpty => text.issueDisplayNameEmpty,
    IssueCode.relationshipSelfReference =>
      text.issueRelationshipSelfReference,
    IssueCode.relationshipDuplicate => text.issueRelationshipDuplicate,
    IssueCode.relationshipFamilyIdMismatch =>
      text.issueRelationshipFamilyIdMismatch,
    IssueCode.personsInDifferentFamilies =>
      text.issuePersonsInDifferentFamilies,
    IssueCode.relationshipEndpointMissing =>
      text.issueRelationshipEndpointMissing,
    IssueCode.relationshipCreatesCycle => text.issueRelationshipCreatesCycle,
    IssueCode.deathBeforeBirth => text.issueDeathBeforeBirth,
    IssueCode.implausibleLifespan => text.issueImplausibleLifespan,
    IssueCode.parentBornAfterChild => text.issueParentBornAfterChild,
    IssueCode.childBornLongAfterParentDeath =>
      text.issueChildBornLongAfterParentDeath,
    IssueCode.implausibleParentAge => text.issueImplausibleParentAge,
    IssueCode.spouseIsAncestorOrDescendant =>
      text.issueSpouseIsAncestorOrDescendant,
  };
}
