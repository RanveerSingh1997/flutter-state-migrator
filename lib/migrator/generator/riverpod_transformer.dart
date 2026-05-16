import '../analysis/body_transformer.dart';
import '../models/ir_models.dart';
import '../utils/naming.dart';

class TextEdit {
  final int offset;
  final int length;
  final String replacement;
  TextEdit(this.offset, this.length, this.replacement);
}

class RiverpodTransformer {
  final _bodyTransformer = BodyTransformer();

  /// Tracks which files have already received the @riverpod file-level header.
  final _fileHeaderInjected = <String>{};

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
    final isMethodCall = node.isMethodCall;

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

  List<TextEdit> _transformProviderDeclaration(
    ProviderDeclarationNode node,
    String originalSource,
  ) {
    // If it's a root-level provider wrapping the app, replace with ProviderScope
    if (node.childOffset != null && node.childLength != null) {
      final child = originalSource.substring(
        node.childOffset!,
        node.childOffset! + node.childLength!,
      );
      return [
        TextEdit(node.offset, node.length, 'ProviderScope(child: $child)'),
      ];
    }
    // For nested providers, we often just remove them as Riverpod providers are global
    return [TextEdit(node.offset, node.length, '')];
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

  List<TextEdit> _transformConsumer(ConsumerNode node, String originalSource) {
    final providerName = providerNameForType(node.consumedClass);
    final builderSource = _extractBuilderSource(
      originalSource: originalSource,
      nodeOffset: node.offset,
      nodeLength: node.length,
      builderOffset: node.builderOffset,
      builderLength: node.builderLength,
      pattern: RegExp(r'builder:\s*(.+?)(?:,\s*child:|\s*\)$)', dotAll: true),
    );
    final childSource = _extractNamedArgumentSource(
      originalSource: originalSource,
      nodeOffset: node.offset,
      nodeLength: node.length,
      valueOffset: node.childOffset,
      valueLength: node.childLength,
      pattern: RegExp(r'child:\s*(.+?)\s*\)$', dotAll: true),
    );

    if (builderSource != null) {
      final signatureMatch = RegExp(
        r'\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*(=>|\{)',
      ).firstMatch(builderSource);

      if (signatureMatch != null) {
        final ctx = signatureMatch.group(1)!.trim();
        final val = signatureMatch.group(2)!.trim();
        final ch = signatureMatch.group(3)!.trim();
        final type = signatureMatch.group(4)!;

        String newBuilder;
        if (type == '=>') {
          final body = builderSource.substring(signatureMatch.end).trim();
          newBuilder =
              '($ctx, ref, $ch) {\n'
              '      final $val = ref.watch($providerName);\n'
              '      return $body;\n'
              '    }';
        } else {
          final body = builderSource.substring(signatureMatch.end).trim();
          newBuilder =
              '($ctx, ref, $ch) {\n'
              '      final $val = ref.watch($providerName);\n'
              '      $body';
        }

        String replacement = 'Consumer(\n    builder: $newBuilder,\n';
        if (childSource != null) {
          replacement += '    child: $childSource,\n';
        }
        replacement += '  )';

        return [TextEdit(node.offset, node.length, replacement)];
      }
    }

    return [];
  }

  List<TextEdit> _transformSelector(SelectorNode node, String originalSource) {
    // Skip when no real selector was captured (fallback placeholder).
    if (node.selectorSnippet.startsWith('/*')) return [];
    final providerName = providerNameForType(node.consumedClass);
    final selector = _normaliseSelectorSnippet(node.selectorSnippet);
    final builderSource = _extractBuilderSource(
      originalSource: originalSource,
      nodeOffset: node.offset,
      nodeLength: node.length,
      builderOffset: node.builderOffset,
      builderLength: node.builderLength,
      pattern: RegExp(r'builder:\s*(.+?)(?:,\s*child:|\s*\)$)', dotAll: true),
    );
    final childSource = _extractNamedArgumentSource(
      originalSource: originalSource,
      nodeOffset: node.offset,
      nodeLength: node.length,
      valueOffset: node.childOffset,
      valueLength: node.childLength,
      pattern: RegExp(r'child:\s*(.+?)\s*\)$', dotAll: true),
    );

    if (builderSource != null) {
      final signatureMatch = RegExp(
        r'\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*(=>|\{)',
      ).firstMatch(builderSource);

      if (signatureMatch != null) {
        final ctx = signatureMatch.group(1)!.trim();
        final val = signatureMatch.group(2)!.trim();
        final ch = signatureMatch.group(3)!.trim();
        final type = signatureMatch.group(4)!;

        String newBuilder;
        if (type == '=>') {
          final body = builderSource.substring(signatureMatch.end).trim();
          newBuilder =
              '($ctx, ref, $ch) {\n'
              '      final $val = ref.watch($providerName.select($selector));\n'
              '      return $body;\n'
              '    }';
        } else {
          final body = builderSource.substring(signatureMatch.end).trim();
          newBuilder =
              '($ctx, ref, $ch) {\n'
              '      final $val = ref.watch($providerName.select($selector));\n'
              '      $body';
        }

        String replacement = 'Consumer(\n    builder: $newBuilder,\n';
        if (childSource != null) {
          replacement += '    child: $childSource,\n';
        }
        replacement += '  )';

        return [TextEdit(node.offset, node.length, replacement)];
      }
    }

    return [];
  }

  String _normaliseSelectorSnippet(String snippet) {
    final trimmed = snippet.trim();
    final expressionMatch = RegExp(
      r'\(\s*\w+\s*,\s*(\w+)\s*\)\s*=>\s*([\s\S]+)',
    ).firstMatch(trimmed);
    if (expressionMatch != null) {
      final oldVar = expressionMatch.group(1)!;
      final expr = _replaceSelectorVariable(
        expressionMatch.group(2)!.trim(),
        oldVar,
      );
      return '(state) => $expr';
    }

    final blockMatch = RegExp(
      r'\(\s*\w+\s*,\s*(\w+)\s*\)\s*\{([\s\S]*)\}$',
    ).firstMatch(trimmed);
    if (blockMatch != null) {
      final oldVar = blockMatch.group(1)!;
      final blockBody = _replaceSelectorVariable(
        blockMatch.group(2)!.trim(),
        oldVar,
      );
      return '(state) { $blockBody }';
    }

    return '(state) => $snippet';
  }

  String? _extractBuilderSource({
    required String originalSource,
    required int nodeOffset,
    required int nodeLength,
    required int? builderOffset,
    required int? builderLength,
    required RegExp pattern,
  }) {
    if (builderOffset != null && builderLength != null) {
      return originalSource.substring(
        builderOffset,
        builderOffset + builderLength,
      );
    }
    return _extractNamedArgumentSource(
      originalSource: originalSource,
      nodeOffset: nodeOffset,
      nodeLength: nodeLength,
      valueOffset: null,
      valueLength: null,
      pattern: pattern,
    );
  }

  String? _extractNamedArgumentSource({
    required String originalSource,
    required int nodeOffset,
    required int nodeLength,
    required int? valueOffset,
    required int? valueLength,
    required RegExp pattern,
  }) {
    if (valueOffset != null && valueLength != null) {
      return originalSource.substring(valueOffset, valueOffset + valueLength);
    }

    final nodeSource = originalSource.substring(
      nodeOffset,
      nodeOffset + nodeLength,
    );
    final match = pattern.firstMatch(nodeSource);
    return match?.group(1)?.trim();
  }

  String _replaceSelectorVariable(String source, String variableName) {
    return source.replaceAllMapped(
      RegExp('(?<![\\w.])${RegExp.escape(variableName)}(?!\\w)'),
      (_) => 'state',
    );
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
    final edits = <TextEdit>[];

    if (!_fileHeaderInjected.contains(node.filePath)) {
      _fileHeaderInjected.add(node.filePath);
      final fileName = node.filePath.split('/').last.replaceAll('.dart', '');
      final header =
          '''
import "package:riverpod_annotation/riverpod_annotation.dart";
part "$fileName.g.dart";
// Run: dart run build_runner build --delete-conflicting-outputs

''';
      edits.add(TextEdit(0, 0, header));
    }

    final (buildReturnType, buildBody) = _inferBuildSignature(node);

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
    final asyncKw = node.notifierType == NotifierType.asyncNotifier ? ' async' : '';
    buffer.writeln('  $buildReturnType build()$asyncKw {');
    buffer.writeln('    $buildBody');
    buffer.writeln('  }');
    buffer.writeln('');

    for (final method in node.methods) {
      if (method.isGetter) continue;

      final transformedBody = _bodyTransformer.transformBody(
        method.bodySnippet,
        node.stateFields,
      );
      final methodReturn = method.isAsync ? 'Future<void>' : 'void';
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

    edits.add(TextEdit(node.offset, node.length, buffer.toString()));
    return edits;
  }

  (String, String) _inferBuildSignature(LogicUnitNode node) {
    switch (node.notifierType) {
      case NotifierType.asyncNotifier:
        final method = node.methods.firstWhere(
          (m) => !m.isGetter && (m.isAsync || m.returnType.startsWith('Future')),
          orElse: () => MethodInfo(
            name: '',
            callsNotifyListeners: false,
            bodySnippet: '',
            returnType: 'dynamic',
          ),
        );
        final innerType = _extractTypeParam(method.returnType, 'Future');
        final body = method.bodySnippet.isNotEmpty
            ? _extractBodyContent(method.bodySnippet)
            : 'return null; // TODO: Return initial async state';
        return ('Future<$innerType>', body);
      case NotifierType.streamNotifier:
        final method = node.methods.firstWhere(
          (m) => !m.isGetter && m.returnType.startsWith('Stream'),
          orElse: () => MethodInfo(
            name: '',
            callsNotifyListeners: false,
            bodySnippet: '',
            returnType: 'dynamic',
          ),
        );
        final innerType = _extractTypeParam(method.returnType, 'Stream');
        final body = method.bodySnippet.isNotEmpty
            ? _extractBodyContent(method.bodySnippet)
            : 'return const Stream.empty(); // TODO: Return stream';
        return ('Stream<$innerType>', body);
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

    final stateClass = '${node.name}State';
    return (stateClass, 'return $stateClass();');
  }

  String _extractTypeParam(String returnType, String wrapper) {
    final match = RegExp('$wrapper<(.+)>').firstMatch(returnType);
    return match?.group(1) ?? 'dynamic';
  }

  String _extractBodyContent(String bodySnippet) {
    String s = bodySnippet.trim();
    if (s.startsWith('async*')) {
      s = s.substring(6).trim();
    } else if (s.startsWith('async')) {
      s = s.substring(5).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      return s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('=>')) {
      return 'return ${s.substring(2).trim()};';
    }
    return s;
  }

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
}
