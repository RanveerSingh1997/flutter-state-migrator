import 'dart:convert';

import 'package:flutter_state_migrator/migrator/analysis/ai_manager.dart';
import 'package:flutter_state_migrator/migrator/analysis/architecture_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/governance_engine.dart';
import 'package:flutter_state_migrator/migrator/models/graph_models.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AIManager', () {
    test('uses local LLM responses for method refactoring guidance', () async {
      final manager = AIManager(
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://localhost:11434/api/generate');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['model'], 'llama3.1');
          expect(payload['prompt'], contains('CounterController'));
          return http.Response(jsonEncode({
            'response': 'state = state.copyWith(count: state.count + delta);',
          }), 200);
        }),
      );

      final guidance = await manager.refactorMethodBody(
        className: 'CounterController',
        stateFields: const ['_count'],
        methodName: 'increment',
        methodBody: '{ _count += delta; notifyListeners(); }',
      );

      expect(guidance.source, AiGuidanceSource.localLlm);
      expect(guidance.recommendation, contains('state.copyWith'));
      expect(guidance.fallbackReason, isNull);
      expect(guidance.prompt, contains('Tracked state fields: _count'));
    });

    test('falls back deterministically when local LLM is unavailable', () async {
      final manager = AIManager(
        client: MockClient(
          (_) async => http.Response('service unavailable', 503),
        ),
      );

      final guidance = await manager.refactorMethodBody(
        className: 'CounterController',
        stateFields: const ['_count'],
        methodName: 'increment',
        methodBody: '{ _count += 1; notifyListeners(); }',
      );

      expect(guidance.source, AiGuidanceSource.deterministicFallback);
      expect(guidance.recommendation, contains('state = state.copyWith'));
      expect(guidance.fallbackReason, contains('status 503'));
    });

    test('builds architecture guidance from smells and governance violations', () async {
      final graph = ArchitectureGraph();
      final node = LogicUnitNode(
        name: 'DashboardController',
        role: 'presentation',
        stateFields: const [],
        methods: const [],
        isNotifier: true,
        filePath: 'lib/dashboard.dart',
        offset: 0,
        length: 10,
      );
      graph.nodes['logic:DashboardController'] = node;

      final manager = AIManager(
        client: MockClient(
          (_) async => http.Response('not ready', 500),
        ),
      );

      final guidance = await manager.buildArchitectureGuidance(
        graph: graph,
        smells: [
          ArchitectureSmell(
            nodeId: 'logic:DashboardController',
            name: 'High Coupling',
            description: 'Class DashboardController depends on 9 other components.',
          ),
        ],
        violations: [
          GovernanceViolation(
            nodeId: 'logic:DashboardController',
            ruleName: 'Forbidden Dependency',
            message: 'Architecture violation: Layer "presentation" is not allowed to depend on "data".',
          ),
        ],
      );

      expect(guidance, hasLength(2));
      expect(guidance[0].title, contains('High Coupling'));
      expect(guidance[0].recommendation, contains('Reduce direct dependencies'));
      expect(guidance[1].title, contains('Forbidden Dependency'));
      expect(guidance[1].fallbackReason, contains('status 500'));
    });
  });
}
