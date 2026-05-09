void main() {
  final snippet = '''
              Consumer<String>(
                builder: (context, data, child) {
                  return Text(data);
                },
              ),
''';
  final builderRegex = RegExp(
    r'builder:\s*\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)\s*\{',
    multiLine: true,
  );
  final builderMatch = builderRegex.firstMatch(snippet);
  if (builderMatch != null) {
    print('Match found!');
    print('Group 1: ${builderMatch.group(1)}');
    print('Group 2: ${builderMatch.group(2)}');
    print('Group 3: ${builderMatch.group(3)}');
  } else {
    print('No match found');
  }
}
