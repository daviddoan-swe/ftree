/// The local SQLite schema (ARCHITECTURE §8).
///
/// Infrastructure, not domain: this file imports Drift, and the domain must
/// never import it back. The dependency runs data → domain only.
///
/// Six things the schema had to get right from the first version, because
/// changing them once real data exists is a migration on every installed
/// device (DOMAIN.md §18):
///
///   * partial dates stored as ISO-prefix text plus a separate approximate
///     flag, so a year-only date can never be mistaken for 1 January
///   * lunar dates in their own columns rather than folded into the ISO text
///   * `updatedAt` and nullable `deletedAt` on every table, so a row deleted
///     before synchronisation exists still leaves a tombstone
///   * `ON DELETE CASCADE` from a relationship to both of its endpoints
///   * `UNIQUE (familyId, type, personAId, personBId)` on relationships
///   * UUID v7 text primary keys, never composite with `familyId`
library;

import 'package:drift/drift.dart';

import '../../domain/person.dart';
import '../../domain/relationship.dart';

part 'app_database.g.dart';

/// Columns every synchronizable table carries (DOMAIN.md §15.2).
///
/// `deletedAt` exists from the first schema rather than from the
/// synchronisation milestone. Rows hard-deleted before tombstones exist leave
/// no record of the deletion, so on first sync any peer still holding the row
/// re-proposes it and it returns — and the intent cannot be recovered
/// afterwards.
///
/// `updatedAt` is metadata only. It must never decide which side wins a
/// conflict: device clocks drift and users change them, so a machine with a
/// wrong date would win every conflict permanently (§15.3).
mixin _SyncColumns on Table {
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

/// A managed family-tree dataset — a boundary, not a kinship group.
class Families extends Table with _SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// Whether the family keeps its dates and anniversaries by the lunar
  /// calendar. Travels with the tree rather than following the viewer.
  BoolColumn get usesLunarCalendar =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Someone recorded in a tree.
///
/// Twelve date columns — six per date — rather than one blob each. Explicit
/// columns keep the ISO text sortable, which is the reason §4.1 chose that
/// format over JSON.
class Persons extends Table with _SyncColumns {
  TextColumn get id => text()();

  TextColumn get familyId =>
      text().references(Families, #id, onDelete: KeyAction.cascade)();

  TextColumn get displayName => text()();
  TextColumn get givenName => text().nullable()();
  TextColumn get additionalNames => text().nullable()();
  TextColumn get familyName => text().nullable()();

  /// Surname at birth. Present from the first schema because by the time
  /// anyone notices it missing, the values are no longer known (§3.1).
  TextColumn get birthFamilyName => text().nullable()();

  /// Stored by name, so the database is readable and adding a value later does
  /// not renumber the existing rows.
  TextColumn get sex => textEnum<Sex>()();

  // Birth date — Gregorian, then the optional lunar reading.
  TextColumn get birthDateIso => text().nullable()();
  BoolColumn get birthDateApproximate =>
      boolean().withDefault(const Constant(false))();
  IntColumn get birthLunarYear => integer().nullable()();
  IntColumn get birthLunarMonth => integer().nullable()();
  IntColumn get birthLunarDay => integer().nullable()();
  BoolColumn get birthLunarIsLeapMonth =>
      boolean().withDefault(const Constant(false))();

  // Death date, same shape.
  TextColumn get deathDateIso => text().nullable()();
  BoolColumn get deathDateApproximate =>
      boolean().withDefault(const Constant(false))();
  IntColumn get deathLunarYear => integer().nullable()();
  IntColumn get deathLunarMonth => integer().nullable()();
  IntColumn get deathLunarDay => integer().nullable()();
  BoolColumn get deathLunarIsLeapMonth =>
      boolean().withDefault(const Constant(false))();

  TextColumn get birthPlace => text().nullable()();
  TextColumn get deathPlace => text().nullable()();
  TextColumn get biography => text().nullable()();

  /// An opaque reference, deliberately not a foreign key: the media table does
  /// not exist yet (§3.3).
  TextColumn get profileMediaRef => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// An edge between two people.
///
/// The endpoint columns mean different things by type: parent and child for
/// `parentChild`, and merely the lower and higher id for `spouse`, which is
/// stored in canonical order (§5.1). The unique key below only rejects a
/// duplicate spouse because of that ordering.
class Relationships extends Table with _SyncColumns {
  TextColumn get id => text()();

  TextColumn get familyId =>
      text().references(Families, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => textEnum<RelationshipType>()();

  // Both endpoints point at Persons, so each reference needs its own name or
  // the generator cannot tell the two apart.
  @ReferenceName('relationshipsAsPersonA')
  TextColumn get personAId =>
      text().references(Persons, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('relationshipsAsPersonB')
  TextColumn get personBId =>
      text().references(Persons, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{familyId, type, personAId, personBId},
  ];
}

/// The application's local database.
///
/// Takes its executor rather than choosing one, so tests can run against an
/// in-memory database while the application uses a file. There is no hidden
/// default: the caller always says which.
@DriftDatabase(tables: <Type>[Families, Persons, Relationships])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  /// Timestamps are stored as ISO-8601 UTC text, not as Unix integers.
  ///
  /// Drift's default writes an integer and hands back a *local* `DateTime`, so
  /// a value written as UTC comes back shifted and no longer flagged UTC. The
  /// instant survives; the zone does not. Every date comparison in this
  /// application is deliberately UTC (§4.1), and a synchronisation clock that
  /// silently changes zone between write and read is the kind of defect that
  /// only shows up in one timezone at one time of year.
  ///
  /// This is a storage format, so it belongs in the first schema: switching
  /// later means rewriting every timestamp on every installed device.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    beforeOpen: (OpeningDetails details) async {
      // SQLite ignores foreign keys unless asked, per connection. Without this
      // the CASCADE clauses above are decoration and deleting a person would
      // leave orphaned edges — the corruption §15.1 exists to prevent.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
