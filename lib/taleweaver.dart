/// Taleweaver — a pure-Dart port of the Taleweaver word processor engine.
///
/// This is the public API surface. Downstream consumers import from this
/// barrel file only.
library taleweaver;

// ---------------------------------------------------------------------------
// URL Safety
// ---------------------------------------------------------------------------
export 'src/core/url_safety.dart';

// ---------------------------------------------------------------------------
// Performance Tracing
// ---------------------------------------------------------------------------
export 'src/core/perf/perf_trace.dart';

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------
export 'src/core/styles/color.dart';
export 'src/core/styles/length.dart';

// ---------------------------------------------------------------------------
// State — types and access primitives
// ---------------------------------------------------------------------------
export 'src/core/state/block_id.dart';
export 'src/core/state/attrs.dart';
export 'src/core/state/inline_content.dart';
export 'src/core/state/block.dart';
export 'src/core/state/block_position.dart';
export 'src/core/state/page_config.dart';
export 'src/core/state/block_kinds.dart';
export 'src/core/state/block_schema.dart';
export 'src/core/state/tw_doc.dart';
export 'src/core/state/tw_undo_manager.dart';
export 'src/core/state/snapshot.dart';
export 'src/core/state/state.dart';
export 'src/core/state/block_traversal.dart';
export 'src/core/state/document_order.dart';
export 'src/core/state/history.dart';
export 'src/core/state/list_defs.dart';
export 'src/core/state/build_document_from_tree.dart';

// ---------------------------------------------------------------------------
// Geometry-free cursor
// ---------------------------------------------------------------------------
export 'src/core/cursor/cursor_ops.dart';
export 'src/core/cursor/grapheme_utils.dart';
export 'src/core/cursor/object_selection.dart';
export 'src/core/cursor/selection.dart';

// ---------------------------------------------------------------------------
// Text layout core
// ---------------------------------------------------------------------------
export 'src/core/layout/graphemes.dart';
export 'src/core/layout/mat2d.dart';
export 'src/core/layout/mock_shaper.dart';
export 'src/core/layout/text_measurer.dart';
export 'src/core/layout/text_shaper.dart';
export 'src/core/layout/text_spacing.dart';
export 'src/core/layout/text_tokenize.dart';
export 'src/core/layout/text_transform.dart';
export 'src/core/layout/uax14/index.dart';
export 'src/core/layout/uax9/index.dart';

// ---------------------------------------------------------------------------
// Geometry-free editor state
// ---------------------------------------------------------------------------
export 'src/core/editor/editor_action.dart';
export 'src/core/editor/editor_state.dart';

// ---------------------------------------------------------------------------
// Print layout geometry
// ---------------------------------------------------------------------------
export 'src/core/print/layout/layout_box.dart';
export 'src/core/print/layout/page_box.dart';
export 'src/core/print/layout/page_config.dart';
export 'src/core/print/layout/ifc.dart';
export 'src/core/print/layout/bfc.dart';
export 'src/core/digital/computed_style_to_css.dart';
export 'src/core/digital/render_to_dom.dart';

// ---------------------------------------------------------------------------
// Yjs-compatible shared types (incremental port)
// ---------------------------------------------------------------------------
export 'src/yjs/doc.dart';
export 'src/yjs/events.dart';
export 'src/yjs/types.dart';
export 'src/yjs/ids.dart';
export 'src/yjs/encoding.dart';
export 'src/yjs/id.dart';
export 'src/yjs/structs.dart';
export 'src/yjs/update_codec.dart';
