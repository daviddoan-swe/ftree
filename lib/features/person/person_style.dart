/// How a person is drawn: which glyph, and in which colour.
///
/// One place, because a row in the family list, a row in a relatives list and
/// the portrait on a profile all describe the same person and must agree.
library;

import 'package:flutter/material.dart';

import '../../app/grouped_list.dart';
import '../../domain/genealogical_date.dart';
import '../../domain/person.dart';

/// The years beside a name: `1808 – 1874`, or `1978` for somebody with no
/// death recorded, or nothing at all.
///
/// Years only, even where the full date is known: a line read at a glance
/// wants the span, and mixing precisions gives `1835–1902-04`, which reads
/// like two different kinds of thing. The full dates are one tap away.
///
/// **No trailing dash.** `1978–` says "and still going", which is a claim
/// nothing in the record supports — a missing death date is far more often a
/// death nobody wrote down (ARCHITECTURE §11.1). A lone birth year says only
/// what is known.
///
/// Spaces around the dash, because an approximate year carries a tilde and
/// `1835–~1902` reads as a typo.
String? lifeYears(Person person) {
  String year(GenealogicalDate date) =>
      '${date.isApproximate ? '~' : ''}${date.year}';

  final born = person.birthDate;
  final died = person.deathDate;

  if (born == null && died == null) return null;
  if (died == null) return year(born!);
  // A death with no birth still needs the dash, or the year reads as a birth.
  if (born == null) return '– ${year(died)}';
  return '${year(born)} – ${year(died)}';
}

/// The figure that stands for a person — on a row, on a chart, on a portrait.
///
/// `unknown` gets a figure of its own rather than nothing: it is a recorded
/// answer (DOMAIN.md §3.2), and an absent glyph would read as a screen that
/// forgot to draw one.
IconData personIcon(Person person) => switch (person.sex) {
  Sex.male => Icons.man,
  Sex.female => Icons.woman,
  Sex.unknown => Icons.person,
};

/// Blue, pink, or grey — and grey for anybody with a death date.
///
/// The dead are drawn back rather than out. A gia phả is mostly the dead, so
/// they cannot be hidden; but at a glance the living are who a reader is
/// usually looking for, and colour is the cheapest way to separate them.
///
/// Reads [Person.hasDied], which is one-way by design: it proves a death,
/// never a life. Somebody with nothing recorded either way keeps their colour,
/// because the record is silent, not because they are known to be living.
Color personColor(Person person) => person.hasDied
    ? GroupedColors.grey
    : switch (person.sex) {
        Sex.male => GroupedColors.blue,
        Sex.female => GroupedColors.pink,
        Sex.unknown => GroupedColors.grey,
      };
