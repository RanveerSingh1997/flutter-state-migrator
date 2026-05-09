class ImportManager {
  /// Adds required Riverpod imports and optionally removes unused Provider imports.
  String processImports(String content, {bool cleanProvider = true}) {
    String newContent = content;

    // 1. Add Riverpod imports if needed
    final needsRiverpod =
        newContent.contains('ConsumerWidget') ||
        newContent.contains('ConsumerState') ||
        newContent.contains('ProviderScope') ||
        newContent.contains('ref.watch') ||
        newContent.contains('ref.read');

    final hasRiverpodImport = newContent.contains(
      "import 'package:flutter_riverpod/flutter_riverpod.dart'",
    );

    if (needsRiverpod && !hasRiverpodImport) {
      // Find the last import and insert after it
      final lastImportIdx = newContent.lastIndexOf(
        RegExp(r'^import .*;$', multiLine: true),
      );
      if (lastImportIdx != -1) {
        final lineEndIdx = newContent.indexOf('\n', lastImportIdx);
        newContent = newContent.replaceRange(
          lineEndIdx + 1,
          lineEndIdx + 1,
          "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
        );
      } else {
        // No imports found, prepend to top
        newContent =
            "import 'package:flutter_riverpod/flutter_riverpod.dart';\n" +
            newContent;
      }
    }

    // 2. Remove Provider import if requested and no longer used
    if (cleanProvider) {
      final providerUsage = RegExp(
        r'\bProvider\b|\bConsumer\b|\bSelector\b|\bMultiProvider\b',
      ).allMatches(newContent);
      // Filter out comments and imports themselves
      bool trulyUsed = false;
      for (final match in providerUsage) {
        final lineStart = newContent.lastIndexOf('\n', match.start) + 1;
        final lineEnd = newContent.indexOf('\n', match.start);
        final line = newContent.substring(
          lineStart,
          lineEnd != -1 ? lineEnd : newContent.length,
        );
        if (!line.trim().startsWith('import') &&
            !line.trim().startsWith('//')) {
          trulyUsed = true;
          break;
        }
      }

      if (!trulyUsed) {
        newContent = newContent.replaceAll(
          RegExp(r"import 'package:provider/provider.dart';\n?"),
          "",
        );
      }
    }

    return newContent;
  }
}
