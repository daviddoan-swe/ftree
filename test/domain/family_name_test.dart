/// The surname inside a family's name (PRODUCT.md §1.1).
///
/// One rule, two readers: the letter on the family glyph and the surname a new
/// person starts with. They were written separately once; this is what keeps
/// them from disagreeing.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/family_name.dart';
import 'package:ftree/domain/name_search.dart';

void main() {
  group('the naming word', () {
    test('Họ Nguyễn is Nguyễn', () {
      expect(familySurname('Họ Nguyễn'), 'Nguyễn');
    });

    test('a branch says where, not who', () {
      // Họ Nguyễn – Phù Ninh is a Nguyễn who lives somewhere.
      expect(familySurname('Họ Nguyễn – Phù Ninh'), 'Nguyễn');
    });

    test('Gia đình Trần is Trần, tone marks and all', () {
      // `đình` only matches the generic list once it is folded.
      expect(familySurname('Gia đình Trần'), 'Trần');
    });

    test('written without tone marks it still works', () {
      // Half the family types this way, and a file may arrive written so.
      expect(familySurname('Ho Doan'), 'Doan');
    });

    test('English phrasing too, because a file may carry it', () {
      expect(familySurname('the Nguyễn family'), 'Nguyễn');
    });

    test('a name that is only a name is left alone', () {
      expect(familySurname('Nguyễn'), 'Nguyễn');
    });

    test('tone marks are kept — this is a name, not a search key', () {
      // foldForSearch is used to *compare* words against the generic list,
      // never to rewrite the answer. A surname handed back folded would put
      // `nguyen` on thirty people.
      //
      // Written against the folded form rather than against a literal: the
      // first draft asserted `isNot('Nguyen')` and passed happily while the
      // function returned `nguyen`, because folding lower-cases too.
      final surname = familySurname('Họ Nguyễn');

      expect(surname, 'Nguyễn');
      expect(surname, isNot(foldForSearch(surname)));
    });
  });

  group('what it refuses to do', () {
    test('a name made only of generic words comes back whole', () {
      // Somebody typed just `Họ`. Answering with nothing is a worse answer
      // than answering with what they wrote.
      expect(familySurname('Họ'), 'Họ');
      expect(familySurname('Gia đình'), 'Gia');
    });

    test('nothing in, nothing out', () {
      expect(familySurname(''), '');
      expect(familySurname('   '), '');
    });

    test('untidy spacing does not change the answer', () {
      expect(familySurname('  Họ   Nguyễn  '), 'Nguyễn');
    });
  });
}
