import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';

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
      final stateVariables = <String>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final metadata in member.metadata) {
            if (metadata.name.name == 'observable') {
              for (final variable in member.fields.variables) {
                stateVariables.add(variable.name.lexeme);
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
          final body = member.body.toSource();
          final returnType = member.returnType?.toSource() ?? 'void';
          final isAsync = member.body is BlockFunctionBody
              ? (member.body as BlockFunctionBody).keyword?.lexeme == 'async'
              : member.body is ExpressionFunctionBody
              ? (member.body as ExpressionFunctionBody).keyword?.lexeme ==
                    'async'
              : false;
          methods.add(
            MethodInfo(
              name: member.name.lexeme,
              callsNotifyListeners: isAction,
              bodySnippet: body,
              isAsync: isAsync,
              returnType: returnType,
            ),
          );
        }
      }

      nodes.add(
        LogicUnitNode(
          name: className,
          stateVariables: stateVariables,
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
    return NotifierType.stateNotifier;
  }
}
