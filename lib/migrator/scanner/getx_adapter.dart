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

      bool isFamilyCandidate = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final source = variable.toSource();
            if (source.contains('.obs')) {
              stateVariables.add(variable.name.lexeme);
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
          final body = member.body.toSource();
          final returnType = member.returnType?.toSource() ?? 'void';
          final isAsync = member.body is BlockFunctionBody
              ? (member.body as BlockFunctionBody).keyword?.lexeme == 'async'
              : member.body is ExpressionFunctionBody
                  ? (member.body as ExpressionFunctionBody).keyword?.lexeme ==
                      'async'
                  : false;
          methods.add(MethodInfo(
            name: member.name.lexeme,
            callsNotifyListeners: body.contains('.value ='),
            bodySnippet: body,
            isAsync: isAsync,
            returnType: returnType,
          ));
        }
      }

      nodes.add(LogicUnitNode(
        name: className,
        stateVariables: stateVariables,
        methods: methods,
        isNotifier: true,
        notifierType: _detectNotifierType(methods),
        isFamilyCandidate: isFamilyCandidate,
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

  NotifierType _detectNotifierType(List<MethodInfo> methods) {
    for (final m in methods) {
      if (m.returnType.startsWith('Stream<')) return NotifierType.streamNotifier;
    }
    for (final m in methods) {
      if (m.isAsync || m.returnType.startsWith('Future<')) {
        return NotifierType.asyncNotifier;
      }
    }
    return NotifierType.stateNotifier;
  }
}
