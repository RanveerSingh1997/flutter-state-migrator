import '../models/ir_models.dart';
import '../analysis/body_transformer.dart';

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
        '${node.providedType.toLowerCase()}${node.providerType}';
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
    final providerName = '${node.consumedClass.toLowerCase()}Provider';
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

    switch (node.notifierType) {
      case NotifierType.asyncNotifier:
        buffer.writeln(
          '// 🔄 Suggestion: Convert ${node.name} to AsyncNotifier (detected async methods)',
        );
        buffer.writeln('@riverpod');
        buffer.writeln(
          'class ${node.name}Notifier extends ${node.isFamilyCandidate ? '_\$${node.name}Notifier' : 'AsyncNotifier<dynamic>'} {',
        );
        buffer.writeln('  @override');
        buffer.writeln('  Future<dynamic> build() async {');
        buffer.writeln('    return null; // TODO: Return initial async state');
        buffer.writeln('  }');
        for (final method in node.methods) {
          final transformedBody = _bodyTransformer.transformBody(
            method.bodySnippet,
            node.stateVariables,
          );
          buffer.writeln(
            '  ${method.isAsync ? 'Future<void>' : 'void'} ${method.name}() $transformedBody',
          );
          buffer.writeln();
        }
        buffer.writeln('}');
        if (node.isFamilyCandidate) {
          buffer.writeln(
            '// ⚠️  This class has constructor parameters — use .family modifier:',
          );
          buffer.writeln(
            '// final ${node.name.toLowerCase()}Provider = AsyncNotifierProvider.family<${node.name}Notifier, dynamic, ArgType>(...);',
          );
        }

      case NotifierType.streamNotifier:
        buffer.writeln(
          '// 🔄 Suggestion: Convert ${node.name} to StreamNotifier (detected Stream return types)',
        );
        buffer.writeln('@riverpod');
        buffer.writeln(
          'class ${node.name}Notifier extends StreamNotifier<dynamic> {',
        );
        buffer.writeln('  @override');
        buffer.writeln('  Stream<dynamic> build() {');
        buffer.writeln(
          '    return const Stream.empty(); // TODO: Return stream',
        );
        buffer.writeln('  }');
        for (final method in node.methods) {
          final transformedBody = _bodyTransformer.transformBody(
            method.bodySnippet,
            node.stateVariables,
          );
          buffer.writeln('  void ${method.name}() $transformedBody');
          buffer.writeln();
        }
        buffer.writeln('}');
        if (node.isFamilyCandidate) {
          buffer.writeln(
            '// ⚠️  This class has constructor parameters — use .family modifier:',
          );
          buffer.writeln(
            '// final ${node.name.toLowerCase()}Provider = StreamNotifierProvider.family<${node.name}Notifier, dynamic, ArgType>(...);',
          );
        }

      case NotifierType.notifier:
        buffer.writeln(
          '// 🔄 Suggestion: Convert ${node.name} to Notifier (Riverpod 2.0+)',
        );
        buffer.writeln('@riverpod');
        buffer.writeln(
          'class ${node.name}Notifier extends ${node.isFamilyCandidate ? '_\$${node.name}Notifier' : 'Notifier<dynamic>'} {',
        );
        buffer.writeln('  @override');
        buffer.writeln('  dynamic build() {');
        buffer.writeln('    return null; // TODO: Return initial state');
        buffer.writeln('  }');
        for (final method in node.methods) {
          final transformedBody = _bodyTransformer.transformBody(
            method.bodySnippet,
            node.stateVariables,
          );
          buffer.writeln(
            '  void ${method.name}() $transformedBody',
          );
          buffer.writeln();
        }
        buffer.writeln('}');
        if (node.isFamilyCandidate) {
          buffer.writeln(
            '// ⚠️  This class has constructor parameters — use .family modifier:',
          );
          buffer.writeln(
            '// final ${node.name.toLowerCase()}Provider = NotifierProvider.family<${node.name}Notifier, dynamic, ArgType>(...);',
          );
        }

      case NotifierType.stateNotifier:
        final stateClassName = '${node.name}State';
        buffer.writeln(
          '// 🔄 Suggestion: Convert ${node.name} to StateNotifier',
        );
        buffer.writeln(
          '// Note: StateNotifier requires an immutable state class.',
        );
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
        buffer.writeln('');
        buffer.writeln(
          'class ${node.name}Notifier extends StateNotifier<$stateClassName> {',
        );
        buffer.writeln('  ${node.name}Notifier() : super($stateClassName());');
        buffer.writeln('');
        for (final method in node.methods) {
          final transformedBody = _bodyTransformer.transformBody(
            method.bodySnippet,
            node.stateVariables,
          );
          buffer.writeln('  void ${method.name}() $transformedBody');
          buffer.writeln();
        }
        buffer.writeln('}');
        if (node.isFamilyCandidate) {
          buffer.writeln(
            '// ⚠️  This class has constructor parameters — use .family modifier:',
          );
          final providerName = '${node.name.toLowerCase()}Provider';
          buffer.writeln(
            '// final $providerName = StateNotifierProvider.family<${node.name}Notifier, ${node.name}State, ArgType>((ref, arg) {',
          );
          buffer.writeln('//   return ${node.name}Notifier(arg);');
          buffer.writeln('// });');
        }
    }

    return buffer.toString();
  }

  String _generateProviderDeclaration(ProviderDeclarationNode node) {
    final buffer = StringBuffer();
    final providerName = '${node.providedClass.toLowerCase()}Provider';
    buffer.writeln(
      '// 🔄 Suggestion: Replace ${node.providerType} with StateNotifierProvider',
    );
    buffer.writeln(
      'final $providerName = StateNotifierProvider<${node.providedClass}Notifier, ${node.providedClass}State>((ref) {',
    );
    buffer.writeln('  return ${node.providedClass}Notifier();');
    buffer.writeln('});');
    return buffer.toString();
  }

  String _generateConsumerWidget(ConsumerNode node) {
    final buffer = StringBuffer();
    final providerName = '${node.consumedClass.toLowerCase()}Provider';
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
    final providerName = '${node.consumedClass.toLowerCase()}Provider';
    if (node.isInBuildMethod) {
      return '// 🔄 Inside build() — use ref.watch for reactive rebuilds\n'
          'final state = ref.watch($providerName);';
    } else {
      return '// 🔄 Outside build() — use ref.read for one-shot access in callbacks\n'
          'ref.read($providerName.notifier).someMethod();';
    }
  }
}
