/// Letting a second person into a family (PRODUCT.md §5.1).
///
/// Sharing put one family on the server under one account. This is how anybody
/// else reaches it — the part §4.2 promises when it calls an account "what one
/// family needs in order to be kept by more than one person".
///
/// ## The code is made here and hashed here
///
/// The owner's device generates the code and sends the server only its hash.
/// The plaintext never travels at all on the way in; it crosses the wire once,
/// later, when somebody types it to accept — and even then it is hashed and
/// compared, never stored.
///
/// So a stolen database yields a column of hashes and nothing that opens a
/// family. What remains is the message the owner sent, and the owner's own
/// device, which already holds the whole gia phả anyway.
///
/// ## Why this is not on `FamilyRepository`
///
/// Same reason as `FamilyClaims`: that interface has two implementations and
/// SQLite cannot answer any of this. A device holds no invitations
/// (ARCHITECTURE §7).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long a code lasts (PRODUCT §5.1).
const Duration invitationLifetime = Duration(days: 7);

/// The alphabet a code is drawn from.
///
/// Thirty-two letters, and the four missing ones are the point: `O` and `0`,
/// `I` and `1` are the same character to somebody reading a code off one
/// screen and typing it into another. A code nobody can transcribe is a code
/// nobody uses.
const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// A fresh code, grouped for reading: `K7P2-9XMR-4T`.
///
/// Ten characters from thirty-two is about fifty bits. That is short of what
/// one would want for a bearer secret on its own, and is enough here because
/// it is not on its own: the code dies after one use and after seven days, and
/// a wrong guess has to beat a real person to a family whose id the guesser
/// does not have.
String newInvitationCode([Random? random]) {
  final source = random ?? Random.secure();
  final picked = <String>[
    for (var i = 0; i < 10; i++) _alphabet[source.nextInt(_alphabet.length)],
  ];

  return '${picked.sublist(0, 4).join()}-'
      '${picked.sublist(4, 8).join()}-'
      '${picked.sublist(8).join()}';
}

/// The form that gets hashed, on this side and on the server's.
///
/// A code is read off one screen and typed into another, so it arrives however
/// the person left it: lower case, spaces, hyphens kept or dropped. Comparing
/// the raw text would refuse `k7p2 9xmr4t` for a code issued as
/// `K7P2-9XMR-4T`, and nobody would be able to see why.
///
/// The server has the same function, `canonical_invitation_code`. The two must
/// agree exactly or no code ever matches, which is why both are one line and
/// both are tested against the same examples.
String canonicalInvitationCode(String code) =>
    code.replaceAll(RegExp('[^A-Za-z0-9]'), '').toUpperCase();

/// Pulls a code out of whatever somebody pasted.
///
/// What gets shared is a sentence, because a bare `6E54-7LNH-MR` arriving in
/// Zalo tells the person nothing about what it is for. But the phone's own
/// Copy button copies that whole sentence, and so does anybody forwarding the
/// message — so the box that takes a code has to cope with a paragraph around
/// it. Refusing one would be refusing the most obvious way to move a code
/// between two phones.
///
/// Matched on the grouped shape a code is always issued in, and the **last**
/// match wins: both messages put the family's name before the code, and a
/// family could in principle be named something that looks like one.
///
/// Anything with no match comes back unchanged, so a hand-typed code — with or
/// without its hyphens — still reaches [canonicalInvitationCode] as before.
String invitationCodeIn(String text) {
  final matches = RegExp(
    r'[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{2}',
  ).allMatches(text);

  return matches.isEmpty ? text : matches.last[0]!;
}

/// Hex sha256 of the canonical form. What the server stores.
String invitationCodeHash(String code) =>
    sha256.convert(utf8.encode(canonicalInvitationCode(code))).toString();

