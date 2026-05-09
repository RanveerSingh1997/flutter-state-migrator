void main() {
  final snippet = """
Consumer<CounterModel>(
  builder: (context, counter, child) {
    return Text('\${counter.count}');
  },
)""";

  // 1. Replace Consumer<Type>
  final consumerRegex = RegExp(r'Consumer<\w+>');
  print(snippet.replaceAll(consumerRegex, 'Consumer'));

  // 2. Find builder signature
  final builderRegex = RegExp(
    r'builder:\s*\(([^,]+),\s*([^,]+),\s*([^)]+)\)\s*\{',
  );
  final match = builderRegex.firstMatch(snippet);
  if (match != null) {
    final ctx = match.group(1);
    final val = match.group(2);
    final ch = match.group(3);
    print('Found params: $ctx, $val, $ch');

    // Create new builder signature
    final newBuilder =
        "builder: ($ctx, ref, $ch) {\n    final $val = ref.watch(counterModelProvider);";
    print(snippet.replaceFirst(match.group(0)!, newBuilder));
  }
}
