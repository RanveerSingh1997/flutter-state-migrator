import 'package:flutter_test/flutter_test.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_state_migrator/migrator/scanner/provider_adapter.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';

void main() {
  group('ProviderAdapter Tests', () {
    test('Detects ChangeNotifier class', () {
      const source = '''
class MyModel extends ChangeNotifier {
  int count = 0;
  void increment() {
    count++;
    notifyListeners();
  }
}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.length, 1);
      expect(adapter.nodes.first, isA<LogicUnitNode>());
      final node = adapter.nodes.first as LogicUnitNode;
      expect(node.name, 'MyModel');
      expect(node.isNotifier, true);
    });

    test('Detects MultiProvider with child', () {
      const source = '''
final widget = MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => MyModel()),
  ],
  child: Container(),
);
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      // MultiProvider node + ChangeNotifierProvider node
      expect(adapter.nodes.any((n) => n is MultiProviderNode), true);
      final multiNode =
          adapter.nodes.firstWhere((n) => n is MultiProviderNode)
              as MultiProviderNode;
      expect(multiNode.childOffset, isNotNull);
    });

    test('Detects Selector with correct types', () {
      const source = '''
final s = Selector<MyModel, int>(
  selector: (_, model) => model.count,
  builder: (context, count, child) => Text('\$count'),
);
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is SelectorNode), true);
      final selectorNode =
          adapter.nodes.firstWhere((n) => n is SelectorNode) as SelectorNode;
      expect(selectorNode.consumedClass, 'MyModel');
      expect(selectorNode.selectedType, 'int');
      expect(selectorNode.selectorSnippet, '(_, model) => model.count');
    });
  });
}
