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
    bool isMobXStore = false;
    for (final member in node.members) {
      if (member is FieldDeclaration) {
        for (final metadata in member.metadata) {
          if (metadata.name.name == 'observable') {
            isMobXStore = true;
            break;
          }
        }
      }
    }

    if (isMobXStore) {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final metadata in member.metadata) {
            if (metadata.name.name == 'observable') {
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
            if (metadata.name.name == 'action') {
              isAction = true;
              break;
            }
          }
          methods.add(buildMethodInfo(member, callsNotifyListeners: isAction));
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
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
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

  NotifierType _detectNotifierType(List<MethodInfo> methods) {
    for (final m in methods) {
      if (m.returnType.startsWith('Stream<'))
        return NotifierType.streamNotifier;
    }
    for (final m in methods) {
      if (m.isAsync || m.returnType.startsWith('Future<')) {
        return NotifierType.asyncNotifier;
      }
    }
    return NotifierType.notifier;
  }
}
