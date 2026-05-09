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
        final stateType = extendsClause.superclass.typeArguments?.arguments.last.toSource() ?? 'dynamic';
        
        final methods = <MethodInfo>[];
        for (final member in node.members) {
          if (member is MethodDeclaration) {
            final body = member.body.toSource();
            final callsEmit = body.contains('emit(');
            methods.add(MethodInfo(
              name: member.name.lexeme,
              callsNotifyListeners: callsEmit, // Map 'emit' to notifyListeners for IR consistency
              bodySnippet: body,
            ));
          }
        }

        nodes.add(LogicUnitNode(
          name: className,
          stateVariables: [stateType], // Use state type as a marker
          methods: methods,
          isNotifier: true,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ));
      }
    }
    super.visitClassDeclaration(node);
  }
}
