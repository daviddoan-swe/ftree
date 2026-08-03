/// Matching a typed query against a name (PRODUCT.md §1.1).
///
/// **Search ignores diacritics.** Typing `nguyen` has to find *Nguyễn*. On a
/// phone keyboard the tone marks are extra work, half the family will type
/// without them, and a search that answers "no results" for a name that is
/// plainly there reads as the application being broken.
///
/// Folding is written out rather than taken from a package: Vietnamese needs
/// one table of about ninety characters, and Dart's core has no Unicode
/// normalisation to lean on.
library;

/// Every accented form, grouped under the letter it folds to.
///
/// `đ` folds to `d`: it is a distinct letter in Vietnamese, but somebody typing
/// `dinh` is looking for *Đình*, and refusing that helps nobody.
const Map<String, String> _accents = <String, String>{
  'a': 'àáạảãăằắặẳẵâầấậẩẫ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _folded = <int, String>{
  for (final entry in _accents.entries)
    for (final rune in entry.value.runes) rune: entry.key,
};

/// Lower-cased and stripped of tone marks, ready to compare.
String foldForSearch(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    buffer.write(_folded[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// Whether [name] should be shown for [query].
///
/// A substring match, not a prefix one: a reader looking for *Nguyễn Văn Cả*
/// may well type the given name they remember rather than the surname every
/// second person in the tree shares.
///
/// An empty or blank query matches everything — clearing the field puts the
/// whole list back rather than emptying it.
bool nameMatches(String name, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return true;
  return foldForSearch(name).contains(needle);
}
