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

  group('rankName', () {
    test('the given name outranks everything', () {
      // It is what a relative is actually called, and the last word of a
      // Vietnamese name.
      expect(rankName('Nguyễn Văn Hải', 'hai'), NameMatch.givenName);
    });

    test('the start of a given name comes next', () {
      expect(rankName('Nguyễn Văn Hải', 'hả'), NameMatch.givenNameStart);
    });

    test('a middle name ranks below a given one', () {
      expect(rankName('Võ Hải Linh', 'hai'), NameMatch.middleName);
      expect(
        NameMatch.middleName.index,
        greaterThan(NameMatch.givenName.index),
      );
    });

    test('the surname ranks below both', () {
      // Everybody in a gia phả shares it, so it narrows almost nothing.
      expect(rankName('Nguyễn Văn Cả', 'nguyen'), NameMatch.familyName);
    });

    test('a match buried inside a word ranks last', () {
      // Nearly always an accident of spelling rather than the name wanted.
      expect(rankName('Nguyễn Thị Thái', 'hai'), NameMatch.insideAWord);
    });

    test('a name it does not answer at all comes back null', () {
      expect(rankName('Nguyễn Văn Cả', 'tran'), isNull);
    });

    test('a one-word name is its own given name', () {
      expect(rankName('Hải', 'hai'), NameMatch.givenName);
    });

    test('diacritics are ignored, as everywhere else', () {
      expect(rankName('Nguyễn Văn Hải', 'HAI'), NameMatch.givenName);
      expect(rankName('Nguyễn Đình Lâm', 'dinh'), NameMatch.middleName);
    });

    test('an empty query answers every name, at the weakest rank', () {
      // Clearing the field puts the list back in the order it was in rather
      // than re-sorting it into a new one.
      expect(rankName('Nguyễn Văn Cả', ''), NameMatch.insideAWord);
      expect(rankName('Nguyễn Văn Cả', '  '), NameMatch.insideAWord);
    });
  });

  group('rankedByName', () {
    List<String> order(List<String> names, String query) =>
        rankedByName(names, query, nameOf: (n) => n);

    test('puts those called it above those merely containing it', () {
      // The fault this exists for: typing `van` on a real family brings back
      // six who are called Văn buried among nine who are not.
      expect(
        order(<String>['Nguyễn Văn Phong', 'Trần Thị Vân'], 'van'),
        <String>['Trần Thị Vân', 'Nguyễn Văn Phong'],
      );
    });

    test('drops the names it does not answer', () {
      expect(
        order(<String>['Nguyễn Văn Hải', 'Lê Thị Hoà'], 'hai'),
        <String>['Nguyễn Văn Hải'],
      );
    });

    test('settles a tie with the shorter name', () {
      expect(
        order(<String>['Nguyễn Văn Đình Hải', 'Lê Hải'], 'hai'),
        <String>['Lê Hải', 'Nguyễn Văn Đình Hải'],
      );
    });

    test('settles the rest by the order given, not by chance', () {
      // Two names of the same rank and the same length. Dart's sort is not
      // stable, so without carrying the position through, the list would
      // reshuffle under the reader's finger between keystrokes.
      final names = <String>['Lê Văn Hải', 'Đỗ Văn Hải', 'Vũ Văn Hải'];

      expect(order(names, 'hai'), names);
      expect(order(names, 'hai'), order(names, 'hai'));
    });

    test('an empty query keeps everybody, in the order given', () {
      final names = <String>['Trần Thị Mậu', 'Nguyễn Văn Cả', 'Lê Thị Hoà'];

      expect(order(names, ''), names);
    });

    test('ranks a whole list the way a reader would expect', () {
      expect(
        order(<String>[
          'Nguyễn Thị Thái', // inside a word
          'Võ Hải Linh', // middle name
          'Nguyễn Văn Hải', // given name
          'Lê Thị Hoà', // no answer
        ], 'hai'),
        <String>['Nguyễn Văn Hải', 'Võ Hải Linh', 'Nguyễn Thị Thái'],
      );
    });
  });
}
