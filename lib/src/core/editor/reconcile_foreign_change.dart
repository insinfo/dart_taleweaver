/// Applies a peer document change to the local editor view.
library;

import '../state/block_id.dart';
import '../state/state.dart';
import 'editor_state.dart';

/// Rebuilds only the state snapshot cache entries affected by a remote edit.
///
/// A foreign change is not part of the local undo history, so selection,
/// history and editor configuration pass through unchanged. The dirty ids are
/// retained for incremental render/layout consumers, matching the TypeScript
/// `reconcileForeignChange` seam.
EditorState reconcileForeignChange(EditorState editor, Set<BlockId> dirtyIds) {
  editor.state.snapshotCache.invalidate(dirtyIds.map((id) => id.value).toSet());
  return EditorState(
    state: freshState(editor.state),
    selection: editor.selection,
    history: editor.history,
    containerWidth: editor.containerWidth,
    lastDirtyIds: Set<BlockId>.of(dirtyIds),
  );
}
