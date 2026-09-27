/// What each copy of a family allows (PRODUCT.md §5.0).
///
/// The table in §5.0 in executable form. Every right but [FamilyRights.mayExport]
/// mirrors a policy in `20260924000003_policies.sql`, so a change here that
/// does not match one there is a change that will be refused by the server.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/family_roles.dart';
import 'package:ftree/data/repositories/drift_family_repository.dart';
import 'package:ftree/domain/family.dart';

void main() {
  group('the table in §5.0', () {
    const roles = <FamilyRole?>[
      null,
      FamilyRole.owner,
      FamilyRole.editor,
      FamilyRole.viewer,
    ];

    /// Reads one column of the table: which roles a right is granted to.
    List<FamilyRole?> granted(bool Function(FamilyRole?) right) =>
        roles.where(right).toList();

    test('export — owner, and a copy nobody else has a claim on', () {
      // The one right with no policy behind it. An export never reaches the
      // server, so hiding it is the whole of the enforcement — a rule, not a
      // lock (§5.0).
      expect(granted((r) => r.mayExport), <FamilyRole?>[
        null,
        FamilyRole.owner,
      ]);
    });

    test('Chia sẻ — only a family that is not up there', () {
      expect(granted((r) => r.mayShare), <FamilyRole?>[null]);
    });

    test('the member list — the owner alone', () {
      // `family_members` answers nobody else anyway.
      expect(granted((r) => r.mayManageMembers), <FamilyRole?>[
        FamilyRole.owner,
      ]);
    });

    test('renaming the family — the owner’s, like deleting it', () {
      // What a family is called is not a record an editor is filling in. One
      // editor renaming it renames it for the whole household, and their
      // business is the people inside rather than what the gia phả is called.
      expect(granted((r) => r.mayRenameFamily), <FamilyRole?>[
        null,
        FamilyRole.owner,
      ]);
    });

    test('deleting the family — an editor may not', () {
      // The policy says so as "and deleted_at IS NULL" on both sides: an
      // editor can neither tombstone a live family nor revive a dead one.
      expect(granted((r) => r.mayDeleteFamily), <FamilyRole?>[
        null,
        FamilyRole.owner,
      ]);
    });

    test('people and relationships — owner and editor', () {
      // persons_insert, persons_update, and the same pair for relationships.
      // Deleting is soft, so it is an update and an editor may do it.
      expect(granted((r) => r.mayEditPeople), <FamilyRole?>[
        null,
        FamilyRole.owner,
        FamilyRole.editor,
      ]);
    });

    test('a viewer may do nothing at all', () {
      const viewer = FamilyRole.viewer;

      expect(viewer.mayExport, isFalse);
      expect(viewer.mayShare, isFalse);
      expect(viewer.mayManageMembers, isFalse);
      expect(viewer.mayRenameFamily, isFalse);
      expect(viewer.mayDeleteFamily, isFalse);
      expect(viewer.mayEditPeople, isFalse);
      expect(viewer.mayImportInto, isFalse);
    });

    test('and a copy with no role may do everything', () {
      // A family made here, or one that arrived as a file — which carries no
      // rights with it (§5.7). Full rights, not an absence of information.
      const none = null as FamilyRole?;

      expect(none.mayExport, isTrue);
      expect(none.mayShare, isTrue);
      expect(none.mayRenameFamily, isTrue);
      expect(none.mayDeleteFamily, isTrue);
      expect(none.mayEditPeople, isTrue);
      expect(none.mayImportInto, isTrue);
      expect(
        none.mayManageMembers,
        isFalse,
        reason: 'there are no members to manage until it is shared',
      );
    });
  });

  group('remembering what a copy arrived as', () {
    late AppDatabase db;
    late DriftFamilyRepository repository;
    late FamilyRoles roles;

    const one = 'f0000000-0000-7000-8000-000000000001';
    const two = 'f0000000-0000-7000-8000-000000000002';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftFamilyRepository(db);
      roles = FamilyRoles(db);

      await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn'));
      await repository.saveFamily(const Family(id: two, name: 'Họ Trần'));
    });

    tearDown(() async {
      await db.close();
    });

    test('a family made here carries no role', () async {
      expect(await roles.all(), isEmpty);
    });

    test('one family does not take the other’s role', () async {
      // The answer to holding one family you made and one you were invited
      // into: the role is a column on the family, so both are true at once on
      // the same phone (§5.0).
      await roles.remember(one, FamilyRole.editor);

      expect(await roles.all(), <String, FamilyRole>{one: FamilyRole.editor});
    });

    test('a later role replaces the earlier one', () async {
      await roles.remember(one, FamilyRole.viewer);
      await roles.remember(one, FamilyRole.editor);

      expect(await roles.all(), <String, FamilyRole>{one: FamilyRole.editor});
    });

    test('remembering does not make the family look edited', () async {
      // updatedAt is what synchronisation orders by (§15.2). A note about the
      // copy is not a change to the gia phả.
      final before = (await db.select(db.families).get())
          .firstWhere((f) => f.id == one)
          .updatedAt;

      await roles.remember(one, FamilyRole.editor);

      expect(
        (await db.select(db.families).get())
            .firstWhere((f) => f.id == one)
            .updatedAt,
        before,
      );
    });

    test('a deleted family is still listed, with its role', () async {
      // It used to be left out, and that was the rule behind two holes. A
      // deleted family is drawn nowhere, so nothing that *lists* families
      // noticed — but two things still ask what this account may do to one,
      // and both were told "nothing is known". Null reads as a family nobody
      // else has a claim on, which reads as every right.
      //
      // The two: pushing the tombstone, and deciding whether an old backup
      // may put the family back. An editor holding a file could undo the
      // owner's deletion for the whole household (PRODUCT §5.10).
      await roles.remember(one, FamilyRole.editor);

      await repository.deleteFamily(one);

      expect(await roles.all(), <String, FamilyRole>{one: FamilyRole.editor});
    });

    test('an ordinary edit leaves the role alone', () async {
      // saveFamily writes every column it is given. If it wrote myRole too,
      // renaming a family would hand its holder rights they were never given.
      await roles.remember(one, FamilyRole.viewer);

      await repository.saveFamily(const Family(id: one, name: 'Họ Nguyễn 2'));

      expect(await roles.all(), <String, FamilyRole>{one: FamilyRole.viewer});
    });
  });

  group('bringing the local roles in line with the server', () {
    late AppDatabase db;
    late DriftFamilyRepository repository;
    late FamilyRoles roles;

    const mine = 'f0000000-0000-7000-8000-00000000000a';
    const invited = 'f0000000-0000-7000-8000-00000000000b';
    const other = 'f0000000-0000-7000-8000-00000000000c';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = DriftFamilyRepository(db);
      roles = FamilyRoles(db);

      // Three copies on one phone: one made here, and two joined.
      await repository.saveFamily(const Family(id: mine, name: 'Nhà tôi'));
      await repository.saveFamily(const Family(id: invited, name: 'Họ Nguyễn'));
      await repository.saveFamily(const Family(id: other, name: 'Họ Trần'));
      await roles.remember(invited, FamilyRole.viewer);
      await roles.remember(other, FamilyRole.editor);
    });

    tearDown(() async {
      await db.close();
    });

    test('a promotion arrives', () async {
      // The hole §5.0 left open: an owner changing somebody's role never
      // reached their device, so a promoted editor kept seeing a viewer's
      // screen until they were sent a fresh invitation.
      final changed = await roles.reconcile(<String, FamilyRole>{
        invited: FamilyRole.editor,
        other: FamilyRole.editor,
      });

      expect(changed, isTrue);
      expect(await roles.all(), <String, FamilyRole>{
        invited: FamilyRole.editor,
        other: FamilyRole.editor,
      });
    });

    test('and so does a demotion', () async {
      await roles.reconcile(<String, FamilyRole>{
        invited: FamilyRole.viewer,
        other: FamilyRole.viewer,
      });

      expect(await roles.all(), <String, FamilyRole>{
        invited: FamilyRole.viewer,
        other: FamilyRole.viewer,
      });
    });

    test('being put out of one family leaves the others alone', () async {
      // The whole worry in one check. Removed from Họ Nguyễn; still an editor
      // of Họ Trần; and Nhà tôi was never anybody else's business.
      await roles.reconcile(<String, FamilyRole>{other: FamilyRole.editor});

      expect(await roles.all(), <String, FamilyRole>{
        invited: FamilyRole.removed,
        other: FamilyRole.editor,
      });
    });

    test('a family made here is never touched', () async {
      // It has no role, so the server has nothing to say about it — not even
      // when the server names nothing at all.
      await roles.reconcile(const <String, FamilyRole>{});

      expect(
        await roles.all(),
        isNot(contains(mine)),
        reason: 'no role, and reconciling must not invent one',
      );
      final here = await repository.loadFamily(mine);
      expect(here!.family.name, 'Nhà tôi');
    });

    test(
      'a family the server names but this device does not is ignored',
      () async {
        // Somebody invited on another phone. Nothing to write here, and
        // inventing a row would put a family on the list that is not on it.
        final changed = await roles.reconcile(<String, FamilyRole>{
          'f0000000-0000-7000-8000-00000000000d': FamilyRole.owner,
          invited: FamilyRole.viewer,
          other: FamilyRole.editor,
        });

        expect(changed, isFalse);
        expect(await roles.all(), hasLength(2));
      },
    );

    test('nothing to do reports nothing to do', () async {
      // The caller redraws on true, so a reconcile that changes nothing must
      // say so — otherwise it asks to be run again, for ever.
      final changed = await roles.reconcile(<String, FamilyRole>{
        invited: FamilyRole.viewer,
        other: FamilyRole.editor,
      });

      expect(changed, isFalse);
    });

    test('a family somebody deleted keeps its role', () async {
      // Deleted is not the same as put out, and folding them together takes the
      // role away. The role is what lets an owner put the family back from a
      // file (PRODUCT §5.10) — so an owner who deleted on one device would find
      // their own backup refused on another. The copy still goes; that is
      // RemovedFamilies, and it is given this same set.
      final changed = await roles.reconcile(
        <String, FamilyRole>{other: FamilyRole.editor},
        deleted: <String>{invited},
      );

      expect(changed, isFalse);
      expect(await roles.all(), containsPair(invited, FamilyRole.viewer));
    });

    test('and one left out with no reason given is still a removal', () async {
      // The guard must not swallow the case it sits next to.
      await roles.reconcile(
        <String, FamilyRole>{other: FamilyRole.editor},
        deleted: <String>{'f0000000-0000-7000-8000-0000000000ff'},
      );

      expect(await roles.all(), containsPair(invited, FamilyRole.removed));
    });

    test('once removed, it stays removed', () async {
      await roles.reconcile(const <String, FamilyRole>{});
      final again = await roles.reconcile(const <String, FamilyRole>{});

      expect(again, isFalse);
    });

    test('being invited back undoes it', () async {
      await roles.reconcile(const <String, FamilyRole>{});
      expect(await roles.all(), containsPair(invited, FamilyRole.removed));

      await roles.reconcile(<String, FamilyRole>{invited: FamilyRole.editor});

      expect(await roles.all(), containsPair(invited, FamilyRole.editor));
    });
  });
}
