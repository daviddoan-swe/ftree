/// Application entry point.
///
/// Opens the database and hands it to the provider graph. Nothing else lives
/// here: the shell is in `app/app.dart` and every screen in `features/`.
library;

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/cloud/cloud_session.dart';
import 'data/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened here rather than by the first screen that wants it. The interface
  // has to know at launch whether anybody is signed in, so that the account
  // button appears only for somebody who has an account to manage.
  //
  // With no stored session this is object construction and no request, which
  // is what the majority who never sign in pay. With one, it restores that
  // session — which is the whole point of doing it at all.
  //
  // It is also why `main` opens it and no provider does: initialising starts a
  // token-refresh timer, and a timer started inside a widget test outlives the
  // test that started it.
  await openCloud();

  runApp(
    ProviderScope(
      overrides: <Override>[
        // The database is chosen here rather than inside the provider, so tests
        // can supply an in-memory one without the application knowing.
        databaseProvider.overrideWithValue(
          AppDatabase(driftDatabase(name: 'ftree')),
        ),
      ],
      child: const FtreeApp(),
    ),
  );
}
