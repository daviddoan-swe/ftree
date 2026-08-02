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
      zero: 'Nobody yet',
    );
    return '$_temp0';
  }

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSaveAnyway => 'Save anyway';

  @override
  String get actionReview => 'Review';

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
