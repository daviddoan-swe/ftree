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

  /// No description provided for @familyRemovedNotice.
  ///
  /// In vi, this message translates to:
  /// **'Bác không còn quyền trên dòng họ này. Đây là bản đã tải về máy, chỉ đọc được.'**
  String get familyRemovedNotice;

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
  /// **'Ví dụ: Nguyễn'**
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

  /// Tuổi dưới ảnh đại diện — tuổi lúc mất, hoặc tuổi hiện nay
  ///
  /// In vi, this message translates to:
  /// **'{years, plural, other{{years} tuổi}}'**
  String personAge(int years);

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

  /// Đầu dải đường đi: thoát khỏi chuỗi hồ sơ, về danh sách người của dòng họ
  ///
  /// In vi, this message translates to:
  /// **'Về danh sách người'**
  String get trailToList;

  /// Như trailToList, khi chuỗi hồ sơ bắt đầu từ màn hình cây
  ///
  /// In vi, this message translates to:
  /// **'Về cây gia phả'**
  String get trailToTree;

  /// No description provided for @exportConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xuất dòng họ này?'**
  String get exportConfirmTitle;

  /// Xuất là đưa dữ liệu riêng tư ra ngoài, không thu lại được (PRODUCT §10)
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{Gửi 1 người ra khỏi máy} other{Gửi toàn bộ {count} người ra khỏi máy}}, kèm ngày tháng, nơi chốn và ghi chú — gồm cả người còn sống. File gửi đi rồi thì không thu lại được.'**
  String exportConfirmBody(int count);

  /// No description provided for @exportAction.
  ///
  /// In vi, this message translates to:
  /// **'Xuất'**
  String get exportAction;

  /// No description provided for @exportNothing.
  ///
  /// In vi, this message translates to:
  /// **'Dòng họ này không còn gì để xuất'**
  String get exportNothing;

  /// No description provided for @importTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập gia phả'**
  String get importTitle;

  /// Ngày file được xuất ra, theo đồng hồ của máy đã xuất
  ///
  /// In vi, this message translates to:
  /// **'File ghi ngày {date}'**
  String importFrom(String date);

  /// No description provided for @importNewFamily.
  ///
  /// In vi, this message translates to:
  /// **'Dòng họ này chưa có trên máy'**
  String get importNewFamily;

  /// No description provided for @importAddsPeople.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Không thêm người nào} =1{Thêm 1 người} other{Thêm {count} người}}'**
  String importAddsPeople(int count);

  /// No description provided for @importAddsRelationships.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Không thêm quan hệ nào} =1{Thêm 1 quan hệ} other{Thêm {count} quan hệ}}'**
  String importAddsRelationships(int count);

  /// No description provided for @importAlreadyHerePeople.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 người đã có sẵn} other{{count} người đã có sẵn}}'**
  String importAlreadyHerePeople(int count);

  /// No description provided for @importAlreadyHereRelationships.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 quan hệ đã có sẵn} other{{count} quan hệ đã có sẵn}}'**
  String importAlreadyHereRelationships(int count);

  /// Quan hệ bị luật của dòng họ từ chối — thiếu người ở một đầu, hoặc tạo thành vòng tổ tiên
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 quan hệ không nhận được} other{{count} quan hệ không nhận được}}'**
  String importRejected(int count);

  /// Giới hạn của việc gộp, phải nói thẳng chứ không để người dùng tự phát hiện (PRODUCT §9.1)
  ///
  /// In vi, this message translates to:
  /// **'Chỉ thêm, không sửa gì đang có. Bản sửa trên máy người khác không truyền sang được.'**
  String get importAddOnly;

  /// No description provided for @importNothingNew.
  ///
  /// In vi, this message translates to:
  /// **'File này không có gì mới so với máy'**
  String get importNothingNew;

  /// No description provided for @importAction.
  ///
  /// In vi, this message translates to:
  /// **'Nhập'**
  String get importAction;

  /// No description provided for @importNotAllowed.
  ///
  /// In vi, this message translates to:
  /// **'Bác chỉ có quyền xem dòng họ này, nên không nhập thêm vào được.'**
  String get importNotAllowed;

  /// No description provided for @importFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không đọc được file'**
  String get importFailed;

  /// No description provided for @importDonePeople.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Không thêm người nào} =1{Đã thêm 1 người} other{Đã thêm {count} người}}'**
  String importDonePeople(int count);

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

  /// No description provided for @treeTurn.
  ///
  /// In vi, this message translates to:
  /// **'Xoay biểu đồ'**
  String get treeTurn;

  /// Quay lại gốc đã vẽ trước đó, sau khi chạm hai lần để sang nhánh khác
  ///
  /// In vi, this message translates to:
  /// **'Về nhánh trước'**
  String get treeBack;

  /// Chip that clears the đời filter on a list of people
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get generationFilterAll;

  /// Chip for people the founding line does not reach, who have no đời in this family’s counting
  ///
  /// In vi, this message translates to:
  /// **'Chưa rõ đời'**
  String get generationFilterUnknown;

  /// Nhãn một đời trên dải dọc theo trục đời, đếm từ thuỷ tổ
  ///
  /// In vi, this message translates to:
  /// **'Đời {number}'**
  String treeGenerationOrdinal(int number);

  /// Số người của cả gia phả ở đời đó, kể cả người đang bị gập lại
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, other{{count} người}}'**
  String treeGenerationCount(int count);

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

  /// Bật đã mất thì phải ghi được ít nhất một trong hai — app lưu sự việc, không lưu lời khẳng định suông
  ///
  /// In vi, this message translates to:
  /// **'Cần ngày mất hoặc nơi mất'**
  String get issueDeceasedWithoutDetail;

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

  /// No description provided for @accountTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get accountTitle;

  /// No description provided for @accountWhy.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản chỉ dùng để chia sẻ dòng họ. Gia phả trên máy vẫn dùng được bình thường mà không cần đăng nhập.'**
  String get accountWhy;

  /// No description provided for @accountCreate.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get accountCreate;

  /// No description provided for @accountSignIn.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get accountSignIn;

  /// No description provided for @membersAction.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get membersAction;

  /// No description provided for @accountSignOut.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get accountSignOut;

  /// No description provided for @accountSignOutTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất khỏi tài khoản này?'**
  String get accountSignOutTitle;

  /// No description provided for @accountSignOutBody.
  ///
  /// In vi, this message translates to:
  /// **'Gia phả trên máy vẫn còn nguyên và vẫn dùng được mà không cần tài khoản.\n\nNhưng những mã lời mời đang treo sẽ không gửi lại được từ máy này nữa. Hãy huỷ chúng rồi tạo mã mới sau khi đăng nhập lại.'**
  String get accountSignOutBody;

  /// No description provided for @accountName.
  ///
  /// In vi, this message translates to:
  /// **'Tên'**
  String get accountName;

  /// No description provided for @accountNameHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên bác muốn người trong dòng họ nhìn thấy'**
  String get accountNameHint;

  /// No description provided for @accountNameMissing.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập tên'**
  String get accountNameMissing;

  /// No description provided for @accountEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountPassword.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get accountPassword;

  /// Ghi dưới ô mật khẩu, nói luật trước khi người dùng phải đoán
  ///
  /// In vi, this message translates to:
  /// **'Ít nhất {count} ký tự'**
  String accountPasswordHint(int count);

  /// No description provided for @accountEmailMissing.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập email'**
  String get accountEmailMissing;

  /// No description provided for @accountEmailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không đúng dạng'**
  String get accountEmailInvalid;

  /// No description provided for @accountPasswordShort.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu cần ít nhất {count} ký tự'**
  String accountPasswordShort(int count);

  /// No description provided for @accountPasswordMissing.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mật khẩu'**
  String get accountPasswordMissing;

  /// No description provided for @accountWrongCredentials.
  ///
  /// In vi, this message translates to:
  /// **'Email hoặc mật khẩu không đúng'**
  String get accountWrongCredentials;

  /// No description provided for @accountEmailTaken.
  ///
  /// In vi, this message translates to:
  /// **'Email này đã có tài khoản. Hãy chọn Đăng nhập.'**
  String get accountEmailTaken;

  /// No description provided for @accountConfirmEmail.
  ///
  /// In vi, this message translates to:
  /// **'Đã tạo tài khoản. Hãy mở email, bấm liên kết xác nhận, rồi quay lại đăng nhập.'**
  String get accountConfirmEmail;

  /// Lời của chính server, khi không có thông báo riêng cho trường hợp đó
  ///
  /// In vi, this message translates to:
  /// **'Không xong được: {reason}'**
  String accountRefused(String reason);

  /// No description provided for @shareAction.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ'**
  String get shareAction;

  /// No description provided for @shareConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chia sẻ dòng họ này?'**
  String get shareConfirmTitle;

  /// No description provided for @shareConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Dòng họ này sẽ được gửi lên máy chủ và bác trở thành chủ của nó. Các dòng họ khác trên máy vẫn ở lại máy. Đã gửi rồi thì không rút về được.'**
  String get shareConfirmBody;

  /// Tên dòng họ nằm trong câu: chia sẻ vài dòng họ liền nhau thì bốn câu giống hệt nhau không phân biệt được
  ///
  /// In vi, this message translates to:
  /// **'Đã chia sẻ {name}'**
  String shareDone(String name);

  /// No description provided for @shareAlreadyShared.
  ///
  /// In vi, this message translates to:
  /// **'{name} đã được chia sẻ rồi'**
  String shareAlreadyShared(String name);

  /// No description provided for @shareClaimedByOther.
  ///
  /// In vi, this message translates to:
  /// **'Dòng họ này đã có người khác chia sẻ. Hãy nhờ họ mời bác vào để cùng sửa.'**
  String get shareClaimedByOther;

  /// No description provided for @shareFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không chia sẻ được'**
  String get shareFailed;

  /// No description provided for @roleOwner.
  ///
  /// In vi, this message translates to:
  /// **'Chủ'**
  String get roleOwner;

  /// No description provided for @roleEditor.
  ///
  /// In vi, this message translates to:
  /// **'Người sửa'**
  String get roleEditor;

  /// No description provided for @roleViewer.
  ///
  /// In vi, this message translates to:
  /// **'Người xem'**
  String get roleViewer;

  /// No description provided for @inviteAction.
  ///
  /// In vi, this message translates to:
  /// **'Mời'**
  String get inviteAction;

  /// No description provided for @inviteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lời mời'**
  String get inviteTitle;

  /// No description provided for @inviteNone.
  ///
  /// In vi, this message translates to:
  /// **'Chưa mời ai vào dòng họ này'**
  String get inviteNone;

  /// No description provided for @inviteNew.
  ///
  /// In vi, this message translates to:
  /// **'Mời thêm'**
  String get inviteNew;

  /// No description provided for @inviteSend.
  ///
  /// In vi, this message translates to:
  /// **'Gửi'**
  String get inviteSend;

  /// No description provided for @inviteRevoke.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get inviteRevoke;

  /// No description provided for @inviteNoCode.
  ///
  /// In vi, this message translates to:
  /// **'Máy này không còn giữ mã'**
  String get inviteNoCode;

  /// No description provided for @inviteExpiresIn.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =0{Hết hạn hôm nay} =1{Còn 1 ngày} other{Còn {count} ngày}}'**
  String inviteExpiresIn(int count);

  /// No description provided for @inviteUsed.
  ///
  /// In vi, this message translates to:
  /// **'Đã dùng'**
  String get inviteUsed;

  /// No description provided for @inviteRevoked.
  ///
  /// In vi, this message translates to:
  /// **'Đã huỷ'**
  String get inviteRevoked;

  /// No description provided for @inviteExpired.
  ///
  /// In vi, this message translates to:
  /// **'Hết hạn'**
  String get inviteExpired;

  /// No description provided for @inviteOwnerWarningTitle.
  ///
  /// In vi, this message translates to:
  /// **'Mời làm chủ dòng họ?'**
  String get inviteOwnerWarningTitle;

  /// No description provided for @inviteOwnerWarningBody.
  ///
  /// In vi, this message translates to:
  /// **'Người này sẽ làm được mọi thứ bác làm được: mời người khác, mời thêm chủ, và xoá cả dòng họ. Không có cách nào lấy lại quyền đó.'**
  String get inviteOwnerWarningBody;

  /// No description provided for @inviteRevokeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ mã mời?'**
  String get inviteRevokeTitle;

  /// No description provided for @inviteRevokeBody.
  ///
  /// In vi, this message translates to:
  /// **'Mã này sẽ không dùng được nữa. Người bác đã gửi cho sẽ không vào được. Bác tạo mã mới bất cứ lúc nào.'**
  String get inviteRevokeBody;

  /// Nội dung tin nhắn chủ gửi đi, qua bảng chia sẻ của máy
  ///
  /// In vi, this message translates to:
  /// **'Mã mời vào gia phả {family}: {code}\n\nMã dùng một lần và hết hạn sau 7 ngày.'**
  String inviteMessage(String family, String code);

  /// No description provided for @inviteEnterTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã mời'**
  String get inviteEnterTitle;

  /// No description provided for @inviteEnterWhy.
  ///
  /// In vi, this message translates to:
  /// **'Mã do chủ dòng họ gửi cho bác. Nhập xong, gia phả sẽ được tải về máy này.'**
  String get inviteEnterWhy;

  /// No description provided for @inviteEnterLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã mời'**
  String get inviteEnterLabel;

  /// No description provided for @inviteEnterAction.
  ///
  /// In vi, this message translates to:
  /// **'Vào dòng họ'**
  String get inviteEnterAction;

  /// No description provided for @inviteCodeMissing.
  ///
  /// In vi, this message translates to:
  /// **'Hãy nhập mã mời'**
  String get inviteCodeMissing;

  /// No description provided for @inviteNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không có mã này. Hãy kiểm tra lại từng ký tự.'**
  String get inviteNotFound;

  /// No description provided for @inviteAlreadyUsed.
  ///
  /// In vi, this message translates to:
  /// **'Mã này đã được dùng rồi. Hãy hỏi lại người đã mời bác.'**
  String get inviteAlreadyUsed;

  /// No description provided for @inviteWasRevoked.
  ///
  /// In vi, this message translates to:
  /// **'Mã này đã bị huỷ. Hãy hỏi lại người đã mời bác.'**
  String get inviteWasRevoked;

  /// No description provided for @inviteHasExpired.
  ///
  /// In vi, this message translates to:
  /// **'Mã này đã hết hạn. Hãy xin một mã mới.'**
  String get inviteHasExpired;

  /// No description provided for @membersOwnerOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ chủ dòng họ mới quản lý được thành viên và lời mời.'**
  String get membersOwnerOnly;

  /// No description provided for @memberChangeRole.
  ///
  /// In vi, this message translates to:
  /// **'Đổi vai'**
  String get memberChangeRole;

  /// No description provided for @memberNoName.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đặt tên'**
  String get memberNoName;

  /// No description provided for @conflictsTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần bác quyết'**
  String get conflictsTitle;

  /// No description provided for @conflictsWaiting.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, =1{1 người đang chờ bác quyết} other{{count} người đang chờ bác quyết}}'**
  String conflictsWaiting(int count);

  /// No description provided for @conflictsNone.
  ///
  /// In vi, this message translates to:
  /// **'Không còn gì phải quyết'**
  String get conflictsNone;

  /// No description provided for @conflictMine.
  ///
  /// In vi, this message translates to:
  /// **'Bản của bác'**
  String get conflictMine;

  /// No description provided for @conflictTheirs.
  ///
  /// In vi, this message translates to:
  /// **'Bản trên máy chủ'**
  String get conflictTheirs;

  /// No description provided for @conflictWas.
  ///
  /// In vi, this message translates to:
  /// **'Trước đó: {value}'**
  String conflictWas(String value);

  /// No description provided for @conflictEmpty.
  ///
  /// In vi, this message translates to:
  /// **'để trống'**
  String get conflictEmpty;

  /// No description provided for @conflictYes.
  ///
  /// In vi, this message translates to:
  /// **'có'**
  String get conflictYes;

  /// No description provided for @conflictNo.
  ///
  /// In vi, this message translates to:
  /// **'không'**
  String get conflictNo;

  /// No description provided for @conflictKeep.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lựa chọn này'**
  String get conflictKeep;

  /// No description provided for @conflictRemovedByThem.
  ///
  /// In vi, this message translates to:
  /// **'Đã bị xoá ở máy khác, trong lúc bác đang sửa.'**
  String get conflictRemovedByThem;

  /// No description provided for @conflictRemovedByMe.
  ///
  /// In vi, this message translates to:
  /// **'Bác đã xoá người này ở máy này, trong lúc máy khác đang sửa.'**
  String get conflictRemovedByMe;

  /// No description provided for @conflictKeepPerson.
  ///
  /// In vi, this message translates to:
  /// **'Giữ lại trong gia phả'**
  String get conflictKeepPerson;

  /// No description provided for @conflictRemovePerson.
  ///
  /// In vi, this message translates to:
  /// **'Xoá khỏi gia phả'**
  String get conflictRemovePerson;

  /// No description provided for @conflictForEverybody.
  ///
  /// In vi, this message translates to:
  /// **'Cho cả họ, ở lần đồng bộ tới'**
  String get conflictForEverybody;

  /// No description provided for @conflictAsServerHas.
  ///
  /// In vi, this message translates to:
  /// **'Theo bản trên máy chủ: {value}'**
  String conflictAsServerHas(String value);

  /// No description provided for @conflictDropsMine.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ phần bác sửa mà chưa gửi'**
  String get conflictDropsMine;

  /// No description provided for @conflictDecide.
  ///
  /// In vi, this message translates to:
  /// **'Lưu quyết định này'**
  String get conflictDecide;

  /// No description provided for @conflictBirthDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh'**
  String get conflictBirthDate;

  /// No description provided for @conflictBirthApproximate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh là áng chừng'**
  String get conflictBirthApproximate;

  /// No description provided for @conflictBirthLunar.
  ///
  /// In vi, this message translates to:
  /// **'Ngày sinh âm lịch'**
  String get conflictBirthLunar;

  /// No description provided for @conflictDeathDate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất'**
  String get conflictDeathDate;

  /// No description provided for @conflictDeathApproximate.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất là áng chừng'**
  String get conflictDeathApproximate;

  /// No description provided for @conflictDeathLunar.
  ///
  /// In vi, this message translates to:
  /// **'Ngày mất âm lịch'**
  String get conflictDeathLunar;

  /// No description provided for @conflictMedia.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh đại diện'**
  String get conflictMedia;

  /// No description provided for @membersTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thành viên'**
  String get membersTitle;

  /// No description provided for @membersYou.
  ///
  /// In vi, this message translates to:
  /// **'bác'**
  String get membersYou;

  /// No description provided for @memberRemove.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ khỏi dòng họ'**
  String get memberRemove;

  /// No description provided for @memberRemoveTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gỡ người này?'**
  String get memberRemoveTitle;

  /// No description provided for @memberRemoveBody.
  ///
  /// In vi, this message translates to:
  /// **'Họ sẽ không đọc hay sửa dòng họ này trên máy chủ được nữa. Bản đã tải về máy họ thì vẫn còn.'**
  String get memberRemoveBody;

  /// No description provided for @memberRemoveLastOwner.
  ///
  /// In vi, this message translates to:
  /// **'Dòng họ phải luôn có ít nhất một chủ'**
  String get memberRemoveLastOwner;
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
