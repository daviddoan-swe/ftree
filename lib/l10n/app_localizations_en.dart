// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppTextEn extends AppText {
  AppTextEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Family Tree';

  @override
  String get familiesTitle => 'Families';

  @override
  String get familiesEmpty => 'No families yet';

  @override
  String get familyRemovedNotice =>
      'You no longer have any rights on this family. What follows is the copy already downloaded, and it can only be read.';

  @override
  String get familiesEmptyHint => 'Create a family to start recording it';

  @override
  String get familyCreate => 'Create family';

  @override
  String get familyName => 'Family name';

  @override
  String get familyNameHint => 'For example: Nguyễn';

  @override
  String get familyDescription => 'Notes';

  @override
  String get familyUsesLunarCalendar => 'Use the lunar calendar';

  @override
  String get familyUsesLunarCalendarHint =>
      'Record lunar dates and work out giỗ';

  @override
  String familyPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
      zero: 'nobody',
    );
    return '$_temp0';
  }

  @override
  String familyRelationshipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships',
      one: '1 relationship',
      zero: 'no relationships',
    );
    return '$_temp0';
  }

  @override
  String get familyEdit => 'Edit family';

  @override
  String get familyDelete => 'Delete family';

  @override
  String familyDeleteBody(String people, String relationships) {
    return 'Deletes this family along with $people and $relationships. This cannot be undone.';
  }

  @override
  String get familyDeleteEmptyBody =>
      'This family has nobody in it. This cannot be undone.';

  @override
  String get familyDeleteTypeName => 'Type the family name to confirm';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSaveAnyway => 'Save anyway';

  @override
  String get actionReview => 'Review';

  @override
  String get actionClose => 'Close';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String deleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get peopleEmpty => 'Nobody in this family yet';

  @override
  String get peopleEmptyHint =>
      'Add the first person to start building the tree';

  @override
  String get personAdd => 'Add person';

  @override
  String get personEdit => 'Edit person';

  @override
  String get personDisplayName => 'Display name';

  @override
  String get personDisplayNameHint =>
      'The name as it should appear on the tree';

  @override
  String get personNameParts => 'Name parts';

  @override
  String get personGivenName => 'Given name';

  @override
  String get personAdditionalNames => 'Additional names';

  @override
  String get personFamilyName => 'Family name';

  @override
  String get personBirthFamilyName => 'Family name at birth';

  @override
  String get personSex => 'Sex';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexUnknown => 'Unknown';

  @override
  String get personBirth => 'Born';

  @override
  String get personDeath => 'Died';

  @override
  String get personBirthPlace => 'Place of birth';

  @override
  String get personDeathPlace => 'Place of death';

  @override
  String get personBiography => 'Notes';

  @override
  String personAge(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years old',
      one: '1 year old',
    );
    return '$_temp0';
  }

  @override
  String get personDelete => 'Delete this person';

  @override
  String personDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removes $count relationships as well. This cannot be undone.',
      one: 'Removes 1 relationship as well. This cannot be undone.',
      zero: 'This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get trailToList => 'Back to the list of people';

  @override
  String get trailToTree => 'Back to the family tree';

  @override
  String get exportConfirmTitle => 'Export this family?';

  @override
  String exportConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sends all $count people off the device',
      one: 'Sends 1 person off the device',
    );
    return '$_temp0, with their dates, places and notes — including those still living. A file that has been sent cannot be called back.';
  }

  @override
  String get vaultSetTitle => 'Set a password';

  @override
  String get vaultSetWhy =>
      'The file can only be opened with this password. Without it nobody can open it — including you.';

  @override
  String get vaultSetLabel => 'Password';

  @override
  String get vaultSetAgain => 'Type it again';

  @override
  String get vaultSetAction => 'Export';

  @override
  String vaultTooShort(int count) {
    return 'At least $count characters. A few ordinary words work well.';
  }

  @override
  String get vaultMismatch => 'The two do not match';

  @override
  String get vaultSendApart =>
      'Send the password some other way — a call, or in person. In the same message as the file it protects nothing.';

  @override
  String get vaultOpenTitle => 'Password';

  @override
  String get vaultOpenWhy => 'This file needs a password. Ask whoever sent it.';

  @override
  String get vaultOpenAction => 'Open';

  @override
  String get vaultWrong => 'Wrong password, or the file is damaged';

  @override
  String get vaultTooNew =>
      'This backup was made by a newer version of the application';

  @override
  String get vaultWorking => 'Exporting the file…';

  @override
  String get vaultOpening => 'Opening…';

  @override
  String get exportAction => 'Export';

  @override
  String get exportNothing => 'There is nothing left in this family to export';

  @override
  String get importTitle => 'Import a family';

  @override
  String importFrom(String date) {
    return 'Written $date';
  }

  @override
  String get importNewFamily => 'This family is not on the device yet';

  @override
  String importAddsPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count people',
      one: 'Add 1 person',
      zero: 'No people to add',
    );
    return '$_temp0';
  }

  @override
  String importAddsRelationships(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count relationships',
      one: 'Add 1 relationship',
      zero: 'No relationships to add',
    );
    return '$_temp0';
  }

  @override
  String importAlreadyHerePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are already here',
      one: '1 person is already here',
    );
    return '$_temp0';
  }

  @override
  String importAlreadyHereRelationships(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships are already here',
      one: '1 relationship is already here',
    );
    return '$_temp0';
  }

  @override
  String importRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count relationships cannot be taken',
      one: '1 relationship cannot be taken',
    );
    return '$_temp0';
  }

  @override
  String get importAddOnly =>
      'Adds only; nothing already here is changed. A correction made on someone else\'s device does not travel.';

  @override
  String get importNothingNew =>
      'There is nothing in this file that is not already here';

  @override
  String get importAction => 'Import';

  @override
  String get importDeletedByOwner =>
      'The owner of this family deleted it. Only they can bring it back.';

  @override
  String get importNotAllowed =>
      'You may only read this family, so nothing can be merged into it.';

  @override
  String get importFailed => 'The file could not be read';

  @override
  String importDonePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count people',
      one: 'Added 1 person',
      zero: 'No people added',
    );
    return '$_temp0';
  }

  @override
  String get personProfile => 'Profile';

  @override
  String get personRelatives => 'Relatives';

  @override
  String get personNoRelatives => 'Not connected to anybody yet';

  @override
  String get relationParents => 'Parents';

  @override
  String get relationChildren => 'Children';

  @override
  String get relationSpouses => 'Spouses';

  @override
  String get relationSiblings => 'Siblings';

  @override
  String siblingSharedParents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parents in common',
      one: '1 parent in common',
    );
    return '$_temp0';
  }

  @override
  String get treeTitle => 'Family tree';

  @override
  String get treeEmpty => 'Nobody to draw yet';

  @override
  String get treeFit => 'Fit';

  @override
  String get treeDrawFrom => 'Draw from here';

  @override
  String get treeTurn => 'Turn the chart';

  @override
  String get treeBack => 'Back to the previous branch';

  @override
  String get generationFilterAll => 'All';

  @override
  String get generationFilterUnknown => 'Gen unknown';

  @override
  String treeGenerationOrdinal(int number) {
    return 'Gen $number';
  }

  @override
  String treeGenerationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get relationshipAdd => 'Add relationship';

  @override
  String get relationshipAddParent => 'Add a parent';

  @override
  String get relationshipAddSpouse => 'Add a spouse';

  @override
  String get relationshipAddChild => 'Add a child';

  @override
  String get relationshipChoosePerson => 'Choose a person';

  @override
  String get searchByName => 'Search by name';

  @override
  String get searchNoMatch => 'No name matches';

  @override
  String get relationshipNobodyElse => 'Nobody else in this family yet';

  @override
  String get relationshipRemoveTitle => 'Remove relationship?';

  @override
  String relationshipRemoveBody(String subject, String other) {
    return 'Removes the link between $subject and $other. Both people stay in the tree.';
  }

  @override
  String get dateYear => 'Year';

  @override
  String get dateMonth => 'Month';

  @override
  String get dateDay => 'Day';

  @override
  String get dateApproximate => 'About';

  @override
  String get dateLeapMonth => 'Leap';

  @override
  String get dateCalendarGregorian => 'Gregorian';

  @override
  String get dateCalendarLunar => 'Lunar';

  @override
  String get dateYearOnlyIsFine => 'A year on its own is fine';

  @override
  String get dateUnknown => 'Unknown';

  @override
  String get dateLunarSuffix => 'lunar';

  @override
  String get dateApproximatePrefix => 'about';

  @override
  String get dateImpossible => 'No such date';

  @override
  String get dateNeedsYear => 'A year is needed';

  @override
  String get dateNeedsMonth => 'A day needs a month';

  @override
  String dateLunarStored(String gregorian) {
    return 'Stored as $gregorian';
  }

  @override
  String get validationCannotSave => 'Cannot save';

  @override
  String get validationCheckBeforeSaving => 'Worth checking';

  @override
  String get issueFamilyNameEmpty => 'A family needs a name';

  @override
  String get issueDisplayNameEmpty => 'This person needs a display name';

  @override
  String get issueRelationshipSelfReference =>
      'A person cannot be related to themselves';

  @override
  String get issueRelationshipDuplicate => 'This relationship already exists';

  @override
  String get issueDeceasedWithoutDetail =>
      'A date or a place of death is needed';

  @override
  String get issueRelationshipFamilyIdMismatch =>
      'This relationship belongs to another family';

  @override
  String get issuePersonsInDifferentFamilies =>
      'These two people are in different families';

  @override
  String get issueRelationshipEndpointMissing =>
      'One of the two people could not be found';

  @override
  String get issueRelationshipCreatesCycle =>
      'This would make someone their own ancestor';

  @override
  String get issueDeathBeforeBirth => 'Died before being born';

  @override
  String get issueImplausibleLifespan => 'An unusually long life';

  @override
  String get issueParentBornAfterChild => 'The parent was born after the child';

  @override
  String get issueChildBornLongAfterParentDeath =>
      'Born well after the parent died';

  @override
  String get issueImplausibleParentAge => 'An unusual age to become a parent';

  @override
  String get issueSpouseIsAncestorOrDescendant =>
      'These spouses are ancestor and descendant';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountWhy =>
      'An account is only for sharing a family. The gia phả on this device works as it always did, with nobody signed in.';

  @override
  String get accountCreate => 'Sign up';

  @override
  String get accountSignIn => 'Sign in';

  @override
  String get membersAction => 'Members';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSignOutTitle => 'Sign out of this account?';

  @override
  String get accountSignOutBody =>
      'The gia phả on this device stays exactly as it is, and still works with nobody signed in.\n\nBut invitation codes still standing cannot be sent from this device again. Revoke them and make new ones once you have signed back in.';

  @override
  String get accountName => 'Name';

  @override
  String get accountNameHint => 'The name people in the family will see';

  @override
  String get accountNameMissing => 'Enter your name';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountPassword => 'Password';

  @override
  String accountPasswordHint(int count) {
    return 'At least $count characters';
  }

  @override
  String get accountEmailMissing => 'Enter an email address';

  @override
  String get accountEmailInvalid => 'That is not an email address';

  @override
  String accountPasswordShort(int count) {
    return 'A password needs at least $count characters';
  }

  @override
  String get accountPasswordMissing => 'Enter your password';

  @override
  String get accountWrongCredentials => 'That email and password do not match';

  @override
  String get accountEmailTaken =>
      'That email already has an account. Choose Sign in.';

  @override
  String get accountConfirmEmail =>
      'The account was created. Open your email, follow the confirmation link, then come back and sign in.';

  @override
  String accountRefused(String reason) {
    return 'It did not go through: $reason';
  }

  @override
  String get shareAction => 'Share';

  @override
  String get shareConfirmTitle => 'Share this family?';

  @override
  String get shareConfirmBody =>
      'This family will be sent to the server and you become its owner. Every other family on this device stays on it. Once sent, it cannot be taken back.';

  @override
  String shareDone(String name) {
    return '$name has been shared';
  }

  @override
  String shareAlreadyShared(String name) {
    return '$name is already shared';
  }

  @override
  String get shareClaimedByOther =>
      'Somebody else has already shared this family. Ask them to invite you so you can both work on it.';

  @override
  String get shareFailed => 'It could not be shared';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Viewer';

  @override
  String get inviteAction => 'Invite';

  @override
  String get inviteTitle => 'Invitations';

  @override
  String get inviteNone => 'Nobody has been invited to this family yet';

  @override
  String get inviteNew => 'New invitation';

  @override
  String get inviteSend => 'Send';

  @override
  String get inviteRevoke => 'Revoke';

  @override
  String get inviteNoCode => 'This device no longer holds the code';

  @override
  String inviteExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Expires today',
    );
    return '$_temp0';
  }

  @override
  String inviteRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get inviteNobodyUsed => 'Nobody used it';

  @override
  String get inviteLive => 'Still valid';

  @override
  String get inviteSearch => 'Search by address';

  @override
  String get inviteNoMatch => 'No invitation matches';

  @override
  String get inviteUsed => 'Used';

  @override
  String get inviteRevoked => 'Revoked';

  @override
  String get inviteExpired => 'Expired';

  @override
  String get inviteOwnerWarningTitle => 'Invite them as an owner?';

  @override
  String get inviteOwnerWarningBody =>
      'They will be able to do everything you can: invite others, make further owners, and delete the whole family. There is no way to take it back.';

  @override
  String get inviteRevokeTitle => 'Revoke this code?';

  @override
  String get inviteRevokeBody =>
      'The code stops working. Whoever you sent it to will not be able to join with it. You can make a new one at any time.';

  @override
  String inviteMessage(String family, String code) {
    return 'Your code for the $family family tree: $code\n\nIt works once, and expires in seven days.';
  }

  @override
  String get inviteEnterTitle => 'Enter an invitation code';

  @override
  String get inviteEnterWhy =>
      'The owner of a family sent you this code. Once it is entered, the gia phả is downloaded onto this device.';

  @override
  String get inviteEnterLabel => 'Invitation code';

  @override
  String get inviteEnterAction => 'Join the family';

  @override
  String get inviteCodeMissing => 'Enter the code';

  @override
  String get inviteNotFound =>
      'There is no such code. Check it character by character.';

  @override
  String get inviteAlreadyUsed =>
      'This code has already been used. Ask whoever invited you.';

  @override
  String get inviteWasRevoked =>
      'This code was revoked. Ask whoever invited you.';

  @override
  String get inviteFamilyDeleted =>
      'That family has been deleted. Ask whoever invited you.';

  @override
  String get inviteHasExpired => 'This code has expired. Ask for a new one.';

  @override
  String get membersOwnerOnly =>
      'Only the owner of a family manages its members and invitations.';

  @override
  String get memberChangeRole => 'Change role';

  @override
  String get memberNoName => 'No name given';

  @override
  String get syncNever => 'Not synced';

  @override
  String get syncJustNow => 'Synced';

  @override
  String syncMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: 'A minute ago',
    );
    return '$_temp0';
  }

  @override
  String syncHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: 'An hour ago',
    );
    return '$_temp0';
  }

  @override
  String syncDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }

  @override
  String syncWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
    );
    return '$_temp0';
  }

  @override
  String get syncNothingNew => 'Synced';

  @override
  String syncBroughtDown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count changes',
      one: 'Updated 1 change',
    );
    return '$_temp0';
  }

  @override
  String syncSentUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent $count changes',
      one: 'Sent 1 change',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'No connection';

  @override
  String get syncRefused =>
      'The server would not take it — check what you may do here';

  @override
  String get conflictsTitle => 'Which to keep';

  @override
  String conflictsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people to choose for',
      one: '1 person to choose for',
    );
    return '$_temp0';
  }

  @override
  String get conflictsNone => 'All chosen';

  @override
  String get conflictMine => 'On this device';

  @override
  String get conflictTheirs => 'On the server';

  @override
  String conflictWas(String value) {
    return 'Before: $value';
  }

  @override
  String get conflictEmpty => 'left empty';

  @override
  String get conflictYes => 'yes';

  @override
  String get conflictNo => 'no';

  @override
  String get conflictKeep => 'Keep these';

  @override
  String get conflictRemovedByThem =>
      'Removed on another device, while this one was editing.';

  @override
  String get conflictRemovedByMe =>
      'Removed on this device, while another was editing.';

  @override
  String get conflictKeepPerson => 'Keep them in the gia phả';

  @override
  String get conflictRemovePerson => 'Remove them from the gia phả';

  @override
  String get conflictForEverybody =>
      'For everybody, at the next synchronisation';

  @override
  String conflictAsServerHas(String value) {
    return 'As the server has them: $value';
  }

  @override
  String get conflictDropsMine => 'Unsent changes here are dropped';

  @override
  String get conflictDecide => 'Save this decision';

  @override
  String get conflictBirthDate => 'Date of birth';

  @override
  String get conflictBirthApproximate => 'Birth is approximate';

  @override
  String get conflictBirthLunar => 'Lunar date of birth';

  @override
  String get conflictDeathDate => 'Date of death';

  @override
  String get conflictDeathApproximate => 'Death is approximate';

  @override
  String get conflictDeathLunar => 'Lunar date of death';

  @override
  String get conflictMedia => 'Portrait';

  @override
  String get membersSearch => 'Name or address';

  @override
  String get filterAll => 'All';

  @override
  String get membersNoMatch => 'Nobody here matches that';

  @override
  String get membersTitle => 'Members';

  @override
  String get membersYou => 'you';

  @override
  String get memberRemove => 'Remove from the family';

  @override
  String get memberRemoveTitle => 'Remove this person?';

  @override
  String get memberRemoveBody =>
      'They will no longer be able to read or change this family on the server. Whatever they already downloaded stays on their device.';

  @override
  String get memberRemoveLastOwner =>
      'A family must always have at least one owner';

  @override
  String familyGoneDeleted(String name) {
    return '$name was deleted';
  }

  @override
  String familyGoneRemoved(String name) {
    return 'You are no longer in $name';
  }

  @override
  String familiesGone(int count) {
    return '$count families are gone';
  }
}
