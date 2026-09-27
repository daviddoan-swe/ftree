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
  String get familyRemovedNotice =>
      'Không có quyền. Đây là bản đã tải về máy, chỉ đọc được.';

  @override
  String get familiesEmptyHint => 'Tạo một gia đình để bắt đầu ghi gia phả';

  @override
  String get familyCreate => 'Tạo gia đình';

  @override
  String get familyName => 'Tên gia đình';

  @override
  String get familyNameHint => 'Ví dụ: Nguyễn';

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
  String get trailToList => 'Về danh sách người';

  @override
  String get trailToTree => 'Về cây gia phả';

  @override
  String get exportConfirmTitle => 'Xuất dòng họ này?';

  @override
  String exportConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gửi toàn bộ $count người ra khỏi máy',
      one: 'Gửi 1 người ra khỏi máy',
    );
    return '$_temp0, kèm ngày tháng, nơi chốn và ghi chú — gồm cả người còn sống. File gửi đi rồi thì không thu lại được.';
  }

  @override
  String get vaultSetTitle => 'Đặt mật khẩu';

  @override
  String get vaultSetWhy =>
      'Tệp xuất ra chỉ mở được bằng mật khẩu này. Mất mật khẩu là không ai mở được tệp nữa, kể cả người tạo ra nó.';

  @override
  String get vaultSetLabel => 'Mật khẩu';

  @override
  String get vaultSetAgain => 'Nhập lại';

  @override
  String get vaultSetAction => 'Xuất dữ liệu';

  @override
  String vaultTooShort(int count) {
    return 'Ít nhất $count ký tự. Vài từ thường ghép lại là đủ tốt.';
  }

  @override
  String get vaultMismatch => 'Hai lần nhập không giống nhau';

  @override
  String get vaultSendApart =>
      'Gửi mật khẩu bằng đường khác — gọi điện, hoặc nói trực tiếp. Gửi chung một tin nhắn với tệp thì coi như không có mật khẩu.';

  @override
  String get vaultOpenTitle => 'Mật khẩu';

  @override
  String get vaultOpenWhy => 'Tệp này cần mật khẩu. Hãy hỏi người đã gửi.';

  @override
  String get vaultOpenAction => 'Mở';

  @override
  String get vaultWrong => 'Sai mật khẩu, hoặc tệp đã hỏng';

  @override
  String get vaultTooNew => 'Bản sao lưu này do phiên bản mới hơn tạo ra';

  @override
  String get vaultWorking => 'Đang xuất file…';

  @override
  String get vaultOpening => 'Đang mở…';

  @override
  String get exportAction => 'Xuất';

  @override
  String get exportNothing => 'Dòng họ này không còn gì để xuất';

  @override
  String get importTitle => 'Nhập gia phả';

  @override
  String importFrom(String date) {
    return 'File ghi ngày $date';
  }

  @override
  String get importNewFamily => 'Dòng họ này chưa có trên máy';

  @override
  String importAddsPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thêm $count người',
      one: 'Thêm 1 người',
      zero: 'Không thêm người nào',
    );
    return '$_temp0';
  }

  @override
  String importAddsRelationships(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Thêm $count quan hệ',
      one: 'Thêm 1 quan hệ',
      zero: 'Không thêm quan hệ nào',
    );
    return '$_temp0';
  }

  @override
  String importAlreadyHerePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count người đã có sẵn',
      one: '1 người đã có sẵn',
    );
    return '$_temp0';
  }

  @override
  String importAlreadyHereRelationships(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quan hệ đã có sẵn',
      one: '1 quan hệ đã có sẵn',
    );
    return '$_temp0';
  }

  @override
  String importRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quan hệ không nhận được',
      one: '1 quan hệ không nhận được',
    );
    return '$_temp0';
  }

  @override
  String get importAddOnly =>
      'Chỉ thêm, không sửa gì đang có. Bản sửa trên máy người khác không truyền sang được.';

  @override
  String get importNothingNew => 'File này không có gì mới so với máy';

  @override
  String get importAction => 'Nhập';

  @override
  String get importDeletedByOwner =>
      'Chủ dòng họ đã xoá dòng họ này. Chỉ chủ mới khôi phục lại được.';

  @override
  String get importNotAllowed =>
      'Chỉ có quyền xem dòng họ này, nên không nhập thêm vào được.';

  @override
  String get importFailed => 'Không đọc được file';

  @override
  String importDonePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Đã thêm $count người',
      one: 'Đã thêm 1 người',
      zero: 'Không thêm người nào',
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
  String get generationFilterAll => 'Tất cả';

  @override
  String get generationFilterUnknown => 'Chưa rõ đời';

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

  @override
  String get accountTitle => 'Tài khoản';

  @override
  String get accountWhy =>
      'Tài khoản chỉ dùng để chia sẻ dòng họ. Gia phả trên máy vẫn dùng được bình thường mà không cần đăng nhập.';

  @override
  String get accountCreate => 'Đăng ký';

  @override
  String get accountSignIn => 'Đăng nhập';

  @override
  String get membersAction => 'Thành viên';

  @override
  String get accountSignOut => 'Đăng xuất';

  @override
  String get accountSignOutTitle => 'Đăng xuất khỏi tài khoản này?';

  @override
  String get accountSignOutBody =>
      'Gia phả trên máy vẫn còn nguyên và vẫn dùng được mà không cần tài khoản.\n\nNhưng những mã lời mời đang treo sẽ không gửi lại được từ máy này nữa. Hãy huỷ chúng rồi tạo mã mới sau khi đăng nhập lại.';

  @override
  String get accountName => 'Tên';

  @override
  String get accountNameHint => 'Tên hiển thị';

  @override
  String get accountNameMissing => 'Hãy nhập tên';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountPassword => 'Mật khẩu';

  @override
  String accountPasswordHint(int count) {
    return 'Ít nhất $count ký tự';
  }

  @override
  String get accountEmailMissing => 'Hãy nhập email';

  @override
  String get accountEmailInvalid => 'Email không đúng dạng';

  @override
  String accountPasswordShort(int count) {
    return 'Mật khẩu cần ít nhất $count ký tự';
  }

  @override
  String get accountPasswordMissing => 'Hãy nhập mật khẩu';

  @override
  String get accountWrongCredentials => 'Email hoặc mật khẩu không đúng';

  @override
  String get accountEmailTaken =>
      'Email này đã có tài khoản. Hãy chọn Đăng nhập.';

  @override
  String get accountConfirmEmail =>
      'Đã tạo tài khoản. Hãy mở email, bấm liên kết xác nhận, rồi quay lại đăng nhập.';

  @override
  String accountRefused(String reason) {
    return 'Không xong được: $reason';
  }

  @override
  String get shareAction => 'Chia sẻ';

  @override
  String get shareConfirmTitle => 'Chia sẻ dòng họ này?';

  @override
  String get shareConfirmBody =>
      'Dòng họ này sẽ được gửi lên máy chủ và tài khoản này trở thành chủ của nó. Các dòng họ khác trên máy vẫn ở lại máy. Đã gửi rồi thì không rút về được.';

  @override
  String shareDone(String name) {
    return 'Đã chia sẻ $name';
  }

  @override
  String shareAlreadyShared(String name) {
    return '$name đã được chia sẻ rồi';
  }

  @override
  String get shareClaimedByOther =>
      'Dòng họ này đã có người khác chia sẻ. Hãy nhờ họ mời vào để cùng sửa.';

  @override
  String get shareFailed => 'Không chia sẻ được';

  @override
  String get roleOwner => 'Chủ';

  @override
  String get roleEditor => 'Người sửa';

  @override
  String get roleViewer => 'Người xem';

  @override
  String get inviteAction => 'Mời';

  @override
  String get inviteTitle => 'Lời mời';

  @override
  String get inviteNone => 'Chưa mời ai vào dòng họ này';

  @override
  String get inviteNew => 'Mời thêm';

  @override
  String get inviteSend => 'Gửi';

  @override
  String get inviteRevoke => 'Huỷ';

  @override
  String get inviteNoCode => 'Máy này không còn giữ mã';

  @override
  String inviteExpiresIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Còn $count ngày',
      one: 'Còn 1 ngày',
      zero: 'Hết hạn hôm nay',
    );
    return '$_temp0';
  }

  @override
  String inviteRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get inviteNobodyUsed => 'Chưa ai dùng';

  @override
  String get inviteLive => 'Còn hiệu lực';

  @override
  String get inviteSearch => 'Tìm theo email';

  @override
  String get inviteNoMatch => 'Không có lời mời khớp';

  @override
  String get inviteUsed => 'Đã dùng';

  @override
  String get inviteRevoked => 'Đã huỷ';

  @override
  String get inviteExpired => 'Hết hạn';

  @override
  String get inviteOwnerWarningTitle => 'Mời làm chủ dòng họ?';

  @override
  String get inviteOwnerWarningBody =>
      'Người này sẽ làm được mọi thứ chủ dòng họ làm được: mời người khác, mời thêm chủ, và xoá cả dòng họ. Không có cách nào lấy lại quyền đó.';

  @override
  String get inviteRevokeTitle => 'Huỷ mã mời?';

  @override
  String get inviteRevokeBody =>
      'Mã này sẽ không dùng được nữa. Người đã nhận mã sẽ không vào được. Có thể tạo mã mới bất cứ lúc nào.';

  @override
  String inviteMessage(String family, String code) {
    return 'Mã mời vào gia phả $family: $code\n\nMã dùng một lần và hết hạn sau 7 ngày.';
  }

  @override
  String get inviteEnterTitle => 'Nhập mã mời';

  @override
  String get inviteEnterWhy =>
      'Mã do chủ dòng họ gửi. Nhập xong, gia phả sẽ được tải về máy này.';

  @override
  String get inviteEnterLabel => 'Mã mời';

  @override
  String get inviteEnterAction => 'Vào dòng họ';

  @override
  String get inviteCodeMissing => 'Hãy nhập mã mời';

  @override
  String get inviteNotFound => 'Không có mã này. Hãy kiểm tra lại từng ký tự.';

  @override
  String get inviteAlreadyUsed =>
      'Mã này đã được dùng rồi. Hãy hỏi lại người đã mời.';

  @override
  String get inviteWasRevoked => 'Mã này đã bị huỷ. Hãy hỏi lại người đã mời.';

  @override
  String get inviteFamilyDeleted =>
      'Dòng họ này đã bị xoá. Hãy hỏi lại người đã mời.';

  @override
  String get inviteHasExpired => 'Mã này đã hết hạn. Hãy xin một mã mới.';

  @override
  String get membersOwnerOnly =>
      'Chỉ chủ dòng họ mới quản lý được thành viên và lời mời.';

  @override
  String get memberChangeRole => 'Đổi vai';

  @override
  String get memberNoName => 'Chưa đặt tên';

  @override
  String get syncNever => 'Chưa đồng bộ';

  @override
  String get syncJustNow => 'Đã đồng bộ';

  @override
  String syncMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phút trước',
      one: '1 phút trước',
    );
    return '$_temp0';
  }

  @override
  String syncHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giờ trước',
      one: '1 giờ trước',
    );
    return '$_temp0';
  }

  @override
  String syncDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ngày trước',
      one: 'Hôm qua',
    );
    return '$_temp0';
  }

  @override
  String syncWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Có $count thay đổi',
      one: 'Có 1 thay đổi',
    );
    return '$_temp0';
  }

  @override
  String get syncNothingNew => 'Đã đồng bộ';

  @override
  String syncBroughtDown(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cập nhật $count thay đổi',
      one: 'Cập nhật 1 thay đổi',
    );
    return '$_temp0';
  }

  @override
  String syncSentUp(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gửi lên $count thay đổi',
      one: 'Gửi lên 1 thay đổi',
    );
    return '$_temp0';
  }

  @override
  String get syncOffline => 'Không có mạng';

  @override
  String get syncRefused => 'Máy chủ không nhận — hãy xem lại quyền ở đây';

  @override
  String get conflictsTitle => 'Chọn bản giữ lại';

  @override
  String conflictsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Có $count người cần chọn bản',
      one: 'Có 1 người cần chọn bản',
    );
    return '$_temp0';
  }

  @override
  String get conflictsNone => 'Đã chọn xong';

  @override
  String get conflictMine => 'Bản ở máy này';

  @override
  String get conflictTheirs => 'Bản trên máy chủ';

  @override
  String conflictWas(String value) {
    return 'Trước đó: $value';
  }

  @override
  String get conflictEmpty => 'để trống';

  @override
  String get conflictYes => 'có';

  @override
  String get conflictNo => 'không';

  @override
  String get conflictKeep => 'Giữ lựa chọn này';

  @override
  String get conflictRemovedByThem =>
      'Đã bị xoá ở máy khác, trong lúc máy này đang sửa.';

  @override
  String get conflictRemovedByMe =>
      'Người này bị xoá ở máy này, trong lúc máy khác đang sửa.';

  @override
  String get conflictKeepPerson => 'Giữ lại trong gia phả';

  @override
  String get conflictRemovePerson => 'Xoá khỏi gia phả';

  @override
  String get conflictForEverybody => 'Cho cả họ, ở lần đồng bộ tới';

  @override
  String conflictAsServerHas(String value) {
    return 'Theo bản trên máy chủ: $value';
  }

  @override
  String get conflictDropsMine => 'Bỏ phần sửa chưa gửi';

  @override
  String get conflictDecide => 'Lưu quyết định này';

  @override
  String get conflictBirthDate => 'Ngày sinh';

  @override
  String get conflictBirthApproximate => 'Ngày sinh là áng chừng';

  @override
  String get conflictBirthLunar => 'Ngày sinh âm lịch';

  @override
  String get conflictDeathDate => 'Ngày mất';

  @override
  String get conflictDeathApproximate => 'Ngày mất là áng chừng';

  @override
  String get conflictDeathLunar => 'Ngày mất âm lịch';

  @override
  String get conflictMedia => 'Ảnh đại diện';

  @override
  String get membersSearch => 'Tìm tên hoặc email';

  @override
  String get filterAll => 'Tất cả';

  @override
  String get membersNoMatch => 'Không có ai khớp';

  @override
  String get membersTitle => 'Thành viên';

  @override
  String get membersYou => 'bạn';

  @override
  String get memberRemove => 'Gỡ khỏi dòng họ';

  @override
  String get memberRemoveTitle => 'Gỡ người này?';

  @override
  String get memberRemoveBody =>
      'Họ sẽ không đọc hay sửa dòng họ này trên máy chủ được nữa. Bản đã tải về máy họ thì vẫn còn.';

  @override
  String get memberRemoveLastOwner => 'Dòng họ phải luôn có ít nhất một chủ';

  @override
  String familyGoneDeleted(String name) {
    return '$name đã bị xoá';
  }

  @override
  String familyGoneRemoved(String name) {
    return 'Bạn không còn trong $name';
  }

  @override
  String familiesGone(int count) {
    return '$count dòng họ không còn';
  }
}
