/// Taleweaver — a pure-Dart port of the Taleweaver word processor engine.
///
/// This is the public API surface. Downstream consumers import from this
/// barrel file only.
library taleweaver;

// ---------------------------------------------------------------------------
// URL Safety
// ---------------------------------------------------------------------------
export 'src/url_safety.dart';

// ---------------------------------------------------------------------------
// Performance Tracing
// ---------------------------------------------------------------------------
export 'src/perf/perf_trace.dart';

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------
export 'src/styles/color.dart';
export 'src/styles/length.dart';

// ---------------------------------------------------------------------------
// State — types and access primitives
// ---------------------------------------------------------------------------
export 'src/state/block_id.dart';
export 'src/state/attrs.dart';
export 'src/state/inline_content.dart';
export 'src/state/block.dart';
export 'src/state/block_position.dart';
export 'src/state/page_config.dart';
export 'src/state/block_kinds.dart';
export 'src/state/block_schema.dart';
export 'src/state/tw_doc.dart';
export 'src/state/tw_undo_manager.dart';
export 'src/state/snapshot.dart';
export 'src/state/state.dart';
export 'src/state/block_traversal.dart';
export 'src/state/document_order.dart';
export 'src/state/history.dart';
export 'src/state/list_defs.dart';
export 'src/state/build_document_from_tree.dart';
