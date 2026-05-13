import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/analysis/visualizer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderVisualizer', () {
    test('generates Mermaid output with typed nodes and labeled edges', () {
      final graph = GraphBuilder().buildGraph([
        LogicUnitNode(
          name: 'CounterModel',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          role: 'provider',
          filePath: 'lib/counter.dart',
          offset: 0,
          length: 200,
        ),
        WidgetNode(
          widgetName: 'CounterPage',
          widgetType: 'StatelessWidget',
          buildMethodOffset: 20,
          filePath: 'lib/counter.dart',
          offset: 201,
          length: 200,
        ),
        ProviderOfNode(
          consumedClass: 'CounterModel',
          isInBuildMethod: true,
          filePath: 'lib/counter.dart',
          offset: 260,
          length: 20,
        ),
      ]);

      final visualizer = ProviderVisualizer();
      final mermaid = visualizer.generateMermaid(graph);

      expect(mermaid, contains('graph TD'));
      expect(mermaid, contains('PROVIDER: CounterModel'));
      expect(mermaid, contains('WIDGET: CounterPage'));
      expect(mermaid, contains('WATCHES'));
      expect(mermaid, contains('classDef logic'));
      expect(mermaid, contains('classDef widget'));
    });

    test('creates summary snapshot with graph counts', () {
      final graph = GraphBuilder().buildGraph([
        LogicUnitNode(
          name: 'SessionController',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          filePath: 'lib/session.dart',
          offset: 0,
          length: 100,
        ),
      ]);

      final snapshot = ProviderVisualizer().createSnapshot(graph);

      expect(snapshot.nodeCount, 1);
      expect(snapshot.edgeCount, 0);
      expect(snapshot.logicUnitCount, 1);
      expect(snapshot.widgetCount, 0);
    });
  });
}
