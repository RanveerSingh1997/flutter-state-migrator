import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import '../models/ir_models.dart';
import 'scanner_utils.dart';

class GetXAdapter extends RecursiveAstVisitor<void> {
  final String filePath;
  final List<ProviderNode> nodes = [];

  GetXAdapter(this.filePath);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause != null &&
        extendsClause.superclass.name.lexeme == 'GetxController') {
      final className = node.name.lexeme;
      final stateFields = <FieldInfo>[];
      final methods = <MethodInfo>[];

      bool isFamilyCandidate = false;
      for (final member in node.members) {
        if (member is FieldDeclaration) {
          for (final variable in member.fields.variables) {
            final source = variable.toSource();
            if (source.contains('.obs')) {
              stateFields.add(
                FieldInfo(
                  rawName: variable.name.lexeme,
                  type: _inferObservableType(
                    member.fields.type?.toSource(),
                    variable.initializer?.toSource(),
                  ),
                  initializer: _normalizeObservableInitializer(
                    variable.initializer?.toSource(),
                  ),
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
          methods.add(
            buildMethodInfo(
              member,
              callsNotifyListeners: member.body.toSource().contains('.value ='),
            ),
          );
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
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'find' && node.target?.toSource() == 'Get') {
      // Get.find<T>()
      final type = node.typeArguments?.arguments.first.toSource() ?? 'dynamic';
      nodes.add(
        ProviderOfNode(
          consumedClass: type,
          filePath: filePath,
          offset: node.offset,
          length: node.length,
        ),
      );
    }
    super.visitMethodInvocation(node);
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

  String _inferObservableType(String? declaredType, String? initializer) {
    if (declaredType != null && declaredType.isNotEmpty) {
      if (declaredType == 'RxInt') return 'int';
      if (declaredType == 'RxDouble') return 'double';
      if (declaredType == 'RxBool') return 'bool';
      if (declaredType == 'RxString') return 'String';
      if (declaredType.startsWith('RxList<')) {
        return declaredType.replaceFirst('RxList<', 'List<');
      }
      if (declaredType.startsWith('RxMap<')) {
        return declaredType.replaceFirst('RxMap<', 'Map<');
      }
      final generic = RegExp(r'^Rx<(.+)>$').firstMatch(declaredType);
      if (generic != null) {
        return generic.group(1)!.trim();
      }
    }

    final normalized = _normalizeObservableInitializer(initializer);
    if (normalized == null) return 'dynamic';
    if (RegExp(r'^\d+$').hasMatch(normalized)) return 'int';
    if (RegExp(r'^\d+\.\d+$').hasMatch(normalized)) return 'double';
    if (normalized == 'true' || normalized == 'false') return 'bool';
    if ((normalized.startsWith("'") && normalized.endsWith("'")) ||
        (normalized.startsWith('"') && normalized.endsWith('"'))) {
      return 'String';
    }
    if (normalized.startsWith('[') && normalized.endsWith(']')) {
      return 'List<dynamic>';
    }
    if (normalized.startsWith('{') && normalized.endsWith('}')) {
      return 'Map<dynamic, dynamic>';
    }
    return 'dynamic';
  }

  String? _normalizeObservableInitializer(String? initializer) {
    if (initializer == null) return null;
    return initializer.replaceFirst(RegExp(r'\.obs$'), '');
  }
}
