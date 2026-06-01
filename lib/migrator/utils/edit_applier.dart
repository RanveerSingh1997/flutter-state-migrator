import 'dart:io';

import '../generator/riverpod_transformer.dart';

/// Applies a set of [TextEdit]s to [source] safely, resolving overlaps by
/// preferring the edit with the smaller (outer/parent) offset.
///
/// Algorithm:
///   1. Sort edits ascending by offset so outer edits are seen first.
///      Pure insertions (length == 0) at the same offset as a replacement are
///      sorted BEFORE the replacement so they are always accepted.
///   2. Walk through and claim non-overlapping ranges. Pure insertions (length
///      == 0) are NEVER treated as overlapping — they occupy no range and
///      can always be applied alongside content replacements at the same offset.
///   3. Re-sort accepted edits descending for application so higher-offset
///      edits are applied first to avoid index-shift errors.
///   4. When a non-zero edit is skipped due to overlap a warning is written to
///      stderr so the problem is visible in the CLI output.
String applyEdits(String source, List<TextEdit> edits) {
  if (edits.isEmpty) return source;

  final sortedAsc = List<TextEdit>.from(edits)
    ..sort((a, b) {
      final cmp = a.offset.compareTo(b.offset);
      if (cmp != 0) return cmp;
      // At the same offset: pure insertions come first so they are always
      // accepted before content-replacing edits claim the range.
      if (a.length == 0 && b.length != 0) return -1;
      if (b.length == 0 && a.length != 0) return 1;
      // Among content replacements: prefer the larger (outer) edit.
      return b.length.compareTo(a.length);
    });

  // (start, end) exclusive ranges claimed by accepted content-replacing edits.
  final claimed = <(int, int)>[];
  final accepted = <TextEdit>[];

  for (final edit in sortedAsc) {
    // Pure insertions occupy no range — they can never truly overlap with a
    // content-replacing edit and are always accepted.
    if (edit.length == 0) {
      accepted.add(edit);
      continue;
    }

    final end = edit.offset + edit.length;
    final overlaps = claimed.any((r) => edit.offset < r.$2 && end > r.$1);
    if (!overlaps) {
      claimed.add((edit.offset, end));
      accepted.add(edit);
    } else {
      stderr.writeln(
        '[Migrator] WARNING: Edit at offset ${edit.offset} '
        '(len ${edit.length}) skipped due to overlap with an earlier edit.',
      );
    }
  }

  // Apply in descending offset order to avoid index shifts.
  // At the same offset, apply replacements BEFORE insertions: a replacement
  // rewrites [offset, offset+len] and the insertion then prepends at the new
  // offset 0, producing: `<insertion><replacement>`.
  accepted.sort((a, b) {
    final cmp = b.offset.compareTo(a.offset);
    if (cmp != 0) return cmp;
    // Same offset: replacements (length > 0) come before insertions (length == 0).
    if (a.length == 0 && b.length != 0) return 1;
    if (b.length == 0 && a.length != 0) return -1;
    return 0;
  });
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
