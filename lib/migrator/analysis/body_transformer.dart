class BodyTransformer {
  String transformBody(String body, List<String> stateFields) {
    String transformed = body;

    for (final field in stateFields) {
      // 1. Handle increment/decrement: _count++ -> state = state.copyWith(count: state.count + 1)
      final incrementPattern = RegExp('$field\\+\\+');
      if (incrementPattern.hasMatch(transformed)) {
        transformed = transformed.replaceAll(
          incrementPattern,
          'state = state.copyWith(${_stripLeadingUnderscore(field)}: state.${_stripLeadingUnderscore(field)} + 1)',
        );
      }

      final decrementPattern = RegExp('$field--');
      if (decrementPattern.hasMatch(transformed)) {
        transformed = transformed.replaceAll(
          decrementPattern,
          'state = state.copyWith(${_stripLeadingUnderscore(field)}: state.${_stripLeadingUnderscore(field)} - 1)',
        );
      }

      // 2. Handle simple assignment: _count = 10 -> state = state.copyWith(count: 10)
      final assignmentPattern = RegExp('$field\\s*=\\s*([^;]+)');
      if (assignmentPattern.hasMatch(transformed)) {
        transformed = transformed.replaceAllMapped(assignmentPattern, (match) {
          final newValue = match.group(1)?.trim();
          return 'state = state.copyWith(${_stripLeadingUnderscore(field)}: $newValue)';
        });
      }
    }

    // 3. Remove notifyListeners() or emit() calls as they are no longer needed
    transformed = transformed.replaceAll(RegExp(r'notifyListeners\(\);?'), '');
    transformed = transformed.replaceAll(RegExp(r'emit\(.+?\);?'), '');

    return transformed;
  }

  String _stripLeadingUnderscore(String name) {
    return name.startsWith('_') ? name.substring(1) : name;
  }
}
