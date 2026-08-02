# Taleweaver Dart Port - Task List

## Fase 0 — Core / Utils
- `[x]` `url_safety.dart`
- `[x]` `perf_trace.dart`
- `[x]` `color.dart`
- `[x]` `length.dart`
- `[x]` `block_id.dart`
- `[x]` `attrs.dart`
- `[x]` `inline_content.dart`
- `[x]` `block.dart`
- `[x]` `block_position.dart`

## Fase 1 — Data Model (TwDoc)
- `[x]` `tw_doc.dart` (Novo! Substitui o yjs-doc.ts)
- `[x]` `tw_undo_manager.dart` (Novo! Substitui yjs-history)
- `[x]` `state.dart`
- `[x]` `snapshot.dart`
- `[x]` `block_schema.dart`
- `[x]` `block_kinds.dart`
- `[x]` `block_traversal.dart`
- `[x]` `document_order.dart`
- `[x]` `history.dart`
- `[x]` `list_defs.dart`
- `[x]` `build_document_from_tree.dart`
- `[x]` `page_config.dart`
- `[x]` `embed_content_cascade.dart`
- `[x]` `block_compare.dart`
- `[x]` `span_iteration.dart`

## Fase 2 — Layer 3 Operations (estrutura portada; cobertura equivalente pendente)
- `[x]` `state/ops/apply_attrs.dart`
- `[x]` `state/ops/delete_range.dart`
- `[x]` `state/ops/insert_block.dart`
- `[x]` `state/ops/insert_text.dart`
- `[x]` `state/ops/merge_blocks.dart`
- `[x]` `state/ops/remove_block.dart`
- `[x]` `state/ops/replace_range.dart`
- `[x]` `state/ops/set_block_attrs.dart`
- `[x]` `state/ops/split_block.dart`
- `[x]` Portada a estrutura das operações restantes em `lib/src/core/state/ops/`
- `[/]` Validar comportamento contra os testes da referência e corrigir diferenças sem reduzir escopo
  - `[x]` `comment_ops.dart`
  - `[x]` `create_table.dart`
  - `[x]` `delete_table.dart`
  - `[ ]` `delete_table_column.dart`
  - `[ ]` `delete_table_column_span_aware.dart`
  - `[ ]` `delete_table_row.dart`
  - `[ ]` `delete_table_row_span_aware.dart`
  - `[ ]` `insert_blocks_after.dart`
  - `[ ]` `insert_comment_markers.dart`
  - `[ ]` `insert_cross_reference.dart`
  - `[ ]` `insert_footnote.dart`
  - `[ ]` `insert_inline_image.dart`
  - `[ ]` `insert_items.dart`
  - `[ ]` `insert_new_blocks.dart`
  - `[ ]` `insert_page_field.dart`
  - `[ ]` `insert_tab.dart`
  - `[ ]` `insert_table_column.dart`
  - `[ ]` `insert_table_column_span_aware.dart`
  - `[ ]` `insert_table_row.dart`
  - `[ ]` `insert_table_row_span_aware.dart`
  - `[ ]` `insert_template_body.dart`
  - `[ ]` `merge_block_attrs.dart`
  - `[ ]` `merge_cells.dart`
  - `[ ]` `merge_section.dart`
  - `[ ]` `reparent_children.dart`
  - `[ ]` `replace_block_with_text.dart`
  - `[ ]` `replace_matches.dart`
  - `[ ]` `replace_with_suggestion.dart`
  - `[ ]` `section_break.dart`
  - `[x]` `set_block_type.dart`
  - `[x]` `set_list_restart.dart`
  - `[x]` `set_list_type.dart`
  - `[x]` `set_table_header_rows.dart`
  - `[x]` `split_cell.dart`
  - `[x]` `suggestion_ops.dart`
  - `[x]` `table_header_rows.dart`

## Qualidade da fundação
- `[x]` Dirty tracking automático em mutações diretas e indiretas das três árvores
- `[x]` Snapshots profundos para attrs, listas e conteúdo inline
- `[x]` No-op preserva identidade de `State`
- `[x]` Testes executáveis em `test/state_transaction_test.dart`
- `[ ]` CRDT Yjs completo e compatibilidade de updates
- `[ ]` Testes Dart equivalentes aos testes de `referencias/yjs-main` e `referencias/taleweaver-main`

