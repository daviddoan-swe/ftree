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
