import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../models/ir_models.dart';
import 'scanner_utils.dart';

/// AST visitor that detects MobX store patterns in Dart source.
///
/// Identifies classes as MobX stores by the presence of `@observable` or
/// `@computed` field annotations, then emits a [LogicUnitNode] with all
/// annotated fields captured as state. [ConsumerNode] is emitted for
/// `Observer` widgets.
class MobXAdapter extends RecursiveAstVisitor<void> {
  /// Absolute path to the source file being visited.
  final String filePath;

  /// IR nodes detected during the visitation.
  final List<ProviderNode> nodes = [];

  /// Creates a [MobXAdapter] for the source file at [filePath].
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
      final className = node.namePart.typeName.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in classBody.members) {
        if (member is FieldDeclaration) {
          bool hasObservable = false;
          bool hasComputed = false;
          for (final metadata in member.metadata) {
            final name = metadata.name.toSource();
            if (name == 'observable') hasObservable = true;
            if (name == 'computed') hasComputed = true;
          }
          if (hasObservable || hasComputed) {
            for (final variable in member.fields.variables) {
              // @computed fields are getters in MobX but stored as late fields;
              // mark them with a `// computed` initializer hint so the
              // transformer can emit a derived Provider instead of a state field.
              stateFields.add(
                FieldInfo(
                  rawName: variable.name.lexeme,
                  type: member.fields.type?.toSource() ?? 'dynamic',
                  initializer: hasComputed
                      ? (variable.initializer?.toSource() ?? '/* computed */')
                      : variable.initializer?.toSource(),
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
