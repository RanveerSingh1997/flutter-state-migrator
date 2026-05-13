import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

class MobXAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  MobXAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final classBody = node.body;
    if (classBody is! BlockClassBody) {
      super.visitClassDeclaration(node);
      return;
    }

    bool isMobXStore = false;
    // Also check for abstract classes ending in '_Store' or with 'Store' mixin
    // but the most reliable way is checking for annotations.
    for (final member in classBody.members) {
      if (member is FieldDeclaration) {
        for (final metadata in member.metadata) {
          final name = metadata.name.toSource();
          if (name == 'observable' || name == 'computed') {
            isMobXStore = true;
            break;
          }
        }
      }
      if (isMobXStore) break;
    }

    if (isMobXStore) {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in classBody.members) {
        if (member is FieldDeclaration) {
          bool hasObservable = false;
          for (final metadata in member.metadata) {
            if (metadata.name.toSource() == 'observable') {
              hasObservable = true;
              break;
            }
          }
          if (hasObservable) {
            for (final variable in member.fields.variables) {
              stateFields.add(
                FieldInfo(
                  rawName: variable.name.lexeme,
                  type: member.fields.type?.toSource() ?? 'dynamic',
                  initializer: variable.initializer?.toSource(),
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
          bool isAction = false;
          for (final metadata in member.metadata) {
            if (metadata.name.toSource() == 'action') {
              isAction = true;
              break;
            }
          }
          // We capture all methods, but mark if they are actions (callsNotifyListeners equivalent)
          methods.add(buildMethodInfo(member, callsNotifyListeners: isAction));
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
    if (typeName == 'Observer') {
      nodes.add(
        ConsumerNode(
          consumedClass: 'MobXStore', // Heuristic for MobX Observer
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }
    super.visitInstanceCreationExpression(node);
  }
}
