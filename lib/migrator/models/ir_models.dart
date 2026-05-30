/// Base class for all semantic IR nodes emitted by the scanner adapters.
///
/// Each node represents one detectable construct in a Flutter source file —
/// a notifier class, a widget, a provider declaration, or a provider access.
/// Nodes carry source location ([filePath], [offset], [length]) so that
/// downstream transformers can produce precise [TextEdit]s.
abstract class ProviderNode {
  /// Absolute path to the source file that contains this node.
  final String filePath;

  /// Byte offset of the node's start within the source file.
  final int offset;

  /// Byte length of the node within the source file.
  final int length;

  ProviderNode({
    required this.filePath,
    required this.offset,
    required this.length,
  });
}

/// Which Riverpod notifier primitive best fits the detected class shape.
enum NotifierType { stateNotifier, notifier, asyncNotifier, streamNotifier }

/// A single field captured from a class declaration.
class FieldInfo {
  /// Raw source name (may have leading `_`), e.g. `_count`.
  final String rawName;

  /// Public name (leading `_` stripped), e.g. `count`.
  String get publicName =>
      rawName.startsWith('_') ? rawName.substring(1) : rawName;

  /// Dart type as source text, e.g. `int`, `String`, `List<Todo>`.
  final String type;

  /// Source text of the initializer expression.
  final String? initializer;

  /// Creates a [FieldInfo].
  const FieldInfo({
    required this.rawName,
    this.type = 'dynamic',
    this.initializer,
  });
}

/// A parameter captured from a method declaration.
class ParamInfo {
  /// Parameter name as it appears in source.
  final String name;

  /// Dart type of the parameter, defaulting to `'dynamic'` when unresolved.
  final String type;

  /// Creates a [ParamInfo].
  const ParamInfo({required this.name, this.type = 'dynamic'});

  /// Returns `'type name'` — the parameter in source-compatible form.
  String toSource() => '$type $name';
}

/// Captured information about a single method in a detected class.
class MethodInfo {
  /// Method name as it appears in source.
  final String name;

  /// True when the method calls `notifyListeners()`, `emit()`, or equivalent.
  final bool callsNotifyListeners;

  /// Full body source text including braces or the `=> expr` arrow.
  final String bodySnippet;

  /// True when the method body contains `async`/`await`.
  final bool isAsync;

  /// Source text of the declared return type.
  final String returnType;

  /// True for Dart getter declarations.
  final bool isGetter;

  /// Formal parameters of the method.
  final List<ParamInfo> parameters;

  /// Creates a [MethodInfo].
  MethodInfo({
    required this.name,
    required this.callsNotifyListeners,
    required this.bodySnippet,
    this.isAsync = false,
    this.returnType = 'void',
    this.isGetter = false,
    this.parameters = const [],
  });

  /// Comma-separated parameter list in source-compatible form.
  String get paramSource => parameters.map((p) => p.toSource()).join(', ');
}

/// IR node for a ChangeNotifier / Bloc / Cubit / GetxController / MobX store.
class LogicUnitNode extends ProviderNode {
  final String name;
  final List<FieldInfo> stateFields;
  final List<MethodInfo> methods;
  final bool isNotifier;

  /// Best-fit Riverpod primitive inferred from the class's method signatures.
  final NotifierType notifierType;

  /// True when the class constructor has required parameters.
  final bool isFamilyCandidate;

  /// Semantic architecture role (e.g., 'bloc', 'controller', 'repository', 'service')
  final String role;

  /// Name of the superclass.
  final String? superClassName;

  /// Names of mixins used by this class.
  final List<String> mixins;

  /// Creates a [LogicUnitNode].
  LogicUnitNode({
    required this.name,
    required this.stateFields,
    required this.methods,
    required this.isNotifier,
    this.notifierType = NotifierType.stateNotifier,
    this.isFamilyCandidate = false,
    this.role = 'logic',
    this.superClassName,
    this.mixins = const [],
    required super.filePath,
    required super.offset,
    required super.length,
  });

  /// Raw field names in declaration order.
  List<String> get stateVariables => stateFields.map((f) => f.rawName).toList();

  /// Serialises the node to a JSON-compatible map for reports and dashboards.
  Map<String, dynamic> toJson() => {
    'type': 'logic_unit',
    'name': name,
    'role': role,
    'state': stateFields
        .map((f) => {'name': f.rawName, 'type': f.type})
        .toList(),
    'methods': methods.length,
    'notifier': isNotifier,
    'notifierType': notifierType.name,
    'isFamilyCandidate': isFamilyCandidate,
    'superClass': superClassName,
    'mixins': mixins,
  };
}

/// IR node for an explicit Provider/ChangeNotifierProvider declaration site.
class ProviderDeclarationNode extends ProviderNode {
  /// Provider widget type, e.g. `'ChangeNotifierProvider'` or `'BlocProvider'`.
  final String providerType;

