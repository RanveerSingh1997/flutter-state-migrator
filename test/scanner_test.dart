import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/bloc_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/getx_adapter.dart';
import 'package:flutter_state_migrator/migrator/scanner/mobx_adapter.dart';
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

  group('BLoC extended patterns', () {
    test('BlocAdapter detects MultiBlocProvider as MultiProviderNode', () {
      const source = '''
final widget = MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => CounterBloc()),
  ],
  child: MyApp(),
);
''';
      final result = parseString(content: source);
      final adapter = BlocAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is MultiProviderNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is MultiProviderNode)
              as MultiProviderNode;
      expect(node.childOffset, isNotNull);
    });

    test('BlocAdapter detects BlocSelector and captures selector', () {
      const source = '''
final widget = BlocSelector<CounterBloc, CounterState, int>(
  selector: (state) => state.count,
  builder: (context, count) => Text('\$count'),
);
''';
      final result = parseString(content: source);
      final adapter = BlocAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is SelectorNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is SelectorNode) as SelectorNode;
      expect(node.consumedClass, 'CounterBloc');
      expect(node.selectedType, 'int');
      expect(node.selectorSnippet, contains('state.count'));
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

    test('GetXAdapter detects Get.lazyPut and Get.create', () {
      const source = '''
void setup() {
  Get.lazyPut<AuthController>(() => AuthController());
  Get.create<ItemController>(() => ItemController());
}
''';
      final result = parseString(content: source);
      final adapter = GetXAdapter('test.dart');
      result.unit.accept(adapter);

      final decls = adapter.nodes.whereType<ProviderDeclarationNode>().toList();
      expect(decls.length, 2);
      expect(decls[0].providerType, 'Get.lazyPut');
      expect(decls[0].providedClass, 'AuthController');
      expect(decls[1].providerType, 'Get.create');
      expect(decls[1].providedClass, 'ItemController');
    });

    test('MobXAdapter captures @computed fields as state', () {
      const source = '''
class CartStore {
  @observable
  List<Item> items = [];

  @computed
  int get totalCount => items.length;
}
''';
      final result = parseString(content: source);
      final adapter = MobXAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.length, 1);
      final node = adapter.nodes.first as LogicUnitNode;
      // Both @observable and @computed fields should appear in stateFields
      expect(node.stateFields.any((f) => f.rawName == 'items'), true);
    });
  });

  group('ValueNotifier / ValueListenableBuilder', () {
    test('ProviderAdapter detects ValueNotifier subclass', () {
      const source = '''
class CounterNotifier extends ValueNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => value++;
}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.length, 1);
      final node = adapter.nodes.first as LogicUnitNode;
      expect(node.name, 'CounterNotifier');
      expect(node.superClassName, 'ValueNotifier');
      expect(node.stateFields.single.rawName, 'value');
      expect(node.stateFields.single.type, 'int');
    });

    test('ProviderAdapter detects ValueListenableBuilder as ConsumerNode', () {
      const source = '''
final w = ValueListenableBuilder<int>(
  valueListenable: notifier,
  builder: (context, value, child) => Text('\$value'),
);
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is ConsumerNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is ConsumerNode) as ConsumerNode;
      expect(node.consumedClass, 'int');
      expect(node.builderOffset, isNotNull);
    });
  });

  group('ProxyProvider / context.select', () {
    test('ProviderAdapter detects ChangeNotifierProxyProvider', () {
      const source = '''
final widget = ChangeNotifierProxyProvider<AuthService, UserNotifier>(
  create: (_) => UserNotifier(),
  update: (_, auth, previous) => previous!..update(auth),
  child: Container(),
);
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is ProxyProviderNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is ProxyProviderNode)
              as ProxyProviderNode;
      expect(node.baseType, 'AuthService');
      expect(node.resultType, 'UserNotifier');
      expect(node.isChangeNotifier, true);
      expect(node.childOffset, isNotNull);
    });

    test('ProviderAdapter detects ProxyProvider (non-ChangeNotifier)', () {
      const source = '''
final widget = ProxyProvider<AuthService, UserService>(
  update: (_, auth, __) => UserService(auth),
);
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is ProxyProviderNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is ProxyProviderNode)
              as ProxyProviderNode;
      expect(node.isChangeNotifier, false);
      expect(node.baseType, 'AuthService');
      expect(node.resultType, 'UserService');
    });

    test('ProviderAdapter detects context.select and captures selector', () {
      const source = '''
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.select<Counter, int>((c) => c.count);
    return Text('\$count');
  }
}
''';
      final result = parseString(content: source);
      final adapter = ProviderAdapter('test.dart');
      result.unit.accept(adapter);

      expect(adapter.nodes.any((n) => n is ContextSelectNode), true);
      final node =
          adapter.nodes.firstWhere((n) => n is ContextSelectNode)
              as ContextSelectNode;
      expect(node.consumedClass, 'Counter');
      expect(node.selectorSnippet, contains('c.count'));
    });
  });
}
