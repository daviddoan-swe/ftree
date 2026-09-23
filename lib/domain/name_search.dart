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

/// Where in a name a query landed, best first.
///
/// A Vietnamese name reads họ–đệm–tên: the surname comes first and the given
/// name last. In a gia phả the surname is shared by nearly everybody and so
/// distinguishes nobody, while the given name is what a relative is actually
/// called. The order here follows that, rather than the order the words appear
/// in.
enum NameMatch {
  /// The given name, whole: `Hải` for *Nguyễn Văn Hải*.
  givenName,

  /// The start of the given name: `hả` for *Nguyễn Văn Hải*.
  givenNameStart,

  /// A middle name, whole: `Hải` for *Võ Hải Linh*.
  middleName,

  /// The start of a middle name.
  middleNameStart,

  /// The surname, which in a gia phả narrows almost nothing.
  familyName,

  /// Somewhere inside a word, which is nearly always an accident: `hai` in
  /// *Thái*.
  insideAWord,
}

/// How well [name] answers [query], or null where it does not answer at all.
///
/// An empty query is answered by every name, at the weakest rank, so that
/// clearing the field puts the list back in the order it was in rather than
/// re-sorting it into a new one.
NameMatch? rankName(String name, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return NameMatch.insideAWord;

  final folded = foldForSearch(name);
  if (!folded.contains(needle)) return null;

  final words = folded.split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return NameMatch.insideAWord;

  // A one-word name is its own given name: there is nothing else it could be.
  final given = words.last;
  if (given == needle) return NameMatch.givenName;
  if (given.startsWith(needle)) return NameMatch.givenNameStart;

  final middles = words.length > 2 ? words.sublist(1, words.length - 1) : const <String>[];
  if (middles.contains(needle)) return NameMatch.middleName;
  if (middles.any((w) => w.startsWith(needle))) return NameMatch.middleNameStart;

  if (words.first.startsWith(needle)) return NameMatch.familyName;

  return NameMatch.insideAWord;
}

/// [items] that answer [query], best answer first.
///
/// Ordering matters once a family is large: typing `thi` on three hundred
/// people brings back eleven, none of whom is *called* Thị — it is a middle
/// name — and typing `van` brings back six who are called Văn buried among
/// nine who are not. Which of them the reader wanted is decided by where the
/// query landed in the name, not by who was entered first.
///
/// Ties are settled by the shorter name and then by the order given, so the
/// list is the same on every keystroke rather than reshuffling under the
/// finger. Dart's sort is not stable, so the original position is carried
/// into the comparison rather than relied upon.
List<T> rankedByName<T>(
  Iterable<T> items,
  String query, {
  required String Function(T) nameOf,
}) {
  // Nothing typed, nothing to rank. Returned untouched rather than run
  // through the comparison, which would otherwise sort the whole family by
  // length of name the moment the field was cleared.
  if (foldForSearch(query.trim()).isEmpty) return items.toList();

  final scored = <({T item, NameMatch rank, int length, int at})>[];

  var at = 0;
  for (final item in items) {
    final name = nameOf(item);
    final rank = rankName(name, query);
    if (rank != null) {
      scored.add((item: item, rank: rank, length: name.length, at: at));
    }
    at++;
  }

  scored.sort((a, b) {
    final byRank = a.rank.index.compareTo(b.rank.index);
    if (byRank != 0) return byRank;
    final byLength = a.length.compareTo(b.length);
    if (byLength != 0) return byLength;
    return a.at.compareTo(b.at);
  });

  return <T>[for (final scored in scored) scored.item];
}
