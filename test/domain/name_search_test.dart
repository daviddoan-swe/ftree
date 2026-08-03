import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/name_search.dart';

void main() {
  group('folding', () {
    test('strips every Vietnamese tone mark', () {
      expect(foldForSearch('Nguyễn'), 'nguyen');
      expect(foldForSearch('Trần Thị Mậu'), 'tran thi mau');
      expect(foldForSearch('Nguyễn Phúc Thịnh'), 'nguyen phuc thinh');
      expect(foldForSearch('Lê Thị Hoà'), 'le thi hoa');
      expect(foldForSearch('Đường'), 'duong');
      expect(foldForSearch('Vũ Thị Tý'), 'vu thi ty');
    });

    test('covers every vowel family', () {
      expect(foldForSearch('àáạảãăằắặẳẵâầấậẩẫ'), 'a' * 17);
      expect(foldForSearch('èéẹẻẽêềếệểễ'), 'e' * 11);
      expect(foldForSearch('ìíịỉĩ'), 'i' * 5);
      expect(foldForSearch('òóọỏõôồốộổỗơờớợởỡ'), 'o' * 17);
      expect(foldForSearch('ùúụủũưừứựửữ'), 'u' * 11);
      expect(foldForSearch('ỳýỵỷỹ'), 'y' * 5);
    });

    test('leaves everything else alone', () {
      expect(foldForSearch('Phù Ninh, Nam Định 1887'), 'phu ninh, nam dinh 1887');
    });
  });

  group('matching', () {
    test('finds a name typed without its marks', () {
      // The point of the whole file: this is how the name arrives from a phone
      // keyboard half the time.
      expect(nameMatches('Nguyễn Văn Cả', 'nguyen'), isTrue);
      expect(nameMatches('Trần Thị Mậu', 'tran thi'), isTrue);
      expect(nameMatches('Nguyễn Đình Chiểu', 'dinh'), isTrue);
    });

    test('finds a name typed with them', () {
      expect(nameMatches('Nguyễn Văn Cả', 'Nguyễn'), isTrue);
      expect(nameMatches('Nguyễn Văn Cả', 'văn'), isTrue);
    });

    test('ignores case on both sides', () {
      expect(nameMatches('NGUYỄN VĂN CẢ', 'nguyen'), isTrue);
      expect(nameMatches('nguyễn văn cả', 'NGUYEN'), isTrue);
    });

    test('matches inside the name, not only at the start', () {
      // Everybody in a gia phả shares the surname; the given name is what
      // distinguishes them, and it is the last word.
      expect(nameMatches('Nguyễn Văn Cả', 'ca'), isTrue);
      expect(nameMatches('Nguyễn Thị Thu Hà', 'thu'), isTrue);
    });

    test('says no when the name really does not contain it', () {
      expect(nameMatches('Nguyễn Văn Cả', 'tran'), isFalse);
      expect(nameMatches('Lê Thị Hoà', 'x'), isFalse);
    });

    test('an empty query matches everything', () {
      // Clearing the field puts the whole list back rather than emptying it.
      expect(nameMatches('Nguyễn Văn Cả', ''), isTrue);
      expect(nameMatches('Nguyễn Văn Cả', '   '), isTrue);
    });
  });
}
