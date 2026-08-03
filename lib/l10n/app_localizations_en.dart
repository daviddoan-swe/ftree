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
  String get familiesEmptyHint => 'Create a family to start recording it';

  @override
  String get familyCreate => 'Create family';

  @override
  String get familyName => 'Family name';

  @override
  String get familyNameHint => 'For example: the Nguyễn family';

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
  String treeOffChart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count not on this branch',
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
}
