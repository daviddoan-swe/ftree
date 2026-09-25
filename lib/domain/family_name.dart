/// The surname inside a family's name (PRODUCT.md §1.1).
///
/// A family is written *Họ Nguyễn*, *Gia đình Trần*, *the Nguyễn family*. The
/// leading or trailing word says "the family of" and carries no identity — the
/// name is **Nguyễn**. Every place that needs the name itself rather than the
/// phrase asks here, so the rule is written once: the glyph on the family list
/// takes its letter from it, and the person form offers it as the surname
/// somebody is about to type for the fifth time.
///
/// In the domain because it is a fact about Vietnamese family names rather than
/// about any screen, and because it has to be testable without Flutter.
library;

import 'name_search.dart';

/// Words that describe *a family* rather than name one.
///
/// Compared folded, so an entry carrying its tone marks — *đình*, *chi* — still
/// matches. Vietnamese and English both, because a family imported from a file
/// somebody else wrote may be named in either.
const Set<String> _generic = <String>{
  'ho',
  'gia',
  'dinh',
  'chi',
  'nhanh',
  'family',
  'the',
  'clan',
};

/// The naming word of [name], or the whole of it when there is no other.
///
/// *Họ Nguyễn* is Nguyễn. *Họ Nguyễn – Phù Ninh* is still Nguyễn: the branch
/// says where, not who.
///
/// A name made only of generic words — somebody who typed just *Họ* — comes
/// back unchanged rather than empty. Returning nothing would be a worse answer
/// than returning what they wrote.
String familySurname(String name) {
  final words = name.trim().split(RegExp(r'\s+'))
    ..removeWhere((word) => word.isEmpty);
  if (words.isEmpty) return '';

  return words.firstWhere(
    (word) => !_generic.contains(foldForSearch(word)),
    orElse: () => words.first,
  );
}
