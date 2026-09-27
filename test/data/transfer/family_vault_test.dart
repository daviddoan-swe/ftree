/// A gia phả sealed with a password (PRODUCT.md §9.2).
///
/// Slow on purpose: Argon2id is the point, and every test here pays for it
/// twice. That cost is the feature.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/transfer/family_vault.dart';

void main() {
  const gia = '{"version":1,"family":{"name":"Họ Nguyễn"}}';
  const password = 'gia phả họ Nguyễn 2026';

  test('what goes in comes back out', () async {
    final sealed = await seal(contents: gia, password: password);

    expect(await unseal(sealed: sealed, password: password), gia);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'and nothing of it is readable in between',
    () async {
      // The whole point. A file that leaked the family's name in its header
      // would tell whoever found it whose records these are.
      final sealed = await seal(contents: gia, password: password);

      expect(sealed.contains('Nguyễn'), isFalse);
      expect(sealed.contains('family'), isFalse);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'the wrong password is refused, not half-answered',
    () async {
      final sealed = await seal(contents: gia, password: password);

      await expectLater(
        unseal(sealed: sealed, password: 'gia phả họ Nguyễn 2027'),
        throwsA(
          isA<VaultException>().having(
            (e) => e.refusal,
            'refusal',
            VaultRefusal.wrongPasswordOrDamaged,
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('a tampered body is refused too', () async {
    // GCM authenticates as well as hides. Without that a changed file would
    // decrypt into rubbish and the rubbish would be merged into a gia phả.
    final sealed = await seal(contents: gia, password: password);
    final envelope = jsonDecode(sealed) as Map<String, dynamic>;
    final body = base64.decode(envelope['body'] as String);
    body[0] ^= 0xFF;
    envelope['body'] = base64.encode(body);

    await expectLater(
      unseal(sealed: jsonEncode(envelope), password: password),
      throwsA(isA<VaultException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'and so is a header somebody made cheaper',
    () async {
      // The attack the associated data exists for: lower the work factor in
      // the plain header, then guess passwords against the easier sum.
      final sealed = await seal(contents: gia, password: password);
      final envelope = jsonDecode(sealed) as Map<String, dynamic>;
      (envelope['kdf'] as Map<String, dynamic>)['memory'] = 8;

      await expectLater(
        unseal(sealed: jsonEncode(envelope), password: password),
        throwsA(isA<VaultException>()),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'every seal gets its own salt and its own nonce',
    () async {
      // Comparing the two files as a whole is not enough: fix the salt and the
      // nonce still differs, so the bytes differ and a weaker test passes — as
      // the one that used to stand here did. Each has to be looked at alone.
      //
      // A reused salt means one password always makes one key, so cracking one
      // backup opens every backup that person ever made. A reused nonce under
      // the same key is worse: GCM leaks the two plaintexts against each other
      // and forgery becomes possible.
      Map<String, dynamic> head(String sealed) =>
          jsonDecode(sealed) as Map<String, dynamic>;

      final one = head(await seal(contents: gia, password: password));
      final two = head(await seal(contents: gia, password: password));

      expect(
        (one['kdf'] as Map<String, dynamic>)['salt'],
        isNot((two['kdf'] as Map<String, dynamic>)['salt']),
        reason: 'a salt reused makes one key for every backup',
      );
      expect(
        (one['cipher'] as Map<String, dynamic>)['nonce'],
        isNot((two['cipher'] as Map<String, dynamic>)['nonce']),
        reason: 'a nonce reused under one key breaks GCM outright',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the same password typed two ways still opens it',
    () async {
      // `phả` is one code point or two, identical on every screen. Hashed as
      // they arrive, a backup sealed on one keyboard would refuse the same
      // password typed on another — and the refusal would look exactly like
      // getting it wrong.
      const composed = 'gia phả 2026'; // phả as one code point
      const decomposed = 'gia phả 2026'; // pha + combining hook

      expect(composed, isNot(decomposed), reason: 'different bytes');

      final sealed = await seal(contents: gia, password: composed);

      expect(await unseal(sealed: sealed, password: decomposed), gia);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'a plain file is not mistaken for a sealed one',
    () async {
      expect(looksSealed('{"version":1,"family":{}}'), isFalse);
      expect(looksSealed('không phải json'), isFalse);
      expect(
        looksSealed(await seal(contents: gia, password: password)),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'one from a later version says so rather than failing oddly',
    () async {
      final sealed = await seal(contents: gia, password: password);
      final envelope = jsonDecode(sealed) as Map<String, dynamic>;
      envelope['ftree'] = familyVaultVersion + 1;

      await expectLater(
        unseal(sealed: jsonEncode(envelope), password: password),
        throwsA(
          isA<VaultException>().having(
            (e) => e.refusal,
            'refusal',
            VaultRefusal.tooNew,
          ),
        ),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
