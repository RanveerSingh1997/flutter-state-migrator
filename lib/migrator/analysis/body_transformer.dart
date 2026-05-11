class BodyTransformer {
  String transformBody(String body, List<String> stateFields) {
    var transformed = body;
    final fieldMap = {
      for (final field in stateFields) field: _stripLeadingUnderscore(field),
    };

    for (final entry in fieldMap.entries) {
      transformed = _rewriteListMutation(
        transformed,
        entry.key,
        entry.value,
        fieldMap,
      );
      transformed = _rewriteFieldMutation(
        transformed,
        entry.key,
        entry.value,
        fieldMap,
      );
    }

    transformed = transformed.replaceAll(
      RegExp(r'notifyListeners\(\);?\s*'),
      '',
    );
    transformed = transformed.replaceAll(RegExp(r'emit\([^;]*\);?\s*'), '');
    transformed = _mergeAdjacentCopyWithStatements(transformed);

    return transformed.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
  }

  String _rewriteListMutation(
    String source,
    String rawField,
    String stateField,
    Map<String, String> fieldMap,
  ) {
    final escaped = RegExp.escape(rawField);
    var transformed = source;

    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.add\\(([^;]+)\\);'),
      (match) {
        final item = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: [...state.$stateField, $item]);';
      },
    );

    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.remove\\(([^;]+)\\);'),
      (match) {
        final item = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: state.$stateField.where((entry) => entry != $item).toList());';
      },
    );

    return transformed;
  }

  String _rewriteFieldMutation(
    String source,
    String rawField,
    String stateField,
    Map<String, String> fieldMap,
  ) {
    final escaped = RegExp.escape(rawField);
    var transformed = source;

    transformed = transformed.replaceAllMapped(
      RegExp('(?:\\+\\+$escaped|$escaped\\+\\+)'),
      (_) => 'state = state.copyWith($stateField: state.$stateField + 1)',
    );
    transformed = transformed.replaceAllMapped(
      RegExp('(?:--$escaped|$escaped--)'),
      (_) => 'state = state.copyWith($stateField: state.$stateField - 1)',
    );
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\s*\\+=\\s*([^;]+);'),
      (match) {
        final delta = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: state.$stateField + $delta);';
      },
    );
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\s*-=\\s*([^;]+);'),
      (match) {
        final delta = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: state.$stateField - $delta);';
      },
    );
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\s*\\?\\?=\\s*([^;]+);'),
      (match) {
        final value = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: state.$stateField ?? $value);';
      },
    );
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\s*=\\s*(?![=])([^;]+);'),
      (match) {
        final value = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
        );
        return 'state = state.copyWith($stateField: $value);';
      },
    );

    return transformed;
  }

  String _normalizeStateReferences(
    String expression,
    Map<String, String> fieldMap,
  ) {
    var normalized = expression;
    for (final entry in fieldMap.entries) {
      final escaped = RegExp.escape(entry.key);
      normalized = normalized.replaceAllMapped(
        RegExp('(?<![\\w.])$escaped(?!\\w)'),
        (_) => 'state.${entry.value}',
      );
    }
    return normalized;
  }

  String _mergeAdjacentCopyWithStatements(String body) {
    final lines = body.split('\n');
    final merged = <String>[];
    var pendingIndent = '';
    final pendingUpdates = <String>[];
    final seenFields = <String>{};

    void flushPending() {
      if (pendingUpdates.isEmpty) return;
      merged.add(
        '${pendingIndent}state = state.copyWith(${pendingUpdates.join(', ')});',
      );
      pendingIndent = '';
      pendingUpdates.clear();
      seenFields.clear();
    }

    for (final line in lines) {
      final match = RegExp(
        r'^(\s*)state = state\.copyWith\((.+)\);\s*$',
      ).firstMatch(line);
      if (match == null) {
        flushPending();
        merged.add(line);
        continue;
      }

      final indent = match.group(1)!;
      final update = match.group(2)!.trim();
      final fieldNames = RegExp(
        r'(^|,\s*)([A-Za-z_]\w*)\s*:',
      ).allMatches(update).map((m) => m.group(2)!).toSet();
      final canMerge =
          pendingUpdates.isEmpty ||
          (indent == pendingIndent &&
              seenFields.intersection(fieldNames).isEmpty);

      if (!canMerge) {
        flushPending();
      }

      pendingIndent = indent;
      pendingUpdates.add(update);
      seenFields.addAll(fieldNames);
    }

    flushPending();
    return merged.join('\n');
  }

  String _stripLeadingUnderscore(String name) {
    return name.startsWith('_') ? name.substring(1) : name;
  }
}
