import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';

void main() {
  final transformer = RiverpodTransformer();

  group('RiverpodTransformer Tests', () {
    test('Transforms Provider.of to ref.watch', () {
      const source = 'Provider.of<Counter>(context)';
      final node = ProviderOfNode(
        consumedClass: 'Counter',
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.length, 1);
      expect(edits.first.replacement, 'ref.watch(counterProvider)');
    });

    test('Transforms Selector to Consumer', () {
      const source = '''
Selector<MyModel, int>(
  selector: (_, model) => model.count,
  builder: (context, count, child) => Text('\$count'),
)''';
      final node = SelectorNode(
        consumedClass: 'MyModel',
        selectedType: 'int',
        selectorSnippet: '(_, model) => model.count',
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      // Should have: Replace Selector with Consumer, Remove selector arg, Replace builder signature
      expect(edits.any((e) => e.replacement == 'Consumer'), true);
      expect(edits.any((e) => e.replacement.contains('ref.watch(mymodelProvider.select')), true);
    });

    test('Unwraps MultiProvider', () {
      const childSource = 'Container()';
      const source = 'MultiProvider(providers: [], child: $childSource)';
      final node = MultiProviderNode(
        childOffset: source.indexOf(childSource),
        childLength: childSource.length,
        filePath: 'test.dart',
        offset: 0,
        length: source.length,
      );

      final edits = transformer.transformNode(node, source);
      expect(edits.length, 1);
      expect(edits.first.replacement, childSource);
    });
  });
}
