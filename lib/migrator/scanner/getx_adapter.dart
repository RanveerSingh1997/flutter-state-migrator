import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';

class GetXAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  GetXAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null && extendsClause.superclass.name.lexeme == 'GetxController') {
      final className = node.name.lexeme;
      final stateVariables = <String>[];
      final methods = <MethodInfo>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final source = variable.toSource();
            if (source.contains('.obs')) {
              stateVariables.add(variable.name.lexeme);
            }
          }
        } else if (member is MethodDeclaration) {
          final body = member.body.toSource();
          methods.add(MethodInfo(
            name: member.name.lexeme,
            callsNotifyListeners: body.contains('.value ='), // Mapping GetX observable update
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
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'find' && node.target?.toSource() == 'Get') {
      // Get.find<T>()
      final type = node.typeArguments?.arguments.first.toSource() ?? 'dynamic';
      nodes.add(ProviderOfNode(
        consumedClass: type,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }
    super.visitMethodInvocation(node);
  }
}
