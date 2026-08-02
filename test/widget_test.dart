// Minimal smoke test: the app builds and pumps a frame without throwing.
//
// It deliberately asserts nothing about what is on screen. Real UI coverage
// arrives with the UI itself at M5; until then this exists so that
// `flutter test` still proves the app boots at runtime, which static analysis
// cannot tell you.

import 'package:flutter_test/flutter_test.dart';

import 'package:ftree/main.dart';

void main() {
  testWidgets('app builds without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(tester.takeException(), isNull);
  });
}
