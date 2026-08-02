// Smoke test: the application boots against a real database and reaches its
// first screen.
//
// It replaced a check on the template counter at M5, as planned at M0. The
// database is in memory, so this exercises the whole stack — widget tree,
// providers, repository, SQLite — without touching the device's files.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/app.dart';
import 'package:ftree/app/providers.dart';
import 'package:ftree/data/database/app_database.dart';

void main() {
  testWidgets('the app boots and shows the family list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[databaseProvider.overrideWithValue(db)],
        child: const FtreeApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Vietnamese is the template locale, and the test binding reports 'en',
    // so this asserts on the English text the app falls back to.
    expect(find.text('Families'), findsOneWidget);
    expect(find.text('No families yet'), findsOneWidget);
  });
}
