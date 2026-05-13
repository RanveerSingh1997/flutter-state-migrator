// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../dashboard/lib/main.dart';

void main() {
  testWidgets('dashboard exposes Mermaid graph and governance views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const ArchitectureIntelligencePlatform());

    expect(find.text('Overview'), findsAtLeastNWidgets(1));
    expect(find.text('Dependency Graph'), findsOneWidget);

    await tester.tap(find.text('Dependency Graph'));
    await tester.pumpAndSettle();

    expect(find.text('Mermaid Relationship Diagram'), findsOneWidget);
    expect(find.byKey(const Key('mermaid-diagram')), findsOneWidget);

    await tester.tap(find.text('Governance'));
    await tester.pumpAndSettle();

    expect(find.text('Governance Contracts'), findsOneWidget);
    expect(find.text('Forbidden Imports'), findsOneWidget);
  });
}
