import 'dart:convert';
import 'dart:io';

import 'package:flutter_state_migrator/migrator/analysis/architecture_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/governance_engine.dart';
import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/analysis/ide_intelligence.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdeIntelligenceEngine', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('ide_intelligence_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('builds diagnostics with source ranges and quick fixes', () {
      final file = File('${tmpDir.path}/counter.dart')
        ..writeAsStringSync('''
class CounterController {
  Future<void> load() async {
    await Future<void>.value();
  }
}
''');

      final node = LogicUnitNode(
        name: 'CounterController',
        stateFields: const [],
        methods: [
          MethodInfo(
            name: 'load',
            callsNotifyListeners: false,
            bodySnippet: '{ await Future<void>.value(); }',
            isAsync: true,
          ),
          MethodInfo(
            name: 'loadAgain',
            callsNotifyListeners: false,
            bodySnippet: '{ await Future<void>.value(); }',
            isAsync: true,
          ),
          MethodInfo(
            name: 'loadThird',
            callsNotifyListeners: false,
            bodySnippet: '{ await Future<void>.value(); }',
            isAsync: true,
          ),
          MethodInfo(
            name: 'loadFourth',
            callsNotifyListeners: false,
            bodySnippet: '{ await Future<void>.value(); }',
            isAsync: true,
          ),
        ],
        isNotifier: true,
        filePath: file.path,
        offset: 0,
        length: file.readAsStringSync().length,
      );

      final graph = GraphBuilder().buildGraph([node]);
      final smells = ArchitectureIntelligenceEngine(graph).analyze();
      final report = IdeIntelligenceEngine(
        tmpDir.path,
      ).buildReport(graph: graph, smells: smells, violations: const []);

      expect(report.totalDiagnostics, greaterThan(0));
      expect(report.diagnostics.first.filePath, file.path);
      expect(report.diagnostics.first.startLine, 1);
      expect(report.diagnostics.first.quickFixes, isNotEmpty);
      expect(
        report.diagnostics.first.quickFixes.any(
          (fix) => fix.command == 'flutter-migrator.showRecommendation',
        ),
        isTrue,
      );
    });

    test('serializes governance findings as IDE JSON payload', () {
      final fileA = File('${tmpDir.path}/view.dart')
        ..writeAsStringSync('class MyView {}');
      final fileB = File('${tmpDir.path}/data.dart')
        ..writeAsStringSync('class MyData {}');

      final graph = GraphBuilder().buildGraph([
        LogicUnitNode(
          name: 'MyView',
          role: 'presentation',
          stateFields: const [],
          methods: const [],
          isNotifier: false,
          filePath: fileA.path,
          offset: 0,
          length: fileA.readAsStringSync().length,
        ),
        LogicUnitNode(
          name: 'MyData',
          role: 'data',
          stateFields: const [],
          methods: const [],
          isNotifier: false,
          filePath: fileB.path,
          offset: 0,
          length: fileB.readAsStringSync().length,
        ),
        ProviderOfNode(
          consumedClass: 'MyData',
          filePath: fileA.path,
          offset: 0,
          length: 5,
        ),
      ]);

      final violations = GovernanceEngine(graph, {
        'forbidden_imports': ['presentation -> data'],
      }).validate();
      final report = IdeIntelligenceEngine(
        tmpDir.path,
      ).buildReport(graph: graph, smells: const [], violations: violations);

      final jsonMap =
          jsonDecode(jsonEncode(report.toJson())) as Map<String, dynamic>;
      final diagnostics = jsonMap['diagnostics'] as List<dynamic>;

      expect(jsonMap['summary']['governanceDiagnosticCount'], 1);
      expect(diagnostics.single['category'], 'governance');
      expect(diagnostics.single['quickFixes'], isNotEmpty);
    });
  });
}
