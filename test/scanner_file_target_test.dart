import 'dart:io';

import 'package:flutter_state_migrator/migrator/scanner/ast_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AstScanner can scan a single file target', () {
    final dir = Directory.systemTemp.createTempSync('scanner_file_target_');
    addTearDown(() => dir.deleteSync(recursive: true));

    final file = File('${dir.path}/counter.dart')
      ..writeAsStringSync('''
class CounterModel extends ChangeNotifier {
  int count = 0;
}
''');

    final nodes = AstScanner(file.path).scanProject();

    expect(nodes, isNotEmpty);
  });
}
