/// Sending a family out as a file (PRODUCT.md §9.1).
///
/// Split the same way the import is, and for the same reason: [fileNameFor]
/// and the encoding are plain functions that can be checked without a device,
/// and only [exportFamily] touches the file system and the share sheet.
///
/// ## Why the share sheet rather than "save to Files"
///
/// The point of an export is reaching a relative — in practice through Zalo.
/// A save dialog would put the file somewhere and leave the reader to find it,
/// open the Files app, and share it from there. Three steps for one act, and a
/// feature that takes three steps is a feature nobody uses.
///
/// ## Why a temporary directory
///
/// The file exists only long enough to hand to the share sheet; the system
/// clears it afterwards. Written into the documents directory it would survive
/// instead, and every export would leave behind a copy the reader never sees
/// and never deletes.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/confirm.dart';
import '../../app/providers.dart';
import '../../data/transfer/family_file.dart';
import '../../domain/family.dart';
import '../../l10n/app_localizations.dart';

/// What to call the file holding [family], exported on [at].
///
/// Unaccented and lowercase, because this name has to survive every file
/// system and every chat application it passes through. Dated, so somebody
/// holding two exports of the same family can tell which is the later one —
/// and dated by the day only, since the clock belongs to the exporting device
/// and minutes would lend it a precision it has not got (§15.3).
String fileNameFor(Family family, DateTime at) {
  final local = at.toLocal();
  final day =
      '${local.year}-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}';

  return '${_plain(family.name)}-$day.json';
}

/// Vietnamese reduced to letters a filename can carry.
///
/// Not the general Unicode fold — this handles the vowels a Vietnamese name
/// actually contains, plus đ, and turns everything else into a hyphen. A name
/// that reduces to nothing falls back to `gia-pha`, because a file called
/// `-2026-09-24.json` says nothing to anybody.
String _plain(String name) {
  const marked = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const plain = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
      'ooooooooooooooooouuuuuuuuuuuyyyyyd';

  final folded = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final at = marked.indexOf(char);
    folded.write(at >= 0 ? plain[at] : char);
  }

  final slug = folded
      .toString()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');

  return slug.isEmpty ? 'gia-pha' : slug;
}

/// Writes [familyId] out and offers it to whatever the reader wants to send it
/// with.
///
/// Returns false **only** when there was nothing to export — a family that has
/// been deleted, or an id nothing answers to. Declining the confirmation
/// returns true: there was something to send, and the reader chose not to.
/// The two are different answers and the caller says different things about
/// them.
Future<bool> exportFamily(
  BuildContext context,
  WidgetRef ref,
  String familyId, {
  DateTime Function() now = DateTime.now,
}) async {
  final snapshot = await ref
      .read(familyRepositoryProvider)
      .loadFamily(familyId);
  if (snapshot == null) return false;

  // Asked after loading, so the question can say how many people are about to
  // leave, and asked before anything is written or shared.
  //
  // An export destroys nothing, which is why it is easy to treat as harmless.
  // What it does is put a family's record — living relatives included — beyond
  // anything this application can reach again. PRODUCT §10 makes that data
  // private by default; sending it is the one act that undoes that, and it
  // deserves to be a decision rather than a swipe.
  if (!context.mounted) return false;
  final text = AppText.of(context);
  final agreed = await confirmIrreversible(
    context,
    title: text.exportConfirmTitle,
    body: text.exportConfirmBody(snapshot.graph.persons.length),
    confirmLabel: text.exportAction,
  );
  if (!agreed) return true; // Something was there; it stays here.

  final at = now();
  final contents = encodeFamilyFile(
    family: snapshot.family,
    persons: snapshot.graph.persons,
    relationships: snapshot.graph.relationships,
    at: at,
  );

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${fileNameFor(snapshot.family, at)}');
  await file.writeAsString(contents);

  if (!context.mounted) return false;
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'application/json')],
      subject: snapshot.family.name,
      // Where the sheet appears from on a tablet. Without it iPad throws
      // rather than guessing.
      sharePositionOrigin: _originIn(context),
    ),
  );
  return true;
}

/// The rectangle the share sheet points at, in global coordinates.
Rect _originIn(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// What to say when a family cannot be exported because it holds nothing.
String exportEmptyMessage(BuildContext context) =>
    AppText.of(context).exportNothing;
