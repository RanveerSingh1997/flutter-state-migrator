import '../models/ir_models.dart';

/// Rewrites method bodies from mutable ChangeNotifier/BLoC style to immutable
/// Riverpod state-update style using regex-based pattern substitution.
///
/// Handles `.add`, `.addAll`, `.remove`, `.removeWhere`, `.clear`, assignment
/// (`=`, `+=`, `-=`), increment/decrement (`++`, `--`), null-coalescing assignment
/// (`??=`), and `notifyListeners()` / `emit()` removal.
class BodyTransformer {
  /// Transform a method body from ChangeNotifier mutation style to Riverpod
  /// state-update style.
  String transformBody(String body, List<FieldInfo> stateFields) {
    var transformed = body;
    final isSingleField = stateFields.length == 1;

    // Build a mapping rawName -> publicName for all state fields.
    final fieldMap = {for (final f in stateFields) f.rawName: f.publicName};

    for (final entry in fieldMap.entries) {
      final raw = entry.key;
      final pub = entry.value;

      // 1. Handle collection mutations (add/remove/clear)
      transformed = _rewriteCollectionMutations(
        transformed,
        raw,
        pub,
        fieldMap,
        isSingleField,
      );

      // 2. Handle numeric/boolean/generic mutations (=, +=, -=, ++, --, ??=)
      transformed = _rewriteFieldMutations(
        transformed,
        raw,
        pub,
        fieldMap,
        isSingleField,
      );
    }

    // 3. Clean up framework-specific calls
    transformed = transformed.replaceAll(
      RegExp(r'notifyListeners\(\);?\s*'),
      '',
    );
    transformed = transformed.replaceAll(RegExp(r'emit\([^;]*\);?\s*'), '');

    // 4. Merge adjacent copyWith calls for better readability
    if (!isSingleField) {
      transformed = _mergeAdjacentCopyWithStatements(transformed);
    }

    return transformed.replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
  }

  String _rewriteCollectionMutations(
    String source,
    String rawField,
    String stateField,
    Map<String, String> fieldMap,
    bool isSingleField,
  ) {
    final escaped = RegExp.escape(rawField);
    var transformed = source;

    // .add(item) -> state = state.copyWith(field: [...state.field, item])
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.add\\(([^;]+)\\);'),
      (match) {
        final item = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        if (isSingleField) {
          return 'state = [...state, $item];';
        }
        return 'state = state.copyWith($stateField: [...state.$stateField, $item]);';
      },
    );

    // .addAll(items) -> state = state.copyWith(field: [...state.field, ...items])
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.addAll\\(([^;]+)\\);'),
      (match) {
        final items = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        if (isSingleField) {
          return 'state = [...state, ...$items];';
        }
        return 'state = state.copyWith($stateField: [...state.$stateField, ...$items]);';
      },
    );

    // .remove(item) -> state = state.copyWith(field: state.field.where((e) => e != item).toList())
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.remove\\(([^;]+)\\);'),
      (match) {
        final item = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        if (isSingleField) {
          return 'state = state.where((e) => e != $item).toList();';
        }
        return 'state = state.copyWith($stateField: state.$stateField.where((e) => e != $item).toList());';
      },
    );

    // .removeWhere((item) => predicate)
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\.removeWhere\\(\\(([^)]+)\\)\\s*=>\\s*([^;]+)\\);'),
      (match) {
        final arg = match.group(1)!.trim();
        final body = _normalizeStateReferences(
          match.group(2)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        var inverted = body;
        if (body.contains('==')) {
          inverted = body.replaceAll('==', '!=');
        } else if (body.contains('!=')) {
          inverted = body.replaceAll('!=', '==');
        } else {
          inverted = '!($body)';
        }

        if (isSingleField) {
          return 'state = state.where(($arg) => $inverted).toList();';
        }
        return 'state = state.copyWith($stateField: state.$stateField.where(($arg) => $inverted).toList());';
      },
    );

    // .clear() -> state = state.copyWith(field: [])
    transformed = transformed.replaceAll(
      RegExp('$escaped\\.clear\\(\\);'),
      isSingleField
          ? 'state = [];'
          : 'state = state.copyWith($stateField: []);',
    );

    return transformed;
  }

  String _rewriteFieldMutations(
    String source,
    String rawField,
    String stateField,
    Map<String, String> fieldMap,
    bool isSingleField,
  ) {
    final escaped = RegExp.escape(rawField);
    var transformed = source;

    // Increment/Decrement
    transformed = transformed.replaceAllMapped(
      RegExp('(?:\\+\\+$escaped|$escaped\\+\\+)'),
      (_) => isSingleField
          ? 'state = state + 1'
          : 'state = state.copyWith($stateField: state.$stateField + 1)',
    );
    transformed = transformed.replaceAllMapped(
      RegExp('(?:--$escaped|$escaped--)'),
      (_) => isSingleField
          ? 'state = state - 1'
          : 'state = state.copyWith($stateField: state.$stateField - 1)',
    );

    // Compound Assignments (+=, -=, *=, /=)
    final operators = ['\\+=', '-=', '\\*=', '/='];
    for (final op in operators) {
      final cleanOp = op.replaceAll('\\', '');
      final mathOp = cleanOp.substring(0, 1);
      transformed = transformed.replaceAllMapped(
        RegExp('$escaped\\s*$op\\s*([^;]+);'),
        (match) {
          final delta = _normalizeStateReferences(
            match.group(1)!.trim(),
            fieldMap,
            isSingleField: isSingleField,
          );
          if (isSingleField) {
            return 'state = state $mathOp $delta;';
          }
          return 'state = state.copyWith($stateField: state.$stateField $mathOp $delta);';
        },
      );
    }

    // Null-aware assignment (??=)
    transformed = transformed.replaceAllMapped(
      RegExp('$escaped\\s*\\?\\?=\\s*([^;]+);'),
      (match) {
        final value = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        if (isSingleField) {
          return 'state = state ?? $value;';
        }
        return 'state = state.copyWith($stateField: state.$stateField ?? $value);';
      },
    );

    // Direct assignment (=)
    transformed = transformed.replaceAllMapped(
      RegExp('(?<![=!])$escaped\\s*=\\s*(?![=])([^;]+);'),
      (match) {
        final value = _normalizeStateReferences(
          match.group(1)!.trim(),
          fieldMap,
          isSingleField: isSingleField,
        );
        if (isSingleField) {
          return 'state = $value;';
        }
        return 'state = state.copyWith($stateField: $value);';
      },
    );

    return transformed;
  }

  /// Replaces internal references to other state fields within an expression.
  /// e.g., if we are updating 'total' and the expression is 'count * price',
  /// it becomes 'state.count * state.price'.
  String _normalizeStateReferences(
    String expression,
    Map<String, String> fieldMap, {
    required bool isSingleField,
  }) {
    var normalized = expression;
    for (final entry in fieldMap.entries) {
      final escaped = RegExp.escape(entry.key);
      // Negative lookbehind/lookahead to ensure we don't match sub-words or member access
      normalized = normalized.replaceAllMapped(
        RegExp('(?<![\\w.])$escaped(?!\\w)'),
        (_) => isSingleField ? 'state' : 'state.${entry.value}',
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

      // Extract field names from the copyWith call (e.g., "count: state.count + 1")
      final fieldNames = RegExp(
        r'(?:^|,\s*)([A-Za-z_]\w*)\s*:',
      ).allMatches(update).map((m) => m.group(1)!).toSet();

      // Only merge if we aren't updating the same field twice in one copyWith
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
}
