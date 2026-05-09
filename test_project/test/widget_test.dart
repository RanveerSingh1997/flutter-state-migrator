import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:test_project/counter_model.dart';
import 'package:test_project/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: const MyApp()));

    expect(find.text('Count: 0'), findsOneWidget);
  });
}

// TODO: Auto-migrated Riverpod Provider
final countermodelProvider =
    StateNotifierProvider<CounterModelNotifier, CounterModelState>((ref) {
      return CounterModelNotifier();
    });
