import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

class ProviderAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  /// Tracks whether the visitor is currently inside a `build()` method body.
  bool _inBuildMethod = false;

  /// Tracks nested callback/lambda scopes inside `build()` such as `onPressed`,
  /// `builder`, and other closures. Reads inside these closures should be
  /// treated as imperative one-shot access, not reactive watches.
  int _callbackDepth = 0;

  ProviderAdapter(this.filePath);

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final wasBuild = _inBuildMethod;
    if (node.name.lexeme == 'build') {
      _inBuildMethod = true;
    }
    super.visitMethodDeclaration(node);
    _inBuildMethod = wasBuild;
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    final shouldTrackCallback = _inBuildMethod;
    if (shouldTrackCallback) {
      _callbackDepth++;
    }
    super.visitFunctionExpression(node);
    if (shouldTrackCallback) {
      _callbackDepth--;
    }
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final classBody = node.body;
    if (classBody is! BlockClassBody) {
      super.visitClassDeclaration(node);
      return;
    }

    final extendsClause = node.extendsClause;
    final superClassName = extendsClause?.superclass.name.lexeme;
    final mixins =
        node.withClause?.mixinTypes.map((t) => t.name.lexeme).toList() ?? [];

    // Detect ChangeNotifier classes (Standard Provider pattern)
    if (extendsClause != null && superClassName == 'ChangeNotifier') {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in classBody.members) {
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
          notifierType: detectNotifierType(methods),
          isFamilyCandidate: isFamilyCandidate,
          role: _inferRole(className, superClassName),
          superClassName: superClassName,
          mixins: mixins,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (extendsClause != null && superClassName == 'StatelessWidget') {
      final className = node.name.lexeme;
      int buildMethodOffset = -1;

      for (final member in classBody.members) {
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
    } else if (extendsClause != null && superClassName == 'StatefulWidget') {
      final className = node.name.lexeme;
      int createStateOffset = -1;
      for (final member in classBody.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'createState') {
          createStateOffset = member.offset;
        }
      }
      nodes.add(
        WidgetNode(
          widgetName: className,
          widgetType: 'StatefulWidget',
          buildMethodOffset: createStateOffset,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (extendsClause != null && superClassName == 'State') {
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
    } else if (extendsClause != null && superClassName == 'HookWidget') {
      final className = node.name.lexeme;
      int buildMethodOffset = -1;
      for (final member in classBody.members) {
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
    } else if (_isLogicClass(
      className: node.name.lexeme,
      superClassName: superClassName,
    )) {
      // Catch-all for other logic classes (repositories, services)
      final className = node.name.lexeme;
      nodes.add(
        LogicUnitNode(
          name: className,
          stateFields: [], // Not a framework-managed state
          methods: [], // Could be expanded to scan methods
          isNotifier: false,
          role: _inferRole(className, superClassName),
          superClassName: superClassName,
          mixins: mixins,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    super.visitClassDeclaration(node);
  }

  bool _isLogicClass({required String className, String? superClassName}) {
    final lowerName = className.toLowerCase();
    return lowerName.endsWith('repository') ||
        lowerName.endsWith('service') ||
        lowerName.endsWith('manager') ||
        lowerName.endsWith('api');
  }

  String _inferRole(String className, String? superClassName) {
    final lowerName = className.toLowerCase();
    if (lowerName.endsWith('repository')) return 'repository';
    if (lowerName.endsWith('service')) return 'service';
    if (lowerName.endsWith('api')) return 'api';
    if (lowerName.endsWith('provider')) return 'provider';
    if (superClassName == 'ChangeNotifier') return 'provider';
    return 'logic';
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;

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
    } else if (typeName == 'Consumer') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        int? builderOffset;
        int? builderLength;
        int? childOffset;
        int? childLength;

        for (final arg in node.argumentList.arguments) {
          if (arg is! NamedExpression) continue;
          if (arg.name.label.name == 'builder') {
            builderOffset = arg.expression.offset;
            builderLength = arg.expression.length;
          } else if (arg.name.label.name == 'child') {
            childOffset = arg.expression.offset;
            childLength = arg.expression.length;
          }
        }

        nodes.add(
          ConsumerNode(
            consumedClass: consumedType,
            builderOffset: builderOffset,
            builderLength: builderLength,
            childOffset: childOffset,
            childLength: childLength,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (typeName == 'MultiProvider') {
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
    } else if (typeName == 'Selector') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.length >= 2) {
        final consumedType = typeArgs.arguments[0].beginToken.lexeme;
        final selectedType = typeArgs.arguments[1].beginToken.lexeme;
        String selectorSnippet = '/* TODO: Selector */';
        int? builderOffset;
        int? builderLength;
        int? childOffset;
        int? childLength;
        for (final arg in node.argumentList.arguments) {
          if (arg is! NamedExpression) continue;
          if (arg.name.label.name == 'selector') {
            selectorSnippet = arg.expression.toSource();
          } else if (arg.name.label.name == 'builder') {
            builderOffset = arg.expression.offset;
            builderLength = arg.expression.length;
          } else if (arg.name.label.name == 'child') {
            childOffset = arg.expression.offset;
            childLength = arg.expression.length;
          }
        }
        nodes.add(
          SelectorNode(
            consumedClass: consumedType,
            selectedType: selectedType,
            selectorSnippet: selectorSnippet,
            builderOffset: builderOffset,
            builderLength: builderLength,
            childOffset: childOffset,
            childLength: childLength,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (typeName == 'FutureProvider' || typeName == 'StreamProvider') {
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
    if (node.target == null &&
        _handleConstructorLikeInvocation(
          typeName: node.methodName.name,
          typeArguments: node.typeArguments,
          argumentList: node.argumentList,
          offset: node.offset,
          length: node.length,
        )) {
      super.visitMethodInvocation(node);
      return;
    }

    if (node.target != null &&
        node.target!.beginToken.lexeme == 'Provider' &&
        node.methodName.name == 'of') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        final isReactiveBuildContext = _inBuildMethod && _callbackDepth == 0;
        final hasListenFalse = node.toSource().contains('listen: false');
        nodes.add(
          ProviderOfNode(
            consumedClass: consumedType,
            isInBuildMethod: isReactiveBuildContext && !hasListenFalse,
            isMethodCall: _isFollowedByMethodCall(node),
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (node.target != null &&
        node.target!.beginToken.lexeme == 'context' &&
        (node.methodName.name == 'read' || node.methodName.name == 'watch')) {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        final isReactiveBuildContext = _inBuildMethod && _callbackDepth == 0;
        final isWatch = node.methodName.name == 'watch';
        nodes.add(
          ProviderOfNode(
            consumedClass: consumedType,
            isInBuildMethod: isWatch && isReactiveBuildContext,
            isMethodCall: _isFollowedByMethodCall(node),
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }

    super.visitMethodInvocation(node);
  }

  bool _handleConstructorLikeInvocation({
    required String typeName,
    required TypeArgumentList? typeArguments,
    required ArgumentList argumentList,
    required int offset,
    required int length,
  }) {
    if (typeName == 'ChangeNotifierProvider') {
      String? providedClass;
      int? childOffset;
      int? childLength;
      for (final arg in argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name == 'create') {
          providedClass = _inferConstructedType(arg.expression);
        } else if (arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        ProviderDeclarationNode(
          providerType: typeName,
          providedClass: providedClass ?? 'Unknown',
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: offset,
          length: length,
        ),
      );
      return true;
    }

    if (typeName == 'Consumer') {
      if (typeArguments == null || typeArguments.arguments.isEmpty) {
        return false;
      }
      int? builderOffset;
      int? builderLength;
      int? childOffset;
      int? childLength;

      for (final arg in argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name == 'builder') {
          builderOffset = arg.expression.offset;
          builderLength = arg.expression.length;
        } else if (arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }

      nodes.add(
        ConsumerNode(
          consumedClass: typeArguments.arguments.first.toSource(),
          builderOffset: builderOffset,
          builderLength: builderLength,
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: offset,
          length: length,
        ),
      );
      return true;
    }

    if (typeName == 'MultiProvider') {
      int? childOffset;
      int? childLength;
      for (final arg in argumentList.arguments) {
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
          offset: offset,
          length: length,
        ),
      );
      return true;
    }

    if (typeName == 'Selector') {
      if (typeArguments == null || typeArguments.arguments.length < 2) {
        return false;
      }
      String selectorSnippet = '/* TODO: Selector */';
      int? builderOffset;
      int? builderLength;
      int? childOffset;
      int? childLength;
      for (final arg in argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name == 'selector') {
          selectorSnippet = arg.expression.toSource();
        } else if (arg.name.label.name == 'builder') {
          builderOffset = arg.expression.offset;
          builderLength = arg.expression.length;
        } else if (arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
      nodes.add(
        SelectorNode(
          consumedClass: typeArguments.arguments[0].toSource(),
          selectedType: typeArguments.arguments[1].toSource(),
          selectorSnippet: selectorSnippet,
          builderOffset: builderOffset,
          builderLength: builderLength,
          childOffset: childOffset,
          childLength: childLength,
          filePath: filePath,
          offset: offset,
          length: length,
        ),
      );
      return true;
    }

    if (typeName == 'FutureProvider' || typeName == 'StreamProvider') {
      final providedType =
          (typeArguments != null && typeArguments.arguments.isNotEmpty)
          ? typeArguments.arguments.first.toSource()
          : 'Unknown';
      int? childOffset;
      int? childLength;
      for (final arg in argumentList.arguments) {
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
          offset: offset,
          length: length,
        ),
      );
      return true;
    }

    return false;
  }

  String? _inferConstructedType(Expression expression) {
    if (expression is FunctionExpression) {
      final body = expression.body;
      if (body is ExpressionFunctionBody) {
        return _inferConstructedType(body.expression);
      }
    }
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }
    if (expression is MethodInvocation && expression.target == null) {
      return expression.methodName.name;
    }
    return null;
  }

  bool _isFollowedByMethodCall(MethodInvocation node) {
    final parent = node.parent;
    if (parent is MethodInvocation && parent.target == node) return true;
    if (parent is PropertyAccess && parent.target == node) {
      final grandParent = parent.parent;
      if (grandParent is MethodInvocation && grandParent.target == parent)
        return true;
    }
    return false;
  }
}
