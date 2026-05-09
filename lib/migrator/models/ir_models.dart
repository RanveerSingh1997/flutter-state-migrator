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

class MethodInfo {
  final String name;
  final bool callsNotifyListeners;
  final String bodySnippet;

  MethodInfo({
    required this.name,
    required this.callsNotifyListeners,
    required this.bodySnippet,
  });
}

class LogicUnitNode extends ProviderNode {
  final String name;
  final List<String> stateVariables;
  final List<MethodInfo> methods;
  final bool isNotifier;

  LogicUnitNode({
    required this.name,
    required this.stateVariables,
    required this.methods,
    required this.isNotifier,
    required super.filePath,
    required super.offset,
    required super.length,
  });

  Map<String, dynamic> toJson() => {
    'type': 'logic_unit',
    'name': name,
    'state': stateVariables,
    'methods': methods,
    'notifier': isNotifier,
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

  ProviderOfNode({
    required this.consumedClass,
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
