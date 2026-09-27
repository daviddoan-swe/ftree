/// Saying where a family stands with the server (ROADMAP M9, step 5).
///
/// Synchronisation used to be a black box. It runs when a family is opened,
/// when it is left, and when somebody pulls it down — and nothing anywhere
/// said whether any of that had worked. A person added on one phone sat there
/// for a day; finding out why took `sqlite3` and `psql`.
///
/// Two channels, and which one is used depends on whether anybody asked.
///
/// **Nobody asked** — opening a family, leaving it. This line, which is
/// passive: always there, answering when somebody looks at it. A notice on
/// every open would fire ten times a day and be learned away, and one on
/// leaving would surface over whatever screen came next, attached to nothing.
///
/// **Somebody asked** — pulling the gia phả down. Then they are owed a direct
/// answer, and [syncReport] is what a caller shows them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;

import '../../app/grouped_list.dart';
import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';

/// Where this family stands, in one line.
///
/// Built for the bar rather than the body. Standing between the bar and the
/// tree it floated in the middle of nothing, attached to neither — and a line
/// that looks like it landed by accident is read as clutter whatever it says.
/// Under the family's name it is plainly about the family, and it is always
/// there, which a status has to be.
class SyncStatusLine extends ConsumerWidget {
  const SyncStatusLine({required this.familyId, super.key});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppText.of(context);
    final asked = ref.watch(syncedAtProvider(familyId));
    final waiting = ref.watch(waitingProvider(familyId)).valueOrNull ?? 0;

    // Nothing is said until the first answer arrives. A line reading "not
    // synchronised yet" for the half second before the real one would be a
    // small lie told on every single open.
    if (asked.isLoading) return const SizedBox.shrink();

    // The count only when there is one. A time already says it synchronised,
    // so a second half saying so again was the same words twice — and nothing
    // waiting is said by the absence of a number, which is the shortest this
    // line can be said at all.
    final when = _when(text, asked.valueOrNull);

    return Text(
      waiting > 0 ? '$when · ${text.syncWaiting(waiting)}' : when,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: GroupedColors.secondaryLabel(context),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  /// How long ago, in the coarsest unit that is still true.
  ///
  /// Minutes past an hour are noise: somebody reading this wants to know
  /// whether what they are looking at is recent, not to the minute how old it
  /// is. "Three hours ago" answers that; "three hours and eleven minutes ago"
  /// answers it no better and reads as a machine talking.
  String _when(AppText text, DateTime? at) {
    if (at == null) return text.syncNever;

    final ago = DateTime.now().toUtc().difference(at);
    if (ago.inMinutes < 1) return text.syncJustNow;
    if (ago.inMinutes < 60) return text.syncMinutes(ago.inMinutes);
    if (ago.inHours < 24) return text.syncHours(ago.inHours);
    return text.syncDays(ago.inDays);
  }
}

/// What to tell somebody who asked for a synchronisation and got one.
///
/// Concrete, because "Synchronised" says nothing — and would be a lie in the
/// case that matters most, where what came down arrived and what went up was
/// refused. Trouble is named first: it is the half somebody has to act on.
String syncReport(AppText text, SyncResult result) => switch (result.trouble) {
  SyncTrouble.offline => text.syncOffline,
  SyncTrouble.refused => text.syncRefused,
  null when !result.reached => text.syncNothingNew,
  null when result.isQuiet => text.syncNothingNew,
  null => <String>[
    if (result.broughtDown > 0) text.syncBroughtDown(result.broughtDown),
    if (result.sentUp > 0) text.syncSentUp(result.sentUp),
    if (result.conflicted > 0) text.conflictsWaiting(result.conflicted),
  ].join(' · '),
};
