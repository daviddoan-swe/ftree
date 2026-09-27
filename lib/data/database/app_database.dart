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

  /// Whether this row holds a change this device has not sent (ROADMAP M9).
  ///
  /// Set by every write the application makes and cleared by every write
  /// synchronisation makes, so the two can be told apart — which is the whole
  /// of what a pull needs in order not to land on top of somebody's work.
  ///
  /// A flag rather than a comparison against `updatedAt`. That would be asking
  /// the device's own clock whether an edit came after the last sync, and a
  /// clock that steps backwards — a timezone change, a manual correction, an
  /// NTP jump — would drop the edit silently. This is exact.
  BoolColumn get unsent => boolean().withDefault(const Constant<bool>(false))();
}

/// A managed family-tree dataset — a boundary, not a kinship group.
///
/// The row class is named `FamilyRow`, not `Family`: the generated name would
/// otherwise collide with the domain entity, and every file translating between
/// the two would need an import prefix. The suffix also makes it obvious at a
/// glance which side of the boundary a value is on.
@DataClassName('FamilyRow')
class Families extends Table with _SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();

  /// Whether the family keeps its dates and anniversaries by the lunar
  /// calendar. Travels with the tree rather than following the viewer.
  /// When this device sent this family to the cloud, or null.
  ///
  /// **Local only, and not part of [Family].** It says nothing about the gia
  /// phả — it records what this device did with it — so the domain entity
  /// stays clear of it, the same way it stays clear of `updatedAt` (§15.2).
  ///
  /// A mark rather than a question asked of the server: offline there is
  /// nobody to ask, and the answer decides what the interface offers.
  ///
  /// When a synchronisation of this family last finished without trouble.
  ///
  /// Not `lastSeen`, which is a position in the server's sequence and says
  /// nothing about when. Null until the first one succeeds, and left alone by
  /// one that failed: "three hours ago" has to mean the last time it actually
  /// worked, or the line is worse than no line (ROADMAP M9, step 5).
  DateTimeColumn get syncedAt => dateTime().nullable()();

  /// A time rather than a flag, matching `deletedAt` beside it. It reads back
  /// as "shared on the 24th" where a boolean reads as "shared, at some point
  /// nobody wrote down".
  DateTimeColumn get sharedAt => dateTime().nullable()();

  /// What this device may do with this family, or null for full rights.
  ///
  /// **Local only, and not part of [Family].** It says nothing about the gia
  /// phả — it records how this copy came to be here — so the domain entity
  /// stays clear of it, as it does of `sharedAt` and `updatedAt` (§15.2).
  ///
  /// Null means there is nobody else it could belong to: a family made on this
  /// device, or one that arrived as a file, which carries no rights with it
  /// (PRODUCT §5.0). Otherwise it is the role this copy arrived with — `owner`
  /// on pressing Chia sẻ, whatever the code granted on accepting one.
  ///
  /// Read without a network, so the interface holds on a train.
  ///
  /// **Not cleared when signing out**, unlike `sharedAt`. That one records
  /// what this device did and can be recovered by asking; this one records
  /// provenance, and clearing it would hand full rights to anybody who signed
  /// out of an editor's copy.
  TextColumn get myRole => text().nullable()();

  /// The highest `change_seq` this device has taken from the server for this
  /// family, or 0 for one it has never pulled (ROADMAP M9).
  ///
  /// One number for the whole family rather than one per row: the device does
  /// not order anything, it only says where it is, and the server answers with
  /// what came after. `0` therefore means "everything", which makes the first
  /// download and every later pull the same request.
  ///
  /// Written in the same transaction as the rows it accounts for. Written
  /// first, a pull interrupted halfway would leave the rest below a number
  /// already recorded, and nothing would ever ask for them again.
  IntColumn get lastSeen => integer().withDefault(const Constant<int>(0))();

  BoolColumn get usesLunarCalendar =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The two columns a three-way merge needs, on the table people actually edit
