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
export 'src/core/styles/tab_stops.dart';

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
export 'src/core/state/drawing.dart';
export 'src/core/state/tw_doc.dart';
export 'src/core/state/tw_undo_manager.dart';
export 'src/core/state/snapshot.dart';
export 'src/core/state/state.dart';
export 'src/core/state/collab.dart';
export 'src/core/state/extract_text.dart';
export 'src/core/state/block_traversal.dart';
export 'src/core/state/document_order.dart';
export 'src/core/state/find_matches.dart';
export 'src/core/state/history.dart';
export 'src/core/state/list_defs.dart';
export 'src/core/state/table_context.dart';
export 'src/core/state/build_document_from_tree.dart';
export 'src/core/state/serialize/document_serializer.dart';
export 'src/core/state/serialize/binary_serializer.dart';
export 'src/core/state/serialize/json_serializer.dart';
export 'src/core/state/serialize/quill_delta_codec.dart';
export 'src/core/state/serialize/serializer_registry.dart';

// Layer-3 document operations.
export 'src/core/state/ops/apply_attrs.dart';
export 'src/core/state/ops/delete_range.dart';
export 'src/core/state/ops/insert_block.dart';
export 'src/core/state/ops/insert_blocks_after.dart';
export 'src/core/state/ops/insert_inline_image.dart' hide inlineImageEmbedType;
export 'src/core/state/ops/insert_items.dart';
export 'src/core/state/ops/insert_new_blocks.dart';
export 'src/core/state/ops/insert_page_field.dart';
export 'src/core/state/page_field.dart';
export 'src/core/print/layout/field_convergence.dart';
export 'src/core/print/layout/template_layout.dart';
export 'src/core/state/ops/insert_tab.dart';
export 'src/core/state/ops/insert_text.dart';
export 'src/core/state/ops/merge_blocks.dart';
export 'src/core/state/ops/remove_block.dart';
export 'src/core/state/ops/replace_range.dart';
export 'src/core/state/ops/set_block_attrs.dart';
export 'src/core/state/ops/set_block_type.dart';
export 'src/core/state/ops/split_block.dart';

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
export 'src/core/layout/text_intrinsic.dart';
export 'src/core/layout/hyphenator.dart';
export 'src/core/layout/liang_hyphenator.dart';
export 'src/core/layout/hyphenation_en_us.dart';
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
export 'src/core/editor/reconcile_foreign_change.dart';

// ---------------------------------------------------------------------------
// Print layout geometry
// ---------------------------------------------------------------------------
export 'src/core/print/layout/layout_box.dart';
export 'src/core/print/layout/page_box.dart';
export 'src/core/print/layout/page_config.dart';
export 'src/core/print/layout/ifc.dart';
export 'src/core/print/layout/bfc.dart';
export 'src/core/print/layout/pagination.dart';
export 'src/core/print/layout/table_grid.dart';
export 'src/core/print/layout/table_column_sizing.dart';
export 'src/core/print/layout/table_layout.dart';
export 'src/core/print/canvas_renderer.dart';
export 'src/core/print/canvas_export.dart';
export 'src/core/print/canvas_shaper.dart';
export 'src/core/print/cursor/hit_test.dart';
export 'src/core/digital/computed_style_to_css.dart';
export 'src/core/digital/render_to_dom.dart';
export 'src/core/digital/map_before_input.dart';
export 'src/core/digital/map_digital_key.dart';
export 'src/core/digital/editor_controller.dart';
export 'src/core/digital/dom_reconciler.dart';
export 'src/core/digital/dom_browser_reconciler.dart';
export 'src/core/digital/selection_bridge.dart';
export 'src/core/digital/browser_selection_bridge.dart';
export 'src/core/digital/digital_editor_host_config.dart';
export 'src/core/digital/digital_editor_host.dart';
export 'src/core/digital/word_editor.dart';
export 'src/core/digital/word_editor_js.dart';
export 'src/core/render/render.dart';
export 'src/core/render/resolve_cross_reference.dart';
export 'src/core/render/collect_cross_references.dart';
export 'src/core/render/footnote_numbering.dart';
export 'src/core/render/render_pipeline.dart';
export 'src/core/accessibility/accessibility.dart';
export 'src/core/accessibility/dom_mirror.dart';
export 'src/core/accessibility/dom_mirror_reconciler.dart';
export 'src/core/cascade/attr_registry.dart';
export 'src/core/components/component_registry.dart';

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
export 'src/yjs/relative_position.dart';
export 'src/yjs/undo_manager.dart';
export 'src/yjs/snapshot.dart';
export 'src/yjs/awareness.dart';
export 'src/yjs/collaboration.dart';
export 'src/yjs/websocket_provider.dart';
