/// The codes a device keeps of the invitations it issued (PRODUCT.md §5.1).
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/data/database/app_database.dart';
import 'package:ftree/data/database/invitation_codes.dart';

void main() {
  late AppDatabase db;
  late InvitationCodeStore store;

  final clock = DateTime.utc(2026, 9, 25, 12);

  const family = 'f0000000-0000-7000-8000-000000000001';
  const other = 'f0000000-0000-7000-8000-000000000002';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = InvitationCodeStore(db, now: () => clock);
  });

  tearDown(() async {
    await db.close();
  });

  test('nothing is held until an invitation is made', () async {
    expect(await store.forFamily(family), isEmpty);
  });

  test('a code comes back against the invitation it belongs to', () async {
    // The whole feature in one check: the message was closed, and the code is
    // still here to send again.
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');

    expect(await store.forFamily(family), <String, String>{
      'inv-1': 'K7P2-9XMR-4T',
    });
  });

  test('one family does not see another family’s codes', () async {
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');
    await store.remember(id: 'inv-2', familyId: other, code: 'M4QT-7BB2-9K');

    expect(await store.forFamily(family), hasLength(1));
    expect(
      await store.forFamily(other).then((m) => m['inv-2']),
      'M4QT-7BB2-9K',
    );
  });

  test('forgetting one leaves the rest', () async {
    // Called when an invitation is used or revoked. Both make it dead on the
    // server, so a readable copy would only offer a Gửi button that sends
    // something nobody can redeem.
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');
    await store.remember(id: 'inv-2', familyId: family, code: 'M4QT-7BB2-9K');

    await store.forget('inv-1');

    expect(await store.forFamily(family), <String, String>{
      'inv-2': 'M4QT-7BB2-9K',
    });
  });

  test('a family that goes takes its codes with it', () async {
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');
    await store.remember(id: 'inv-2', familyId: other, code: 'M4QT-7BB2-9K');

    await store.forgetFamily(family);

    expect(await store.forFamily(family), isEmpty);
    expect(await store.forFamily(other), hasLength(1));
  });

  test('remembering the same invitation twice does not double it', () async {
    // A retry after a failed write must not leave two rows claiming different
    // codes for one invitation.
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');
    await store.remember(id: 'inv-1', familyId: family, code: 'K7P2-9XMR-4T');

    expect(await store.forFamily(family), hasLength(1));
  });
}
