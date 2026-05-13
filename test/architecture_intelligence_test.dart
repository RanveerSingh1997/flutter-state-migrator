import 'package:flutter_state_migrator/migrator/analysis/architecture_intelligence.dart';
import 'package:flutter_state_migrator/migrator/analysis/governance_engine.dart';
import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:test/test.dart';

void main() {
  group('Architecture Intelligence & Governance Tests', () {
    final builder = GraphBuilder();

    test('Detects God Component smell', () {
      final godNode = LogicUnitNode(
        name: 'GodController',
        stateFields: List.generate(5, (i) => FieldInfo(rawName: 'f$i')),
        methods: List.generate(
          20,
          (i) => MethodInfo(
            name: 'm$i',
            callsNotifyListeners: false,
            bodySnippet: '{}',
          ),
        ),
        isNotifier: true,
        filePath: 'god.dart',
        offset: 0,
        length: 100,
      );

      final graph = builder.buildGraph([godNode]);
      final engine = ArchitectureIntelligenceEngine(graph);
      final smells = engine.analyze();

      expect(smells.any((s) => s.name == 'God Component'), isTrue);
    });

    test('Detects Circular Dependency smell', () {
      final nodeA = LogicUnitNode(
        name: 'ServiceA',
        stateFields: [],
        methods: [],
        isNotifier: false,
        filePath: 'a.dart',
        offset: 0,
        length: 50,
      );
      final nodeB = LogicUnitNode(
        name: 'ServiceB',
        stateFields: [],
        methods: [],
        isNotifier: false,
        filePath: 'b.dart',
        offset: 0,
        length: 50,
      );

      // Edge A -> B
      final callB = ProviderOfNode(
        consumedClass: 'ServiceB',
        filePath: 'a.dart',
        offset: 10,
        length: 10,
      );
      // Edge B -> A
      final callA = ProviderOfNode(
        consumedClass: 'ServiceA',
        filePath: 'b.dart',
        offset: 10,
        length: 10,
      );

      final graph = builder.buildGraph([nodeA, nodeB, callB, callA]);
      final engine = ArchitectureIntelligenceEngine(graph);
      final smells = engine.analyze();

      expect(smells.any((s) => s.name == 'Circular Dependency'), isTrue);
    });

    test('GovernanceEngine detects forbidden dependencies', () {
      final presentationNode = LogicUnitNode(
        name: 'MyView',
        role: 'presentation',
        stateFields: [],
        methods: [],
        isNotifier: false,
        filePath: 'view.dart',
        offset: 0,
        length: 50,
      );
      final dataNode = LogicUnitNode(
        name: 'MyData',
        role: 'data',
        stateFields: [],
        methods: [],
        isNotifier: false,
        filePath: 'data.dart',
        offset: 0,
        length: 50,
      );

      final presentationToData = ProviderOfNode(
        consumedClass: 'MyData',
        filePath: 'view.dart',
        offset: 10,
        length: 10,
      );

      final graph = builder.buildGraph([
        presentationNode,
        dataNode,
        presentationToData,
      ]);
      final gov = GovernanceEngine(graph, {
        'forbidden_imports': ['presentation -> data'],
      });

      final violations = gov.validate();
      expect(violations, isNotEmpty);
      expect(violations.first.ruleName, 'Forbidden Dependency');
    });
  });
}
