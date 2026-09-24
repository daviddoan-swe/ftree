/// Postgres answering the same contract SQLite answers.
///
/// **Not part of the suite.** No `_test.dart` suffix: it needs Docker and a
/// running local Supabase. Run it deliberately:
///
/// ```sh
/// supabase start
/// flutter test test/cloud/repository_contract.dart
/// ```
///
/// The checks are `test/support/repository_contract.dart`, imported unchanged.
/// Nothing here adapts them, and nothing may: the moment this file starts
/// making allowances, the two implementations stop being interchangeable and
/// the interface stops meaning anything.
///
/// ## "Empty" is a fresh account, not a fresh database
///
/// A server keeps what earlier runs left. But a family belongs to whoever
/// created it, and the read policy shows a user only their own — so signing up
/// a new account gives a repository that can see nothing, which is what the
/// contract asks for. The old rows are still there and still invisible, which
/// is the policy doing its job rather than a compromise.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ftree/data/cloud/cloud_session.dart';
import 'package:ftree/data/cloud/supabase_family_repository.dart';
import 'package:ftree/domain/family_repository.dart';

import '../support/repository_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test binding refuses every request so a unit test cannot quietly
  // depend on the network. This file depends on it on purpose.
  HttpOverrides.global = null;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await openCloud();
  });

  runFamilyRepositoryContract(
    named: 'Postgres',
    open: () async {
      await signUp(
        email: 'dev-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: 'correct horse battery',
      );
      return SupabaseFamilyRepository(Supabase.instance.client)
          as FamilyRepository;
    },
    close: () async {
      if (isSignedIn) await signOut();
    },
  );
}
