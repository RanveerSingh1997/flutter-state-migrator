import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transformer = RiverpodTransformer();

  group('RiverpodTransformer - Provider.of / context.read', () {
    test('Transforms Provider.of to ref.watch', () {
      const source = 'Provider.of<Counter>(context)';
      final node = ProviderOfNode(
        consumedClass: 'Counter',
        isInBuildMethod: true,
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.length, 1);
      expect(edits.first.replacement, 'ref.watch(counterProvider)');
    });

    test('Transforms Provider.of method call to notifier read', () {
      const source = 'Provider.of<Counter>(context).increment()';
      final node = ProviderOfNode(
        consumedClass: 'Counter',
        isInBuildMethod: true,
        isMethodCall: true,
        filePath: 'test.dart',
        offset: 0,
        length: 'Provider.of<Counter>(context)'.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.single.replacement, 'ref.read(counterProvider.notifier)');
    });

    test('Transforms context.read to ref.read', () {
      const source = 'context.read<Counter>()';
      final node = ProviderOfNode(
        consumedClass: 'Counter',
        isInBuildMethod: false,
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.single.replacement, 'ref.read(counterProvider)');
    });
  });

  group('RiverpodTransformer - Consumer / Selector (Structured)', () {
    test('Transforms Consumer with builder and child offsets', () {
      const builder = '(context, model, child) => Text(model.count.toString())';
      const child = 'const Icon(Icons.add)';
      const source = 'Consumer<Counter>(builder: $builder, child: $child)';

      final node = ConsumerNode(
        consumedClass: 'Counter',
        builderOffset: source.indexOf(builder),
        builderLength: builder.length,
        childOffset: source.indexOf(child),
        childLength: child.length,
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.length, 1);
      expect(edits.first.replacement, contains('ref.watch(counterProvider)'));
      expect(edits.first.replacement, contains('child: const Icon(Icons.add)'));
    });

    test('Transforms Selector using builder offsets', () {
      const selector = '(_, model) => model.count';
      const builder = '(context, count, child) => Text(count.toString())';
      const source =
          'Selector<Counter, int>(selector: $selector, builder: $builder)';

      final node = SelectorNode(
        consumedClass: 'Counter',
        selectedType: 'int',
        selectorSnippet: selector,
        builderOffset: source.indexOf(builder),
        builderLength: builder.length,
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.length, 1);
      expect(
        edits.first.replacement,
        contains('ref.watch(counterProvider.select((state) => state.count))'),
      );
    });
  });

  group('RiverpodTransformer - Logic Units', () {
    test('Generates Notifier from ChangeNotifier', () {
      const source = 'class Counter extends ChangeNotifier { int count = 0; }';
      final node = LogicUnitNode(
        name: 'Counter',
        stateFields: [
          FieldInfo(rawName: 'count', type: 'int', initializer: '0'),
        ],
        methods: [],
        isNotifier: true,
        filePath: 'counter.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(
        edits.any(
          (e) => e.replacement.contains('class Counter extends _\$Counter'),
        ),
        true,
      );
      expect(
        edits.any(
          (e) => e.replacement.contains(
            'import "package:riverpod_annotation/riverpod_annotation.dart";',
          ),
        ),
        true,
      );
    });

    test('AsyncNotifier build() uses real method body and concrete return type',
        () {
      const source = 'class UserRepo extends ChangeNotifier {}';
      final node = LogicUnitNode(
        name: 'UserRepo',
        stateFields: [],
        methods: [
          MethodInfo(
            name: 'loadUsers',
            callsNotifyListeners: false,
            bodySnippet: 'async { return await api.getUsers(); }',
            isAsync: true,
            returnType: 'Future<List<User>>',
          ),
        ],
        isNotifier: true,
        notifierType: NotifierType.asyncNotifier,
        filePath: 'user_repo.dart',
        offset: 0,
        length: source.length,
      );

      final t2 = RiverpodTransformer();
      final edits = t2.transformNode(node, source);
      // The last edit is always the class body replacement; the first is the file header.
      final classEdit = edits.last;

      expect(classEdit.replacement, contains('Future<List<User>>'));
      expect(classEdit.replacement, contains('build() async {'));
      expect(classEdit.replacement, contains('return await api.getUsers();'));
      expect(classEdit.replacement, isNot(contains('TODO: Return initial async state')));
    });

    test('StreamNotifier build() uses real stream method body and type', () {
      const source = 'class TickerService extends ChangeNotifier {}';
      final node = LogicUnitNode(
        name: 'TickerService',
        stateFields: [],
        methods: [
          MethodInfo(
            name: 'tick',
            callsNotifyListeners: false,
            bodySnippet: '{ return Stream.periodic(Duration(seconds: 1)); }',
            isAsync: false,
            returnType: 'Stream<int>',
          ),
        ],
        isNotifier: true,
        notifierType: NotifierType.streamNotifier,
        filePath: 'ticker.dart',
        offset: 0,
        length: source.length,
      );

      final t2 = RiverpodTransformer();
      final edits = t2.transformNode(node, source);
      final classEdit = edits.last;

      expect(classEdit.replacement, contains('Stream<int>'));
      expect(classEdit.replacement, contains('Stream.periodic'));
      expect(classEdit.replacement, isNot(contains('TODO: Return stream')));
    });
  });
}
