import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_state_migrator/migrator/analysis/body_transformer.dart';
import 'package:flutter_state_migrator/migrator/analysis/dependency_checker.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_generator.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';

void main() {
  group('Phase 28 dependency graph', () {
    test('detects circular logic-unit dependencies', () {
      final warnings = DependencyChecker().checkCircularDependencies([
        LogicUnitNode(
          name: 'CounterModel',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          filePath: 'lib/counter.dart',
          offset: 0,
          length: 10,
        ),
        LogicUnitNode(
          name: 'SessionModel',
          stateFields: const [],
          methods: const [],
          isNotifier: true,
          filePath: 'lib/session.dart',
          offset: 0,
          length: 10,
        ),
        ProviderOfNode(
          consumedClass: 'SessionModel',
          filePath: 'lib/counter.dart',
          offset: 0,
          length: 1,
        ),
        ProviderOfNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/session.dart',
          offset: 0,
          length: 1,
        ),
      ]);

      expect(warnings, hasLength(1));
      expect(
        warnings.single,
        contains('CounterModel → SessionModel → CounterModel'),
      );
    });
  });

  group('Phase 29 body transformer', () {
    test('rewrites list mutation and merges multi-step state updates', () {
      final result = BodyTransformer().transformBody(
        '''
{
  _items.add(todo);
  _count++;
  _label = _label ?? fallback;
}
''',
        const [
          FieldInfo(
            rawName: '_items',
            type: 'List<Todo>',
            initializer: 'const []',
          ),
          FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
          FieldInfo(rawName: '_label', type: 'String?', initializer: 'null'),
        ],
      );

      expect(
        result,
        contains(
          'state = state.copyWith(items: [...state.items, todo], count: state.count + 1, label: state.label ?? fallback);',
        ),
      );
    });
  });

  group('Phase 30 code-gen output', () {
    test('generator emits @riverpod code with build runner instructions', () {
      final output = RiverpodGenerator().generateSuggestion(
        LogicUnitNode(
          name: 'CounterModel',
          stateFields: const [
            FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
          ],
          methods: [
            MethodInfo(
              name: 'count',
              callsNotifyListeners: false,
              bodySnippet: '=> _count',
              isGetter: true,
            ),
            MethodInfo(
              name: 'rename',
              callsNotifyListeners: false,
              bodySnippet: '{ _count = value; notifyListeners(); }',
              parameters: [ParamInfo(name: 'value', type: 'int')],
            ),
          ],
          isNotifier: true,
          filePath: 'lib/counter_model.dart',
          offset: 0,
          length: 10,
        ),
      );

      expect(
        output,
        contains(
          'import "package:riverpod_annotation/riverpod_annotation.dart";',
        ),
      );
      expect(output, contains('part "counter_model.g.dart";'));
      expect(
        output,
        contains('dart run build_runner build --delete-conflicting-outputs'),
      );
      expect(output, contains('@riverpod'));
      expect(output, contains('class CounterModel extends _\$CounterModel'));
      expect(output, contains('int build() {'));
      expect(output, contains('return 0;'));
      expect(output, contains('void rename(int value)'));
      expect(output, isNot(contains('count()')));
    });

    test('transformer emits generated-header once and uses notifier reads', () {
      final transformer = RiverpodTransformer();
      const source = '''
class CounterModel extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment(int delta) {
    _count += delta;
    notifyListeners();
  }
}
''';

      final node = LogicUnitNode(
        name: 'CounterModel',
        stateFields: const [
          FieldInfo(rawName: '_count', type: 'int', initializer: '0'),
        ],
        methods: [
          MethodInfo(
            name: 'count',
            callsNotifyListeners: false,
            bodySnippet: '=> _count',
            isGetter: true,
          ),
          MethodInfo(
            name: 'increment',
            callsNotifyListeners: true,
            bodySnippet: '{ _count += delta; notifyListeners(); }',
            parameters: [ParamInfo(name: 'delta', type: 'int')],
          ),
        ],
        isNotifier: true,
        filePath: 'lib/counter_model.dart',
        offset: 0,
        length: source.length,
      );

      final logicEdits = transformer.transformNode(node, source);
      expect(logicEdits, hasLength(1));
      expect(
        logicEdits.single.replacement,
        contains(
          'import "package:riverpod_annotation/riverpod_annotation.dart";',
        ),
      );
      expect(
        'import "package:riverpod_annotation/riverpod_annotation.dart";'
            .allMatches(logicEdits.single.replacement)
            .length,
        1,
      );
      expect(
        logicEdits.single.replacement,
        contains('part "counter_model.g.dart";'),
      );
      expect(logicEdits.single.replacement, contains('return 0;'));
      expect(
        logicEdits.single.replacement,
        contains('void increment(int delta)'),
      );
      expect(
        logicEdits.single.replacement,
        contains('state = state.copyWith(count: state.count + delta);'),
      );

      final providerRead = transformer.transformNode(
        ProviderOfNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/counter_model.dart',
          offset: 0,
          length: 'Provider.of<CounterModel>(context, listen: false)'.length,
        ),
        'Provider.of<CounterModel>(context, listen: false)',
      );
      expect(providerRead.single.replacement, 'ref.read(counterModelProvider)');
    });

    test('consumer and selector expression builders become valid block builders', () {
      final transformer = RiverpodTransformer();

      const consumerSource =
          "Consumer<CounterModel>(builder: (context, counter, child) => Text('\${counter.count}'))";
      final consumerEdits = transformer.transformNode(
        ConsumerNode(
          consumedClass: 'CounterModel',
          filePath: 'lib/main.dart',
          offset: 0,
          length: consumerSource.length,
        ),
        consumerSource,
      );
      expect(
        consumerEdits.any(
          (edit) =>
              edit.replacement.contains(
                'final counter = ref.watch(counterModelProvider);',
              ) &&
              edit.replacement.contains("return Text('\${counter.count}')"),
        ),
        isTrue,
      );

      const selectorSource =
          "Selector<CounterModel, int>(selector: (_, model) => model.count, builder: (context, count, child) => Text('\$count'))";
      final selectorEdits = transformer.transformNode(
        SelectorNode(
          consumedClass: 'CounterModel',
          selectedType: 'int',
          selectorSnippet: '(_, model) => model.count',
          filePath: 'lib/main.dart',
          offset: 0,
          length: selectorSource.length,
        ),
        selectorSource,
      );
      expect(
        selectorEdits.any(
          (edit) => edit.replacement.contains(
            'final count = ref.watch(counterModelProvider.select((state) => state.count));',
          ),
        ),
        isTrue,
      );
      expect(
        selectorEdits.any(
          (edit) => edit.replacement.contains("return Text('\$count')"),
        ),
        isTrue,
      );
    });
  });
}
