/// Working out what a file would add to a family, before anything is written.
///
/// ## The rule: add only, never overwrite
///
/// Anything already here is left exactly as it is. A person or an edge in the
/// file whose id is already in the family is skipped, not merged field by
/// field, not overwritten.
///
/// That rule is chosen for one reason: **it cannot lose anything**. Deciding
/// that the file's version of a person should replace the one on the device is
/// conflict resolution, which needs to know which is newer — and DOMAIN.md
/// §15.3 says device clocks cannot answer that. Until there is a server-ordered
/// sequence to ask (M9), the only safe answer is to add what is missing and
/// touch nothing else.
///
/// What this costs the reader: a correction made on a relative's device does
/// not travel. They fix a name, send the file, and the name here stays as it
/// was. That is the honest limit of exchanging files, and it is better stated
/// in the interface than discovered.
///
/// ## Two kinds of duplicate
///
/// A person is a duplicate when their **id** is already here. Ids are globally
/// unique (DOMAIN.md §14.1), so the same id genuinely is the same record.
///
/// An edge is a duplicate when its id is here *or* when the same relationship
/// already exists under a different id — two devices can each record the same
/// marriage, each minting its own id. Matching on
/// `(familyId, type, personAId, personBId)` catches that, which is the same
/// key the database's uniqueness constraint uses. Without it the import would
/// be refused by the database rather than by this code, with nothing useful to
/// say about why.
///
/// ## Why the graph is rebuilt for every edge
///
/// Each accepted edge is validated against a graph that already holds the ones
/// accepted before it. A cycle can be closed by two edges that are each
/// perfectly valid alone — precisely the case ARCHITECTURE §3.3 ③ describes for
/// merges — so validating them all against the starting graph would let one
/// through.
///
/// [FamilyGraph] is immutable, so this means building it once per accepted
/// edge: about 0.6 ms at a thousand people, so roughly a second for the largest
/// import anybody is likely to have. Paid once, on a screen that is already
/// waiting, to catch the one defect that would otherwise hang the tree screen
/// forever.
library;

import '../../domain/family.dart';
import '../../domain/family_graph.dart';
import '../../domain/person.dart';
import '../../domain/relationship.dart';
import '../../domain/validation.dart';
import 'family_file.dart';

/// Something in the file that will not be brought in, and why.
final class RejectedEntry {
  const RejectedEntry({required this.describe, required this.code});

  /// How to name the offending record to a reader — a person's name, or the
  /// two ids an edge joins. Not the raw id alone, which tells nobody anything.
  final String describe;

  /// The domain's reason, so the interface can word it in the reader's
  /// language through `issueText` rather than carrying a sentence from here.
  final IssueCode code;
}

/// What importing a file would do, worked out without writing anything.
///
/// Built first and shown to the reader, rather than applied and reported
/// afterwards: an import is somebody handing their family record to a piece of
/// software, and being told what will happen before it happens is the least
/// that deserves.
final class ImportPlan {
  const ImportPlan({
    required this.family,
    required this.familyIsNew,
    required this.newPersons,
    required this.newRelationships,
    required this.personsAlreadyHere,
    required this.relationshipsAlreadyHere,
    required this.rejected,
  });

  /// The family the file belongs to, as the file describes it.
  ///
  /// When [familyIsNew] is false this is *not* written: the family already
  /// here keeps its own name and settings, by the add-only rule.
  final Family family;

  /// Whether this family is absent here and would be created.
  final bool familyIsNew;

  final List<Person> newPersons;
  final List<Relationship> newRelationships;

  /// How many records were skipped for being here already.
  ///
  /// Reported rather than hidden: importing the same file twice should say
  /// "nothing new", not "done", or a reader cannot tell it worked the first
  /// time.
  final int personsAlreadyHere;
  final int relationshipsAlreadyHere;

  /// Entries the family's own rules refuse.
  final List<RejectedEntry> rejected;

  /// Whether applying this would change anything at all.
  bool get changesSomething =>
      familyIsNew || newPersons.isNotEmpty || newRelationships.isNotEmpty;
}

/// Works out what [file] would add to [existing].
///
/// [existing] is null when no family of that id is here yet, in which case
/// everything in the file is new.
///
/// Nothing is written. The caller applies the plan, or shows it and waits.
ImportPlan planImport(FamilyFile file, {FamilySnapshotLike? existing}) {
  final herePersons = <String, Person>{
    for (final person in existing?.persons ?? const <Person>[])
      person.id: person,
  };
  final hereRelationshipIds = <String>{
    for (final edge in existing?.relationships ?? const <Relationship>[])
      edge.id,
  };
  final hereKeys = <RelationshipKey>{
    for (final edge in existing?.relationships ?? const <Relationship>[])
      edge.key,
  };

  final newPersons = <Person>[];
  var personsAlreadyHere = 0;
  for (final person in file.persons) {
    if (herePersons.containsKey(person.id)) {
      personsAlreadyHere++;
      continue;
    }
    newPersons.add(person);
    herePersons[person.id] = person;
  }

  // The graph the incoming edges are judged against: what is here, plus every
  // person the file brings. An edge between two people who both arrive in this
  // same file is perfectly good, and judging it before they are added would
  // reject it as dangling.
  var graph = FamilyGraph(
    persons: herePersons.values,
    relationships: existing?.relationships ?? const <Relationship>[],
  );

  final newRelationships = <Relationship>[];
  final rejected = <RejectedEntry>[];
  var relationshipsAlreadyHere = 0;

  for (final edge in file.relationships) {
    if (hereRelationshipIds.contains(edge.id) || hereKeys.contains(edge.key)) {
      relationshipsAlreadyHere++;
      continue;
    }

    final result = graph.validateAddition(edge);
    if (result.hasErrors) {
      rejected.add(
        RejectedEntry(
          describe: _describe(edge, herePersons),
          code: result.errors.first.code,
        ),
      );
      continue;
    }

    newRelationships.add(edge);
    hereRelationshipIds.add(edge.id);
    hereKeys.add(edge.key);
    // Rebuilt so the next candidate is judged against this one too. See the
    // note at the top of the file on why that is worth what it costs.
    graph = FamilyGraph(
      persons: herePersons.values,
      relationships: <Relationship>[
        ...existing?.relationships ?? const <Relationship>[],
        ...newRelationships,
      ],
    );
  }

  return ImportPlan(
    family: file.family,
    familyIsNew: existing == null,
    newPersons: newPersons,
    newRelationships: newRelationships,
    personsAlreadyHere: personsAlreadyHere,
    relationshipsAlreadyHere: relationshipsAlreadyHere,
    rejected: rejected,
  );
}

/// Names an edge by the people it joins, falling back to ids for anyone the
/// file did not bring.
String _describe(Relationship edge, Map<String, Person> people) {
  String name(String id) => people[id]?.displayName ?? id;
  return '${name(edge.personAId)} — ${name(edge.personBId)}';
}

/// What [planImport] needs to know about a family already on the device.
///
/// An interface rather than `FamilySnapshot` so that planning needs no graph
/// to be built by the caller, and so a test can hand it two lists. The
/// repository's snapshot satisfies it through [SnapshotOfFamily].
abstract interface class FamilySnapshotLike {
  Iterable<Person> get persons;
  Iterable<Relationship> get relationships;
}

/// Adapts whatever holds a family's people and edges to [FamilySnapshotLike].
final class SnapshotOfFamily implements FamilySnapshotLike {
  const SnapshotOfFamily({required this.persons, required this.relationships});

  @override
  final Iterable<Person> persons;

  @override
  final Iterable<Relationship> relationships;
}
