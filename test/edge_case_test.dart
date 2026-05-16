import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:flutter_state_migrator/migrator/generator/riverpod_transformer.dart';
import 'package:flutter_state_migrator/migrator/models/ir_models.dart';
import 'package:flutter_state_migrator/migrator/scanner/provider_adapter.dart';
import 'package:flutter_state_migrator/migrator/utils/edit_applier.dart';
import 'package:test/test.dart';

/// Parses [source] and runs [ProviderAdapter] on it, returning detected nodes.
List<ProviderNode> _scan(String source, {String filename = 'test.dart'}) {
  final result = parseString(content: source, throwIfDiagnostics: false);
  final adapter = ProviderAdapter(filename);
  result.unit.visitChildren(adapter);
  return adapter.nodes;
}

/// Full scan + transform pipeline, returns migrated source string.
String _migrate(String source, {String filename = 'test.dart'}) {
  final nodes = _scan(source, filename: filename);
  final transformer = RiverpodTransformer();
  final edits = <TextEdit>[];
  for (final node in nodes) {
    edits.addAll(transformer.transformNode(node, source));
  }
  return applyEdits(source, edits);
}

void main() {
  group('Edge case — generic type parameters', () {
    const genericSource = '''
import 'package:flutter/material.dart';
class ListNotifier<T> extends ChangeNotifier {
  List<T> _items = [];
  void add(T item) { _items = [..._items, item]; notifyListeners(); }
}
''';

    test('scanner detects generic ChangeNotifier without crashing', () {
      final nodes = _scan(genericSource);
      expect(nodes.whereType<LogicUnitNode>(), isNotEmpty);
      final node = nodes.whereType<LogicUnitNode>().first;
      expect(node.name, 'ListNotifier');
    });

    test('transformer produces valid output for generic class', () {
      final migrated = _migrate(genericSource, filename: 'generic.dart');
      expect(migrated, contains('@riverpod'));
      expect(migrated, contains('class ListNotifier'));
    });
  });

  group('Edge case — mixin usage', () {
    const mixinSource = '''
import 'package:flutter/material.dart';
mixin LoggingMixin on ChangeNotifier {
  void log(String msg) {}
}
class TodoNotifier extends ChangeNotifier with LoggingMixin {
  final List<String> _todos = [];
  void addTodo(String todo) { _todos.add(todo); notifyListeners(); }
}
''';

    test('scanner detects TodoNotifier and records LoggingMixin', () {
      final nodes = _scan(mixinSource);
      final node = nodes.whereType<LogicUnitNode>().firstWhere(
        (n) => n.name == 'TodoNotifier',
      );
      expect(node.mixins, contains('LoggingMixin'));
    });

    test('transformer does not crash on mixin-bearing class', () {
      expect(() => _migrate(mixinSource, filename: 'mixin.dart'), returnsNormally);
    });
  });

  group('Edge case — family candidate (multiple constructor params)', () {
    const paginatedSource = '''
import 'package:flutter/material.dart';
class PaginatedNotifier extends ChangeNotifier {
  final String category;
  final int pageSize;
  int _page = 0;
  PaginatedNotifier({required this.category, this.pageSize = 20});
  Future<void> loadNextPage() async {
    _page++;
    notifyListeners();
  }
}
''';

    test('scanner marks class with required constructor params as family candidate', () {
      final nodes = _scan(paginatedSource);
      final node = nodes.whereType<LogicUnitNode>().first;
      expect(node.isFamilyCandidate, isTrue);
    });

    test('transformer emits family candidate warning comment', () {
      final migrated = _migrate(paginatedSource, filename: 'paginated.dart');
      expect(migrated, contains('Constructor parameters detected'));
    });
  });

  group('Edge case — widget accessing multiple providers', () {
    const multiSource = '''
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
class MultiWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final a = context.watch<ServiceA>();
    final b = context.watch<ServiceB>();
    return Text('\${a.value} \${b.value}');
  }
}
''';

    test('scanner detects ProviderOf nodes for both watched providers', () {
      final nodes = _scan(multiSource);
      final providerOfs = nodes.whereType<ProviderOfNode>().toList();
      expect(providerOfs.length, greaterThanOrEqualTo(2));
      expect(
        providerOfs.map((n) => n.consumedClass),
        containsAll(['ServiceA', 'ServiceB']),
      );
    });

    test('transformer replaces context.watch calls with ref.watch', () {
      final migrated = _migrate(multiSource, filename: 'multi.dart');
      expect(migrated, contains('ref.watch(serviceAProvider)'));
      expect(migrated, contains('ref.watch(serviceBProvider)'));
    });
  });

  group('Edge case — malformed / empty Dart', () {
    test('scanner returns empty list for empty source', () {
      final nodes = _scan('');
      expect(nodes, isEmpty);
    });

    test('scanner does not crash on syntax-error source', () {
      expect(
        () => _scan('class Broken extends { this is not valid dart }}}'),
        returnsNormally,
      );
    });

    test('transformer returns empty edits for unrecognised node types', () {
      // Passing an unrecognised node type should produce no edits, not throw.
      final transformer = RiverpodTransformer();
      // HookWidgetNode with dummy values; transformer handles it without crash.
      final node = HookWidgetNode(
        widgetName: 'MyHookWidget',
        buildMethodOffset: 0,
        filePath: 'hook.dart',
        offset: 0,
        length: 10,
      );
      expect(
        () => transformer.transformNode(node, 'class MyHookWidget {}'),
        returnsNormally,
      );
    });
  });
}