/// (ROADMAP M9, step 3).
///
/// Only on [Persons]. A family has three mergeable fields and a relationship
/// has none worth merging — changing which two people an edge joins makes it a
/// different edge — so both keep step one's behaviour and hold rather than
/// merge. People are where two relatives fill in different halves of the same
/// record, which is the case this exists for.
mixin _MergeColumns on Table {
  /// The row exactly as the server last gave it, kept from the moment this
  /// device first edits it until that edit has gone.
  ///
  /// Without it there is no telling an edit from an absence of one: two
  /// versions both look like values, and only the one they started from says
  /// which side moved. Null whenever the row is not `unsent`, because then
  /// there is nothing to be merged against.
  TextColumn get baseFields => text().nullable()();

  /// The server's version, kept when it could not be merged.
  ///
  /// A conflict has to outlive the pull that found it. `lastSeen` moves past
  /// the change either way, so a conflict only reported would never be offered
  /// again and the disagreement would quietly become this device's version
  /// winning.
  TextColumn get theirsFields => text().nullable()();

  /// The server has removed this row, and this device has unsent changes to it.
  ///
  /// The other half of [theirsFields], and it cannot be carried by it: a
  /// removal has no fields to keep. Left unrecorded, the pull would have to
  /// choose between landing the tombstone on somebody's unsent work and holding
  /// it forever — and holding it is worse than it sounds, because the next push
  /// sends the row up as a living person and the deletion is undone on the
  /// server with nobody told (ROADMAP M9, step 4).
  BoolColumn get theirsDeleted =>
      boolean().withDefault(const Constant<bool>(false))();
}

