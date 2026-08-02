/// Entity identifiers (DOMAIN.md §14).
///
/// Ids are UUID version 7: a 48-bit millisecond timestamp followed by random
/// bits. They can be generated offline with no server round trip, which an
/// offline-first application requires, and because the timestamp leads, ids
/// created near each other sort near each other. That keeps inserts appending
/// to the end of an index instead of scattering across it, in both SQLite and
/// PostgreSQL.
///
/// Version 4 would also generate offline, but its full randomness scatters
/// every insert. Choosing v7 now costs nothing; changing it later is a
/// primary-key migration across every table on every installed device (§18).
///
/// Ids are globally unique on their own and are never combined with a family
/// id to form a composite key (§14.1).
///
/// Generation is deliberately kept out of the entities. Reading a clock and a
/// random source is not a pure operation, and an entity that generated its own
/// id could not be constructed twice with the same value — every entity test
/// would become non-deterministic. Entities take an id as a constructor
/// argument instead.
library;

import 'dart:math';

/// Layout of UUID v7 per RFC 9562:
///
/// ```
///  bits 0-47    unix timestamp, milliseconds
///  bits 48-51   version, always 0x7
///  bits 52-63   random
///  bits 64-65   variant, always 0b10
///  bits 66-127  random
/// ```
///
/// Rendered in the canonical 8-4-4-4-12 lowercase hexadecimal form.
const int _version = 0x7;
const int _variant = 0x2;

final Random _defaultRandom = Random.secure();

/// Generates a new UUID v7 identifier.
///
/// [at] and [random] exist so tests can pin the output; production callers pass
/// neither. Without injection the only testable property would be "two ids
/// differ", which would not catch a wrong version nibble, a wrong variant, or a
/// timestamp written to the wrong bits.
///
/// No monotonic counter is kept, so two ids generated within the same
/// millisecond have no defined order relative to each other. RFC 9562 describes
/// such a counter as optional; it needs mutable state, and for records a person
/// types by hand the case barely arises and the ordering within one millisecond
/// carries no meaning.
String newId({DateTime? at, Random? random}) {
  final rng = random ?? _defaultRandom;
  final millis = (at ?? DateTime.now()).millisecondsSinceEpoch;

  if (millis < 0) {
    throw ArgumentError.value(
      at,
      'at',
      'must not precede the Unix epoch — UUID v7 cannot represent it',
    );
  }

  final bytes = List<int>.filled(16, 0);

  // Bits 0-47: big-endian millisecond timestamp.
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> (8 * (5 - i))) & 0xFF;
  }

  // The rest starts random; version and variant are then stamped over their
  // fixed positions.
  for (var i = 6; i < 16; i++) {
    bytes[i] = rng.nextInt(256);
  }

  // Bits 48-51: version.
  bytes[6] = (bytes[6] & 0x0F) | (_version << 4);
  // Bits 64-65: variant.
  bytes[8] = (bytes[8] & 0x3F) | (_variant << 6);

  return _format(bytes);
}

/// Whether [value] is a well-formed UUID v7 in canonical form.
///
/// Checks shape, version, and variant. It cannot distinguish a genuine id from
/// a fabricated one, and is meant for guarding boundaries such as parsing
/// stored data rather than for validating user input.
bool isValidId(String value) {
  if (!_canonical.hasMatch(value)) return false;
  final version = int.parse(value[14], radix: 16);
  final variant = int.parse(value[19], radix: 16);
  return version == _version && (variant >> 2) == _variant;
}

final RegExp _canonical = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

String _format(List<int> bytes) {
  final digits = StringBuffer();
  for (final byte in bytes) {
    digits.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  final hex = digits.toString();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
