import 'package:flutter_test/flutter_test.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_state_migrator/migrator/scanner/provider_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/bloc_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/getx_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/mobx_adapter.dart';
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
      expect(node.stateFields.single.type, 'int');
      expect(node.stateFields.single.initializer, '0');
      expect(node.methods.single.parameters, isEmpty);
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

    test('Captures getter and method params for ChangeNotifier', () {
      const source = '''
class SessionModel extends ChangeNotifier {
  String _name = '';
  String get name => _name;
  Future<void> login(String value, {bool remember = false}) async {
    _name = value;
    notifyListeners();
  }
}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      final node = adapter.nodes.first as LogicUnitNode;
      expect(node.stateFields.single.type, 'String');
      expect(node.stateFields.single.initializer, "''");
      expect(node.methods.firstWhere((m) => m.isGetter).name, 'name');
      final login = node.methods.firstWhere((m) => m.name == 'login');
      expect(login.isAsync, true);
      expect(login.parameters.map((p) => p.name), ['value', 'remember']);
    });

    test('Distinguishes reactive reads from callback reads inside build', () {
      const source = '''
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
}

class CounterView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = Provider.of<CounterModel>(context).count;
    return IconButton(
      onPressed: () => Provider.of<CounterModel>(context).increment(),
      icon: Text('\$count'),
    );
  }
}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      final reads = adapter.nodes.whereType<ProviderOfNode>().toList();
      expect(reads, hasLength(2));
      expect(reads.where((node) => node.isInBuildMethod), hasLength(1));
      expect(reads.where((node) => !node.isInBuildMethod), hasLength(1));
    });
  });

  group('Other scanner adapters', () {
    test('BlocAdapter preserves state type and method params', () {
      const source = '''
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  int get current => state;
  void incrementBy(int delta) => emit(state + delta);
}
''';
      final result = parseString(content: source);
      final adapter = BlocAdapter('test.dart');
      result.unit.accept(adapter);

      final node = adapter.nodes.single as LogicUnitNode;
      expect(node.stateFields.single.type, 'int');
      expect(node.methods.firstWhere((m) => m.isGetter).name, 'current');
      expect(
        node.methods.firstWhere((m) => m.name == 'incrementBy').paramSource,
        'int delta',
      );
    });

    test('GetXAdapter normalizes observable fields and params', () {
      const source = '''
class CounterController extends GetxController {
  var count = 0.obs;
  RxString label = ''.obs;
  String get title => label.value;
  void rename(String value) {
    label.value = value;
  }
}
''';
      final result = parseString(content: source);
      final adapter = GetXAdapter('test.dart');
      result.unit.accept(adapter);

      final node =
          adapter.nodes.firstWhere((n) => n is LogicUnitNode) as LogicUnitNode;
      expect(node.stateFields[0].type, 'int');
      expect(node.stateFields[0].initializer, '0');
      expect(node.stateFields[1].type, 'String');
      expect(node.stateFields[1].initializer, "''");
      expect(node.methods.firstWhere((m) => m.isGetter).name, 'title');
      expect(
        node.methods.firstWhere((m) => m.name == 'rename').paramSource,
        'String value',
      );
    });

    test('MobXAdapter keeps observable field types and action params', () {
      const source = '''
class CounterStore {
  @observable
  int count = 0;

  @action
  Future<void> incrementBy(int delta) async {
    count += delta;
  }
}
''';
      final result = parseString(content: source);
      final adapter = MobXAdapter('test.dart');
      result.unit.accept(adapter);

      final node =
          adapter.nodes.firstWhere((n) => n is LogicUnitNode) as LogicUnitNode;
      expect(node.stateFields.single.type, 'int');
      expect(node.stateFields.single.initializer, '0');
      final method = node.methods.single;
      expect(method.name, 'incrementBy');
      expect(method.isAsync, true);
      expect(method.paramSource, 'int delta');
    });
  });
}
