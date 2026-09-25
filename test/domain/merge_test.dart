/// Merging two edits of the same record (ROADMAP M9, step 3).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/domain/merge.dart';

void main() {
  const base = <String, Object?>{
    'displayName': 'Nguyễn Văn A',
    'birthPlace': 'Nam Định',
    'biography': null,
  };

  MergeResult mergeOf(Map<String, Object?> mine, Map<String, Object?> theirs) =>
      merge3(base: base, mine: mine, theirs: theirs);

  group('one side moved it', () {
    test('mine is kept where only I changed it', () async {
      final result = mergeOf(<String, Object?>{
        ...base,
        'birthPlace': 'Nam Định, Ý Yên',
      }, base);

      expect(result.fields['birthPlace'], 'Nam Định, Ý Yên');
      expect(result.isClean, isTrue);
      expect(
        result.tookAnything,
        isFalse,
        reason: 'nothing came from the other side, so nothing needs writing',
      );
    });

    test('theirs is taken where only they changed it', () async {
      // The whole point of keeping a base: without it there is no way to tell
      // their edit from my absence of one.
      final result = mergeOf(base, <String, Object?>{
        ...base,
        'biography': 'Làm nghề dạy học.',
      });

      expect(result.fields['biography'], 'Làm nghề dạy học.');
      expect(result.isClean, isTrue);
      expect(result.tookAnything, isTrue);
    });

    test('a field neither of us touched is left where it was', () {
      final result = mergeOf(base, base);

      expect(result.fields, base);
      expect(result.tookAnything, isFalse);
    });
  });

  group('both sides moved it', () {
    test('different fields merge, and nobody is asked anything', () {
      // The case the whole design is for: two relatives filling in different
      // parts of the same person.
      final result = mergeOf(
        <String, Object?>{...base, 'birthPlace': 'Ý Yên'},
        <String, Object?>{...base, 'biography': 'Làm nghề dạy học.'},
      );

      expect(result.fields['birthPlace'], 'Ý Yên');
      expect(result.fields['biography'], 'Làm nghề dạy học.');
      expect(result.isClean, isTrue);
      expect(result.tookAnything, isTrue);
    });

    test('the same field, the same value, is not a disagreement', () {
      // Two people typing the same correction. Asking about it would be asking
      // about nothing.
      final result = mergeOf(
        <String, Object?>{...base, 'displayName': 'Nguyễn Văn An'},
        <String, Object?>{...base, 'displayName': 'Nguyễn Văn An'},
      );

      expect(result.isClean, isTrue);
      expect(result.fields['displayName'], 'Nguyễn Văn An');
    });

    test('the same field, different values, is a conflict', () {
      final result = mergeOf(
        <String, Object?>{...base, 'displayName': 'Nguyễn Văn An'},
        <String, Object?>{...base, 'displayName': 'Nguyễn Văn Ân'},
      );

      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.field, 'displayName');
      expect(result.conflicts.single.base, 'Nguyễn Văn A');
      expect(result.conflicts.single.mine, 'Nguyễn Văn An');
      expect(result.conflicts.single.theirs, 'Nguyễn Văn Ân');
    });

    test('and nothing is chosen for them', () {
      // A later change_seq says which write reached the server second, not
      // which reading of a hundred-year-old record is right. The device keeps
      // showing what its owner typed until they say otherwise.
      final result = mergeOf(
        <String, Object?>{...base, 'displayName': 'của tôi'},
        <String, Object?>{...base, 'displayName': 'của họ'},
      );

      expect(result.fields['displayName'], 'của tôi');
    });

    test('a conflict in one field does not block the others', () {
      final result = mergeOf(
        <String, Object?>{
          ...base,
          'displayName': 'của tôi',
          'birthPlace': 'Ý Yên',
        },
        <String, Object?>{
          ...base,
          'displayName': 'của họ',
          'biography': 'Làm nghề dạy học.',
        },
      );

      expect(result.conflicts, hasLength(1));
      expect(result.fields['birthPlace'], 'Ý Yên');
      expect(result.fields['biography'], 'Làm nghề dạy học.');
    });
  });

  group('emptiness is a value like any other', () {
    test('clearing a field on one side is an edit', () {
      // Somebody deleting a wrong birthplace has changed something, and a
      // merge that read null as "said nothing" would put it back.
      final result = mergeOf(<String, Object?>{
        ...base,
        'birthPlace': null,
      }, base);

      expect(result.fields['birthPlace'], isNull);
      expect(result.isClean, isTrue);
    });

    test('and clearing against a change is a conflict', () {
      final result = mergeOf(
        <String, Object?>{...base, 'birthPlace': null},
        <String, Object?>{...base, 'birthPlace': 'Ý Yên'},
      );

      expect(result.conflicts.single.field, 'birthPlace');
      expect(result.conflicts.single.mine, isNull);
    });

    test('both clearing it is agreement', () {
      final result = mergeOf(
        <String, Object?>{...base, 'birthPlace': null},
        <String, Object?>{...base, 'birthPlace': null},
      );

      expect(result.isClean, isTrue);
      expect(result.fields['birthPlace'], isNull);
    });
  });

  group('a record that has grown a field', () {
    test('one side knowing a field the base never had is an edit', () {
      // A newer version of the application writing something an older one had
      // no column for. Refusing to merge would be worse than treating it as
      // something neither of us started with.
      final result = merge3(
        base: const <String, Object?>{'displayName': 'A'},
        mine: const <String, Object?>{'displayName': 'A'},
        theirs: const <String, Object?>{'displayName': 'A', 'nickname': 'Cụ'},
      );

      expect(result.fields['nickname'], 'Cụ');
      expect(result.isClean, isTrue);
    });
  });
}
