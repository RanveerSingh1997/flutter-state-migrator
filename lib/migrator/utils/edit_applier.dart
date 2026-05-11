import '../generator/riverpod_transformer.dart';

/// Applies a set of [TextEdit]s to [source] safely, resolving overlaps by
/// preferring the edit with the smaller (outer/parent) offset.
///
/// Algorithm:
///   1. Sort edits ascending by offset so outer edits are seen first.
///   2. Walk through and claim non-overlapping ranges; later edits whose
///      range overlaps an already-claimed range are skipped.
///   3. Re-sort accepted edits descending for application, so higher-offset
///      edits are applied first to avoid index-shift errors.
String applyEdits(String source, List<TextEdit> edits) {
  if (edits.isEmpty) return source;

  final sortedAsc = List<TextEdit>.from(edits)
    ..sort((a, b) {
      final cmp = a.offset.compareTo(b.offset);
      // When offsets are equal, prefer the edit that covers more (outer edit).
      return cmp != 0 ? cmp : b.length.compareTo(a.length);
    });

  // (start, end) exclusive ranges that are already claimed.
  final claimed = <(int, int)>[];
  final accepted = <TextEdit>[];

  for (final edit in sortedAsc) {
    final end = edit.offset + edit.length;
    final overlaps = claimed.any((r) => edit.offset < r.$2 && end > r.$1);
    if (!overlaps) {
      claimed.add((edit.offset, end));
      accepted.add(edit);
    }
  }

  // Apply in descending offset order to avoid index shifts.
  accepted.sort((a, b) => b.offset.compareTo(a.offset));
  var result = source;
  for (final edit in accepted) {
    result = result.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
  return result;
}
