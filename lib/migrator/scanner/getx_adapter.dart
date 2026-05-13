import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

class GetXAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  GetXAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final classBody = node.body;
    if (classBody is! BlockClassBody) {
      super.visitClassDeclaration(node);
      return;
    }

    final extendsClause = node.extendsClause;
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'GetxController') {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in classBody.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final source = variable.toSource();
            if (source.contains('.obs')) {
              stateFields.add(
                FieldInfo(
                  rawName: variable.name.lexeme,
                  type: _inferObservableType(
                    member.fields.type?.toSource(),
                    variable.initializer?.toSource(),
                  ),
                  initializer: _normalizeObservableInitializer(
                    variable.initializer?.toSource(),
                  ),
                ),
              );
            }
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
          methods.add(
            buildMethodInfo(
              member,
              callsNotifyListeners: member.body.toSource().contains('.value ='),
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

    if (typeName == 'GetX' || typeName == 'GetBuilder') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.toSource();
        nodes.add(
          ConsumerNode(
            consumedClass: consumedType,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (typeName == 'GetMaterialApp') {
      // GetMaterialApp is often used to provide dependencies via 'initialBinding'
      nodes.add(
        MultiProviderNode(
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
    final name = node.methodName.name;

    if (name == 'find' && node.target?.toSource() == 'Get') {
      // Get.find<T>()
      final type = node.typeArguments?.arguments.first.toSource() ?? 'dynamic';
      nodes.add(
        ProviderOfNode(
          consumedClass: type,
          isMethodCall: _isFollowedByMethodCall(node),
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    } else if (name == 'put' && node.target?.toSource() == 'Get') {
      // Get.put(MyController())
      final type =
          node.typeArguments?.arguments.first.toSource() ??
          _inferTypeFromPut(node.argumentList.arguments.first);
      if (type != null) {
        nodes.add(
          ProviderDeclarationNode(
            providerType: 'Get.put',
            providedClass: type,
            filePath: filePath,
            offset: node.offset,
            length: node.length,
          ),
        );
      }
    } else if (name == 'Obx') {
      // Obx(() => ...) is technically a function/constructor invocation depending on implementation,
      // but often appears as a MethodInvocation if used without 'new'.
      nodes.add(
        ConsumerNode(
          consumedClass:
              'RxState', // Heuristic as Obx detects Rx usage automatically
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }

    super.visitMethodInvocation(node);
  }

  bool _isFollowedByMethodCall(MethodInvocation node) {
    final parent = node.parent;
    if (parent is MethodInvocation && parent.target == node) {
      return true;
    }
    if (parent is PropertyAccess && parent.target == node) {
      final grandParent = parent.parent;
      if (grandParent is MethodInvocation && grandParent.target == parent) {
        return true;
      }
    }
    return false;
  }

  String? _inferTypeFromPut(Expression expression) {
    if (expression is InstanceCreationExpression) {
      return expression.constructorName.type.name.lexeme;
    }
    if (expression is MethodInvocation && expression.target == null) {
      return expression.methodName.name;
    }
    return null;
  }

  String _inferObservableType(String? declaredType, String? initializer) {
    if (declaredType != null && declaredType.isNotEmpty) {
      if (declaredType == 'RxInt') return 'int';
      if (declaredType == 'RxDouble') return 'double';
      if (declaredType == 'RxBool') return 'bool';
      if (declaredType == 'RxString') return 'String';
      if (declaredType.startsWith('RxList<')) {
        return declaredType.replaceFirst('RxList<', 'List<');
      }
      if (declaredType.startsWith('RxMap<')) {
        return declaredType.replaceFirst('RxMap<', 'Map<');
      }
      final generic = RegExp(r'^Rx<(.+)>$').firstMatch(declaredType);
      if (generic != null) {
        return generic.group(1)!.trim();
      }
    }

    final normalized = _normalizeObservableInitializer(initializer);
    if (normalized == null) return 'dynamic';
    if (RegExp(r'^\d+$').hasMatch(normalized)) return 'int';
    if (RegExp(r'^\d+\.\d+$').hasMatch(normalized)) return 'double';
    if (normalized == 'true' || normalized == 'false') return 'bool';
    if ((normalized.startsWith("'") && normalized.endsWith("'")) ||
        (normalized.startsWith('"') && normalized.endsWith('"'))) {
      return 'String';
    }
    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      return 'List<dynamic>';
    }
    if (normalized.startsWith('{') && normalized.endsWith('}')) {
      return 'Map<dynamic, dynamic>';
    }
    return 'dynamic';
  }

  String? _normalizeObservableInitializer(String? initializer) {
    if (initializer == null) return null;
    return initializer.replaceFirst(RegExp(r'\.obs$'), '');
  }
}
