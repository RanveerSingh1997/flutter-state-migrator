import '../models/ir_models.dart';
import '../analysis/body_transformer.dart';
import '../utils/naming.dart';

class TextEdit {
  final int offset;
  final int length;
  final String replacement;
  TextEdit(this.offset, this.length, this.replacement);
}

class RiverpodTransformer {
  final _bodyTransformer = BodyTransformer();

  /// Tracks which files have already received the @riverpod file-level header
  /// (imports + part directive). Keyed by absolute file path.
  final _fileHeaderInjected = <String>{};

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
    final providerName = providerNameForType(node.consumedClass);
    final isMethodCall = _isFollowedByMethodCall(
      originalSource,
      node.offset + node.length,
    );
    final imperativeValueRead = 'ref.read($providerName)';
    final imperativeNotifierRead = 'ref.read($providerName.notifier)';
    final reactiveWatch = 'ref.watch($providerName)';

    if (snippet.startsWith('Provider.of')) {
      if (isMethodCall) {
        return [TextEdit(node.offset, node.length, imperativeNotifierRead)];
      }
      if (snippet.contains('listen: false') || !node.isInBuildMethod) {
        return [TextEdit(node.offset, node.length, imperativeValueRead)];
      } else {
        return [TextEdit(node.offset, node.length, reactiveWatch)];
      }
    } else if (snippet.startsWith('context.read')) {
      return [
        TextEdit(
          node.offset,
          node.length,
          isMethodCall ? imperativeNotifierRead : imperativeValueRead,
        ),
      ];
    } else if (snippet.startsWith('context.watch')) {
      return [
        TextEdit(
          node.offset,
          node.length,
          isMethodCall
              ? imperativeNotifierRead
              : (node.isInBuildMethod ? reactiveWatch : imperativeValueRead),
        ),
      ];
    }
    return [];
  }

  bool _isFollowedByMethodCall(String source, int endOffset) {
    var index = endOffset;
    while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
      index++;
    }
    if (index >= source.length || source[index] != '.') {
      return false;
    }

    index++;
    while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
      index++;
    }
    while (index < source.length &&
        RegExp(r'[A-Za-z0-9_]').hasMatch(source[index])) {
      index++;
    }
    while (index < source.length && RegExp(r'\s').hasMatch(source[index])) {
      index++;
    }

    return index < source.length && source[index] == '(';
  }

  List<TextEdit> _transformProviderDeclaration(
    ProviderDeclarationNode node,
    String originalSource,
  ) {
    final edits = <TextEdit>[];

    // Remove the legacy Provider widget wrapper; replace with ProviderScope if
    // there is a child widget, otherwise remove entirely.
    if (node.childOffset != null && node.childLength != null) {
      final child = originalSource.substring(
        node.childOffset!,
        node.childOffset! + node.childLength!,
      );
      edits.add(
        TextEdit(node.offset, node.length, 'ProviderScope(child: $child)'),
      );
    } else {
      // No child captured — just delete the legacy wrapper expression.
      edits.add(TextEdit(node.offset, node.length, ''));
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

    final providerName = providerNameForType(node.consumedClass);
    final normalisedSelector = _normaliseSelectorSnippet(node.selectorSnippet);
    final expressionBuilder = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*=>\s*([\s\S]*?)(?=,\s*\)|\)\s*$)',
      multiLine: true,
    ).firstMatch(snippet);
    if (expressionBuilder != null) {
      final ctx = expressionBuilder.group(1)!.trim();
      final val = expressionBuilder.group(2)!.trim();
      final ch = expressionBuilder.group(3)!.trim();
      final expr = expressionBuilder.group(4)!.trim();
      edits.add(
        TextEdit(
          node.offset + expressionBuilder.start,
          expressionBuilder.group(0)!.length,
          'builder: ($ctx, ref, $ch) {\n'
          '    final $val = ref.watch($providerName.select($normalisedSelector));\n'
          '    return $expr;\n'
          '  }',
        ),
      );
      return edits;
    }

    final blockBuilder = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*\{',
      multiLine: true,
    ).firstMatch(snippet);
    if (blockBuilder != null) {
      final ctx = blockBuilder.group(1)!.trim();
      final val = blockBuilder.group(2)!.trim();
      final ch = blockBuilder.group(3)!.trim();
      edits.add(
        TextEdit(
          node.offset + blockBuilder.start,
          blockBuilder.group(0)!.length,
          'builder: ($ctx, ref, $ch) {\n'
          '    final $val = ref.watch($providerName.select($normalisedSelector));',
        ),
      );
    }

    return edits;
  }

  /// Converts the legacy `(ctx, model) => model.name` selector lambda to the
  /// Riverpod `(state) => state.name` form.
  String _normaliseSelectorSnippet(String snippet) {
    // Match `(ctx, model) => expr` or `(ctx, model) { ... }`
    final match = RegExp(
      r'\(\s*\w+\s*,\s*(\w+)\s*\)\s*=>\s*([\s\S]+)',
    ).firstMatch(snippet.trim());
    if (match != null) {
      final oldVar = match.group(1)!;
      var expr = match.group(2)!.trim();
      // Replace the old model variable name with `state`
      expr = expr.replaceAllMapped(
        RegExp('(?<![\\w.])${RegExp.escape(oldVar)}(?!\\w)'),
        (_) => 'state',
      );
      return '(state) => $expr';
    }
    // Fallback: wrap as-is
    return '(state) => $snippet';
  }

  List<TextEdit> _transformAsyncProvider(
    AsyncProviderNode node,
    String originalSource,
  ) {
    final providerName = providerNameForType(node.providedType);
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
final $providerName = ${node.providerType == 'FutureProvider' ? 'FutureProvider' : 'StreamProvider'}<${node.providedType}>((ref) async {
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

    // ── Bug 5 fix: only emit file-level header once per file ──────────────────
    final isFirstInFile = !_fileHeaderInjected.contains(node.filePath);
    if (isFirstInFile) {
      _fileHeaderInjected.add(node.filePath);
      buffer.writeln(
        'import "package:riverpod_annotation/riverpod_annotation.dart";',
      );
      final fileName = node.filePath.split('/').last.replaceAll('.dart', '');
      buffer.writeln('part "$fileName.g.dart";');
      buffer.writeln(
        '// Run: dart run build_runner build --delete-conflicting-outputs',
      );
      buffer.writeln('');
    }

    // ── Bug 8 + 9 fix: infer build() return type and initial value ─────────────
    final (buildReturnType, buildBody) = _inferBuildSignature(node);

    // ── State class: only generated for multi-field notifiers ──────────────────
    // For single-field classes, we use the field type directly as the state.
    if (node.stateFields.length > 1) {
      _emitStateClass(buffer, node);
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
    buffer.writeln('    $buildBody');
    buffer.writeln('  }');
    buffer.writeln('');

    // ── Bug 1 fix: skip getter methods ────────────────────────────────────────
    // ── Bug 2 fix: emit method parameters ────────────────────────────────────
    for (final method in node.methods) {
      if (method.isGetter) continue; // Bug 1: skip getters

      final transformedBody = _bodyTransformer.transformBody(
        method.bodySnippet,
        node.stateFields,
      );
      final methodReturn = method.isAsync ? 'Future<void>' : 'void';
      // Bug 2: include parameters in signature
      buffer.writeln(
        '  $methodReturn ${method.name}(${method.paramSource}) $transformedBody',
      );
      buffer.writeln();
    }
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('/* TODO: Original class:');
    buffer.writeln(snippet);
    buffer.writeln('*/');

    // ── Bug 7 fix: no manual StateNotifierProvider — @riverpod + build_runner
    //    generates the provider automatically. Nothing appended.

    return [TextEdit(node.offset, node.length, buffer.toString())];
  }

  /// Infers the `build()` return type and initial body expression from the
  /// detected [FieldInfo] list.
  ///
  /// Rules:
  ///   - 0 fields → `void build()` (practically unused, Notifier with no state)
  ///   - 1 field  → use the field's declared type + initializer directly
  ///   - >1 fields → generate a `${ClassName}State` class
  (String, String) _inferBuildSignature(LogicUnitNode node) {
    switch (node.notifierType) {
      case NotifierType.asyncNotifier:
        return (
          'Future<dynamic>',
          'return null; // TODO: Return initial async state',
        );
      case NotifierType.streamNotifier:
        return (
          'Stream<dynamic>',
          'return const Stream.empty(); // TODO: Return stream',
        );
      default:
        break;
    }

    if (node.stateFields.isEmpty) {
      return ('void', '// TODO: no state fields detected');
    }

    if (node.stateFields.length == 1) {
      final f = node.stateFields.first;
      final type = f.type == 'dynamic' ? 'dynamic' : f.type;
      final init = f.initializer;
      if (init != null) {
        return (type, 'return $init;');
      }
      return (type, 'return ${_defaultForType(type)};');
    }

    // Multi-field → use generated state class
    final stateClass = '${node.name}State';
    return (stateClass, 'return $stateClass();');
  }

  /// Returns a sensible Dart default for common types.
  String _defaultForType(String type) {
    switch (type.trim()) {
      case 'int':
        return '0';
      case 'double':
        return '0.0';
      case 'String':
        return "''";
      case 'bool':
        return 'false';
      default:
        if (type.startsWith('List')) return 'const []';
        if (type.startsWith('Map')) return 'const {}';
        return 'null';
    }
  }

  void _emitStateClass(StringBuffer buffer, LogicUnitNode node) {
    final stateClassName = '${node.name}State';

    buffer.writeln('class $stateClassName {');
    for (final field in node.stateFields) {
      buffer.writeln('  final ${field.type} ${field.publicName};');
    }
    buffer.writeln('');

    // Constructor
    buffer.writeln('  const $stateClassName({');
    for (final field in node.stateFields) {
      final init = field.initializer;
      if (init != null) {
        buffer.writeln('    this.${field.publicName} = $init,');
      } else {
        buffer.writeln('    required this.${field.publicName},');
      }
    }
    buffer.writeln('  });');
    buffer.writeln('');

    // copyWith
    buffer.writeln('  $stateClassName copyWith({');
    for (final field in node.stateFields) {
      buffer.writeln('    ${field.type}? ${field.publicName},');
    }
    buffer.writeln('  }) {');
    buffer.writeln('    return $stateClassName(');
    for (final field in node.stateFields) {
      buffer.writeln(
        '      ${field.publicName}: ${field.publicName} ?? this.${field.publicName},',
      );
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln('}');
    buffer.writeln('');
  }

  List<TextEdit> _transformWidget(WidgetNode node, String originalSource) {
    final edits = <TextEdit>[];
    if (node.widgetType == 'StatelessWidget') {
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

    final providerName = providerNameForType(node.consumedClass);
    final expressionBuilder = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*=>\s*([\s\S]*?)(?=,\s*\)|\)\s*$)',
      multiLine: true,
    ).firstMatch(snippet);
    if (expressionBuilder != null) {
      final ctx = expressionBuilder.group(1)!.trim();
      final val = expressionBuilder.group(2)!.trim();
      final ch = expressionBuilder.group(3)!.trim();
      final expr = expressionBuilder.group(4)!.trim();
      edits.add(
        TextEdit(
          node.offset + expressionBuilder.start,
          expressionBuilder.group(0)!.length,
          'builder: ($ctx, ref, $ch) {\n'
          '    final $val = ref.watch($providerName);\n'
          '    return $expr;\n'
          '  }',
        ),
      );
      return edits;
    }

    final blockBuilder = RegExp(
      r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*\{',
      multiLine: true,
    ).firstMatch(snippet);
    if (blockBuilder != null) {
      final ctx = blockBuilder.group(1)!.trim();
      final val = blockBuilder.group(2)!.trim();
      final ch = blockBuilder.group(3)!.trim();
      edits.add(
        TextEdit(
          node.offset + blockBuilder.start,
          blockBuilder.group(0)!.length,
          'builder: ($ctx, ref, $ch) {\n'
          '    final $val = ref.watch($providerName);',
        ),
      );
    }

    return edits;
  }
}
