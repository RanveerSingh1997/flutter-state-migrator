import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/bloc_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/getx_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/provider_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderAdapter Tests', () {
    test('Detects ChangeNotifier class and infers provider role', () {
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
      expect(node.role, 'provider'); // Standard for ChangeNotifier
      expect(node.superClassName, 'ChangeNotifier');
      expect(node.stateFields.single.type, 'int');
      expect(node.stateFields.single.initializer, '0');
    });

    test('Detects MultiProvider with child offsets', () {
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

      expect(adapter.nodes.any((n) => n is MultiProviderNode), true);
      final multiNode =
          adapter.nodes.firstWhere((n) => n is MultiProviderNode)
              as MultiProviderNode;
      expect(multiNode.childOffset, isNotNull);
    });

    test('Detects Selector and captures builder offsets', () {
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
      expect(selectorNode.builderOffset, isNotNull);
      expect(selectorNode.selectorSnippet, '(_, model) => model.count');
    });

    test('Identifies logic roles for Repository/Service suffixes', () {
      const source = '''
class UserRepository {}
class AuthService {}
class ApiClient {}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      final repository =
          adapter.nodes.firstWhere(
                (n) => n is LogicUnitNode && n.name == 'UserRepository',
              )
              as LogicUnitNode;
      final service =
          adapter.nodes.firstWhere(
                (n) => n is LogicUnitNode && n.name == 'AuthService',
              )
              as LogicUnitNode;

      expect(repository.role, 'repository');
      expect(service.role, 'service');
    });
  });

  group('Framework Adapters', () {
    test('BlocAdapter detects Cubit and captures state type', () {
      const source = '''
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}
''';
      final result = parseString(content: source);
      final adapter = BlocAdapter('test.dart');
      result.unit.accept(adapter);

      final node = adapter.nodes.single as LogicUnitNode;
      expect(node.name, 'CounterCubit');
      expect(node.stateFields.single.type, 'int');
    });

    test('GetXAdapter detects controller put and usage', () {
      const source = '''
void main() {
  final c = Get.put(MyController());
  Get.find<MyController>().increment();
}
''';
      final result = parseString(content: source);
      final adapter = GetXAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is ProviderDeclarationNode), true);
      expect(adapter.nodes.any((n) => n is ProviderOfNode), true);
      final usage =
          adapter.nodes.firstWhere((n) => n is ProviderOfNode)
              as ProviderOfNode;
      expect(usage.isMethodCall, true);
    });
  });
}
