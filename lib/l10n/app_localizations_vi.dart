// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppTextVi extends AppText {
  AppTextVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Gia Phả';

  @override
  String get familiesTitle => 'Gia đình';

  @override
  String get familiesEmpty => 'Chưa có gia đình nào';

  @override
  String get familiesEmptyHint => 'Tạo một gia đình để bắt đầu ghi gia phả';

  @override
  String get familyCreate => 'Tạo gia đình';

  @override
  String get familyName => 'Tên gia đình';

  @override
  String get familyNameHint => 'Ví dụ: Họ Nguyễn';

  @override
  String get familyDescription => 'Ghi chú';

  @override
  String get familyUsesLunarCalendar => 'Dùng âm lịch';

  @override
  String get familyUsesLunarCalendarHint => 'Ghi kèm ngày âm và tính ngày giỗ';

  @override
  String familyPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người',
      one: '1 người',
      zero: 'chưa có ai',
    );
    return '$_temp0';
  }

  @override
  String familyRelationshipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quan hệ',
      one: '1 quan hệ',
      zero: 'chưa có quan hệ nào',
    );
    return '$_temp0';
  }

  @override
  String get familyEdit => 'Sửa gia đình';

  @override
  String get familyDelete => 'Xoá gia đình';

  @override
  String familyDeleteBody(String people, String relationships) {
    return 'Xoá gia đình này cùng $people và $relationships. Không thể hoàn tác.';
  }

  @override
  String get familyDeleteEmptyBody =>
      'Gia đình này chưa có ai. Không thể hoàn tác.';

  @override
  String get familyDeleteTypeName => 'Gõ tên gia đình để xác nhận';

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionSaveAnyway => 'Vẫn lưu';

  @override
  String get actionReview => 'Xem lại';

  @override
  String get actionClose => 'Đóng';

  @override
  String get actionAdd => 'Thêm';

  @override
  String get actionRemove => 'Gỡ';

  @override
  String get actionEdit => 'Sửa';

  @override
  String get actionDelete => 'Xoá';

  @override
  String deleteTitle(String name) {
    return 'Xoá $name?';
  }

  @override
  String get peopleEmpty => 'Chưa có ai trong gia đình này';

  @override
  String get peopleEmptyHint => 'Thêm người đầu tiên để bắt đầu dựng cây';

  @override
  String get personAdd => 'Thêm người';

  @override
  String get personEdit => 'Sửa thông tin';

  @override
  String get personDisplayName => 'Tên hiển thị';

  @override
  String get personDisplayNameHint => 'Tên đầy đủ như muốn hiện trên cây';

  @override
  String get personNameParts => 'Các phần của tên';

  @override
  String get personGivenName => 'Tên';

  @override
  String get personAdditionalNames => 'Tên đệm và tên khác';

  @override
  String get personFamilyName => 'Họ';

  @override
  String get personBirthFamilyName => 'Họ khai sinh';

  @override
  String get personSex => 'Giới tính';

  @override
  String get sexMale => 'Nam';

  @override
  String get sexFemale => 'Nữ';

  @override
  String get sexUnknown => 'Không rõ';

  @override
  String get personBirth => 'Sinh';

  @override
  String get personDeath => 'Mất';

  @override
  String get personBirthPlace => 'Nơi sinh';

  @override
  String get personDeathPlace => 'Nơi mất';

  @override
  String get personBiography => 'Ghi chép';

  @override
  String personAge(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years tuổi',
    );
    return '$_temp0';
  }

  @override
  String get personDelete => 'Xoá người này';

  @override
  String personDeleteBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gỡ luôn $count quan hệ của người này. Không thể hoàn tác.',
      one: 'Gỡ luôn 1 quan hệ của người này. Không thể hoàn tác.',
      zero: 'Không thể hoàn tác.',
    );
    return '$_temp0';
  }

  @override
  String get personProfile => 'Hồ sơ';

  @override
  String get personRelatives => 'Quan hệ';

  @override
  String get personNoRelatives => 'Chưa nối người này với ai';

  @override
  String get relationParents => 'Cha mẹ';

  @override
  String get relationChildren => 'Con';

  @override
  String get relationSpouses => 'Vợ chồng';

  @override
  String get relationSiblings => 'Anh chị em';

  @override
  String siblingSharedParents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Chung $count cha mẹ',
      one: 'Chung 1 cha mẹ',
    );
    return '$_temp0';
  }

  @override
  String get treeTitle => 'Cây gia phả';

  @override
  String get treeEmpty => 'Chưa có ai để vẽ';

  @override
  String get treeFit => 'Vừa khung';

  @override
  String get treeDrawFrom => 'Vẽ từ người này';

  @override
  String get treeTurn => 'Xoay biểu đồ';

  @override
  String get treeBack => 'Về nhánh trước';

  @override
  String treeGenerationOrdinal(int number) {
    return 'Đời $number';
  }

  @override
  String treeGenerationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người',
    );
    return '$_temp0';
  }

  @override
  String get relationshipAdd => 'Thêm quan hệ';

  @override
  String get relationshipAddParent => 'Thêm cha mẹ';

  @override
  String get relationshipAddSpouse => 'Thêm vợ hoặc chồng';

  @override
  String get relationshipAddChild => 'Thêm con';

  @override
  String get relationshipChoosePerson => 'Chọn người';

  @override
  String get searchByName => 'Tìm theo tên';

  @override
  String get searchNoMatch => 'Không có tên nào khớp';

  @override
  String get relationshipNobodyElse => 'Chưa có ai khác trong gia đình này';

  @override
  String get relationshipRemoveTitle => 'Gỡ quan hệ?';

  @override
  String relationshipRemoveBody(String subject, String other) {
    return 'Gỡ quan hệ giữa $subject và $other. Cả hai người vẫn còn trong gia phả.';
  }

  @override
  String get dateYear => 'Năm';

  @override
  String get dateMonth => 'Tháng';

  @override
  String get dateDay => 'Ngày';

  @override
  String get dateApproximate => 'Khoảng';

  @override
  String get dateLeapMonth => 'Nhuận';

  @override
  String get dateCalendarGregorian => 'Dương';

  @override
  String get dateCalendarLunar => 'Âm';

  @override
  String get dateYearOnlyIsFine => 'Chỉ cần năm cũng được';

  @override
  String get dateUnknown => 'Không rõ';

  @override
  String get dateLunarSuffix => 'âm lịch';

  @override
  String get dateApproximatePrefix => 'khoảng';

  @override
  String get dateImpossible => 'Ngày này không tồn tại';

  @override
  String get dateNeedsYear => 'Cần có năm';

  @override
  String get dateNeedsMonth => 'Có ngày thì phải có tháng';

  @override
  String dateLunarStored(String gregorian) {
    return 'Lưu dương lịch: $gregorian';
  }

  @override
  String get validationCannotSave => 'Không thể lưu';

  @override
  String get validationCheckBeforeSaving => 'Có điều cần xem lại';

  @override
  String get issueFamilyNameEmpty => 'Gia đình phải có tên';

  @override
  String get issueDisplayNameEmpty => 'Người này phải có tên hiển thị';

  @override
  String get issueRelationshipSelfReference =>
      'Không thể tạo quan hệ của một người với chính mình';

  @override
  String get issueRelationshipDuplicate => 'Quan hệ này đã tồn tại';

  @override
  String get issueDeceasedWithoutDetail => 'Cần ngày mất hoặc nơi mất';

  @override
  String get issueRelationshipFamilyIdMismatch =>
      'Quan hệ này thuộc gia đình khác';

  @override
  String get issuePersonsInDifferentFamilies =>
      'Hai người thuộc hai gia đình khác nhau';

  @override
  String get issueRelationshipEndpointMissing =>
      'Không tìm thấy một trong hai người';

  @override
  String get issueRelationshipCreatesCycle =>
      'Quan hệ này khiến một người thành tổ tiên của chính mình';

  @override
  String get issueDeathBeforeBirth => 'Ngày mất trước ngày sinh';

  @override
  String get issueImplausibleLifespan => 'Tuổi thọ dài bất thường';

  @override
  String get issueParentBornAfterChild => 'Cha mẹ sinh sau con';

  @override
  String get issueChildBornLongAfterParentDeath =>
      'Con sinh khá lâu sau khi cha mẹ mất';

  @override
  String get issueImplausibleParentAge => 'Tuổi làm cha mẹ bất thường';

  @override
  String get issueSpouseIsAncestorOrDescendant =>
      'Hai vợ chồng là tổ tiên và hậu duệ của nhau';
}