## Yjs — portabilidade incremental
- `[x]` `YDoc` com tipos compartilhados integrados
- `[x]` `YDoc` integrado ao client ID, clocks e `YStructStore`
- `[x]` `YMap`, `YArray` e `YText` com operações básicas
- `[x]` Transações, origem e observadores locais
- `[x]` `YIdSet` com ranges, cobertura, gaps e remoção
- `[x]` Codificação/decodificação varint com inteiros signed/unsigned
- `[x]` `YId` e state vectors com codec determinístico
- `[x]` Structs `YItem`, `YGC`, `YSkip` e `YStructStore` com integridade
- `[x]` Codec interno versionado, merge, aplicação e convergência de updates
- `[x]` Operações locais de Array/Text geram structs e updates
- `[x]` Store CRDT com `ID`, `Item`, `GC` e `Skip`
- `[ ]` Updates V1/V2 e merge/diff byte-compatíveis com Yjs
- `[ ]` Snapshots e relative positions
- `[ ]` UndoManager compatível
- `[ ]` Portar a suíte completa de `referencias/yjs-main/tests`

## Fase 3 — Layer 4 View / Layout Adapters
- `[ ]` `layout_adapters` e `view_trees`

## Fase 7 — Cursor geometry-free
- `[x]` Grapheme boundaries e word boundaries em offsets UTF-16
- `[x]` Movimento por caractere e palavra entre blocos folha
- `[x]` Seleção de palavra e expansão de seleção
- `[x]` Predicados de seleção e seleção de objetos
- `[ ]` Equivalência completa com todos os testes TS de cursor

## Fase 7 — Layout text core
- `[x]` Grapheme segmentation compartilhada com cursor e shaper
- `[x]` Tokenização de white-space e mandatory line breaks
- `[x]` Text transform com mapeamento source/display
- `[x]` Mat2D affine, composição, aplicação e inversão
- `[x]` TextShaper/TextMeasurer e mock shaper
- `[x]` Text spacing e break opportunities básicas
- `[ ]` UAX #14 completo e tabelas Unicode
- `[ ]` UAX #9 bidi completo e tabelas Unicode
- `[ ]` Intrinsic sizes, hyphenation e shaping Canvas
- `[x]` UAX #9 baseline: classes, paragraph direction, níveis básicos, reorder L2 e mirrors básicos

## Fase 8 — Editor state machine
- `[x]` EditorState, EditorAction e reducer geometry-free básicos
- `[x]` Inserção de texto, seleção, movimento de palavra e expansão
- `[x]` Delete range/backward/forward básico
- `[x]` Integração inicial com History undo/redo
- `[ ]` Portar todas as ações e coalescing da referência
- `[ ]` Paste, formatting, tabelas, imagens, comentários e sugestões

## Fase 9 — Print layout geometry
- `[x]` LayoutBox, BlockBox, TextRunBox, LineBox e PageBox base
- `[x]` Page size, margins, page gap e content geometry
- `[ ]` BFC/IFC, fragmentation, pagination e table layout
- `[ ]` Cursor geométrico, hit-test e selection geometry
- `[x]` IFC/BFC baseline para texto medido por clusters e quebra por largura
- `[x]` Paginação baseline por altura útil em `PageBox`

## Fase 12 — Digital backend
- `[x]` Conversão inicial de ComputedStyle para CSS inline
- `[x]` Ponte inicial RenderNode -> `package:web` DOM
- `[ ]` Render State/RenderNode para `package:web` DOM
- `[ ]` Reconciler incremental e selection bridge
- `[ ]` beforeinput/key mapping e controller contenteditable

## Fase 4 — Componentes
- `[ ]` `components` e `registry`

## Fase 14 — Demo web
- `[x]` `web/index.html`
- `[x]` `web/main.dart` com toolbar e host contenteditable inicial
- `[x]` Entry point compila com `dart compile js`
- `[ ]` Integração completa do reducer/editor com eventos DOM
