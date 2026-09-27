/// A gia phả sealed with a password (PRODUCT.md §9.2).
///
/// [encodeFamilyFile] produces plain JSON: names, dates, birthplaces and the
/// lives of people who are still alive. A file like that reaching one wrong
/// person reaches everybody they forward it to, and nothing can be taken back.
/// So the file that leaves the device is sealed, and the password is the only
/// thing that opens it.
///
/// ## What this protects, and what it does not
///
/// It protects a file that is *found*: left in a chat application's cache, in
/// a Downloads folder, on a phone somebody lost. Against that it is complete —
/// without the password the bytes are noise.
///
/// It does **not** protect against the person it was sent to passing on the
/// file *and* the password. No file encryption can, and the honest place to
/// say so is the screen that asks for the password: sending both in the same
/// message is the same as sending neither. Access that can be withdrawn is the
/// cloud invitation (§5.5), not a file.
///
/// ## Why these algorithms
///
/// **Argon2id** derives the key, because people choose weak passwords and a
/// found file can be attacked offline as fast as the attacker's hardware
/// allows. Argon2id is memory-hard, so that hardware buys much less than it
/// would against a plain hash. It has no native implementation on either
/// platform — `cryptography_flutter` covers AES, ChaCha20, HMAC and PBKDF2 and
/// not this — so it runs in Dart and it is slow. Measured on a development
/// Mac: 64 MiB costs 2.5 seconds, 32 MiB costs one. A mid-range Android phone
/// will be several times that, which is why [seal] and [unseal] belong in an
/// isolate and why the cost is written into the file rather than assumed.
///
/// PBKDF2 was measured beside it and is worse on both counts: 600,000 rounds
/// took 5.8 seconds and it is not memory-hard.
///
/// **AES-256-GCM** does the encryption, and authenticates as well as hides. A
/// tampered file fails to open instead of decrypting into rubbish that then
/// gets merged into somebody's gia phả. The header is passed as associated
/// data, so nobody can lower the work factor in it and attack the result at
/// their leisure.
///
/// ## The envelope
///
/// ```json
/// {
///   "ftree":  1,
///   "kdf":    {"name": "argon2id", "memory": 32768, "iterations": 3,
///              "parallelism": 1, "salt": "<base64>"},
///   "cipher": {"name": "aes-256-gcm", "nonce": "<base64>"},
///   "body":   "<base64>"
/// }
/// ```
///
/// The header is plain, and has to be: without the salt and the exact cost
/// parameters the key cannot be derived again, and a later version that raises
/// the cost could not open a file written by this one. It names no family —
/// what leaks from a sealed file should be nothing at all.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// The envelope's own version, separate from the gia phả format inside it.
const int familyVaultVersion = 1;

/// The shortest password that will be sealed.
///
/// Long rather than complicated. A passphrase somebody can remember — four or
/// five ordinary words — resists an offline attack better than eight
/// characters of punctuation nobody can recall, and it is what people will
/// actually use. Spaces and Vietnamese letters are welcome, which is the whole
/// reason [_normalised] exists.
const int minimumVaultPassword = 12;

/// Work factors, written into every file that is sealed.
///
/// Read back from the file when opening, never assumed — raising these later
/// must not make today's backups unreadable. 32 MiB is a compromise struck
/// against a phone: it is the point where a development Mac takes about a
/// second, and the oldest supported Android will take several.
const int _memoryKiB = 32 * 1024;
const int _iterations = 3;
const int _parallelism = 1;

/// Why a sealed file could not be opened.
enum VaultRefusal {
  /// Not one of these at all.
  notAVault,

  /// Sealed by a later version of the application.
  tooNew,

  /// The password is wrong, or the file has been damaged or tampered with.
  ///
  /// The two cannot be told apart, and saying so plainly is better than
  /// guessing: authentication fails identically either way.
  wrongPasswordOrDamaged,
}

final class VaultException implements Exception {
  const VaultException(this.refusal);

  final VaultRefusal refusal;

  @override
  String toString() => 'VaultException(${refusal.name})';
}

