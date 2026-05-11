import '../models/ir_models.dart';
import '../analysis/body_transformer.dart';
import '../utils/naming.dart';

class RiverpodGenerator {
  final _bodyTransformer = BodyTransformer();
  String generateSuggestion(ProviderNode node) {
    if (node is LogicUnitNode) {
      return _generateStateNotifier(node);
    } else if (node is ProviderDeclarationNode) {
      return _generateProviderDeclaration(node);
    } else if (node is ConsumerNode) {
      return _generateConsumerWidget(node);
    } else if (node is ProviderOfNode) {
      return _generateRefWatchRead(node);
    } else if (node is MultiProviderNode) {
      return _generateMultiProvider();
    } else if (node is SelectorNode) {
      return _generateSelectorWidget(node);
    } else if (node is AsyncProviderNode) {
      return _generateAsyncProvider(node);
    }
    return '';
  }

  String _generateAsyncProvider(AsyncProviderNode node) {
    final providerName =
        '${toLowerCamel(node.providedType)}${node.providerType}';
    return '''// 🔄 Suggestion: ${node.providerType} in Riverpod exposes an AsyncValue<${node.providedType}>.
// Define it globally:
final $providerName = ${node.providerType}<${node.providedType}>((ref) async {
  // return await fetchSomething();
});

// When consuming it in a ConsumerWidget:
// final asyncValue = ref.watch($providerName);
// return asyncValue.when(
//   data: (data) => Text(data.toString()),
//   loading: () => CircularProgressIndicator(),
//   error: (err, stack) => Text('Error: \$err'),
// );''';
  }

  String _generateMultiProvider() {
    return '''// 🔄 Suggestion: Replace MultiProvider with ProviderScope
// Riverpod providers are global, so you don't need to nest them in the widget tree.
// Just wrap your app in ProviderScope:
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}''';
  }

  String _generateSelectorWidget(SelectorNode node) {
    final providerName = providerNameForType(node.consumedClass);
    return '''// 🔄 Suggestion: Replace Selector with ref.watch and select()
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This will only rebuild when the selected value changes
    final selectedValue = ref.watch($providerName.select((state) => state.someProperty));
    return /* Your UI */;
  }
}''';
  }

  String _generateStateNotifier(LogicUnitNode node) {
    final buffer = StringBuffer();
    final fileName = node.filePath.split('/').last.replaceAll('.dart', '');
    final stateClassName = '${node.name}State';
    final buildReturnType = switch (node.notifierType) {
      NotifierType.asyncNotifier => 'Future<dynamic>',
      NotifierType.streamNotifier => 'Stream<dynamic>',
      NotifierType.stateNotifier => stateClassName,
      NotifierType.notifier => 'dynamic',
    };
    final buildBody = switch (node.notifierType) {
      NotifierType.asyncNotifier =>
        '    return null; // TODO: Return initial async state',
      NotifierType.streamNotifier =>
        '    return const Stream.empty(); // TODO: Return stream',
      NotifierType.stateNotifier => '    return $stateClassName();',
      NotifierType.notifier => '    return null; // TODO: Return initial state',
    };
    final header = switch (node.notifierType) {
      NotifierType.asyncNotifier =>
        '// 🔄 Suggestion: Convert ${node.name} to an @riverpod AsyncNotifier',
      NotifierType.streamNotifier =>
        '// 🔄 Suggestion: Convert ${node.name} to an @riverpod StreamNotifier',
      NotifierType.stateNotifier =>
        '// 🔄 Suggestion: Convert ${node.name} to an @riverpod notifier with immutable state',
      NotifierType.notifier =>
        '// 🔄 Suggestion: Convert ${node.name} to an @riverpod Notifier',
    };

    buffer.writeln(header);
    buffer.writeln(
      'import "package:riverpod_annotation/riverpod_annotation.dart";',
    );
    buffer.writeln('part "$fileName.g.dart";');
    buffer.writeln(
      '// Run: dart run build_runner build --delete-conflicting-outputs',
    );
    buffer.writeln();

    if (node.notifierType == NotifierType.stateNotifier) {
      buffer.writeln('class $stateClassName {');
      for (final variable in node.stateVariables) {
        final name = variable.startsWith('_')
            ? variable.substring(1)
            : variable;
        buffer.writeln('  final dynamic $name;');
      }
      buffer.writeln();
      buffer.writeln('  $stateClassName({');
      for (final variable in node.stateVariables) {
        final name = variable.startsWith('_')
            ? variable.substring(1)
            : variable;
        buffer.writeln('    this.$name,');
      }
      buffer.writeln('  });');
      buffer.writeln();
      buffer.writeln('  $stateClassName copyWith({');
      for (final variable in node.stateVariables) {
        final name = variable.startsWith('_')
            ? variable.substring(1)
            : variable;
        buffer.writeln('    dynamic $name,');
      }
      buffer.writeln('  }) {');
      buffer.writeln('    return $stateClassName(');
      for (final variable in node.stateVariables) {
        final name = variable.startsWith('_')
            ? variable.substring(1)
            : variable;
        buffer.writeln('      $name: $name ?? this.$name,');
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln('}');
      buffer.writeln();
    }

    buffer.writeln('@riverpod');
    if (node.isFamilyCandidate) {
      buffer.writeln(
        '// ⚠️  Constructor parameters detected — move them to build(...) to generate a family provider.',
      );
    }
    buffer.writeln('class ${node.name} extends _\$${node.name} {');
    buffer.writeln('  @override');
    buffer.writeln('  $buildReturnType build() {');
    buffer.writeln(buildBody);
    buffer.writeln('  }');
    buffer.writeln();
    for (final method in node.methods) {
      final transformedBody = _bodyTransformer.transformBody(
        method.bodySnippet,
        node.stateVariables,
      );
      final methodReturn = method.isAsync ? 'Future<void>' : 'void';
      buffer.writeln('  $methodReturn ${method.name}() $transformedBody');
      buffer.writeln();
    }
    buffer.writeln('}');

    return buffer.toString();
  }

  String _generateProviderDeclaration(ProviderDeclarationNode node) {
    final providerName = providerNameForType(node.providedClass);
    return '''// 🔄 Suggestion: Remove ${node.providerType}; @riverpod now generates $providerName automatically.
// If this provider wrapped part of the widget tree, keep only:
// ProviderScope(child: YourApp())''';
  }

  String _generateConsumerWidget(ConsumerNode node) {
    final buffer = StringBuffer();
    final providerName = providerNameForType(node.consumedClass);
    buffer.writeln(
      '// 🔄 Suggestion: Change Widget to ConsumerWidget and use ref.watch',
    );
    buffer.writeln('class MyWidget extends ConsumerWidget {');
    buffer.writeln('  @override');
    buffer.writeln('  Widget build(BuildContext context, WidgetRef ref) {');
    buffer.writeln('    final state = ref.watch($providerName);');
    buffer.writeln('    return /* Your UI */;');
    buffer.writeln('  }');
    buffer.writeln('}');
    return buffer.toString();
  }

  String _generateRefWatchRead(ProviderOfNode node) {
    final providerName = providerNameForType(node.consumedClass);
    if (node.isInBuildMethod) {
      return '// 🔄 Inside build() — use ref.watch for reactive rebuilds\n'
          'final state = ref.watch($providerName);';
    } else {
      return '// 🔄 Outside build() — use ref.read for one-shot access in callbacks\n'
          'ref.read($providerName.notifier).someMethod();';
    }
  }
}
