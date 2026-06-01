import '../models/ir_models.dart';

/// Annotates method bodies with structured migration hints without rewriting them.
///
/// The previous approach used regex substitution which corrupted string literals,
/// multi-line expressions, and chained calls. This implementation preserves the
/// original body verbatim and prepends a `// TODO(Migrator):` comment block
/// that lists each detected mutation pattern and its Riverpod equivalent.
///
/// Developers apply the pattern mechanically; the comment is the contract.
class BodyTransformer {
  /// Returns the body with a migration hint comment prepended.
  ///
  /// The original source is preserved exactly — no rewrites are performed.
  /// [stateFields] are used to detect which field mutations need migration.
  String transformBody(String body, List<FieldInfo> stateFields) {
    if (stateFields.isEmpty) return body;

    final hints = <String>[];

    final isSingleField = stateFields.length == 1;

    for (final field in stateFields) {
      final raw = field.rawName;
      final pub = field.publicName;
      final stateExpr = isSingleField ? 'state' : 'state.$pub';

      // Detect collection mutations
      if (RegExp('${RegExp.escape(raw)}\\.add\\(').hasMatch(body)) {
        final newVal = isSingleField
            ? '[...state, item]'
            : 'state.copyWith($pub: [...state.$pub, item])';
        hints.add('  //   $raw.add(item) → state = $newVal;');
      }
      if (RegExp('${RegExp.escape(raw)}\\.addAll\\(').hasMatch(body)) {
        final newVal = isSingleField
            ? '[...state, ...items]'
            : 'state.copyWith($pub: [...state.$pub, ...items])';
        hints.add('  //   $raw.addAll(items) → state = $newVal;');
      }
      if (RegExp('${RegExp.escape(raw)}\\.remove\\(').hasMatch(body)) {
        final newVal = isSingleField
            ? 'state.where((e) => e != item).toList()'
            : 'state.copyWith($pub: state.$pub.where((e) => e != item).toList())';
        hints.add('  //   $raw.remove(item) → state = $newVal;');
      }
      if (RegExp('${RegExp.escape(raw)}\\.removeWhere\\(').hasMatch(body)) {
        hints.add(
          '  //   $raw.removeWhere(test) → '
          'state = ${isSingleField ? "state.where((e) => !test(e)).toList()" : "state.copyWith($pub: state.$pub.where((e) => !test(e)).toList())"};',
        );
      }
      if (RegExp('${RegExp.escape(raw)}\\.clear\\(\\)').hasMatch(body)) {
        hints.add(
          '  //   $raw.clear() → state = ${isSingleField ? "const []" : "state.copyWith($pub: const [])"};',
        );
      }

      // Detect scalar mutations
      if (RegExp('(?:\\+\\+${RegExp.escape(raw)}|${RegExp.escape(raw)}\\+\\+)').hasMatch(body)) {
        hints.add('  //   $raw++ → state = $stateExpr + 1;');
      }
      if (RegExp('(?:--${RegExp.escape(raw)}|${RegExp.escape(raw)}--)').hasMatch(body)) {
        hints.add('  //   $raw-- → state = $stateExpr - 1;');
      }
      if (RegExp('${RegExp.escape(raw)}\\s*\\+=').hasMatch(body)) {
        hints.add('  //   $raw += x → state = $stateExpr + x;');
      }
      if (RegExp('${RegExp.escape(raw)}\\s*-=').hasMatch(body)) {
        hints.add('  //   $raw -= x → state = $stateExpr - x;');
      }
      if (RegExp('${RegExp.escape(raw)}\\s*=(?![=>])').hasMatch(body)) {
        hints.add(
          isSingleField
              ? '  //   $raw = x → state = x;'
              : '  //   $raw = x → state = state.copyWith($pub: x);',
        );
      }
    }

    // Detect framework cleanup
    if (body.contains('notifyListeners()')) {
      hints.add('  //   remove notifyListeners() calls entirely');
    }
    if (RegExp(r'\bemit\(').hasMatch(body)) {
      hints.add('  //   emit(x) → state = x;');
    }

    if (hints.isEmpty) return body;

    final hintBlock =
        '  // TODO(Migrator): convert mutable state writes to Riverpod:\n'
        '${hints.join('\n')}\n';

    // Preserve the original body verbatim — strip only the outer braces so the
    // hint is prepended inside the method body.
    final trimmed = body.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      return '{\n$hintBlock$inner}';
    }

    // Arrow body or unusual shape — just prepend as a block comment.
    return '{\n$hintBlock  // Original: $trimmed\n}';
  }
}
