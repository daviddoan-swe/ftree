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
import 'data/database/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
