/// Document positions, spans, and selections.
///
/// Port of `block-position.ts`.
library;

import 'block_id.dart';

// ---------------------------------------------------------------------------
// Position
// ---------------------------------------------------------------------------

/// A position in the document: a block identifier plus a UTF-16 code-unit
/// offset within that block's inline content.
///
/// Stable across edits to other parts of the document (the blockId names a
/// specific block; offsets only change when the named block itself is edited).
class Position {
  final BlockId blockId;
  final int offset;

  const Position({required this.blockId, required this.offset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Position && other.blockId == blockId && other.offset == offset);

  @override
  int get hashCode => Object.hash(blockId, offset);

  @override
  String toString() => 'Position($blockId, $offset)';
}

/// Create a [Position].
Position createPosition(BlockId blockId, int offset) {
  return Position(blockId: blockId, offset: offset);
}

/// True iff [a] and [b] have the same blockId and offset.
bool positionsEqual(Position a, Position b) {
  return a.blockId == b.blockId && a.offset == b.offset;
}

/// Compare two positions in the same block. Returns negative/zero/positive
/// by offset.
///
/// Throws if blockIds differ — cross-block compare requires walking the
/// block tree and lives in [compareBlocksInDocOrder].
int comparePositionsWithinBlock(Position a, Position b) {
  if (a.blockId != b.blockId) {
    throw ArgumentError(
      'comparePositionsWithinBlock called on positions in different blocks '
      '(${a.blockId} vs ${b.blockId}); '
      'use compareBlocksInDocOrder for cross-block compare',
    );
  }
  return a.offset - b.offset;
}

// ---------------------------------------------------------------------------
// Span
// ---------------------------------------------------------------------------

/// A span / selection range. [anchor] is where the selection started;
/// [focus] is the current end.
class Span {
  final Position anchor;
  final Position focus;

  const Span({required this.anchor, required this.focus});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Span && other.anchor == anchor && other.focus == focus);

  @override
  int get hashCode => Object.hash(anchor, focus);

  @override
  String toString() => 'Span($anchor → $focus)';
}

/// Create a [Span].
Span createSpan(Position anchor, Position focus) {
  return Span(anchor: anchor, focus: focus);
}

// ---------------------------------------------------------------------------
// Selection
// ---------------------------------------------------------------------------

/// `Selection` is the editor/cursor-facing name for a [Span].
///
/// Convention: editor + cursor + history code spell it `Selection`; state-layer
/// range math spells it `Span`.
typedef Selection = Span;

/// Whether a selection/span is collapsed (anchor == focus).
bool isCollapsed(Span span) {
  return positionsEqual(span.anchor, span.focus);
}

/// Whether two selections are equal.
bool selectionsEqual(Selection a, Selection b) {
  return positionsEqual(a.anchor, b.anchor) && positionsEqual(a.focus, b.focus);
}