/// Someone recorded in a tree.
///
/// Twelve date columns — six per date — rather than one blob each. Explicit
/// columns keep the ISO text sortable, which is the reason §4.1 chose that
/// format over JSON.
/// Every read of a person filters by family and skips tombstones, so the index
/// covers both columns rather than just the foreign key. `IS NULL` is a usable
/// index constraint in SQLite, so the whole `WHERE` is served.
///
/// Not a partial index over the live rows only, tempting though the smaller
/// index is: synchronisation has to read exactly the tombstones a partial index
/// would leave out (§15.2), and that is a trap which only springs later.
@TableIndex(name: 'persons_by_family', columns: <Symbol>{#familyId, #deletedAt})
@DataClassName('PersonRow')
class Persons extends Table with _SyncColumns, _MergeColumns {
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
/// Three indexes, for three different reads.
///
/// By family, for loading a tree and for deleting one — the same shape as
/// [Persons].
///
/// By each endpoint, because deleting a person tombstones every relationship
/// naming them (§15.1) and that query is `person_a_id = ? OR person_b_id = ?`.
/// With an index on each side SQLite can serve both halves of the `OR`; with
/// neither it scans the whole table on every person deleted. SQLite does not
/// index a foreign key on its own, so nothing here comes for free.
@TableIndex(
  name: 'relationships_by_family',
  columns: <Symbol>{#familyId, #deletedAt},
)
@TableIndex(name: 'relationships_by_person_a', columns: <Symbol>{#personAId})
@TableIndex(name: 'relationships_by_person_b', columns: <Symbol>{#personBId})
@DataClassName('RelationshipRow')
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

/// The plaintext of invitations this device issued (PRODUCT.md §5.1).
///
/// **Deliberately local, and deliberately not on the server.** The server keeps
/// only a hash, so that a database which escapes carries nothing that opens a
/// family. The code itself lives in the message the owner sent — and here,
/// because a message is easy to close by accident and a code that cannot be
/// shown again is a code that has to be thrown away and made afresh.
///
/// Keeping it here costs nothing an attacker did not already have: this device
/// holds the entire gia phả, and whoever can unlock it can simply issue a new
/// invitation. Hashing defends against the *server* being read, which is a
/// different room entirely.
///
/// No `updatedAt`, no `deletedAt`. §15 asks for both on tables that
/// synchronise; this one is the opposite of synchronisable. A row is written
/// when an invitation is made and removed when it is used or revoked, at which
/// point there is nothing left worth showing anybody.
class InvitationCodes extends Table {
  /// The id the server gave the invitation. The two sides are joined on it.
  TextColumn get id => text()();

  /// Kept so the list for one family can be read without asking the server —
  /// and so that deleting a family locally can take its codes with it.
  TextColumn get familyId => text()();

  TextColumn get code => text()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// The application's local database.
///
/// Takes its executor rather than choosing one, so tests can run against an
/// in-memory database while the application uses a file. There is no hidden
/// default: the caller always says which.
@DriftDatabase(
  tables: <Type>[Families, Persons, Relationships, InvitationCodes],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 2 — indexes on the columns every read filters by.
  /// 3 — `families.sharedAt`, so a device knows which families it has shared
  ///     without asking a server it may not be able to reach.
  /// 4 — `invitationCodes`, so an invitation can be sent again after the
  ///     message carrying it was closed.
  /// 5 — `families.myRole`, so the interface offers only what this copy is
  ///     allowed to do, with no network to ask.
  /// 6 — `unsent` on everything that synchronises, and `families.lastSeen`:
  ///     the two facts a pull needs, which of these rows are mine and where I
  ///     had got to.
  /// 7 — `persons.baseFields` and `persons.theirsFields`: the version two
  ///     edits started from, and the one that could not be merged into them.
  /// 8 — `persons.theirsDeleted`, so a removal that meets an edit can be asked
  ///     about rather than silently winning or silently losing.
  /// 9 — `families.syncedAt`, so the device can say when it last managed to
  ///     reach the server rather than leaving somebody to guess.
  @override
  int get schemaVersion => 9;

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

  /// Runs one step of an upgrade and records that it ran, in one transaction.
  ///
  /// Drift runs the steps outside any transaction of its own and writes the
  /// schema version only once all of them have finished — its own words, in
  /// `engines.dart`: "set version now, after migrations ran successfully". So
  /// every `ALTER TABLE` commits on its own while the number on the database
  /// still says where it started.
  ///
  /// A process that stops in between therefore leaves columns added under a
  /// version that does not know about them, and the upgrade runs at launch,
  /// so swiping the application away, a flat battery or iOS reclaiming memory
  /// is enough. A device was found in exactly that state: `my_role` present,
  /// version 4, and `duplicate column name` on every launch afterwards with no
  /// way out from inside the application — uninstalling to clear it takes the
  /// gia phả with it.
  ///
  /// Both halves go in together here, so an interruption leaves the database
  /// exactly as the last finished step left it. That SQLite rolls back
  /// `ALTER TABLE` and `PRAGMA user_version` together is measured, not
  /// assumed. Drift's own write of the version afterwards then finds it
  /// already there and changes nothing.
  Future<void> _step(int from, int to, Future<void> Function() body) async {
    if (from >= to) return;

    await customStatement('BEGIN');
    try {
      await body();
      await customStatement('PRAGMA user_version = $to');
      await customStatement('COMMIT');
    } catch (_) {
      await customStatement('ROLLBACK');
      rethrow;
    }
  }

  /// Creates something named [name] unless the database already has it.
  ///
  /// The same rescue as [_addColumn], for the two steps that make objects
  /// rather than columns. A device stopped inside step 2 or step 4 carries
  /// half its indexes, or the table without the version that knows about it,
  /// and meets `already exists` instead of `duplicate column name`.
  Future<void> _createOnce(String name, Future<void> Function() create) async {
    final present = await customSelect(
      'SELECT 1 FROM sqlite_master WHERE name = ?',
      variables: <Variable<Object>>[Variable<String>(name)],
    ).get();

    if (present.isEmpty) await create();
  }

  /// Adds [column] to [table] unless it is already there.
  ///
  /// [_step] stops this happening from here on. It cannot help the devices it
  /// was too late for: their half-finished work is already committed, and a
  /// transaction cannot reach back and undo what another process committed
  /// before it. Those devices need the replay to meet its own work and step
  /// over it, which is the whole of what this does.
  Future<void> _addColumn(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final present = await customSelect(
      'SELECT 1 FROM pragma_table_info(?) WHERE name = ?',
      variables: <Variable<Object>>[
        Variable<String>(table.actualTableName),
        Variable<String>(column.name),
      ],
    ).get();

    if (present.isEmpty) await m.addColumn(table, column);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),

    /// A device that already holds data gets the same schema a fresh install
    /// gets. The two paths drifting apart is the classic migration defect, and
    /// a test compares them rather than trusting this.
    onUpgrade: (Migrator m, int from, int to) async {
      await _step(from, 2, () async {
        await _createOnce('persons_by_family', () => m.create(personsByFamily));
        await _createOnce(
          'relationships_by_family',
          () => m.create(relationshipsByFamily),
        );
        await _createOnce(
          'relationships_by_person_a',
          () => m.create(relationshipsByPersonA),
        );
        await _createOnce(
          'relationships_by_person_b',
          () => m.create(relationshipsByPersonB),
        );
      });
      await _step(from, 3, () async {
        // Null for every family already here, which is the truth: nothing has
        // been shared, because until now there was nowhere to share it to.
        await _addColumn(m, families, families.sharedAt);
      });
      await _step(from, 4, () async {
        // Empty on every device that upgrades, which is the truth: no
        // invitation has ever been issued from here.
        await _createOnce(
          'invitation_codes',
          () => m.createTable(invitationCodes),
        );
      });
      await _step(from, 5, () async {
        await _addColumn(m, families, families.myRole);

        // Null is right for a family nobody has shared: there is nobody else
        // with a claim on it. But a family already carrying a mark is one this
        // device put on a server, and null there would take its owner's member
        // list away on upgrade.
        //
        // Owner is a guess, and the imprecise case is a family this device
        // *joined* rather than shared — joining marks it too. The guess is
        // safe because it is checked where it matters: the member list asks
        // the server for the caller's role before it draws anything, and
        // answers an editor with "only the owner manages this". A wrong guess
        // here buys somebody a door that opens onto a sentence.
        await customStatement(
          "UPDATE families SET my_role = 'owner' WHERE shared_at IS NOT NULL",
        );
      });
      await _step(from, 6, () async {
        await _addColumn(m, families, families.unsent);
        await _addColumn(m, persons, persons.unsent);
        await _addColumn(m, relationships, relationships.unsent);
        await _addColumn(m, families, families.lastSeen);

        // False and zero for everything already here. Zero is right: a
        // lastSeen above zero would make a pull skip everything below that
        // number, and starting at "I have seen nothing" costs one full pull
        // and nothing else.
        //
        // False is **not** right, and the sentence that used to stand here —
        // "cannot lose anything" — was wrong. It weighed the pull only. A row
        // marked unsent is one a pull will not land on, which is the cost it
        // named; a row marked *sent* is one a push will never offer, and
        // before v6 there was no push, so anything edited after the family was
        // last uploaded had never gone anywhere. Those rows are now sealed on
        // the one device that holds them.
        //
        // Measured, not reasoned: a person added on a v5 device two minutes
        // after its last upload, found afterwards on that phone and on no
        // server. The statements are left exactly as they shipped, because a
        // migration that has run on a device is history and editing it would
        // give two devices different pasts (README, "Changing the local
        // schema"). What the flag lost cannot be recovered from the device
        // either — only the server knows which rows it already holds — so the
        // repair belongs in a reconciliation against it, not here.
        //
        // It cannot recur: from v6 on, `mappers.dart` sets the flag on every
        // write. Only a device that existed before v6 can be carrying sealed
        // work.
      });
      await _step(from, 7, () async {
        // Null for everything, which is the truth: no row on a device that has
        // not synchronised yet has a version it was edited away from, and none
        // is in disagreement with anybody.
        await _addColumn(m, persons, persons.baseFields);
        await _addColumn(m, persons, persons.theirsFields);
      });
      await _step(from, 8, () async {
        // False for everything, which is the truth: nothing has been removed
        // out from under an edit on a device that has not pulled since.
        await _addColumn(m, persons, persons.theirsDeleted);
      });
      await _step(from, 9, () async {
        // Null for everything, which is the truth: a device that has not
        // synchronised since this column existed cannot say when it last did.
        await _addColumn(m, families, families.syncedAt);
      });
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite ignores foreign keys unless asked, per connection. Without this
      // the CASCADE clauses above are decoration and deleting a person would
      // leave orphaned edges — the corruption §15.1 exists to prevent.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
