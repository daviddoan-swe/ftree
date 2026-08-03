import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';

import 'schema_versions/schema.dart';
import 'schema_versions/schema_v1.dart' as v1;

/// The project's first migration, verified against the real v1 schema rather
/// than against a hand-written approximation of it.
///
/// A schema mistake costs a migration on every installed device (DOMAIN.md
/// §18), so the shape of v1 is captured in `drift_schemas/` and replayed here.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('upgrading from v1 produces the v2 schema', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 2);
    await db.close();
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
    await verifier.migrateAndValidate(db, 2);

    final families = await db.select(db.families).get();
    final people = await db.select(db.persons).get();
    expect(families.single.name, 'Họ Nguyễn');
    expect(people.single.displayName, 'Cụ Tổ');

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
