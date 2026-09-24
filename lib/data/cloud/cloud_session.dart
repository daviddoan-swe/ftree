/// Signing in to the cloud (ROADMAP M7).
///
/// Everything the server refuses or allows turns on one value: `auth.uid()`,
/// read from the token the client sends. This is where that token comes from.
///
/// ## What it deliberately is not
///
/// **Not an interface.** There is one implementation and one caller.
/// ARCHITECTURE §7 asks for interfaces to emerge from real use rather than be
/// designed in advance; a second sign-in mechanism is not in sight.
///
/// **Not a gate on anything.** No screen consults it. The application reads
/// and writes SQLite exactly as before, and being signed out is not an error —
/// a gia phả opens on a train. Signing in buys access to the cloud copy, and
/// nothing else, until M9 gives the two copies something to say to each other.
///
/// **Not in the domain.** `Person` and `FamilyGraph` have no idea this exists,
/// and the architecture test that keeps `lib/domain` free of infrastructure
/// covers it.
///
/// ## Where the address and key come from
///
/// `--dart-define`, defaulting to the stack `supabase start` runs. The
/// defaults are Supabase's own published local constants — the same on every
/// machine, documented in their quickstart, and worth nothing to anybody.
///
/// The publishable key is **not a secret** wherever it points. It names the
/// project and nothing more; every request carrying it is still judged row by
/// row by the policies (`20260924000003_policies.sql`). What must never appear
/// here, or in any file, is the secret key: it bypasses RLS entirely, and the
/// pre-commit hook refuses it.
///
/// Read the current pair with `supabase status -o env`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the cloud lives. `--dart-define=SUPABASE_URL=...`
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'http://127.0.0.1:54321',
);

/// The project's public key. `--dart-define=SUPABASE_KEY=...`
const String supabaseKey = String.fromEnvironment(
  'SUPABASE_KEY',
  defaultValue: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
);

/// Prepares the client. Call once, before anything else here.
///
/// The session is kept in the device's own storage, which is what makes
/// signing in outlast closing the application.
///
/// Idempotent, because a second call would otherwise throw and say nothing
/// useful about whatever was being run.
Future<void> openCloud() async {
  if (_ready) return;
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  _ready = true;
}

bool _ready = false;

/// The signed-in user's id, or null.
///
/// This is the value the server's policies are written against. Null here and
/// null there mean the same thing: no family is reachable.
String? get signedInUserId => Supabase.instance.client.auth.currentUser?.id;

/// Whether there is a session at all.
bool get isSignedIn => signedInUserId != null;

/// Creates an account and signs into it.
///
/// Throws [AuthException] with the server's own wording — a password too
/// short, an address already taken. Left to reach the caller rather than
/// flattened into a boolean, because which of those happened is the only
/// useful thing to tell somebody.
Future<void> signUp({required String email, required String password}) async {
  await Supabase.instance.client.auth.signUp(
    email: email,
    password: password,
  );
}

/// Signs in to an account that exists.
Future<void> signIn({required String email, required String password}) async {
  await Supabase.instance.client.auth.signInWithPassword(
    email: email,
    password: password,
  );
}

/// Ends the session.
///
/// The local database is untouched. Signing out is not a way to lock the
/// application — nothing is locked, and §10's privacy is enforced on the
/// server, not here.
Future<void> signOut() async {
  await Supabase.instance.client.auth.signOut();
}
