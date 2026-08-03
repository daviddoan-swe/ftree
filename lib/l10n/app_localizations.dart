import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppText
/// returned by `AppText.of(context)`.
///
/// Applications need to include `AppText.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppText.localizationsDelegates,
///   supportedLocales: AppText.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppText.supportedLocales
/// property.
abstract class AppText {
  AppText(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppText of(BuildContext context) {
    return Localizations.of<AppText>(context, AppText)!;
  }

  static const LocalizationsDelegate<AppText> delegate = _AppTextDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// Tên ứng dụng hiển thị trên thanh tiêu đề
  ///
  /// In vi, this message translates to:
  /// **'Gia Phả'**
  String get appTitle;

  /// Tiêu đề màn hình danh sách gia đình
  ///
  /// In vi, this message translates to:
  /// **'Gia đình'**
  String get familiesTitle;

  /// No description provided for @familiesEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có gia đình nào'**
  String get familiesEmpty;

  /// No description provided for @familiesEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Tạo một gia đình để bắt đầu ghi gia phả'**
  String get familiesEmptyHint;

  /// No description provided for @familyCreate.
  ///
  /// In vi, this message translates to:
  /// **'Tạo gia đình'**
  String get familyCreate;

  /// No description provided for @familyName.
  ///
  /// In vi, this message translates to:
  /// **'Tên gia đình'**
  String get familyName;

  /// No description provided for @familyNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: Họ Nguyễn'**
  String get familyNameHint;

  /// No description provided for @familyDescription.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chú'**
  String get familyDescription;

  /// Bật để nhập và hiển thị ngày âm lịch cho gia đình này
  ///
  /// In vi, this message translates to:
  /// **'Dùng âm lịch'**
  String get familyUsesLunarCalendar;

  /// No description provided for @familyUsesLunarCalendarHint.
  ///
  /// In vi, this message translates to:
  /// **'Ghi kèm ngày âm và tính ngày giỗ'**
  String get familyUsesLunarCalendarHint;

  /// No description provided for @familyPersonCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{chưa có ai} =1{1 người} other{{count} người}}'**
  String familyPersonCount(int count);

  /// No description provided for @familyRelationshipCount.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{chưa có quan hệ nào} =1{1 quan hệ} other{{count} quan hệ}}'**
  String familyRelationshipCount(int count);

  /// No description provided for @familyEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa gia đình'**
  String get familyEdit;

  /// No description provided for @familyDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá gia đình'**
  String get familyDelete;

  /// No description provided for @familyDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'Xoá gia đình này cùng {people} và {relationships}. Không thể hoàn tác.'**
  String familyDeleteBody(String people, String relationships);

  /// No description provided for @familyDeleteEmptyBody.
  ///
  /// In vi, this message translates to:
  /// **'Gia đình này chưa có ai. Không thể hoàn tác.'**
  String get familyDeleteEmptyBody;

  /// Ma sát tỉ lệ với thiệt hại: xoá cả một gia phả thì phải gõ đúng tên
  ///
  /// In vi, this message translates to:
  /// **'Gõ tên gia đình để xác nhận'**
  String get familyDeleteTypeName;

  /// No description provided for @actionSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get actionCancel;

  /// No description provided for @actionSaveAnyway.
  ///
  /// In vi, this message translates to:
  /// **'Vẫn lưu'**
  String get actionSaveAnyway;

  /// No description provided for @actionReview.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại'**
  String get actionReview;

  /// No description provided for @actionClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get actionClose;

  /// No description provided for @actionAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get actionAdd;

  /// No description provided for @actionRemove.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ'**
  String get actionRemove;

  /// No description provided for @actionEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get actionEdit;

  /// Xoá hẳn một người hoặc một gia đình — khác 'Gỡ', chỉ tháo một quan hệ
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get actionDelete;

  /// No description provided for @deleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá {name}?'**
  String deleteTitle(String name);

  /// No description provided for @peopleEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ai trong gia đình này'**
  String get peopleEmpty;

  /// No description provided for @peopleEmptyHint.
  ///
  /// In vi, this message translates to:
  /// **'Thêm người đầu tiên để bắt đầu dựng cây'**
  String get peopleEmptyHint;

  /// No description provided for @personAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm người'**
  String get personAdd;

  /// No description provided for @personEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa thông tin'**
  String get personEdit;

  /// No description provided for @personDisplayName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get personDisplayName;

  /// No description provided for @personDisplayNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên đầy đủ như muốn hiện trên cây'**
  String get personDisplayNameHint;

  /// No description provided for @personNameParts.
  ///
  /// In vi, this message translates to:
  /// **'Các phần của tên'**
  String get personNameParts;

  /// No description provided for @personGivenName.
  ///
  /// In vi, this message translates to:
  /// **'Tên'**
  String get personGivenName;

  /// No description provided for @personAdditionalNames.
  ///
  /// In vi, this message translates to:
  /// **'Tên đệm và tên khác'**
  String get personAdditionalNames;

  /// No description provided for @personFamilyName.
  ///
  /// In vi, this message translates to:
  /// **'Họ'**
  String get personFamilyName;

  /// Họ trước khi lấy chồng — cách nối một người vào chi bên ngoại
  ///
  /// In vi, this message translates to:
  /// **'Họ khai sinh'**
  String get personBirthFamilyName;

  /// No description provided for @personSex.
  ///
  /// In vi, this message translates to:
  /// **'Giới tính'**
  String get personSex;

  /// No description provided for @sexMale.
  ///
  /// In vi, this message translates to:
  /// **'Nam'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In vi, this message translates to:
  /// **'Nữ'**
  String get sexFemale;

  /// No description provided for @sexUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Không rõ'**
  String get sexUnknown;

  /// No description provided for @personBirth.
  ///
  /// In vi, this message translates to:
  /// **'Sinh'**
  String get personBirth;

  /// No description provided for @personDeath.
  ///
  /// In vi, this message translates to:
  /// **'Mất'**
  String get personDeath;

  /// No description provided for @personBirthPlace.
  ///
  /// In vi, this message translates to:
  /// **'Nơi sinh'**
  String get personBirthPlace;

  /// No description provided for @personDeathPlace.
  ///
  /// In vi, this message translates to:
  /// **'Nơi mất'**
  String get personDeathPlace;

  /// No description provided for @personBiography.
  ///
  /// In vi, this message translates to:
  /// **'Ghi chép'**
  String get personBiography;

  /// No description provided for @personDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá người này'**
  String get personDelete;

  /// No description provided for @personDeleteBody.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Không thể hoàn tác.} =1{Gỡ luôn 1 quan hệ của người này. Không thể hoàn tác.} other{Gỡ luôn {count} quan hệ của người này. Không thể hoàn tác.}}'**
  String personDeleteBody(int count);

  /// No description provided for @personProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get personProfile;

  /// No description provided for @personRelatives.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ'**
  String get personRelatives;

  /// No description provided for @personNoRelatives.
  ///
  /// In vi, this message translates to:
  /// **'Chưa nối người này với ai'**
  String get personNoRelatives;

  /// No description provided for @relationParents.
  ///
  /// In vi, this message translates to:
  /// **'Cha mẹ'**
  String get relationParents;

  /// No description provided for @relationChildren.
  ///
  /// In vi, this message translates to:
  /// **'Con'**
  String get relationChildren;

  /// No description provided for @relationSpouses.
  ///
  /// In vi, this message translates to:
  /// **'Vợ chồng'**
  String get relationSpouses;

  /// No description provided for @relationSiblings.
  ///
  /// In vi, this message translates to:
  /// **'Anh chị em'**
  String get relationSiblings;

  /// Số cha mẹ chung — không gọi thẳng là anh em ruột hay cùng cha khác mẹ, vì một người có thể có cả cha mẹ đẻ lẫn cha mẹ nuôi
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{Chung 1 cha mẹ} other{Chung {count} cha mẹ}}'**
  String siblingSharedParents(int count);

