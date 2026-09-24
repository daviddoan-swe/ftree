/// Postgres-backed implementation of [FamilyRepository] (ROADMAP M7).
///
/// The second answer to the same questions `DriftFamilyRepository` answers,
/// and the reason the repository is an interface at all (ARCHITECTURE §7).
/// Both are held to `test/support/repository_contract.dart`, unchanged.
///
/// ## It is not wired into the application
///
/// Nothing in `lib/features` asks for this. The application reads and writes
/// SQLite exactly as before; swapping the two is M9's job, when
/// synchronisation gives the two copies something to say to each other. Until
/// then this exists to prove the cloud schema keeps the same promises.
///
/// ## Where the rules actually live
///
/// Not here. Every read below returns whatever the policies let through, and
/// every write is refused or allowed by them
/// (`20260924000003_policies.sql`). There is no permission check in this file
/// and there must not be: a check here would be a second, weaker copy of a
/// rule the server already enforces, and the first one to fall out of step.
///
/// One consequence is worth knowing before reading the code. **A forbidden
/// UPDATE does not fail.** `USING` decides which rows a statement can see, so
/// a row a policy refuses is simply not there: nothing changes and nothing is
/// raised. A forbidden INSERT, by contrast, throws. The asymmetry belongs to
/// Postgres, not to this file.
///
/// ## Three operations go through functions
///
/// `saveAll`, `deletePerson` and `deleteFamily` promise more than one
/// statement's worth of atomicity, and every PostgREST request is its own
/// transaction. They call `save_family_all`, `delete_person_deep` and
/// `delete_family_deep`, which are SECURITY INVOKER — the policies judge every
/// statement inside them exactly as they would from outside.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/family_repository.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import 'cloud_mappers.dart';

final class SupabaseFamilyRepository implements FamilyRepository {
  /// [now] is injectable so tests can pin timestamps, as the SQLite one is.
  SupabaseFamilyRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SupabaseClient _db;
  final DateTime Function() _now;

  /// Always UTC. `timestamptz` keeps an instant, and a local reading sent
  /// without its zone is a different instant (§15.3).
  DateTime get _timestamp => _now().toUtc();

  @override
  Future<List<Family>> listFamilies() async {
    final rows = await _db
        .from('families')
        .select()
        .isFilter('deleted_at', null);

    return rows.map(familyFromRow).toList();
  }

  @override
  Future<FamilySnapshot?> loadFamily(String familyId) async {
    // Three requests rather than one nested select. The nested form would
    // return people inside their family, and the graph wants them as lists;
    // unpicking that costs more than the extra round trips, which are local
    // to one screen opening.
    final families = await _db
        .from('families')
        .select()
        .eq('id', familyId)
        .isFilter('deleted_at', null);
    if (families.isEmpty) return null;

    final people = await _db
        .from('persons')
        .select()
        .eq('family_id', familyId)
        .isFilter('deleted_at', null);

    final edges = await _db
        .from('relationships')
        .select()
        .eq('family_id', familyId)
        .isFilter('deleted_at', null);

    return FamilySnapshot(
      family: familyFromRow(families.first),
      graph: FamilyGraph(
        persons: people.map(personFromRow),
        relationships: edges.map(relationshipFromRow),
      ),
    );
  }

  @override
  Future<void> saveFamily(Family family) async {
    // Through the function, not an upsert. Creating a family and editing one
    // are different acts to the server — anyone signed in may do the first,
    // only an owner or editor the second — and an upsert asks for both at
    // once, so a new family is always refused. The function branches; the
    // rule lives there rather than in two places.
    await saveAll(family: family);
  }

  @override
  Future<void> savePerson(Person person) async {
    await _db
        .from('persons')
        .upsert(personToRow(person, updatedAt: _timestamp));
  }

  @override
  Future<void> saveRelationship(Relationship relationship) async {
    await _db
        .from('relationships')
        .upsert(relationshipToRow(relationship, updatedAt: _timestamp));
  }

  @override
  Future<void> saveAll({
    Family? family,
    Iterable<Person> persons = const <Person>[],
    Iterable<Relationship> relationships = const <Relationship>[],
  }) async {
    // One timestamp for the whole write. Stamped row by row, a reader
    // ordering by change would see the people arrive before the edges that
    // join them.
    final at = _timestamp;

    await _db.rpc<void>(
      'save_family_all',
      params: <String, Object?>{
        'family': family == null ? null : familyToRow(family, updatedAt: at),
        'people': <Object?>[
          for (final person in persons) personToRow(person, updatedAt: at),
        ],
        'edges': <Object?>[
          for (final edge in relationships)
            relationshipToRow(edge, updatedAt: at),
        ],
      },
    );
  }

  @override
  Future<void> deletePerson(String personId) async {
    // The person and every edge naming them, together. Left live those edges
    // still travel to other devices as relationships to somebody who is not
    // there (§15.1).
    await _db.rpc<void>(
      'delete_person_deep',
      params: <String, Object?>{
        'person': personId,
        'at': _timestamp.toIso8601String(),
      },
    );
  }

  @override
  Future<void> deleteRelationship(String relationshipId) async {
    final at = _timestamp;

    await _db
        .from('relationships')
        .update(<String, Object?>{
          'deleted_at': at.toIso8601String(),
          'updated_at': at.toIso8601String(),
        })
        .eq('id', relationshipId);
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    await _db.rpc<void>(
      'delete_family_deep',
      params: <String, Object?>{
        'family': familyId,
        'at': _timestamp.toIso8601String(),
      },
    );
  }
}
