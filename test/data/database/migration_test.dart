import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';

import 'schema_versions/schema.dart';
import 'schema_versions/schema_v1.dart' as v1;
import 'schema_versions/schema_v4.dart' as v4;
import 'schema_versions/schema_v7.dart' as v7;

/// Every migration, verified against the real shipped schemas rather than
/// against hand-written approximations of them.
///
/// A schema mistake costs a migration on every installed device (DOMAIN.md
/// §18), so each version's shape is captured in `drift_schemas/` and replayed
/// here.
///
/// **Every earlier version is upgraded to the current one, not merely to the
/// next.** A device that has not been opened since v1 does not stop at v2 on
/// its way; it runs both steps in one go, and that is the path that has to
/// work.
void main() {
  /// Read from the database rather than written down, so this file cannot
  /// fall behind a version bump without failing.
  final currentSchema = AppDatabase(NativeDatabase.memory()).schemaVersion;

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  for (final from in <int>[1, 2, 3, 4, 5, 6, 7, 8]) {
    test('upgrading from v$from produces the current schema', () async {
      final db = AppDatabase(await verifier.startAt(from));

      await verifier.migrateAndValidate(db, currentSchema);
      await db.close();
    });
  }

  group('an upgrade that was interrupted half way', () {
    // The shape a real device was found in. Drift runs the steps outside any
    // transaction and writes `PRAGMA user_version` only after all of them have
    // finished (`engines.dart`: "set version now, after migrations ran
    // successfully"), so each `ALTER TABLE` commits on its own. Anything that
    // stops the process in between — swiping the application away, a low
    // battery, iOS reclaiming memory — leaves columns added under a version
    // that does not know about them.
    //
    // Replaying then met its own work: `duplicate column name: my_role`, on
    // every launch, for ever. There is no way out from inside the application,
    // and uninstalling to clear it takes the gia phả with it.

    /// A v4 database that got part of the way and stopped.
    ///
    /// Built through the real v4 schema, then given the columns a later step
    /// had already committed — with the version left where it was, which is
    /// exactly the state the process dying would leave behind.
    Future<AppDatabase> halfWayThrough(int stoppedAt, {String? holding}) async {
      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());

      if (holding != null) {
        final stamp = DateTime.utc(2026, 9, 24).toIso8601String();
        await old.customStatement(
          'INSERT INTO families (id, name, uses_lunar_calendar, updated_at) '
          "VALUES ('f-1', '$holding', 0, '$stamp')",
        );
      }

      await old.customStatement(
        'ALTER TABLE families ADD COLUMN my_role TEXT NULL',
      );
      if (stoppedAt > 5) {
        await old.customStatement(
          // Exactly as drift writes it, `CHECK` included. Written by hand
          // without one, the recovered schema fails to match and the test
          // reports a defect that only the fixture had.
          'ALTER TABLE persons ADD COLUMN unsent INTEGER NOT NULL DEFAULT 0 '
          'CHECK (unsent IN (0, 1))',
        );
      }
      await old.customStatement('PRAGMA user_version = 4');
      await old.close();

      return AppDatabase(schema.newConnection());
    }

    test('opens anyway, and finishes the job', () async {
      final db = await halfWayThrough(5);

      // Reaching the schema at all is the assertion: before this, opening it
      // threw `duplicate column name` and went on throwing for ever.
      await verifier.migrateAndValidate(db, currentSchema);
      await db.close();
    });

    test('and so does one that stopped a step later', () async {
      final db = await halfWayThrough(6);

      await verifier.migrateAndValidate(db, currentSchema);
      await db.close();
    });

    test('one stopped among the indexes recovers too', () async {
      // Step 2 makes four of them. Stopping after the first leaves a database
      // that meets `already exists` rather than `duplicate column name` — the
      // same wall by another name.
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await old.customStatement(
        'CREATE INDEX persons_by_family ON persons (family_id, deleted_at)',
      );
      await old.customStatement('PRAGMA user_version = 1');
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, currentSchema);
      await db.close();
    });

    test('a step that fails leaves nothing of itself behind', () async {
      // The other half, and the one that stops this happening again. Step 5
      // adds a column and then backfills it; taking away what the backfill
      // reads makes it fail after the column is in. Without the transaction
      // the column would stay, the version would not move, and the device
      // would be in exactly the state described above.
      final schema = await verifier.schemaAt(4);
      final prepared = v4.DatabaseAtV4(schema.newConnection());
      await prepared.customStatement(
        'ALTER TABLE families DROP COLUMN shared_at',
      );
      await prepared.close();

      final db = AppDatabase(schema.newConnection());
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<Exception>()),
      );
      await db.close();

      // Opened at 4 because that is still what it says, so nothing migrates
      // and the raw state can be read.
      final after = v4.DatabaseAtV4(schema.newConnection());
      final version = await after
          .customSelect('SELECT * FROM pragma_user_version')
          .getSingle();
      final columns = await after
          .customSelect(
            "SELECT name FROM pragma_table_info('families') WHERE name = 'my_role'",
          )
          .get();

      expect(version.data.values.first, 4, reason: 'the step did not finish');
      expect(columns, isEmpty, reason: 'and left none of its work behind');
      await after.close();
    });

    test('the data it already held is still there afterwards', () async {
      // Recovering by starting from an empty database would be no recovery at
      // all — it is the gia phả that is being rescued, not the schema.
      final db = await halfWayThrough(5, holding: 'Họ Nguyễn');

      await verifier.migrateAndValidate(db, currentSchema);

      final rows = await db.customSelect('SELECT name FROM families').get();
      expect(rows.single.read<String>('name'), 'Họ Nguyễn');
      await db.close();
    });
  });

  test('a device that already holds data keeps it', () async {
    const familyId = 'f0000000-0000-7000-8000-000000000000';
    const personId = 'p0000000-0000-7000-8000-000000000001';
    final at = DateTime.utc(2026, 8, 3);

    // Written into the real v1 schema, in the text form the application
    // stores timestamps as (§8, storeDateTimeAsText).
    final stamp = at.toIso8601String();
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
      'INSERT INTO families (id, name, uses_lunar_calendar, updated_at) '
      "VALUES ('$familyId', 'Họ Nguyễn', 0, '$stamp')",
    );
    await old.customStatement(
      'INSERT INTO persons (id, family_id, display_name, sex, updated_at) '
      "VALUES ('$personId', '$familyId', 'Cụ Tổ', 'male', '$stamp')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, currentSchema);

    final families = await db.select(db.families).get();
    final people = await db.select(db.persons).get();
    expect(families.single.name, 'Họ Nguyễn');
    expect(people.single.displayName, 'Cụ Tổ');
    expect(
      families.single.sharedAt,
      isNull,
      reason: 'nothing was shared before there was anywhere to share it to',
    );
    expect(
      families.single.myRole,
      isNull,
      reason: 'and a family nobody shared is one nobody else has a claim on',
    );

    await db.close();
  });

  test(
    'a family already shared keeps its member list after the upgrade',
    () async {
      // v5 added the role column. Null there for a family already carrying a
      // mark would take its owner's member list away on upgrade — the one thing
      // an upgrade must never do is quietly remove a control somebody had.
      const familyId = 'f0000000-0000-7000-8000-000000000000';
      final stamp = DateTime.utc(2026, 9, 24).toIso8601String();

      final schema = await verifier.schemaAt(4);
      final old = v4.DatabaseAtV4(schema.newConnection());
      await old.customStatement(
        'INSERT INTO families (id, name, uses_lunar_calendar, updated_at, '
        "shared_at) VALUES ('$familyId', 'Họ Nguyễn', 0, '$stamp', '$stamp')",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, currentSchema);

      expect((await db.select(db.families).get()).single.myRole, 'owner');

      await db.close();
    },
  );

  test('an upgrade never clears a flag that means "not sent yet"', () async {
    // The fence around a mistake already made. v6 added `unsent` and gave
    // every existing row the column default, false — "the server has this" —
    // when before v6 there was no push at all, so anything written after the
    // family was last uploaded had gone nowhere. Those rows became invisible
    // to synchronisation on the one device holding them. Measured on a real
    // phone: a person added two minutes after the last upload, present there
    // and on no server.
    //
    // It cannot be undone. The flag was the only record of what had been
    // sent, and only the server knows now. No recovery is being written,
    // because a fresh install runs `onCreate` and never these steps, so no
    // device that has not already upgraded can reach it — and the ones that
    // can are this project's own (ROADMAP M9, step 4).
    //
    // What this stops is the next step doing it again.
    final schema = await verifier.schemaAt(7);
    final old = v7.DatabaseAtV7(schema.newConnection());
    final stamp = DateTime.utc(2026, 9, 25).toIso8601String();
    await old.customStatement(
      'INSERT INTO families (id, name, uses_lunar_calendar, updated_at, '
      "unsent, last_seen) VALUES ('f-1', 'Họ Nguyễn', 0, '$stamp', 1, 0)",
    );
    await old.customStatement(
      'INSERT INTO persons (id, family_id, display_name, sex, updated_at, '
      "unsent, base_fields) VALUES ('p-1', 'f-1', 'Cụ Tổ', 'unknown', '$stamp', 1, "
      "'{}')",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, currentSchema);

    final person = (await db.select(db.persons).get()).single;
    expect(person.unsent, isTrue, reason: 'it still has not gone anywhere');
    expect(person.baseFields, '{}', reason: 'nor has what it started from');
    expect((await db.select(db.families).get()).single.unsent, isTrue);

    await db.close();
  });

  test('a fresh install gets the same indexes as an upgraded one', () async {
    // The classic migration defect is onCreate and onUpgrade drifting apart,
    // leaving new users on a different schema from everybody else. Only the
    // indexes are compared: they are what this migration adds, and both paths
    // build them from the same generated definitions, so the text really
    // should match. The tables are covered by migrateAndValidate above, which
    // compares types and constraints rather than the spacing and quoting of
    // two different DDL emitters.
    Future<List<String>> indexesOf(AppDatabase db) async {
      final rows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .get();
      return <String>[for (final row in rows) row.read<String>('sql')];
    }

    final fresh = AppDatabase(NativeDatabase.memory());
    final freshIndexes = await indexesOf(fresh);
    await fresh.close();

    final upgraded = AppDatabase(await verifier.startAt(1));
    final upgradedIndexes = await indexesOf(upgraded);
    await upgraded.close();

    expect(freshIndexes, hasLength(4));
    expect(upgradedIndexes, freshIndexes);
  });

  group('the indexes are used, not merely present', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    /// What SQLite says it will do. `SEARCH` means an index; `SCAN` means every
    /// row of the table, which is what this whole change exists to stop.
    Future<String> planFor(String sql) async {
      final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
      return rows.map((r) => r.read<String>('detail')).join(' | ');
    }

    test('loading a family finds its people by index', () async {
      final plan = await planFor(
        "SELECT * FROM persons WHERE family_id = 'x' AND deleted_at IS NULL",
      );

      expect(plan, contains('persons_by_family'));
      expect(plan, isNot(contains('SCAN persons')));
    });

    test('loading a family finds its relationships by index', () async {
      final plan = await planFor(
        'SELECT * FROM relationships '
        "WHERE family_id = 'x' AND deleted_at IS NULL",
      );

      expect(plan, contains('relationships_by_family'));
      expect(plan, isNot(contains('SCAN relationships')));
    });

    test('deleting a person finds their edges from both ends', () async {
      // person_a_id OR person_b_id: without an index on each side SQLite reads
      // the whole table every time somebody is deleted.
      final plan = await planFor(
        "SELECT * FROM relationships WHERE person_a_id = 'x' "
        "OR person_b_id = 'x'",
      );

      expect(plan, contains('relationships_by_person_a'));
      expect(plan, contains('relationships_by_person_b'));
      expect(plan, isNot(contains('SCAN relationships')));
    });
  });
}
