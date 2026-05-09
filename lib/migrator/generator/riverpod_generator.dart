import '../models/ir_models.dart';

class RiverpodGenerator {
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
    buffer.writeln('// 🔄 Suggestion: Convert ${node.name} to StateNotifier');
    buffer.writeln('// Note: StateNotifier requires an immutable state class.');
    buffer.writeln('class ${node.name}State {');
    for (final state in node.stateVariables) {
      buffer.writeln('  // final dynamic $state;');
    }
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln(
      'class ${node.name}Notifier extends StateNotifier<${node.name}State> {',
    );
    buffer.writeln('  ${node.name}Notifier() : super(${node.name}State());');
    buffer.writeln('');
    for (final method in node.methods) {
      final notifyMsg = method.callsNotifyListeners
          ? ' // (Original called notifyListeners)'
          : '';
      buffer.writeln('  void ${method.name}(/* args */) {$notifyMsg');
      buffer.writeln('    // state = newState;');
      buffer.writeln('  }');
    }
    buffer.writeln('}');
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
    final buffer = StringBuffer();
    final providerName = '${node.consumedClass.toLowerCase()}Provider';
    buffer.writeln(
      '// 🔄 Suggestion: Replace Provider.of / context.read / Get.find with ref.read or ref.watch',
    );
    buffer.writeln('// Use for rebuilding UI:');
    buffer.writeln('final state = ref.watch($providerName);');
    buffer.writeln('// Use for events/callbacks:');
    buffer.writeln('ref.read($providerName.notifier).someMethod();');
    return buffer.toString();
  }
}
