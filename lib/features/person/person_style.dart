/// How a person is drawn: which glyph, and in which colour.
///
/// One place, because a row in the family list, a row in a relatives list and
/// the portrait on a profile all describe the same person and must agree.
library;

import 'package:flutter/material.dart';

import '../../app/grouped_list.dart';
import '../../domain/person.dart';

/// The figure on a list row.
IconData personIcon(Person person) => switch (person.sex) {
  Sex.male => Icons.man,
  Sex.female => Icons.woman,
  Sex.unknown => Icons.person,
};

/// The badge on a portrait: Mars, Venus, or a question mark.
///
/// `unknown` gets a glyph rather than an empty space — it is a recorded answer
/// (DOMAIN.md §3.2), and leaving the badge off would make it look like the
/// screen forgot to draw one. A question mark rather than a cross, which on a
/// badge reads as "remove".
IconData sexIcon(Sex sex) => switch (sex) {
  Sex.male => Icons.male,
  Sex.female => Icons.female,
  Sex.unknown => Icons.question_mark_rounded,
};

/// Blue, pink, or grey — and grey for anybody with a death date.
///
/// The dead are drawn back rather than out. A gia phả is mostly the dead, so
/// they cannot be hidden; but at a glance the living are who a reader is
/// usually looking for, and colour is the cheapest way to separate them.
///
/// **`deathDate != null` is the only signal available, and it is one-way.** It
/// proves somebody died; its absence proves nothing, so an ancestor with no
/// recorded death still shows in colour. A real living/deceased decision has
/// to arrive before this can be trusted the other way round (ARCHITECTURE
/// §11.1).
Color personColor(Person person) => person.deathDate != null
    ? GroupedColors.grey
    : switch (person.sex) {
        Sex.male => GroupedColors.blue,
        Sex.female => GroupedColors.pink,
        Sex.unknown => GroupedColors.grey,
      };