  /// Name of the class being provided, e.g. `'Counter'`.
  final String providedClass;

  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates a [ProviderDeclarationNode].
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

/// IR node for a Consumer or Builder widget that watches a provider.
class ConsumerNode extends ProviderNode {
  /// Name of the consumed provider type, e.g. `'Counter'`.
  final String consumedClass;

  /// Source offset of the `builder:` argument, if present.
  final int? builderOffset;

  /// Source length of the `builder:` argument, if present.
  final int? builderLength;

  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates a [ConsumerNode].
  ConsumerNode({
    required this.consumedClass,
    this.builderOffset,
    this.builderLength,
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `context.watch`, `context.read`, or `Provider.of` access.
class ProviderOfNode extends ProviderNode {
  /// Name of the consumed provider type.
  final String consumedClass;

  /// True when the access is inside a `build()` method (reactive watch context).
  final bool isInBuildMethod;

  /// True when the result is immediately used for a method call (→ `.notifier`).
  final bool isMethodCall;

  /// Creates a [ProviderOfNode].
  ProviderOfNode({
    required this.consumedClass,
    this.isInBuildMethod = false,
    this.isMethodCall = false,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `Selector` widget that listens to a derived slice of state.
class SelectorNode extends ProviderNode {
  /// Name of the watched provider type.
  final String consumedClass;

  /// Dart type of the selected sub-value, e.g. `'int'`.
  final String selectedType;

  /// Source text of the selector lambda, e.g. `'(s) => s.count'`.
  final String selectorSnippet;

  /// Source offset of the `builder:` argument, if present.
  final int? builderOffset;

  /// Source length of the `builder:` argument, if present.
  final int? builderLength;

  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates a [SelectorNode].
  SelectorNode({
    required this.consumedClass,
    required this.selectedType,
    required this.selectorSnippet,
    this.builderOffset,
    this.builderLength,
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `MultiProvider` wrapper.
class MultiProviderNode extends ProviderNode {
  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates a [MultiProviderNode].
  MultiProviderNode({
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `FutureProvider` or `StreamProvider` declaration.
class AsyncProviderNode extends ProviderNode {
  /// Either `'FutureProvider'` or `'StreamProvider'`.
  final String providerType;

  /// The async value type, e.g. `'List<Todo>'`.
  final String providedType;

  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates an [AsyncProviderNode].
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

/// IR node for a StatelessWidget or StatefulWidget class.
class WidgetNode extends ProviderNode {
  /// Class name of the widget, e.g. `'HomeScreen'`.
  final String widgetName;

  /// Either `'StatelessWidget'` or `'StatefulWidget'`.
  final String widgetType;

  /// Source offset of the `build()` method (or `createState()` for stateful).
  final int? buildMethodOffset;

  /// Creates a [WidgetNode].
  WidgetNode({
    required this.widgetName,
    required this.widgetType,
    this.buildMethodOffset,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `State<T>` class paired with a `StatefulWidget`.
class StateNode extends ProviderNode {
  /// Name of the `State` subclass, e.g. `'_HomeScreenState'`.
  final String stateClassName;

  /// Name of the associated `StatefulWidget` subclass.
  final String widgetName;

  /// Creates a [StateNode].
  StateNode({
    required this.stateClassName,
    required this.widgetName,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `HookWidget` that uses flutter_hooks.
class HookWidgetNode extends ProviderNode {
  /// Class name of the hook widget.
  final String widgetName;

  /// Source offset of the `build()` method.
  final int buildMethodOffset;

  /// Creates a [HookWidgetNode].
  HookWidgetNode({
    required this.widgetName,
    required this.buildMethodOffset,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `ProxyProvider` or `ChangeNotifierProxyProvider` declaration.
///
/// These wrap a result type that depends on another provider type. The Riverpod
/// equivalent is a Notifier whose `build()` calls `ref.watch(baseProvider)`.
class ProxyProviderNode extends ProviderNode {
  /// The dependency type (first type argument), e.g. `AuthService`.
  final String baseType;

  /// The produced type (last type argument), e.g. `UserNotifier`.
  final String resultType;

  /// True when the original is `ChangeNotifierProxyProvider`.
  final bool isChangeNotifier;

  /// Source offset of the `child:` argument, if present.
  final int? childOffset;

  /// Source length of the `child:` argument, if present.
  final int? childLength;

  /// Creates a [ProxyProviderNode].
  ProxyProviderNode({
    required this.baseType,
    required this.resultType,
    this.isChangeNotifier = false,
    this.childOffset,
    this.childLength,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}

/// IR node for a `context.select<T, R>(fn)` call site.
///
/// Maps to `ref.watch(tProvider.select(fn))` in Riverpod.
class ContextSelectNode extends ProviderNode {
  /// Name of the watched provider type, e.g. `'Counter'`.
  final String consumedClass;

  /// Source text of the selector function passed to `context.select`.
  final String selectorSnippet;

  /// Creates a [ContextSelectNode].
  ContextSelectNode({
    required this.consumedClass,
    required this.selectorSnippet,
    required super.filePath,
    required super.offset,
    required super.length,
  });
}
