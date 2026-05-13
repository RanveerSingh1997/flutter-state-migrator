import 'package:flutter_state_migrator/migrator/analysis/graph_builder.dart';
import 'package:flutter_state_migrator/migrator/models/graph_models.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GraphBuilder attributes provider usage to the owning logic unit', () {
    final graph = GraphBuilder().buildGraph([
      LogicUnitNode(
        name: 'CounterModel',
        stateFields: const [],
        methods: const [],
        isNotifier: true,
        filePath: 'lib/counter.dart',
        offset: 0,
        length: 200,
      ),
      ProviderOfNode(
        consumedClass: 'SessionModel',
        filePath: 'lib/counter.dart',
        offset: 120,
        length: 20,
      ),
      LogicUnitNode(
        name: 'SessionModel',
        stateFields: const [],
        methods: const [],
        isNotifier: true,
        filePath: 'lib/session.dart',
        offset: 0,
        length: 200,
      ),
    ]);

    expect(
      graph.edges.any(
        (edge) =>
            edge.fromId == 'logic:CounterModel' &&
            edge.toId == 'logic:SessionModel' &&
            edge.type == RelationshipType.reads,
      ),
      isTrue,
    );
  });
}
