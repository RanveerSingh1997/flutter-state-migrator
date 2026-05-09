import '../models/ir_models.dart';

class TextEdit {
  final int offset;
  final int length;
  final String replacement;
  TextEdit(this.offset, this.length, this.replacement);
}

class RiverpodTransformer {
  /// Returns a list of specific text edits to apply.
  List<TextEdit> transformNode(ProviderNode node, String originalSource) {
    if (node is ProviderOfNode) {
      return _transformProviderOf(node, originalSource);
    } else if (node is ProviderDeclarationNode) {
      return _transformProviderDeclaration(node, originalSource);
    } else if (node is LogicUnitNode) {
      return _transformLogicUnit(node, originalSource);
    } else if (node is WidgetNode) {
      return _transformWidget(node, originalSource);
    } else if (node is ConsumerNode) {
      return _transformConsumer(node, originalSource);
    } else if (node is SelectorNode) {
      return _transformSelector(node, originalSource);
    } else if (node is MultiProviderNode) {
      return _transformMultiProvider(node, originalSource);
    } else if (node is AsyncProviderNode) {
      return _transformAsyncProvider(node, originalSource);
    }
    return [];
  }

  List<TextEdit> _transformProviderOf(ProviderOfNode node, String originalSource) {
    final snippet = originalSource.substring(node.offset, node.offset + node.length);
    final providerName = '${node.consumedClass.toLowerCase()}Provider';

    if (snippet.startsWith('Provider.of')) {
      if (snippet.contains('listen: false')) {
        return [TextEdit(node.offset, node.length, 'ref.read($providerName)')];
      } else {
        return [TextEdit(node.offset, node.length, 'ref.watch($providerName)')];
      }
    } else if (snippet.startsWith('context.read')) {
      return [TextEdit(node.offset, node.length, 'ref.read($providerName.notifier)')];
    } else if (snippet.startsWith('context.watch')) {
      return [TextEdit(node.offset, node.length, 'ref.watch($providerName)')];
    }
    return [];
  }

  List<TextEdit> _transformProviderDeclaration(ProviderDeclarationNode node, String originalSource) {
    final providerName = '${node.providedClass.toLowerCase()}Provider';
    
    final edits = <TextEdit>[];

    if (node.childOffset != null && node.childLength != null) {
      final replacement = originalSource.substring(node.childOffset!, node.childOffset! + node.childLength!);
      edits.add(TextEdit(node.offset, node.length, replacement));
    }

    final globalProviderDef = '''

// TODO: Auto-migrated Riverpod Provider
final $providerName = StateNotifierProvider<${node.providedClass}Notifier, ${node.providedClass}State>((ref) {
  return ${node.providedClass}Notifier();
});
''';

    edits.add(TextEdit(originalSource.length, 0, globalProviderDef));
    return edits;
  }

  List<TextEdit> _transformMultiProvider(MultiProviderNode node, String originalSource) {
    if (node.childOffset != null && node.childLength != null) {
      final replacement = originalSource.substring(node.childOffset!, node.childOffset! + node.childLength!);
      return [TextEdit(node.offset, node.length, replacement)];
    }
    return [];
  }

