import 'package:analyzer/dart/ast/ast.dart';

import '../models/ir_models.dart';

MethodInfo buildMethodInfo(
  MethodDeclaration member, {
  required bool callsNotifyListeners,
}) {
  final body = member.body.toSource();
  final returnType = member.returnType?.toSource() ?? 'void';
  final isAsync = member.body is BlockFunctionBody
      ? (member.body as BlockFunctionBody).keyword?.lexeme == 'async'
      : member.body is ExpressionFunctionBody
      ? (member.body as ExpressionFunctionBody).keyword?.lexeme == 'async'
      : false;
  final isGetter = member.isGetter;

  final params = <ParamInfo>[];
  if (!isGetter && member.parameters != null) {
    for (final param in member.parameters!.parameters) {
      final paramName = param.name?.lexeme ?? '';
      var paramType = 'dynamic';
      if (param is SimpleFormalParameter) {
        paramType = param.type?.toSource() ?? 'dynamic';
      } else if (param is DefaultFormalParameter) {
        final inner = param.parameter;
        if (inner is SimpleFormalParameter) {
          paramType = inner.type?.toSource() ?? 'dynamic';
        }
      }
      if (paramName.isNotEmpty) {
        params.add(ParamInfo(name: paramName, type: paramType));
      }
    }
  }

  return MethodInfo(
    name: member.name.lexeme,
    callsNotifyListeners: callsNotifyListeners,
    bodySnippet: body,
    isAsync: isAsync,
    returnType: returnType,
    isGetter: isGetter,
    parameters: params,
  );
}