/// One invitation as the owner sees it.
///
/// [code] is null whenever this device is not the one that made it, or made it
/// and has since forgotten — a reinstall, a different phone. The row is still
/// listed, because it is still standing and still revocable; there is simply
/// nothing left to send.
final class Invitation {
  const Invitation({
    required this.id,
    required this.familyId,
    required this.role,
    required this.createdAt,
    required this.expiresAt,
    this.code,
    this.acceptedAt,
    this.revokedAt,
  });

  final String id;
  final String familyId;
  final String role;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? code;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  bool get isAccepted => acceptedAt != null;
  bool get isRevoked => revokedAt != null;
  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now);

  /// Whether it could still be used by somebody.
  ///
  /// The three end states are asked about in the order they are decided on the
  /// server, so a revoked invitation that has also expired reads the same way
  /// in both places.
  bool isLiveAt(DateTime now) => !isAccepted && !isRevoked && !isExpiredAt(now);

  Invitation withCode(String? plaintext) => Invitation(
    id: id,
    familyId: familyId,
    role: role,
    createdAt: createdAt,
    expiresAt: expiresAt,
    code: plaintext,
    acceptedAt: acceptedAt,
    revokedAt: revokedAt,
  );
}

/// Somebody in a family, as the member list shows them.
///
/// [email] comes from `family_members`, which is the only way a client sees
/// one: `auth.users` is every account on the server and no client may read it.
final class Member {
  const Member({
    required this.userId,
    required this.role,
    required this.email,
    this.name,
  });

  final String userId;
  final String role;
  final String email;

  /// What they called themselves when they signed up, or null.
  ///
  /// Null for an account made before names were asked for, and for anybody who
  /// left the box empty. The row then shows the address on its own rather than
  /// inventing something out of it — an address with its domain cut off is not
  /// a name, and showing it as one would be the screen telling a lie.
  final String? name;
}

