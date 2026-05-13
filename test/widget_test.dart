// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_state_migrator/main.dart';

void main() {
  testWidgets('Home screen opens the provider demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('State Migrator Demo'), findsOneWidget);
    expect(find.text('Open Provider Implementation'), findsOneWidget);
    expect(find.text('Open Riverpod Implementation'), findsOneWidget);

    await tester.tap(find.text('Open Provider Implementation'));
    await tester.pumpAndSettle();

    expect(find.text('Provider Todo List'), findsOneWidget);
    expect(find.text('New Todo'), findsOneWidget);
  });
}
