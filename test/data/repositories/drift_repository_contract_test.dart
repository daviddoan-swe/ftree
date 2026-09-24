/// SQLite answering the contract every repository has to answer.
///
/// The checks themselves are in `test/support/repository_contract.dart`, run
/// unchanged against every implementation. Postgres answers the same ones in
/// `test/cloud/`.
///
/// Drift's own tests stay where they are and cover what is true of SQLite
/// alone: reopening the file, timestamps stored as UTC text, the schema's
/// migrations. Those are not contract, and Postgres has no opinion on them.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family_repository.dart';

import '../../support/repository_contract.dart';

void main() {
  AppDatabase? open;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  runFamilyRepositoryContract(
    named: 'SQLite',
    // A database per check, in memory: nothing carries over, and nothing has
    // to be cleaned up between them.
    open: () async {
      final db = AppDatabase(NativeDatabase.memory());
      open = db;
      return Future<FamilyRepository>.value(DriftFamilyRepository(db));
    },
    close: () async {
      await open?.close();
      open = null;
    },
  );
}