/// Seals [contents] with [password].
///
/// Slow on purpose. Call it off the interface thread.
Future<String> seal({
  required String contents,
  required String password,
}) async {
  final salt = _random(16);
  final key = await _keyFrom(
    password: password,
    salt: salt,
    memoryKiB: _memoryKiB,
    iterations: _iterations,
    parallelism: _parallelism,
  );

  final nonce = _random(12);
  final header = <String, Object?>{
    'ftree': familyVaultVersion,
    'kdf': <String, Object?>{
      'name': 'argon2id',
      'memory': _memoryKiB,
      'iterations': _iterations,
      'parallelism': _parallelism,
      'salt': base64.encode(salt),
    },
    'cipher': <String, Object?>{
      'name': 'aes-256-gcm',
      'nonce': base64.encode(nonce),
    },
  };

  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(contents),
    secretKey: key,
    nonce: nonce,
    // Bound to the header, so the cost written there cannot be lowered and
    // the file attacked against the weaker one.
    aad: _headerBytes(header),
  );

  return jsonEncode(<String, Object?>{
    ...header,
    'body': base64.encode(<int>[...box.cipherText, ...box.mac.bytes]),
  });
}

/// Opens what [seal] produced, or throws [VaultException].
///
/// Slow on purpose, for the same reason.
Future<String> unseal({
  required String sealed,
  required String password,
}) async {
  final Map<String, Object?> envelope;
  try {
    envelope = (jsonDecode(sealed) as Map<String, dynamic>)
        .cast<String, Object?>();
  } catch (_) {
    throw const VaultException(VaultRefusal.notAVault);
  }

  final version = envelope['ftree'];
  if (version is! int) throw const VaultException(VaultRefusal.notAVault);
  if (version > familyVaultVersion) {
    throw const VaultException(VaultRefusal.tooNew);
  }

  final Uint8List salt, nonce, body;
  final int memoryKiB, iterations, parallelism;
  try {
    final kdf = (envelope['kdf']! as Map<String, dynamic>)
        .cast<String, Object?>();
    final cipher = (envelope['cipher']! as Map<String, dynamic>)
        .cast<String, Object?>();

    if (kdf['name'] != 'argon2id' || cipher['name'] != 'aes-256-gcm') {
      throw const VaultException(VaultRefusal.tooNew);
    }

    salt = base64.decode(kdf['salt']! as String);
    memoryKiB = kdf['memory']! as int;
    iterations = kdf['iterations']! as int;
    parallelism = kdf['parallelism']! as int;
    nonce = base64.decode(cipher['nonce']! as String);
    body = base64.decode(envelope['body']! as String);
  } on VaultException {
    rethrow;
  } catch (_) {
    throw const VaultException(VaultRefusal.notAVault);
  }

  // Read from the file, never from the constants above: a later version that
  // raises the cost still has to open what this one wrote.
  final key = await _keyFrom(
    password: password,
    salt: salt,
    memoryKiB: memoryKiB,
    iterations: iterations,
    parallelism: parallelism,
  );

  const macLength = 16;
  if (body.length < macLength) {
    throw const VaultException(VaultRefusal.wrongPasswordOrDamaged);
  }

  try {
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        body.sublist(0, body.length - macLength),
        nonce: nonce,
        mac: Mac(body.sublist(body.length - macLength)),
      ),
      secretKey: key,
      aad: _headerBytes(<String, Object?>{
        'ftree': version,
        'kdf': envelope['kdf'],
        'cipher': envelope['cipher'],
      }),
    );
    return utf8.decode(clear);
  } catch (_) {
    throw const VaultException(VaultRefusal.wrongPasswordOrDamaged);
  }
}

/// Whether [text] looks like something [unseal] could be given.
///
/// Cheap, and only to choose which screen to show. It decides nothing about
/// whether the file will open.
bool looksSealed(String text) {
  try {
    final parsed = jsonDecode(text);
    return parsed is Map && parsed['ftree'] is int && parsed['body'] is String;
  } catch (_) {
    return false;
  }
}

Future<SecretKey> _keyFrom({
  required String password,
  required List<int> salt,
  required int memoryKiB,
  required int iterations,
  required int parallelism,
}) => Argon2id(
  memory: memoryKiB,
  iterations: iterations,
  parallelism: parallelism,
  hashLength: 32,
).deriveKeyFromPassword(password: _normalised(password), nonce: salt);

/// The password in one canonical spelling.
///
/// `phả` can be typed as one code point or as two, and the two look the same
/// on every screen and hash to different keys. Without this, a backup sealed
/// on one keyboard would refuse the same password typed on another, and the
/// refusal would be indistinguishable from getting it wrong.
String _normalised(String password) => unorm.nfc(password);

/// The header, serialised the one way both ends will serialise it.
List<int> _headerBytes(Map<String, Object?> header) =>
    utf8.encode(jsonEncode(header));

Uint8List _random(int length) {
  final random = SecretKeyData.random(length: length);
  return Uint8List.fromList(random.bytes);
}
