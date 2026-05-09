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

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final metadata in member.metadata) {
            if (metadata.name.name == 'observable') {
              for (final variable in member.fields.variables) {
                stateVariables.add(variable.name.lexeme);
              }
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
          methods.add(MethodInfo(
            name: member.name.lexeme,
            callsNotifyListeners: isAction,
            bodySnippet: body,
          ));
        }
      }

      nodes.add(LogicUnitNode(
        name: className,
        stateVariables: stateVariables,
        methods: methods,
        isNotifier: true,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.toSource();
    if (typeName == 'Observer') {
      nodes.add(ConsumerNode(
        consumedClass: 'MobXStore', // Heuristic for MobX Observer
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }
    super.visitInstanceCreationExpression(node);
  }
}
