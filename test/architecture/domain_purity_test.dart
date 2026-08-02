// Enforces the layering rule stated in CLAUDE.md §3 and ARCHITECTURE.md §6:
// the domain layer must remain pure Dart.
//
// Dart has no built-in import-boundary lint, so `flutter analyze` will never
// report `import 'package:flutter/material.dart'` inside lib/domain/. This test
// is the enforcement mechanism. It is deliberately a plain test rather than a
// lint package: it needs no dependency and no configuration file.
//
// Scope: direct imports and exports only. It cannot detect a domain file that
// depends on infrastructure transitively through another domain file — but a
// transitive dependency has to start with a direct one somewhere, and that one
// is caught here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Packages and SDK libraries the domain layer must not reach for.
///
/// `dart:io` and `dart:ui` are included because they tie the domain to a
/// platform: domain code must run in a plain Dart VM with no Flutter binding.
const _forbidden = <String>[
  'package:flutter/',
  'package:flutter_test/',
  'package:riverpod',
  'package:flutter_riverpod/',
  'package:hooks_riverpod/',
  'package:drift/',
  'package:drift_flutter/',
  'package:sqlite3',
  'package:supabase',
  'package:http/',
  'package:dio/',
  'package:path_provider/',
  'package:shared_preferences/',
  'dart:io',
  'dart:ui',
];

void main() {
  test('domain layer does not depend on Flutter or infrastructure', () {
    final domain = Directory('lib/domain');

    // The domain layer arrives at M1. Until then there is nothing to check,
    // and this test stands ready rather than failing on an absent directory.
    if (!domain.existsSync()) {
      return;
    }

    final violations = <String>[];

    for (final entity in domain.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }

        for (final banned in _forbidden) {
          if (line.contains(banned)) {
            violations.add('${entity.path}:${i + 1}  $line');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'The domain layer must remain pure Dart and testable without '
          'Flutter (CLAUDE.md §3, ARCHITECTURE.md §6).\n'
          'Move the dependency behind a repository abstraction instead.\n\n'
          '${violations.join('\n')}',
    );
  });
}
