import '../models/ir_models.dart';
import '../analysis/body_transformer.dart';

class TextEdit {
  final int offset;
  final int length;
  final String replacement;
  TextEdit(this.offset, this.length, this.replacement);
}

class RiverpodTransformer {
  final _bodyTransformer = BodyTransformer();

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
    } else if (node is StateNode) {
      return _transformState(node, originalSource);
    } else if (node is HookWidgetNode) {
      return _transformHookWidget(node, originalSource);
    }
    return [];
  }

  List<TextEdit> _transformProviderOf(
    ProviderOfNode node,
    String originalSource,
  ) {
    final snippet = originalSource.substring(
      node.offset,
      node.offset + node.length,
    );
    final providerName = '${node.consumedClass.toLowerCase()}Provider';

    if (snippet.startsWith('Provider.of')) {
      // `listen: false` always maps to ref.read regardless of location.
      // Otherwise use build-method context: ref.watch in build(), ref.read in callbacks.
      if (snippet.contains('listen: false') || !node.isInBuildMethod) {
        return [TextEdit(node.offset, node.length, 'ref.read($providerName)')];
      } else {
        return [TextEdit(node.offset, node.length, 'ref.watch($providerName)')];
      }
    } else if (snippet.startsWith('context.read')) {
      return [
        TextEdit(node.offset, node.length, 'ref.read($providerName.notifier)'),
      ];
    } else if (snippet.startsWith('context.watch')) {
      return [TextEdit(node.offset, node.length, 'ref.watch($providerName)')];
    }
    return [];
  }

  List<TextEdit> _transformProviderDeclaration(
    ProviderDeclarationNode node,
    String originalSource,
  ) {
    final edits = <TextEdit>[];

    // 1. Generate the global provider definition
    final providerName = '${node.providedClass.toLowerCase()}Provider';
    final globalDef =
        "\n// TODO: Auto-migrated Riverpod Provider\nfinal $providerName = StateNotifierProvider<${node.providedClass}Notifier, ${node.providedClass}State>((ref) {\n  return ${node.providedClass}Notifier();\n});\n";
    edits.add(TextEdit(originalSource.length, 0, globalDef));

    // 2. Unwrap if it has a child
    if (node.childOffset != null && node.childLength != null) {
      final child = originalSource.substring(
        node.childOffset!,
        node.childOffset! + node.childLength!,
      );
      // If this was a top-level provider, it should probably be a ProviderScope now
      edits.add(
        TextEdit(node.offset, node.length, 'ProviderScope(child: $child)'),
      );
    }

    return edits;
  }

  List<TextEdit> _transformMultiProvider(
    MultiProviderNode node,
    String originalSource,
  ) {
    if (node.childOffset != null && node.childLength != null) {
      final child = originalSource.substring(
        node.childOffset!,
        node.childOffset! + node.childLength!,
      );
      // Wrap in ProviderScope to ensure Riverpod works
      return [
        TextEdit(node.offset, node.length, 'ProviderScope(child: $child)'),
      ];
    }
    return [];
  }

  List<TextEdit> _transformSelector(SelectorNode node, String originalSource) {
    final edits = <TextEdit>[];
    final snippet = originalSource.substring(
      node.offset,
      node.offset + node.length,
    );

    // 1. Replace Selector<A, B> with Consumer
    final selectorRegex = RegExp(r'Selector<\w+,\s*\w+>');
    final selectorMatch = selectorRegex.firstMatch(snippet);
    if (selectorMatch != null) {
      edits.add(
        TextEdit(
          node.offset + selectorMatch.start,
          selectorMatch.group(0)!.length,
          'Consumer',
        ),
      );
    }

    // 2. Remove the selector: argument
    final selectorArgRegex = RegExp(
      r'selector:\s*[\s\S]+?(?=builder:)',
      multiLine: true,
    );
    final selectorArgMatch = selectorArgRegex.firstMatch(snippet);
    if (selectorArgMatch != null) {
      edits.add(
        TextEdit(
          node.offset + selectorArgMatch.start,
          selectorArgMatch.group(0)!.length,
          '',
        ),
      );
    }

    // 3. Find builder signature and replace
    final builderRegex = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*(?:\{|=>)',
      multiLine: true,
    );
    final builderMatch = builderRegex.firstMatch(snippet);
    if (builderMatch != null) {
      final ctx = builderMatch.group(1)!.trim();
      final val = builderMatch.group(2)!.trim();
      final ch = builderMatch.group(3)!.trim();
      final providerName = '${node.consumedClass.toLowerCase()}Provider';

      final isExpression =
          snippet.substring(builderMatch.end - 2, builderMatch.end) == '=>';
      final newBuilder =
          "builder: ($ctx, ref, $ch) " +
          (isExpression
              ? "=> ref.watch($providerName.select(${node.selectorSnippet}))"
              : "{\n    final $val = ref.watch($providerName.select(${node.selectorSnippet}));");

      edits.add(
        TextEdit(
          node.offset + builderMatch.start,
          builderMatch.group(0)!.length,
          newBuilder,
        ),
      );
    }

    return edits;
  }

  List<TextEdit> _transformAsyncProvider(
    AsyncProviderNode node,
    String originalSource,
  ) {
    final providerName = '${node.providedType.toLowerCase()}Provider';
    final edits = <TextEdit>[];

    if (node.childOffset != null && node.childLength != null) {
      final replacement = originalSource.substring(
        node.childOffset!,
        node.childOffset! + node.childLength!,
      );
      edits.add(TextEdit(node.offset, node.length, replacement));
    }

    final globalProviderDef =
        '''

// TODO: Auto-migrated Riverpod ${node.providerType}
final $providerName = ${node.providerType == 'FutureProvider' ? 'FutureProvider' : 'StreamProvider'}<${node.providedType}>((ref) {
  return /* TODO: Return ${node.providerType == 'FutureProvider' ? 'Future' : 'Stream'} */;
});
''';

    edits.add(TextEdit(originalSource.length, 0, globalProviderDef));
    return edits;
  }

  List<TextEdit> _transformLogicUnit(
    LogicUnitNode node,
    String originalSource,
  ) {
    final snippet = originalSource.substring(
      node.offset,
      node.offset + node.length,
    );

    final buffer = StringBuffer();
    buffer.writeln(
      'import "package:riverpod_annotation/riverpod_annotation.dart";',
    );
    final fileName = node.filePath.split('/').last.replaceAll('.dart', '');
    buffer.writeln('part "$fileName.g.dart";');
    buffer.writeln('');

    final buildReturnType = switch (node.notifierType) {
      NotifierType.asyncNotifier => 'Future<dynamic>',
      NotifierType.streamNotifier => 'Stream<dynamic>',
      _ => 'dynamic',
    };

    final buildBody = switch (node.notifierType) {
      NotifierType.asyncNotifier =>
        '    return null; // TODO: Return initial async state',
      NotifierType.streamNotifier =>
        '    return const Stream.empty(); // TODO: Return stream',
      _ => '    return null; // TODO: Return initial state',
    };

    buffer.writeln('@riverpod');
    if (node.isFamilyCandidate) {
      buffer.writeln('// ⚠️  Constructor params detected — add .family arg:');
      buffer.writeln(
        '// @Riverpod(keepAlive: true)',
      );
    }
    buffer.writeln(
      'class ${node.name}Notifier extends _\$${node.name}Notifier {',
    );
    buffer.writeln('  @override');
    buffer.writeln('  $buildReturnType build() {');
    buffer.writeln(buildBody);
    buffer.writeln('  }');
    buffer.writeln('');
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
    buffer.writeln('');
    buffer.writeln('/* TODO: Original class:');
    buffer.writeln(snippet);
    buffer.writeln('*/');

    return [TextEdit(node.offset, node.length, buffer.toString())];
  }

  List<TextEdit> _transformWidget(WidgetNode node, String originalSource) {
    final edits = <TextEdit>[];
    if (node.widgetType == 'StatelessWidget') {
      // Find "extends StatelessWidget" in the class declaration
      // The offset is the start of the class. We can search forward.
      final endSearch = (node.offset + 100 < originalSource.length)
          ? node.offset + 100
          : originalSource.length;
      final searchArea = originalSource.substring(node.offset, endSearch);
      final extendsIdx = searchArea.indexOf('extends StatelessWidget');
      if (extendsIdx != -1) {
        edits.add(
          TextEdit(
            node.offset + extendsIdx,
            'extends StatelessWidget'.length,
            'extends ConsumerWidget',
          ),
        );
      }

      if (node.buildMethodOffset != null) {
        final buildOffset = node.buildMethodOffset!;
        // Find "Widget build(BuildContext context)" around buildMethodOffset
        final buildEndSearch = (buildOffset + 100 < originalSource.length)
            ? buildOffset + 100
            : originalSource.length;
        final buildSearchArea = originalSource.substring(
          buildOffset,
          buildEndSearch,
        );
        final buildIdx = buildSearchArea.indexOf(
          'Widget build(BuildContext context)',
        );
        if (buildIdx != -1) {
          edits.add(
            TextEdit(
              buildOffset + buildIdx,
              'Widget build(BuildContext context)'.length,
              'Widget build(BuildContext context, WidgetRef ref)',
            ),
          );
        }
      }
    } else if (node.widgetType == 'StatefulWidget') {
      final endSearch = (node.offset + 100 < originalSource.length)
          ? node.offset + 100
          : originalSource.length;
      final searchArea = originalSource.substring(node.offset, endSearch);
      final extendsIdx = searchArea.indexOf('extends StatefulWidget');
      if (extendsIdx != -1) {
        edits.add(
          TextEdit(
            node.offset + extendsIdx,
            'extends StatefulWidget'.length,
            'extends ConsumerStatefulWidget',
          ),
        );
      }

      if (node.buildMethodOffset != null && node.buildMethodOffset != -1) {
        final createOffset = node.buildMethodOffset!;
        final createEndSearch = (createOffset + 100 < originalSource.length)
            ? createOffset + 100
            : originalSource.length;
        final createSearchArea = originalSource.substring(
          createOffset,
          createEndSearch,
        );
        final stateIdx = createSearchArea.indexOf('State<${node.widgetName}>');
        if (stateIdx != -1) {
          edits.add(
            TextEdit(
              createOffset + stateIdx,
              'State<${node.widgetName}>'.length,
              'ConsumerState<${node.widgetName}>',
            ),
          );
        }
      }
    }
    return edits;
  }

  List<TextEdit> _transformState(StateNode node, String originalSource) {
    final edits = <TextEdit>[];
    final endSearch = (node.offset + 100 < originalSource.length)
        ? node.offset + 100
        : originalSource.length;
    final searchArea = originalSource.substring(node.offset, endSearch);
    final target = 'extends State<${node.widgetName}>';
    final extendsIdx = searchArea.indexOf(target);
    if (extendsIdx != -1) {
      edits.add(
        TextEdit(
          node.offset + extendsIdx,
          target.length,
          'extends ConsumerState<${node.widgetName}>',
        ),
      );
    }
    return edits;
  }

  List<TextEdit> _transformHookWidget(
    HookWidgetNode node,
    String originalSource,
  ) {
    final edits = <TextEdit>[];
    final endSearch = (node.offset + 100 < originalSource.length)
        ? node.offset + 100
        : originalSource.length;
    final searchArea = originalSource.substring(node.offset, endSearch);
    final extendsIdx = searchArea.indexOf('extends HookWidget');
    if (extendsIdx != -1) {
      edits.add(
        TextEdit(
          node.offset + extendsIdx,
          'extends HookWidget'.length,
          'extends HookConsumerWidget',
        ),
      );
    }

    // Find (BuildContext context) and replace with (BuildContext context, WidgetRef ref)
    final buildSnippet = originalSource.substring(
      node.buildMethodOffset,
      node.offset + node.length,
    );
    final match = RegExp(
      r'build\s*\(\s*BuildContext\s+context\s*\)',
    ).firstMatch(buildSnippet);
    if (match != null) {
      edits.add(
        TextEdit(
          node.buildMethodOffset + match.start,
          match.group(0)!.length,
          'build(BuildContext context, WidgetRef ref)',
        ),
      );
    }
    return edits;
  }

  List<TextEdit> _transformConsumer(ConsumerNode node, String originalSource) {
    final edits = <TextEdit>[];
    final snippet = originalSource.substring(
      node.offset,
      node.offset + node.length,
    );

    // 1. Replace Consumer<Type> with Consumer
    final consumerRegex = RegExp(r'Consumer<\w+>');
    final consumerMatch = consumerRegex.firstMatch(snippet);
    if (consumerMatch != null) {
      edits.add(
        TextEdit(
          node.offset + consumerMatch.start,
          consumerMatch.group(0)!.length,
          'Consumer',
        ),
      );
    }

    // 2. Find builder signature and replace
    final builderRegex = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*(?:\{|=>)',
      multiLine: true,
    );
    final builderMatch = builderRegex.firstMatch(snippet);
    if (builderMatch != null) {
      final ctx = builderMatch.group(1)!.trim();
      final val = builderMatch.group(2)!.trim();
      final ch = builderMatch.group(3)!.trim();
      final providerName = '${node.consumedClass.toLowerCase()}Provider';

      final isExpression =
          snippet.substring(builderMatch.end - 2, builderMatch.end) == '=>';
      final newBuilder =
          "builder: ($ctx, ref, $ch) " +
          (isExpression
              ? "=> ref.watch($providerName)"
              : "{\n    final $val = ref.watch($providerName);");

      edits.add(
        TextEdit(
          node.offset + builderMatch.start,
          builderMatch.group(0)!.length,
          newBuilder,
        ),
      );
    }

    return edits;
  }
}
