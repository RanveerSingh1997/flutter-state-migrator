import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';

class ProviderAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  ProviderAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Detect ChangeNotifier classes
    final extendsClause = node.extendsClause;
    if (extendsClause != null && extendsClause.superclass.name2.lexeme == 'ChangeNotifier') {
      final className = node.name.lexeme;
      final stateVariables = <String>[];
      final methods = <String>[];
      
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            stateVariables.add(variable.name.lexeme);
          }
        } else if (member is MethodDeclaration) {
          if (member.name.lexeme != 'dispose' && !member.name.lexeme.startsWith('_')) {
            methods.add(member.name.lexeme);
          }
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
    } else if (extendsClause != null && extendsClause.superclass.name2.lexeme == 'StatelessWidget') {
      final className = node.name.lexeme;
      int buildMethodOffset = -1;
      
      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'build') {
           buildMethodOffset = member.offset;
        }
      }

      nodes.add(WidgetNode(
        widgetName: className,
        widgetType: 'StatelessWidget',
        buildMethodOffset: buildMethodOffset,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    print('InstanceCreation: \$typeName | Source: \${node.constructorName.type.toSource()}');
    
    // Detect ChangeNotifierProvider(...)
    if (typeName == 'ChangeNotifierProvider') {
       String? providedClass;
       for (final arg in node.argumentList.arguments) {
         if (arg is NamedExpression && arg.name.label.name == 'create') {
           if (arg.expression is FunctionExpression) {
             final func = arg.expression as FunctionExpression;
             final body = func.body;
             if (body is ExpressionFunctionBody) {
                if (body.expression is InstanceCreationExpression) {
                  providedClass = (body.expression as InstanceCreationExpression).constructorName.type.name2.lexeme;
                }
             }
           }
         }
       }
       nodes.add(ProviderDeclarationNode(
         providerType: typeName,
         providedClass: providedClass ?? 'Unknown',
         filePath: filePath,
         offset: node.offset,
         length: node.length,
       ));
    }
    
    // Detect Consumer<T>(...)
    if (typeName == 'Consumer') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(ConsumerNode(consumedClass: consumedType, filePath: filePath, offset: node.offset, length: node.length));
      }
    }

    // Detect MultiProvider(...)
    if (typeName == 'MultiProvider') {
      nodes.add(MultiProviderNode(filePath: filePath, offset: node.offset, length: node.length));
    }

    // Detect Selector<T, R>(...)
    if (typeName == 'Selector') {
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.length >= 2) {
        final consumedType = typeArgs.arguments[0].beginToken.lexeme;
        final selectedType = typeArgs.arguments[1].beginToken.lexeme;
        nodes.add(SelectorNode(
          consumedClass: consumedType, 
          selectedType: selectedType,
          filePath: filePath, 
          offset: node.offset, 
          length: node.length
        ));
      }
    }
    
    // Detect FutureProvider / StreamProvider(...)
    if (typeName == 'FutureProvider' || typeName == 'StreamProvider') {
      String providedType = 'Unknown';
      final typeArgs = node.constructorName.type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        providedType = typeArgs.arguments.first.beginToken.lexeme;
      }
      nodes.add(AsyncProviderNode(
        providerType: typeName,
        providedType: providedType,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }
    
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    // Detect ChangeNotifierProvider(...) as MethodInvocation
    if (methodName == 'ChangeNotifierProvider') {
       String? providedClass;
       for (final arg in node.argumentList.arguments) {
         if (arg is NamedExpression && arg.name.label.name == 'create') {
           if (arg.expression is FunctionExpression) {
             final func = arg.expression as FunctionExpression;
             final body = func.body;
             if (body is ExpressionFunctionBody) {
                // Could be MethodInvocation or InstanceCreationExpression
                if (body.expression is MethodInvocation) {
                  providedClass = (body.expression as MethodInvocation).methodName.name;
                } else if (body.expression is InstanceCreationExpression) {
                  providedClass = (body.expression as InstanceCreationExpression).constructorName.type.name2.lexeme;
                }
             }
           }
         }
       }
       nodes.add(ProviderDeclarationNode(
         providerType: methodName,
         providedClass: providedClass ?? 'Unknown',
         filePath: filePath,
         offset: node.offset,
         length: node.length,
       ));
    }

    // Detect Provider.of<T>(context)
    if (node.target != null && node.target!.beginToken.lexeme == 'Provider' && node.methodName.name == 'of') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(ProviderOfNode(consumedClass: consumedType, filePath: filePath, offset: node.offset, length: node.length));
      }
    }
    
    // Detect context.read<T>() and context.watch<T>()
    if (node.target != null && node.target!.beginToken.lexeme == 'context' && 
        (node.methodName.name == 'read' || node.methodName.name == 'watch')) {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(ProviderOfNode(consumedClass: consumedType, filePath: filePath, offset: node.offset, length: node.length)); // Can reuse ProviderOfNode or create new one
      }
    }
    // Detect Consumer<T>(...) as MethodInvocation (happens without full type resolution)
    if (node.methodName.name == 'Consumer') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        final consumedType = typeArgs.arguments.first.beginToken.lexeme;
        nodes.add(ConsumerNode(consumedClass: consumedType, filePath: filePath, offset: node.offset, length: node.length));
      }
    }

    // Detect MultiProvider(...)
    if (node.methodName.name == 'MultiProvider') {
      nodes.add(MultiProviderNode(filePath: filePath, offset: node.offset, length: node.length));
    }

    // Detect Selector<T, R>(...)
    if (node.methodName.name == 'Selector') {
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.length >= 2) {
        final consumedType = typeArgs.arguments[0].beginToken.lexeme;
        final selectedType = typeArgs.arguments[1].beginToken.lexeme;
        nodes.add(SelectorNode(
          consumedClass: consumedType, 
          selectedType: selectedType,
          filePath: filePath, 
          offset: node.offset, 
          length: node.length
        ));
      }
    }

    // Detect FutureProvider / StreamProvider(...)
    if (node.methodName.name == 'FutureProvider' || node.methodName.name == 'StreamProvider') {
      String providedType = 'Unknown';
      final typeArgs = node.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        providedType = typeArgs.arguments.first.beginToken.lexeme;
      }
      nodes.add(AsyncProviderNode(
        providerType: node.methodName.name,
        providedType: providedType,
        filePath: filePath,
        offset: node.offset,
        length: node.length,
      ));
    }

    super.visitMethodInvocation(node);
  }
}