  /// No description provided for @treeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cây gia phả'**
  String get treeTitle;

  /// No description provided for @treeEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ai để vẽ'**
  String get treeEmpty;

  /// No description provided for @treeFit.
  ///
  /// In vi, this message translates to:
  /// **'Vừa khung'**
  String get treeFit;

  /// No description provided for @treeDrawFrom.
  ///
  /// In vi, this message translates to:
  /// **'Vẽ từ người này'**
  String get treeDrawFrom;

  /// Cây vẽ hậu duệ của một gốc, nên người ngoài nhánh đó không xuất hiện
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, other{{count} người không nằm trong nhánh này}}'**
  String treeOffChart(int count);

  /// No description provided for @relationshipAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm quan hệ'**
  String get relationshipAdd;

  /// No description provided for @relationshipAddParent.
  ///
  /// In vi, this message translates to:
  /// **'Thêm cha mẹ'**
  String get relationshipAddParent;

  /// No description provided for @relationshipAddSpouse.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vợ hoặc chồng'**
  String get relationshipAddSpouse;

  /// No description provided for @relationshipAddChild.
  ///
  /// In vi, this message translates to:
  /// **'Thêm con'**
  String get relationshipAddChild;

  /// No description provided for @relationshipChoosePerson.
  ///
  /// In vi, this message translates to:
  /// **'Chọn người'**
  String get relationshipChoosePerson;

  /// Gợi ý trong ô tìm kiếm — bỏ dấu vẫn tìm được (PRODUCT §1.1)
  ///
  /// In vi, this message translates to:
  /// **'Tìm theo tên'**
  String get searchByName;

  /// No description provided for @searchNoMatch.
  ///
  /// In vi, this message translates to:
  /// **'Không có tên nào khớp'**
  String get searchNoMatch;

  /// No description provided for @relationshipNobodyElse.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có ai khác trong gia đình này'**
  String get relationshipNobodyElse;

  /// No description provided for @relationshipRemoveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ quan hệ?'**
  String get relationshipRemoveTitle;

  /// No description provided for @relationshipRemoveBody.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ quan hệ giữa {subject} và {other}. Cả hai người vẫn còn trong gia phả.'**
  String relationshipRemoveBody(String subject, String other);

  /// No description provided for @dateYear.
  ///
  /// In vi, this message translates to:
  /// **'Năm'**
  String get dateYear;

  /// No description provided for @dateMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get dateMonth;

  /// No description provided for @dateDay.
  ///
  /// In vi, this message translates to:
  /// **'Ngày'**
  String get dateDay;

  /// Nguồn ghi 'khoảng năm 1887' chứ không chắc chắn
  ///
  /// In vi, this message translates to:
  /// **'Khoảng'**
  String get dateApproximate;

  /// No description provided for @dateLeapMonth.
  ///
  /// In vi, this message translates to:
  /// **'Nhuận'**
  String get dateLeapMonth;

  /// No description provided for @dateCalendarGregorian.
  ///
  /// In vi, this message translates to:
  /// **'Dương'**
  String get dateCalendarGregorian;

  /// No description provided for @dateCalendarLunar.
  ///
  /// In vi, this message translates to:
  /// **'Âm'**
  String get dateCalendarLunar;

  /// Nhắc người dùng không phải bịa ngày tháng khi không biết
  ///
  /// In vi, this message translates to:
  /// **'Chỉ cần năm cũng được'**
  String get dateYearOnlyIsFine;

  /// No description provided for @dateUnknown.
  ///
  /// In vi, this message translates to:
  /// **'Không rõ'**
  String get dateUnknown;

  /// No description provided for @dateLunarSuffix.
  ///
  /// In vi, this message translates to:
  /// **'âm lịch'**
  String get dateLunarSuffix;

  /// No description provided for @dateApproximatePrefix.
  ///
  /// In vi, this message translates to:
  /// **'khoảng'**
  String get dateApproximatePrefix;

  /// No description provided for @dateImpossible.
  ///
  /// In vi, this message translates to:
  /// **'Ngày này không tồn tại'**
  String get dateImpossible;

  /// No description provided for @dateNeedsYear.
  ///
  /// In vi, this message translates to:
  /// **'Cần có năm'**
  String get dateNeedsYear;

  /// No description provided for @dateNeedsMonth.
  ///
  /// In vi, this message translates to:
  /// **'Có ngày thì phải có tháng'**
  String get dateNeedsMonth;

  /// Hiện ngày dương mà app quy đổi ra từ ngày âm vừa nhập
  ///
  /// In vi, this message translates to:
  /// **'Lưu dương lịch: {gregorian}'**
  String dateLunarStored(String gregorian);

  /// Tiêu đề khi có lỗi chặn việc lưu
  ///
  /// In vi, this message translates to:
  /// **'Không thể lưu'**
  String get validationCannotSave;

  /// Tiêu đề khi chỉ có cảnh báo — người dùng vẫn lưu được
  ///
  /// In vi, this message translates to:
  /// **'Có điều cần xem lại'**
  String get validationCheckBeforeSaving;

  /// No description provided for @issueFamilyNameEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Gia đình phải có tên'**
  String get issueFamilyNameEmpty;

  /// No description provided for @issueDisplayNameEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Người này phải có tên hiển thị'**
  String get issueDisplayNameEmpty;

  /// No description provided for @issueRelationshipSelfReference.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo quan hệ của một người với chính mình'**
  String get issueRelationshipSelfReference;

  /// No description provided for @issueRelationshipDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ này đã tồn tại'**
  String get issueRelationshipDuplicate;

  /// No description provided for @issueRelationshipFamilyIdMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ này thuộc gia đình khác'**
  String get issueRelationshipFamilyIdMismatch;

  /// No description provided for @issuePersonsInDifferentFamilies.
  ///
  /// In vi, this message translates to:
  /// **'Hai người thuộc hai gia đình khác nhau'**
  String get issuePersonsInDifferentFamilies;

  /// No description provided for @issueRelationshipEndpointMissing.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy một trong hai người'**
  String get issueRelationshipEndpointMissing;

  /// No description provided for @issueRelationshipCreatesCycle.
  ///
  /// In vi, this message translates to:
  /// **'Quan hệ này khiến một người thành tổ tiên của chính mình'**
  String get issueRelationshipCreatesCycle;

  /// No description provided for @issueDeathBeforeBirth.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất trước ngày sinh'**
  String get issueDeathBeforeBirth;

  /// No description provided for @issueImplausibleLifespan.
  ///
  /// In vi, this message translates to:
  /// **'Tuổi thọ dài bất thường'**
  String get issueImplausibleLifespan;

  /// No description provided for @issueParentBornAfterChild.
  ///
  /// In vi, this message translates to:
  /// **'Cha mẹ sinh sau con'**
  String get issueParentBornAfterChild;

  /// No description provided for @issueChildBornLongAfterParentDeath.
  ///
  /// In vi, this message translates to:
  /// **'Con sinh khá lâu sau khi cha mẹ mất'**
  String get issueChildBornLongAfterParentDeath;

  /// No description provided for @issueImplausibleParentAge.
  ///
  /// In vi, this message translates to:
  /// **'Tuổi làm cha mẹ bất thường'**
  String get issueImplausibleParentAge;

  /// No description provided for @issueSpouseIsAncestorOrDescendant.
  ///
  /// In vi, this message translates to:
  /// **'Hai vợ chồng là tổ tiên và hậu duệ của nhau'**
  String get issueSpouseIsAncestorOrDescendant;
}

class _AppTextDelegate extends LocalizationsDelegate<AppText> {
  const _AppTextDelegate();

  @override
  Future<AppText> load(Locale locale) {
    return SynchronousFuture<AppText>(lookupAppText(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppTextDelegate old) => false;
}

AppText lookupAppText(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppTextEn();
    case 'vi':
      return AppTextVi();
  }

  throw FlutterError(
    'AppText.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
