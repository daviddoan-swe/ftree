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
      zero: 'Chưa có ai',
    );
    return '$_temp0';
  }

  @override
  String get actionSave => 'Lưu';

  @override
  String get actionCancel => 'Huỷ';

  @override
  String get actionSaveAnyway => 'Vẫn lưu';

  @override
  String get actionReview => 'Xem lại';

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
