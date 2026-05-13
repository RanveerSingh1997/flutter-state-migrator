import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

class BlocAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  BlocAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final classBody = node.body;
    if (classBody is! BlockClassBody) {
      super.visitClassDeclaration(node);
      return;
    }

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclassName = extendsClause.superclass.name.lexeme;
      if (superclassName == 'Bloc' || superclassName == 'Cubit') {
        final className = node.name.lexeme;
        final stateType =
            extendsClause.superclass.typeArguments?.arguments.last.toSource() ??
            'dynamic';

        final methods = <MethodInfo>[];
        bool isFamilyCandidate = false;
        for (final member in classBody.members) {
          if (member is ConstructorDeclaration) {
            for (final param in member.parameters.parameters) {
              final paramName = param.name?.lexeme ?? '';
              if (paramName != 'key') {
                isFamilyCandidate = true;
                break;
              }
            }
          } else if (member is MethodDeclaration) {
            methods.add(
              buildMethodInfo(
                member,
                callsNotifyListeners: member.body.toSource().contains('emit('),
              ),
            );
          }
        }

        nodes.add(
          LogicUnitNode(
            name: className,
            stateFields: [FieldInfo(rawName: 'state', type: stateType)],
            methods: methods,
            isNotifier: true,
            notifierType: detectNotifierType(methods),
            isFamilyCandidate: isFamilyCandidate,
            role: _inferRole(className),
            superClassName: superclassName,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    }
    super.visitClassDeclaration(node);
  }

  String _inferRole(String className) {
    final lower = className.toLowerCase();
    if (lower.endsWith('bloc')) return 'bloc';
    if (lower.endsWith('cubit')) return 'cubit';
    return 'logic';
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name.lexeme;

    if (typeName == 'BlocProvider' || typeName == 'RepositoryProvider') {
      _handleBlocDeclaration(node, typeName);
    } else if (typeName == 'BlocBuilder' ||
        typeName == 'BlocListener' ||
        typeName == 'BlocConsumer') {
      _handleBlocConsumer(node, typeName);
    }

    super.visitInstanceCreationExpression(node);
  }

  void _handleBlocDeclaration(InstanceCreationExpression node, String type) {
    String? providedClass;
    int? childOffset;
    int? childLength;

    final typeArgs = node.constructorName.type.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      providedClass = typeArgs.arguments.first.toSource();
    }

    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        if (arg.name.label.name == 'create' && providedClass == null) {
          providedClass = _inferTypeFromCreate(arg.expression);
        } else if (arg.name.label.name == 'child') {
          childOffset = arg.expression.offset;
          childLength = arg.expression.length;
        }
      }
    }

    nodes.add(
      ProviderDeclarationNode(
        providerType: type,
        providedClass: providedClass ?? 'Unknown',
        childOffset: childOffset,
        childLength: childLength,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ),
    );
  }

  void _handleBlocConsumer(InstanceCreationExpression node, String type) {
    String? consumedClass;
    final typeArgs = node.constructorName.type.typeArguments;
    if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
      consumedClass = typeArgs.arguments.first.toSource();
    }

    if (consumedClass != null) {
      nodes.add(
        ConsumerNode(
          consumedClass: consumedClass,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }
  }

  String? _inferTypeFromCreate(Expression expression) {
    if (expression is FunctionExpression) {
      final body = expression.body;
      if (body is ExpressionFunctionBody) {
        final expr = body.expression;
        if (expr is InstanceCreationExpression) {
          return expr.constructorName.type.name.lexeme;
        }
      }
    }
    return null;
  }
}
