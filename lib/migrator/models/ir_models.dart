abstract class ProviderNode {
  final String filePath;
  final int offset;
  final int length;

  ProviderNode({
    required this.filePath,
    required this.offset,
    required this.length,
  });
}

/// Which Riverpod notifier primitive best fits the detected class shape.
enum NotifierType { stateNotifier, notifier, asyncNotifier, streamNotifier }

/// A single field captured from a ChangeNotifier class declaration.
class FieldInfo {
  /// Raw source name (may have leading `_`), e.g. `_count`.
  final String rawName;

  /// Public name (leading `_` stripped), e.g. `count`.
  String get publicName =>
      rawName.startsWith('_') ? rawName.substring(1) : rawName;

  /// Dart type as source text, e.g. `int`, `String`, `List<Todo>`.
  /// Falls back to `dynamic` when the type could not be inferred.
  final String type;

  /// Source text of the initializer expression, e.g. `0`, `''`, `[]`.
  /// `null` when no initializer was found.
  final String? initializer;

  const FieldInfo({
    required this.rawName,
    this.type = 'dynamic',
    this.initializer,
  });
}

/// A parameter captured from a method declaration, e.g. `String name`.
class ParamInfo {
  final String name;
  final String type;

  const ParamInfo({required this.name, this.type = 'dynamic'});

  String toSource() => '$type $name';
}

class MethodInfo {
  final String name;
  final bool callsNotifyListeners;
  final String bodySnippet;

  /// True when the method body contains `async`/`await`.
  final bool isAsync;

  /// Source text of the declared return type (e.g. `'Future<void>'`, `'Stream<int>'`).
  final String returnType;

  /// True for Dart getter declarations (`get foo => ...`).
  /// Getters are skipped during code generation.
  final bool isGetter;

  /// Formal parameters of the method, in declaration order.
  final List<ParamInfo> parameters;

  MethodInfo({
    required this.name,
    required this.callsNotifyListeners,
    required this.bodySnippet,
    this.isAsync = false,
    this.returnType = 'void',
    this.isGetter = false,
    this.parameters = const [],
  });

  /// Emits the parameter list as a source string, e.g. `String name, int age`.
  String get paramSource => parameters.map((p) => p.toSource()).join(', ');
}

class LogicUnitNode extends ProviderNode {
  final String name;
  final List<FieldInfo> stateFields;
  final List<MethodInfo> methods;
  final bool isNotifier;

  /// Best-fit Riverpod primitive inferred from the class's method signatures.
  final NotifierType notifierType;

  /// True when the class constructor has required parameters (beyond `key`),
  /// indicating a `.family` provider is needed.
  final bool isFamilyCandidate;

  LogicUnitNode({
    required this.name,
    required this.stateFields,
    required this.methods,
    required this.isNotifier,
    this.notifierType = NotifierType.stateNotifier,
    this.isFamilyCandidate = false,
    required super.filePath,
    required super.offset,
    required super.length,
  });

  /// Backwards-compat: callers that only need the raw names.
  List<String> get stateVariables => stateFields.map((f) => f.rawName).toList();

  Map<String, dynamic> toJson() => {
    'type': 'logic_unit',
    'name': name,
    'state': stateFields
        .map((f) => {'name': f.rawName, 'type': f.type})
        .toList(),
    'methods': methods.length,
    'notifier': isNotifier,
    'notifierType': notifierType.name,
    'isFamilyCandidate': isFamilyCandidate,
  };
}

class ProviderDeclarationNode extends ProviderNode {
  final String providerType; // e.g. ChangeNotifierProvider
  final String providedClass; // e.g. Counter
  final int? childOffset;
  final int? childLength;

  ProviderDeclarationNode({
    required this.providerType,
    required this.providedClass,
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class ConsumerNode extends ProviderNode {
  final String consumedClass;

  ConsumerNode({
    required this.consumedClass,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class ProviderOfNode extends ProviderNode {
  final String consumedClass;

  /// True when this consumption occurs inside a `build()` method.
  /// Used to select `ref.watch` (reactive, in build) vs `ref.read` (one-shot, in callbacks).
  final bool isInBuildMethod;

  ProviderOfNode({
    required this.consumedClass,
    this.isInBuildMethod = false,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class SelectorNode extends ProviderNode {
  final String consumedClass;
  final String selectedType;
  final String selectorSnippet;

  SelectorNode({
    required this.consumedClass,
    required this.selectedType,
    required this.selectorSnippet,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class MultiProviderNode extends ProviderNode {
  final int? childOffset;
  final int? childLength;

  MultiProviderNode({
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class AsyncProviderNode extends ProviderNode {
  final String providerType; // FutureProvider or StreamProvider
  final String providedType; // The type returned by the future/stream
  final int? childOffset;
  final int? childLength;

  AsyncProviderNode({
    required this.providerType,
    required this.providedType,
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class WidgetNode extends ProviderNode {
  final String widgetName;
  final String widgetType; // e.g., StatelessWidget, StatefulWidget
  final int?
  buildMethodOffset; // Where to inject `WidgetRef ref` (null for StatefulWidget)

  WidgetNode({
    required this.widgetName,
    required this.widgetType,
    this.buildMethodOffset,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class StateNode extends ProviderNode {
  final String stateClassName;
  final String widgetName;

  StateNode({
    required this.stateClassName,
    required this.widgetName,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

class HookWidgetNode extends ProviderNode {
  final String widgetName;
  final int buildMethodOffset;

  HookWidgetNode({
    required this.widgetName,
    required this.buildMethodOffset,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}
