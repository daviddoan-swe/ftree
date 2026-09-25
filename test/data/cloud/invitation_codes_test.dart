/// Making a code, and finding one again in whatever it arrives inside
/// (PRODUCT.md §5.2).
///
/// No server: the canonical form and the hash are the contract *with* the
/// server, and the pair of one-line functions on each side have to agree
/// exactly or nothing ever matches. These are the examples both are held to.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/cloud/family_invitations.dart';

void main() {
  group('the shape of a code', () {
    test('ten characters, grouped for reading', () {
      final code = newInvitationCode(Random(7));

      expect(code, matches(RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{2}$')));
      expect(canonicalInvitationCode(code), hasLength(10));
    });

    test('the four characters nobody can transcribe are left out', () {
      // O and 0, I and 1 are the same mark to somebody reading a code off one
      // screen and typing it into another.
      for (var seed = 0; seed < 200; seed++) {
        final code = newInvitationCode(Random(seed));
        expect(code, isNot(contains('O')));
        expect(code, isNot(contains('0')));
        expect(code, isNot(contains('I')));
        expect(code, isNot(contains('1')));
      }
    });

    test('two codes are not the same code', () {
      final made = <String>{for (var i = 0; i < 500; i++) newInvitationCode()};

      expect(made, hasLength(500));
    });
  });

  group('the canonical form, which the server computes too', () {
    test('case and punctuation fall away', () {
      expect(canonicalInvitationCode('k7p2-9xmr-4t'), 'K7P29XMR4T');
      expect(canonicalInvitationCode('k7p2 9xmr4t'), 'K7P29XMR4T');
      expect(canonicalInvitationCode('K7P2-9XMR-4T'), 'K7P29XMR4T');
    });

    test('so the same hash comes out of all of them', () {
      final hash = invitationCodeHash('K7P2-9XMR-4T');

      expect(invitationCodeHash('k7p2 9xmr4t'), hash);
      expect(invitationCodeHash('  K7P29XMR4T  '), hash);
    });

    test('and a different code is a different hash', () {
      expect(
        invitationCodeHash('K7P2-9XMR-4T'),
        isNot(invitationCodeHash('K7P2-9XMR-4Y')),
      );
    });
  });

  group('finding the code inside a message', () {
    // The phone's own Copy button hands over the whole sentence, and so does
    // anybody forwarding it. Refusing that would refuse the most obvious way
    // to move a code between two phones.
    const english =
        'Your code for the Họ Nguyễn (dữ liệu thử) family tree: 6E54-7LNH-MR'
        '\n\nIt works once, and expires in seven days.';
    const vietnamese =
        'Mã mời vào gia phả Họ Nguyễn: 6E54-7LNH-MR'
        '\n\nMã dùng một lần và hết hạn sau 7 ngày.';

    test('the English message', () {
      expect(invitationCodeIn(english), '6E54-7LNH-MR');
    });

    test('the Vietnamese message', () {
      expect(invitationCodeIn(vietnamese), '6E54-7LNH-MR');
    });

    test('a bare code is left exactly as it is', () {
      expect(invitationCodeIn('6E54-7LNH-MR'), '6E54-7LNH-MR');
    });

    test('and so is one typed without its hyphens', () {
      // No match, so it passes through to the canonical form, which is where
      // it was always going to be sorted out.
      expect(invitationCodeIn('6e547lnhmr'), '6e547lnhmr');
      expect(
        canonicalInvitationCode(invitationCodeIn('6e547lnhmr')),
        '6E547LNHMR',
      );
    });

    test('a family named like a code does not win over the code', () {
      // Both messages put the name before the code, so the last match is the
      // one that was issued.
      expect(
        invitationCodeIn(
          'Your code for the AAAA-BBBB-CC family tree: 6E54-7LNH-MR'
          '\n\nIt works once.',
        ),
        '6E54-7LNH-MR',
      );
    });

    test('a message carrying no code at all comes back whole', () {
      expect(invitationCodeIn('chào bác'), 'chào bác');
    });
  });
}
