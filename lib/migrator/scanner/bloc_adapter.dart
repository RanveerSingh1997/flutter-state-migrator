import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';

class BlocAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  BlocAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
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
        for (final member in node.members) {
          if (member is ConstructorDeclaration) {
            for (final param in member.parameters.parameters) {
              final paramName = param.name?.lexeme ?? '';
              if (paramName != 'key') {
                isFamilyCandidate = true;
                break;
              }
            }
          } else if (member is MethodDeclaration) {
            final body = member.body.toSource();
            final callsEmit = body.contains('emit(');
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
                callsNotifyListeners: callsEmit,
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
            stateFields: [FieldInfo(rawName: 'state', type: stateType)],
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
    }
    super.visitClassDeclaration(node);
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