  List<TextEdit> _transformSelector(SelectorNode node, String originalSource) {
    final edits = <TextEdit>[];
    final snippet = originalSource.substring(node.offset, node.offset + node.length);

    // 1. Replace Selector<A, B> with Consumer
    final selectorRegex = RegExp(r'Selector<\w+,\s*\w+>');
    final selectorMatch = selectorRegex.firstMatch(snippet);
    if (selectorMatch != null) {
      edits.add(TextEdit(
          node.offset + selectorMatch.start, selectorMatch.group(0)!.length, 'Consumer'));
    }

    // 2. Remove the selector: argument
    final selectorArgRegex = RegExp(r'selector:\s*[\s\S]+?(?=builder:)', multiLine: true);
    final selectorArgMatch = selectorArgRegex.firstMatch(snippet);
    if (selectorArgMatch != null) {
      edits.add(TextEdit(node.offset + selectorArgMatch.start, selectorArgMatch.group(0)!.length, ''));
    }

    // 3. Find builder signature and replace
    final builderRegex = RegExp(r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*\{', multiLine: true);
    final builderMatch = builderRegex.firstMatch(snippet);
    if (builderMatch != null) {
      final ctx = builderMatch.group(1)!.trim();
      final val = builderMatch.group(2)!.trim();
      final ch = builderMatch.group(3)!.trim();
      final providerName = '${node.consumedClass.toLowerCase()}Provider';

      final newBuilder =
          "builder: ($ctx, ref, $ch) {\n    final $val = ref.watch($providerName.select(${node.selectorSnippet}));";

      edits.add(TextEdit(
          node.offset + builderMatch.start, builderMatch.group(0)!.length, newBuilder));
    }

    return edits;
  }

  List<TextEdit> _transformAsyncProvider(AsyncProviderNode node, String originalSource) {
    final providerName = '${node.providedType.toLowerCase()}Provider';
    final edits = <TextEdit>[];

    if (node.childOffset != null && node.childLength != null) {
      final replacement = originalSource.substring(node.childOffset!, node.childOffset! + node.childLength!);
      edits.add(TextEdit(node.offset, node.length, replacement));
    }

    final globalProviderDef = '''

// TODO: Auto-migrated Riverpod ${node.providerType}
final $providerName = ${node.providerType == 'FutureProvider' ? 'FutureProvider' : 'StreamProvider'}<${node.providedType}>((ref) {
  return /* TODO: Return ${node.providerType == 'FutureProvider' ? 'Future' : 'Stream'} */;
});
''';

    edits.add(TextEdit(originalSource.length, 0, globalProviderDef));
    return edits;
  }

  List<TextEdit> _transformLogicUnit(LogicUnitNode node, String originalSource) {
    final snippet = originalSource.substring(node.offset, node.offset + node.length);
    
    final buffer = StringBuffer();
    buffer.writeln('import "package:riverpod_annotation/riverpod_annotation.dart";');
    // Assuming file name matches class name roughly, this is a heuristic
    final fileName = node.filePath.split('/').last.replaceAll('.dart', '');
    buffer.writeln('part "${fileName}.g.dart";');
    buffer.writeln('');
    buffer.writeln('@riverpod');
    buffer.writeln('class ${node.name}Notifier extends _\$${node.name}Notifier {');
    buffer.writeln('  @override');
    buffer.writeln('  dynamic build() {');
    buffer.writeln('    return null; // TODO: Return initial state');
    buffer.writeln('  }');
    buffer.writeln('');
    for (final method in node.methods) {
      buffer.writeln('  void $method(/* args */) {');
      buffer.writeln('    // state = newState;');
      buffer.writeln('  }');
    }
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('/* TODO: Original ChangeNotifier class:');
    buffer.writeln(snippet);
    buffer.writeln('*/');

    return [TextEdit(node.offset, node.length, buffer.toString())];
  }

  List<TextEdit> _transformWidget(WidgetNode node, String originalSource) {
    final edits = <TextEdit>[];
    if (node.widgetType == 'StatelessWidget') {
      // Find "extends StatelessWidget" in the class declaration
      // The offset is the start of the class. We can search forward.
      final endSearch = (node.offset + 100 < originalSource.length) ? node.offset + 100 : originalSource.length;
      final searchArea = originalSource.substring(node.offset, endSearch);
      final extendsIdx = searchArea.indexOf('extends StatelessWidget');
      if (extendsIdx != -1) {
        edits.add(TextEdit(
          node.offset + extendsIdx,
          'extends StatelessWidget'.length,
          'extends ConsumerWidget'
        ));
      }

      if (node.buildMethodOffset != -1) {
        // Find "Widget build(BuildContext context)" around buildMethodOffset
        final buildEndSearch = (node.buildMethodOffset + 100 < originalSource.length) ? node.buildMethodOffset + 100 : originalSource.length;
        final buildSearchArea = originalSource.substring(node.buildMethodOffset, buildEndSearch);
        final buildIdx = buildSearchArea.indexOf('Widget build(BuildContext context)');
        if (buildIdx != -1) {
          edits.add(TextEdit(
            node.buildMethodOffset + buildIdx,
            'Widget build(BuildContext context)'.length,
            'Widget build(BuildContext context, WidgetRef ref)'
          ));
        }
      }
    }
    return edits;
  }

  List<TextEdit> _transformConsumer(ConsumerNode node, String originalSource) {
    final edits = <TextEdit>[];
    final snippet = originalSource.substring(node.offset, node.offset + node.length);

    // 1. Replace Consumer<Type> with Consumer
    final consumerRegex = RegExp(r'Consumer<\w+>');
    final consumerMatch = consumerRegex.firstMatch(snippet);
    if (consumerMatch != null) {
      edits.add(TextEdit(
          node.offset + consumerMatch.start, consumerMatch.group(0)!.length, 'Consumer'));
    }

    // 2. Find builder signature and replace
    final builderRegex = RegExp(r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*\{', multiLine: true);
    final builderMatch = builderRegex.firstMatch(snippet);
    if (builderMatch != null) {
      final ctx = builderMatch.group(1)!.trim();
      final val = builderMatch.group(2)!.trim();
      final ch = builderMatch.group(3)!.trim();
      final providerName = '${node.consumedClass.toLowerCase()}Provider';

      final newBuilder = "builder: ($ctx, ref, $ch) {\n    final $val = ref.watch($providerName);";

      edits.add(TextEdit(
          node.offset + builderMatch.start, builderMatch.group(0)!.length, newBuilder));
    }

    return edits;
  }
}
