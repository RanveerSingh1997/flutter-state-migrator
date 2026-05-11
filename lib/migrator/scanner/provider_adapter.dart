import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

class ProviderAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  /// Tracks whether the visitor is currently inside a `build()` method body.
  bool _inBuildMethod = false;

  ProviderAdapter(this.filePath);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuild = _inBuildMethod;
    if (node.name.lexeme == 'build') _inBuildMethod = true;
    super.visitMethodDeclaration(node);
    _inBuildMethod = wasBuild;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Detect ChangeNotifier classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'ChangeNotifier') {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final typeSource = member.fields.type?.toSource() ?? 'dynamic';
            final initializer = variable.initializer?.toSource();
            stateFields.add(
              FieldInfo(
                rawName: variable.name.lexeme,
                type: typeSource,
                initializer: initializer,
              ),
            );
          }
        } else if (member is ConstructorDeclaration) {
          // Any constructor param beyond `key` signals a .family provider is needed
          for (final param in member.parameters.parameters) {
            final paramName = param.name?.lexeme ?? '';
            if (paramName != 'key') {
              isFamilyCandidate = true;
              break;
            }
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme == 'dispose') continue;
          methods.add(
            buildMethodInfo(
              member,
              callsNotifyListeners: member.body.toSource().contains(
                'notifyListeners()',
              ),
            ),
          );
        }
      }

      nodes.add(
        LogicUnitNode(
          name: className,
          stateFields: stateFields,
          methods: methods,
          isNotifier: true,
          notifierType: _detectNotifierType(methods),
          isFamilyCandidate: isFamilyCandidate,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'StatelessWidget') {
      final className = node.name.lexeme;
      int buildMethodOffset = -1;

      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          buildMethodOffset = member.offset;
        }
      }

      nodes.add(
        WidgetNode(
          widgetName: className,
          widgetType: 'StatelessWidget',
          buildMethodOffset: buildMethodOffset,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'StatefulWidget') {
      final className = node.name.lexeme;
      int createStateOffset = -1;
      for (final member in node.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'createState') {
          createStateOffset = member.offset;
        }
      }
      nodes.add(
        WidgetNode(
          widgetName: className,
          widgetType: 'StatefulWidget',
          buildMethodOffset:
              createStateOffset, // Reuse this field for createState offset in StatefulWidget
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'State') {
      final className = node.name.lexeme;
      final typeArguments = extendsClause.superclass.typeArguments;
      if (typeArguments != null && typeArguments.arguments.isNotEmpty) {
        final widgetName = typeArguments.arguments.first.toSource();
        nodes.add(
          StateNode(
            stateClassName: className,
            widgetName: widgetName,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'HookWidget') {
      final className = node.name.lexeme;
      int buildMethodOffset = -1;
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
          buildMethodOffset = member.offset;
        }
      }
      nodes.add(
        HookWidgetNode(
          widgetName: className,
          buildMethodOffset: buildMethodOffset,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;

    // Detect ChangeNotifierProvider(...)
    if (typeName == 'ChangeNotifierProvider') {
      String? providedClass;
      int? childOffset;
      int? childLength;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'create') {
            if (arg.expression is FunctionExpression) {
              final func = arg.expression as FunctionExpression;
              final body = func.body;
              if (body is ExpressionFunctionBody) {
                if (body.expression is InstanceCreationExpression) {
                  providedClass =
                      (body.expression as InstanceCreationExpression)
                          .constructorName
                          .type
                          .name
                          .lexeme;
                }
              }
            }
          } else if (arg.name.label.name == 'child') {
            childOffset = arg.expression.offset;
            childLength = arg.expression.length;
          }
        }
      }
      nodes.add(
        ProviderDeclarationNode(
          providerType: typeName,
          providedClass: providedClass ?? 'Unknown',
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    // Detect Consumer<T>(...)
    if (typeName == 'Consumer') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(
          ConsumerNode(
            consumedClass: consumedType,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect MultiProvider(...)
    if (typeName == 'MultiProvider') {
      int? childOffset;
      int? childLength;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        MultiProviderNode(
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    // Detect Selector<T, R>(...)
    if (typeName == 'Selector') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.length >= 2) {
        final consumedType = typeArgs.arguments[0].beginToken.lexeme;
        final selectedType = typeArgs.arguments[1].beginToken.lexeme;
        String selectorSnippet = '/* TODO: Selector */';
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'selector') {
            selectorSnippet = arg.expression.toSource();
          }
        }
        nodes.add(
          SelectorNode(
            consumedClass: consumedType,
            selectedType: selectedType,
            selectorSnippet: selectorSnippet,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect FutureProvider / StreamProvider(...)
    if (typeName == 'FutureProvider' || typeName == 'StreamProvider') {
      String providedType = 'Unknown';
      int? childOffset;
      int? childLength;
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        providedType = typeArgs.arguments.first.beginToken.lexeme;
      }
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        AsyncProviderNode(
          providerType: typeName,
          providedType: providedType,
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final nodeName = node.methodName.name;

    // Detect ChangeNotifierProvider(...) as MethodInvocation
    if (nodeName == 'ChangeNotifierProvider') {
      String? providedClass;
      int? childOffset;
      int? childLength;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'create') {
            if (arg.expression is FunctionExpression) {
              final func = arg.expression as FunctionExpression;
              final body = func.body;
              if (body is ExpressionFunctionBody) {
                // Could be MethodInvocation or InstanceCreationExpression
                if (body.expression is MethodInvocation) {
                  providedClass =
                      (body.expression as MethodInvocation).methodName.name;
                } else if (body.expression is InstanceCreationExpression) {
                  providedClass =
                      (body.expression as InstanceCreationExpression)
                          .constructorName
                          .type
                          .name
                          .lexeme;
                }
              }
            }
          } else if (arg.name.label.name == 'child') {
            childOffset = arg.expression.offset;
            childLength = arg.expression.length;
          }
        }
      }
      nodes.add(
        ProviderDeclarationNode(
          providerType: nodeName,
          providedClass: providedClass ?? 'Unknown',
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    // Detect Provider.of<T>(context)
    if (node.target != null &&
        node.target!.beginToken.lexeme == 'Provider' &&
        node.methodName.name == 'of') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        // `listen: false` overrides build-context — that's always a ref.read.
        final hasListenFalse = node.toSource().contains('listen: false');
        nodes.add(
          ProviderOfNode(
            consumedClass: consumedType,
            isInBuildMethod: _inBuildMethod && !hasListenFalse,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect context.read<T>() and context.watch<T>()
    if (node.target != null &&
        node.target!.beginToken.lexeme == 'context' &&
        (node.methodName.name == 'read' || node.methodName.name == 'watch')) {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        // context.watch is always reactive; context.read is always one-shot.
        final isWatch = node.methodName.name == 'watch';
        nodes.add(
          ProviderOfNode(
            consumedClass: consumedType,
            isInBuildMethod: isWatch || _inBuildMethod,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect Consumer<T>(...) as MethodInvocation
    if (node.methodName.name == 'Consumer') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(
          ConsumerNode(
            consumedClass: consumedType,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect MultiProvider(...)
    if (nodeName == 'MultiProvider') {
      int? childOffset;
      int? childLength;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        MultiProviderNode(
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    // Detect Selector<T, R>(...)
    if (nodeName == 'Selector') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.length >= 2) {
        final consumedType = typeArgs.arguments[0].beginToken.lexeme;
        final selectedType = typeArgs.arguments[1].beginToken.lexeme;
        String selectorSnippet = '/* TODO: Selector */';
        for (final arg in node.argumentList.arguments) {
          if (arg is NamedExpression && arg.name.label.name == 'selector') {
            selectorSnippet = arg.expression.toSource();
          }
        }
        nodes.add(
          SelectorNode(
            consumedClass: consumedType,
            selectedType: selectedType,
            selectorSnippet: selectorSnippet,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    // Detect FutureProvider / StreamProvider(...)
    if (nodeName == 'FutureProvider' || nodeName == 'StreamProvider') {
      String providedType = 'Unknown';
      int? childOffset;
      int? childLength;
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        providedType = typeArgs.arguments.first.beginToken.lexeme;
      }
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        AsyncProviderNode(
          providerType: nodeName,
          providedType: providedType,
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    super.visitMethodInvocation(node);
  }

  NotifierType _detectNotifierType(List<MethodInfo> methods) {
    for (final m in methods) {
      if (m.isGetter) continue;
      if (m.returnType.startsWith('Stream<'))
        return NotifierType.streamNotifier;
    }
    for (final m in methods) {
      if (m.isGetter) continue;
      if (m.isAsync || m.returnType.startsWith('Future<')) {
        return NotifierType.asyncNotifier;
      }
    }
    return NotifierType.notifier;
  }
}
