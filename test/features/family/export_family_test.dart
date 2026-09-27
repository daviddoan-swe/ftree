/// Sending a family out as a file (PRODUCT.md §9.1).
///
/// The share sheet itself is the operating system's and is not tested here —
/// nothing in this process can open one. What is tested is everything up to
/// it: the name the file is given, and that what comes out can be read back in
/// and is the same family.
///
/// The round trip is the test worth having. The format, the merge, and the
/// transaction each pass on their own, but "each part works" has never been
/// the claim — the claim is that a family survives the journey.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/app/providers.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/data/transfer/family_file.dart';
import 'package:ftree/data/transfer/family_import.dart';
import 'package:ftree/domain/family.dart';
import 'package:ftree/domain/genealogical_date.dart';
import 'package:ftree/domain/person.dart';
import 'package:ftree/domain/relationship.dart';
import 'package:ftree/features/family/export_family.dart';
import 'package:ftree/l10n/app_localizations.dart';

void main() {
  const familyId = 'f0000000-0000-7000-8000-000000000000';
  String personId(int n) =>
      'p0000000-0000-7000-8000-${n.toString().padLeft(12, '0')}';

  final at = DateTime.utc(2026, 9, 24, 10);

  group('the name a file is given', () {
    Family named(String name) => Family(id: familyId, name: name);

    test('carries the family and the day', () {
      expect(fileNameFor(named('Nguyen'), at), 'nguyen-2026-09-24.ftree');
    });

    test('Vietnamese is reduced to letters a filename can carry', () {
      // The name passes through file systems and chat applications on its way
      // to a relative. Accents are the first thing one of them mangles.
      expect(
        fileNameFor(named('Họ Nguyễn Đình'), at),
        'ho-nguyen-dinh-2026-09-24.ftree',
      );
    });

    test('every Vietnamese vowel and đ survives the reduction', () {
      // Written out rather than sampled: a missing character would silently
      // become a hyphen, and nobody would notice until a family was named
      // after one.
      expect(
        fileNameFor(named('àáạảã èéẹẻẽ ìíịỉĩ òóọỏõ ùúụủũ ỳýỵỷỹ đ'), at),
        'aaaaa-eeeee-iiiii-ooooo-uuuuu-yyyyy-d-2026-09-24.ftree',
      );
    });

    test('punctuation and spaces become one separator, not many', () {
      expect(
        fileNameFor(named('Họ  Nguyễn   (chi 2)'), at),
        'ho-nguyen-chi-2-2026-09-24.ftree',
      );
    });

    test('a name that reduces to nothing still names the file', () {
      // "-2026-09-24.ftree" tells a reader nothing about what is inside.
      expect(fileNameFor(named('※'), at), 'gia-pha-2026-09-24.ftree');
    });

    test('the day is enough; the clock belongs to another device', () {
      // Minutes would lend somebody else's clock a precision it has not got
      // (§15.3). Two exports on one day share a name, which is correct: they
      // are the same day's answer.
      expect(
        fileNameFor(named('Nguyen'), DateTime.utc(2026, 9, 24, 3)),
        fileNameFor(named('Nguyen'), DateTime.utc(2026, 9, 24, 23)),
      );
    });
  });

  group('the round trip', () {
    late AppDatabase db;
    late DriftFamilyRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftFamilyRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    /// A family with the details most likely to be lost on the way.
    Future<void> seed() async {
      await repository.saveFamily(
        const Family(
          id: familyId,
          name: 'Họ Nguyễn',
          description: 'Gia phả tám đời',
          usesLunarCalendar: true,
        ),
      );
      await repository.savePerson(
        Person(
          id: personId(1),
          familyId: familyId,
          displayName: 'Nguyễn Văn Cả',
          givenName: 'Cả',
          familyName: 'Nguyễn',
          sex: Sex.male,
          // Year only: the precision §4.2 says cannot be recovered once lost.
          birthDate: GenealogicalDate(year: 1887),
          deathDate: GenealogicalDate(
            year: 1950,
            month: 3,
            day: 5,
            lunar: LunarDate(year: 1950, month: 1, day: 17),
          ),
          birthPlace: 'Nam Định',
        ),
      );
      await repository.savePerson(
        Person(
          id: personId(2),
          familyId: familyId,
          displayName: 'Trần Thị Mậu',
          birthFamilyName: 'Trần',
          sex: Sex.female,
          birthDate: GenealogicalDate(year: 1890, isApproximate: true),
        ),
      );
      await repository.saveRelationship(
        Relationship.spouse(
          id: 'r1',
          familyId: familyId,
          personA: personId(1),
          personB: personId(2),
        ),
      );
    }

    /// Everything [exportFamily] does except touching the file system.
    Future<String> exported() async {
      final snapshot = await repository.loadFamily(familyId);
      return encodeFamilyFile(
        family: snapshot!.family,
        persons: snapshot.graph.persons,
        relationships: snapshot.graph.relationships,
        at: at,
      );
    }

    test('a family exported and read back is the same family', () async {
      await seed();

      final plan = planImport(decodeFamilyFile(await exported()));

      expect(plan.familyIsNew, isTrue);
      expect(plan.family.name, 'Họ Nguyễn');
      expect(plan.family.description, 'Gia phả tám đời');
      expect(plan.family.usesLunarCalendar, isTrue);
      expect(plan.newPersons, hasLength(2));
      expect(plan.newRelationships, hasLength(1));
      expect(plan.rejected, isEmpty);
    });

    test('dates come back at the precision they were kept at', () async {
      // The failure this whole feature could cause quietly: a year-only birth
      // written out in full would still import, still look right, and be a
      // date the family never recorded.
      await seed();

      final plan = planImport(decodeFamilyFile(await exported()));
      final first = plan.newPersons.firstWhere((p) => p.id == personId(1));
      final second = plan.newPersons.firstWhere((p) => p.id == personId(2));

      expect(first.birthDate!.toIso(), '1887');
      expect(first.deathDate!.toIso(), '1950-03-05');
      expect(
        first.deathDate!.lunar,
        LunarDate(year: 1950, month: 1, day: 17),
      );
      expect(second.birthDate!.isApproximate, isTrue);
    });

    test('reading it into the device it came from adds nothing', () async {
      // The same family, exported and imported back where it started. Every
      // id is already here, so an add-only merge has nothing to do — and if
      // it had anything to do, the ids would not be the stable, global ones
      // §14.1 promises.
      await seed();
      final text = await exported();
      final here = await repository.loadFamily(familyId);

      final plan = planImport(
        decodeFamilyFile(text),
        existing: SnapshotOfFamily(
          persons: here!.graph.persons,
          relationships: here.graph.relationships,
        ),
      );

      expect(plan.changesSomething, isFalse);
      expect(plan.personsAlreadyHere, 2);
      expect(plan.relationshipsAlreadyHere, 1);
    });

    test('an export carries no deleted rows', () async {
      // Reads filter tombstones, so an export holds only what is live. The
      // consequence is recorded in family_file.dart: an old file can bring
      // back somebody deleted since it was written.
      await seed();
      await repository.deletePerson(personId(2));

      final plan = planImport(decodeFamilyFile(await exported()));

      expect(plan.newPersons, hasLength(1));
      expect(
        plan.newRelationships,
        isEmpty,
        reason: 'the marriage went with them',
      );
    });
  });

  group('it asks before the family leaves the device', () {
    late AppDatabase db;
    late DriftFamilyRepository repository;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftFamilyRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    /// The export set going by [beginExport], still waiting for an answer.
    Future<bool>? running;

    /// Starts an export and stops at whatever it puts on screen.
    ///
    /// The export's future is kept rather than awaited, because the point of
    /// several of these tests is what happens while it is still waiting. The
    /// pumping is awaited, as the test framework requires.
    ///
    /// Only the asking is exercised. Past the confirmation the function writes
    /// a file and opens the system share sheet, neither of which exists in a
    /// test process — so what is checked here is that nothing gets that far
    /// without an answer.
    Future<void> beginExport(WidgetTester tester) async {
      running = null;
      var started = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            localizationsDelegates: AppText.localizationsDelegates,
            supportedLocales: AppText.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                if (!started) {
                  started = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    running = exportFamily(context, ref, familyId);
                  });
                }
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> seedTwo() async {
      await repository.saveFamily(
        const Family(id: familyId, name: 'Họ Nguyễn'),
      );
      for (var n = 1; n <= 2; n++) {
        await repository.savePerson(
          Person(
            id: personId(n),
            familyId: familyId,
            displayName: 'Nguyễn Văn $n',
          ),
        );
      }
    }

    testWidgets('a swipe does not send anything on its own', (tester) async {
      await seedTwo();
      await beginExport(tester);

      expect(find.text('Export this family?'), findsOneWidget);
    });

    testWidgets('the question says how many people would leave', (
      tester,
    ) async {
      // A prompt that says only "are you sure" is a speed bump. This one has
      // to be worth reading: how much goes, and that the living go too.
      await seedTwo();
      await beginExport(tester);

      expect(
        find.textContaining('Sends all 2 people off the device'),
        findsOneWidget,
      );
      expect(find.textContaining('still living'), findsOneWidget);
      expect(find.textContaining('cannot be called back'), findsOneWidget);
    });

    testWidgets('declining is not the same answer as having nothing', (
      tester,
    ) async {
      // False means "there was nothing here", and the list screen says so out
      // loud. Declining must not be reported that way — the reader knows what
      // they just did.
      await seedTwo();
      await beginExport(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(await running, isTrue);
    });

    testWidgets('an empty family is never even asked about', (tester) async {
      await beginExport(tester);

      expect(find.text('Export this family?'), findsNothing);
    });
  });
}
