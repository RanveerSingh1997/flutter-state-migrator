import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:migration_dashboard/app.dart';

void main() {
  testWidgets('Home screen shows title and Riverpod button', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('State Migrator Demo'), findsOneWidget);
    expect(find.text('Open Riverpod Implementation'), findsOneWidget);
  });

  testWidgets('Tapping Riverpod button navigates to TodoScreen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Riverpod Implementation'));
    await tester.pumpAndSettle();

    expect(find.text('Todo List (Riverpod)'), findsOneWidget);
    expect(find.text('New Todo'), findsOneWidget);
  });
}
