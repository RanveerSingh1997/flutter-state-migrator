import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

void main() {
  const source = 'class A extends B {}';
  final result = parseString(content: source);
  final unit = result.unit;
  final clazz = unit.declarations.first as ClassDeclaration;
  final superclass = clazz.extendsClause!.superclass;
  print('Superclass type: ${superclass.runtimeType}');
  try {
    print('Name: ${(superclass as dynamic).name}');
    print('Name runtimeType: ${(superclass as dynamic).name.runtimeType}');
  } catch (e) {
    print('Name property missing: $e');
  }
}