/// Reads and writes invitations. Nothing else knows the server's column names.
final class FamilyInvitations {
  /// [now] is injectable so tests can pin the moment, as the repositories are.
  FamilyInvitations(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient _db;
  final DateTime Function() _now;

  /// Creates one and returns it **with its code**, which is the only moment
  /// the plaintext exists outside a message.
  ///
  /// The caller is responsible for keeping it if it wants to offer it again;
  /// nothing here writes it anywhere.
  Future<Invitation> create({
    required String familyId,
    required String role,
    String? code,
  }) async {
    final plaintext = code ?? newInvitationCode();
    final at = _now().toUtc();

    final row = await _db
        .from('family_invitations')
        .insert(<String, Object?>{
          'family_id': familyId,
          'role': role,
          'token_hash': invitationCodeHash(plaintext),
          'invited_by': _db.auth.currentUser?.id,
          'expires_at': at.add(invitationLifetime).toIso8601String(),
        })
        .select()
        .single();

    return _fromRow(row).withCode(plaintext);
  }

  /// Every invitation ever made for [familyId], newest first.
  ///
  /// Used and revoked ones are included. They are the record of who let whom
  /// in, and a list that hid them would answer "who has been invited?" with
  /// only half the truth.
  Future<List<Invitation>> forFamily(String familyId) async {
    final rows = await _db
        .from('family_invitations')
        .select()
        .eq('family_id', familyId)
        .order('created_at', ascending: false);

    return rows.map(_fromRow).toList();
  }

  /// Makes an unused invitation permanently unusable.
  ///
  /// Refused by the server once it has been accepted, because revoking does
  /// not remove the person it let in — that is tombstoning their membership,
  /// a different act on a different table.
  Future<void> revoke(String invitationId) async {
    await _db
        .from('family_invitations')
        .update(<String, Object?>{
          'revoked_at': _now().toUtc().toIso8601String(),
        })
        .eq('id', invitationId);
  }

  /// Redeems [code] and answers which family it let the caller into.
  ///
  /// Throws [PostgrestException] with one of the server's own words:
  /// `invitation_not_found`, `invitation_revoked`, `invitation_already_used`,
  /// `invitation_expired`, `invitation_needs_an_account`.
  Future<String> accept(String code) async => await _db.rpc<String>(
    'accept_invitation',
    params: <String, Object?>{'code': code},
  );

  /// Who is in [familyId], by the name a relative would recognise.
  ///
  /// Empty for a caller who is not a member — the server answers nothing at
  /// all rather than refusing, so a family somebody has no part in looks the
  /// same as a family that does not exist.
  Future<List<Member>> members(String familyId) async {
    final rows = await _db.rpc<List<dynamic>>(
      'family_members',
      params: <String, Object?>{'target': familyId},
    );

    return <Member>[
      for (final row in rows.cast<Map<String, dynamic>>())
        Member(
          userId: row['user_id'] as String,
          role: row['role'] as String,
          email: (row['email'] as String?) ?? '',
          name: row['name'] as String?,
        ),
    ];
  }

  /// Every role the signed-in account holds, by family id.
  ///
  /// One request for all of them. `memberships_read` lets anybody read their
  /// own row in any family, which is what makes this a single question rather
  /// than one per family — and it is how a device finds out it was promoted,
  /// demoted or put out without being told.
  Future<Map<String, String>> myRoles() async {
    final me = _db.auth.currentUser?.id;
    if (me == null) return const <String, String>{};

    final rows = await _db
        .from('family_memberships')
        .select('family_id, role')
        .eq('user_id', me)
        .isFilter('deleted_at', null);

    return <String, String>{
      for (final row in rows) row['family_id'] as String: row['role'] as String,
    };
  }

  /// Changes what somebody may do in a family.
  ///
  /// Only an owner may call this and mean it — `memberships_update` sees to
  /// that. A refused UPDATE is silent, so the caller reads the list back
  /// rather than trusting that nothing was raised.
  ///
  /// Demoting the last owner is refused by `keep_an_owner`, which does raise:
  /// a family nobody can manage is a family nobody can ever be invited into.
  Future<void> changeRole({
    required String familyId,
    required String userId,
    required String role,
  }) async {
    await _db
        .from('family_memberships')
        .update(<String, Object?>{
          'role': role,
          'updated_at': _now().toUtc().toIso8601String(),
        })
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  /// Tombstones somebody's membership.
  ///
  /// Soft, like every other removal here (§15.1), and refused by the
  /// `keep_an_owner` trigger where it would leave the family with no owner —
  /// which is the one case that breaks something, since a family nobody can
  /// manage is a family nobody can ever be invited into.
  Future<void> remove({
    required String familyId,
    required String userId,
  }) async {
    final at = _now().toUtc().toIso8601String();

    await _db
        .from('family_memberships')
        .update(<String, Object?>{'deleted_at': at, 'updated_at': at})
        .eq('family_id', familyId)
        .eq('user_id', userId);
  }

  Invitation _fromRow(Map<String, dynamic> row) => Invitation(
    id: row['id'] as String,
    familyId: row['family_id'] as String,
    role: row['role'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    expiresAt: DateTime.parse(row['expires_at'] as String).toUtc(),
    acceptedAt: _time(row['accepted_at']),
    revokedAt: _time(row['revoked_at']),
  );

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();
}

/// Which of the server's refusals [error] is, or null if it is not one.
///
/// Matched on the message because these are raised by `RAISE EXCEPTION` and
/// all share SQLSTATE P0001 — the word is the only thing distinguishing them,
/// and both sides of it are ours.
InvitationRefusal? invitationRefusal(Object error) {
  if (error is! PostgrestException) return null;

  for (final refusal in InvitationRefusal.values) {
    if (error.message.contains(refusal.word)) return refusal;
  }

  return null;
}

/// The ways an invitation can be turned down.
enum InvitationRefusal {
  notFound('invitation_not_found'),

  /// Said apart from the others on purpose: this is the sentence that tells
  /// the intended reader, and through them the owner, that somebody else got
  /// to the code first.
  alreadyUsed('invitation_already_used'),

  revoked('invitation_revoked'),
  expired('invitation_expired'),
  needsAnAccount('invitation_needs_an_account');

  const InvitationRefusal(this.word);

  final String word;
}
