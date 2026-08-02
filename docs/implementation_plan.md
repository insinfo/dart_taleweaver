# Portagem Taleweaver: TypeScript → Dart Puro

Portar o motor de processador de texto **Taleweaver** (TypeScript, monorepo com 4 pacotes, ~80.000 linhas de código fonte em ~415 arquivos) para **Dart puro** usando apenas `web: ^1.1.1` e, se necessário, `html: ^0.15.4` como dependências (sem `dart:html`).

O objetivo deste plano é a portabilidade integral de `referencias/yjs-main` e `referencias/taleweaver-main`, sem gambiarras, atalhos ou um MVP descartável. Cada fase só pode ser marcada como concluída quando a implementação Dart cobrir o contrato da referência e tiver testes equivalentes; itens ainda não portados permanecem explicitamente pendentes.

### Estado da portabilidade

O código ativo está em `lib/src/`. A antiga árvore `lib/src` não é uma segunda implementação: ela foi substituída pela organização `core` e não deve ser reintroduzida como compatibilidade artificial. A fundação de estado já possui as operações Layer 3 e os componentes/cascade iniciais, mas a portabilidade ainda não está completa.

**Última etapa concluída:** transações `TwDoc`/`applyOperation`, núcleo Yjs Dart local com relative positions e UndoManager de store baseline, cursor geometry-free, base de layout text (UAX #14 e UAX #9 em baseline), serialização JSON/HTML validada, reducer `EditorState` inicial, modelo geométrico/IFC/BFC/paginação/hit-test textual base do print, renderer Canvas/DOM baseline, mapeamento digital de input/teclas e entrypoint web compilável. Tudo está coberto pela suíte Dart e validação `dart compile js`; tabelas Unicode completas, editor integral, canvas completo, reconciler digital e colaboração ainda permanecem pendentes.

**Próxima etapa obrigatória:** substituir o codec interno pelo formato byte a byte de `referencias/yjs-main` (UpdateEncoder/Decoder V1 e V2), integrar operações do `YDoc` ao store, implementar resolução de conflitos/pending structs, snapshots, relative positions e UndoManager. O núcleo atual ainda não é compatível com colaboração JavaScript.

---

## Visão Geral do Projeto Original

O projeto TypeScript é um monorepo com a seguinte estrutura:

| Pacote TS | Arquivos fonte | Responsabilidade |
|---|---|---|
| `@taleweaver/core` | ~273 | Motor do documento: state (Y.Doc), styles/cascade, render tree, layout text, cursor, editor, components, footnotes, numbering, accessibility, serialização |
| `@taleweaver/print` | ~86 | Backend de impressão/paginação: layout geométrico (BFC/IFC), canvas renderer, cursor geométrico, DOM mirror, editor controller, PDF export |
| `@taleweaver/digital` | ~8 | Backend digital: renderizar State → DOM (contenteditable), reconciler, selection bridge |
| `@taleweaver/react` | ~3 | Wrapper React (não portar) em ves disso criar um projeto de exemplo que demostre o editor a ideia é que este editor seja completo e auto contido e personalizavel e extensivel e possa ser usado embutido em qualquer aplicação web sendo dart puro ngdart ou mesmo aplicações javascript ou typescript pois o editor pode ter uma api javascript atraves de dart js interop com exportações de API npublica|
| `@taleweaver/hyphenation-en-us` | ~2 | Dados de hifenização (Knuth-Liang patterns) |

### Dependência Crítica: Yjs

O core depende fortemente de **Yjs** (~13.6.18) para o modelo de dados (CRDT). Toda a camada `state/` é construída sobre `Y.Doc`, `Y.Map`, `Y.Array`, e `Y.UndoManager`. Isso é a **maior decisão arquitetural** da portagem.

---

## User Review Required

> [!IMPORTANT]

> 2. **Portar o Yjs completo** para Dart (Y.Map, Y.Doc, Y.UndoManager) — mais fiel ao original mas muito trabalhoso
>
> A opção 1 não faz parte do objetivo atual. `TwDoc`/`TwUndoManager` são apenas a fundação transitória da portabilidade e não podem ser tratados como substitutos finais do Yjs. A implementação final deve preservar o comportamento CRDT necessário pelos consumidores de Taleweaver.

> [!IMPORTANT]
> **Escopo:** O projeto completo tem ~80.000 linhas. A execução será faseada por dependências, mas o alvo é o conjunto completo que reproduz a implementação de referência e a demo em https://yuzhenmi.github.io/taleweaver/ — um editor de texto rico no browser com:
> - Edição de texto (inserir, deletar, split/merge parágrafos)
> - Formatação inline (bold, italic, underline, font size/family, cores)
> - Formatação de bloco (headings, alinhamento, listas, espaçamento)
> - Tabelas básicas
> - Imagens
> - Linhas horizontais
> - Canvas rendering paginado (modo print)
> - Undo/Redo
> - Seleção e cursor
> - Serialização JSON/HTML

> [!WARNING]
> Nenhuma funcionalidade é descartada por ser difícil. Footnotes, comments, suggestions/change-tracking, cross-references, table of contents, PDF export, multi-column layout, collaboration, accessibility tree, section breaks, headers/footers e hyphenation são fases posteriores de implementação, não exclusões de escopo.

---

## Open Questions

> [!IMPORTANT]
> 1. **Colaboração (collab)**: O Yjs foi escolhido no original para suportar edição colaborativa em tempo real. Isso é necessário no MVP Dart? Se não, a substituição por `Map` simples é viável. Se sim, precisaríamos de uma solução CRDT em Dart.

> [!IMPORTANT]
> 2. **Modo de renderização**: O demo original usa Canvas2D para o modo "print" (paginado) e DOM contenteditable para o modo "digital". Para o MVP Dart:
>    - **Opção A**: Apenas modo "print" (Canvas2D via `package:web`) — mais complexo mas fiel ao demo
>    - **Opção B**: Apenas modo "digital" (DOM via `package:web`) — mais simples
>    - **Opção C**: Ambos — completo mas mais trabalho
>    
>    O demo que você apontou (https://yuzhenmi.github.io/taleweaver/) usa modo "print" (canvas paginado). Recomendar opção A.

> [!IMPORTANT]
> 3. **package:html vs package:web**: `package:html` (^0.15.4) é um parser HTML server-side. `package:web` (^1.1.1) é o binding FFI para APIs do browser. No contexto Taleweaver:
>    - `package:web` será usado para TODA interação com DOM/Canvas/Events no browser
>    - `package:html` será usado para o parser HTML na serialização (substituindo o `DOMParser` do browser)
>    
>    Confirma esse entendimento?

---

## Arquitetura Proposta em Dart

```
lib/
├── taleweaver.dart                    # Barrel export (API pública)
└── src/
    ├── state/                         # Modelo de dados (substitui Yjs)
    │   ├── tw_doc.dart                # Substituição de Y.Doc
    │   ├── tw_map.dart                # Substituição de Y.Map
    │   ├── tw_undo_manager.dart       # Substituição de Y.UndoManager
    │   ├── state.dart                 # State container
    │   ├── block.dart                 # Block interface
    │   ├── block_id.dart              # BlockId + allocators
    │   ├── block_position.dart        # Position, Span, Selection
    │   ├── block_traversal.dart       # Navegação na árvore
    │   ├── document_order.dart        # Ordenação de blocos
    │   ├── inline_content.dart        # InlineContent, TextItem, EmbedItem
    │   ├── attrs.dart                 # ReadonlyAttrs utilities
    │   ├── block_kinds.dart           # Block kind resolution
    │   ├── block_schema.dart          # Field specs
    │   ├── initial_state.dart         # Empty document creation
    │   ├── history.dart               # Undo/Redo (sem Yjs)
    │   ├── snapshot.dart              # Snapshot caching
    │   ├── span_iteration.dart        # Span iteration utils
    │   ├── active_formatting.dart     # Active formatting detection
    │   ├── list_defs.dart             # List definitions
    │   ├── page_config.dart           # Page setup config
    │   ├── hard_break.dart            # Hard break embed
    │   ├── word_count.dart            # Word count
    │   ├── find_matches.dart          # Find text matches
    │   ├── extract_text.dart          # Text extraction
    │   ├── outline.dart               # Document outline
    │   ├── comments.dart              # Comments (stub para MVP)
    │   ├── suggestions.dart           # Suggestions (stub para MVP)
    │   ├── embed_content_cascade.dart # Embed content trees
    │   ├── table_context.dart         # Table grid helpers
    │   ├── table_grid_core.dart       # Grid assignment
    │   ├── table_column_widths.dart   # Column width calc
    │   ├── table_cell_range.dart      # Cell range ops
    │   ├── table_cell_span.dart       # Cell spanning
    │   ├── ops/                       # Layer 3 operations
    │   │   ├── insert_text.dart
    │   │   ├── delete_range.dart
    │   │   ├── replace_range.dart
    │   │   ├── split_block.dart
    │   │   ├── merge_blocks.dart
    │   │   ├── insert_block.dart
    │   │   ├── remove_block.dart
    │   │   ├── set_block_type.dart
    │   │   ├── set_block_attrs.dart
    │   │   ├── apply_attrs.dart
    │   │   ├── create_table.dart
    │   │   ├── insert_table_row.dart
    │   │   ├── insert_table_column.dart
    │   │   ├── delete_table_row.dart
    │   │   ├── delete_table_column.dart
    │   │   ├── delete_table.dart
    │   │   ├── merge_cells.dart
    │   │   ├── split_cell.dart
    │   │   └── section_break.dart
    │   └── serialize/                 # Serialização
    │       ├── document_serializer.dart
    │       ├── serializer_registry.dart
    │       ├── json_serializer.dart
    │       ├── html_encode.dart
    │       ├── html_decode.dart
    │       ├── html_node.dart
    │       └── html_serializer.dart
    │
    ├── styles/                        # Sistema de estilos CSS-like
    │   ├── style.dart                 # Style type + all CSS properties
    │   ├── computed_style.dart        # ComputedStyle
    │   ├── used_style.dart            # UsedStyle (resolved)
    │   ├── length.dart                # Length, LengthOrAuto
    │   ├── color.dart                 # Color type
    │   ├── property_meta.dart         # Property metadata registry
    │   ├── physical_sides.dart        # Physical border sides
    │   ├── position.dart              # CSS Position + stacking
    │   ├── writing_mode.dart          # WritingMode + axis maps
    │   ├── tab_stops.dart             # Tab stop types
    │   ├── column_config.dart         # Multi-column config
    │   ├── format_counter.dart        # Counter formatting (i, ii, A, B...)
    │   └── author_color.dart          # Author-color palette
    │
    ├── cascade/                       # Style cascade engine
    │   ├── cascade_pass.dart          # Main cascade algorithm
    │   ├── attr_registry.dart         # Attr → Style interpreters
    │   ├── builtin_attrs.dart         # Built-in attr interpreters
    │   ├── compose.dart               # Style composition
    │   ├── flatten_lengths.dart       # Length resolution
    │   └── resolve_length.dart        # Length resolving
    │
    ├── components/                    # Component definitions
    │   ├── component_definition.dart  # ComponentDefinition type
    │   ├── component_registry.dart    # Registry + defaults
    │   ├── document.dart              # Document root component
    │   ├── paragraph.dart             # Paragraph component
    │   ├── heading.dart               # Heading component
    │   ├── list_item.dart             # List-item component
    │   ├── image.dart                 # Image component
    │   ├── horizontal_line.dart       # HR component
    │   ├── section.dart               # Section component
    │   ├── table.dart                 # Table component
    │   ├── table_row.dart             # Table-row component
    │   ├── table_cell.dart            # Table-cell component
    │   ├── table_of_contents.dart     # TOC component (stub)
    │   ├── footnote_body.dart         # Footnote body (stub)
    │   ├── template_body.dart         # Template body (stub)
    │   └── leaf_style_attrs.dart      # Inline style attrs
    │
    ├── render/                        # Render tree (styled tree from state)
    │   ├── render_node.dart           # RenderNode, ElementBox, TextBox
    │   ├── render.dart                # render() entry point
    │   ├── render_core.dart           # Core rendering logic
    │   ├── render_incremental.dart    # Incremental render
    │   ├── render_footnotes.dart      # Footnote rendering
    │   ├── block_view.dart            # Block → RenderNode mapping
    │   ├── layout_metadata.dart       # Layout metadata on boxes
    │   ├── inline_render_key.dart     # Inline keys
    │   ├── collect_cross_references.dart
    │   ├── resolve_cross_reference.dart
    │   └── toc_entry_subtree.dart
    │
    ├── cursor/                        # Selection model
    │   ├── selection.dart             # Selection, isCollapsed
    │   ├── cursor_ops.dart            # moveByChar, moveByWord, etc.
    │   ├── grapheme_utils.dart        # Grapheme boundary utils
    │   └── object_selection.dart      # Object (image/HR) selection
    │
    ├── editor/                        # Editor state machine
    │   ├── editor_action.dart         # EditorAction union type
    │   ├── editor_state.dart          # EditorState + reducer
    │   ├── coalesce_key.dart          # History coalescing
    │   ├── document_io.dart           # Load/export document
    │   ├── block_parent_lookup.dart   # Parent lookup
    │   ├── reconcile_foreign_change.dart
    │   └── actions/                   # Action handlers (~60 handlers)
    │       ├── insert_text.dart
    │       ├── delete_backward.dart
    │       ├── delete_forward.dart
    │       ├── delete_word.dart
    │       ├── delete_range.dart
    │       ├── split_node.dart
    │       ├── paste.dart
    │       ├── undo.dart
    │       ├── redo.dart
    │       ├── set_selection.dart
    │       ├── select_all.dart
    │       ├── toggle_style.dart
    │       ├── set_link.dart
    │       ├── set_text_color.dart
    │       ├── set_highlight.dart
    │       ├── set_font_size.dart
    │       ├── set_font_family.dart
    │       ├── clear_formatting.dart
    │       ├── set_block_type.dart
    │       ├── toggle_list.dart
    │       ├── set_list_type.dart
    │       ├── set_text_align.dart
    │       ├── set_line_spacing.dart
    │       ├── set_paragraph_spacing.dart
    │       ├── indent.dart
    │       ├── list_indent.dart
    │       ├── insert_table.dart
    │       ├── table_edits.dart
    │       ├── insert_image.dart
    │       ├── insert_horizontal_line.dart
    │       ├── set_image_size.dart
    │       ├── set_image_wrap.dart
    │       ├── set_image_alt.dart
    │       ├── helpers.dart
    │       ├── selection_guards.dart
    │       ├── move_word.dart
    │       ├── move_document_boundary.dart
    │       ├── expand_word.dart
    │       ├── expand_document_boundary.dart
    │       ├── escape.dart
    │       ├── replace.dart
    │       ├── section_break.dart
    │       ├── toggle_section_landscape.dart
    │       ├── set_section_columns.dart
    │       ├── insert_header_footer.dart
    │       ├── insert_table_of_contents.dart
    │       ├── object_edits.dart
    │       ├── atomic_edits.dart
    │       └── suggestion_mode.dart   # (stub)
    │
    ├── layout/                        # Text layout (geometry-free core)
    │   ├── text_measurer.dart         # TextMeasurer interface
    │   ├── text_shaper.dart           # TextShaper, ShapedRun, Cluster
    │   ├── mock_shaper.dart           # Mock para testes
    │   ├── mock_hyphenator.dart       # Mock para testes
    │   ├── graphemes.dart             # Grapheme segmentation
    │   ├── text_tokenize.dart         # Line-break tokenization
    │   ├── text_transform.dart        # text-transform CSS
    │   ├── text_spacing.dart          # letter-/word-spacing
    │   ├── intrinsic_sizes.dart       # Intrinsic size computation
    │   ├── mat2d.dart                 # 2x3 affine matrix
    │   ├── hyphenator.dart            # Hyphenator interface
    │   ├── uax14/                     # UAX #14 Line-break
    │   │   ├── line_break_class.dart
    │   │   ├── line_break_table.dart  # (~56KB de dados Unicode)
    │   │   └── break_opportunities.dart
    │   └── uax9/                      # UAX #9 Bidi
    │       ├── bidi_class.dart
    │       ├── bidi_class_table.dart   # (~22KB de dados Unicode)
    │       ├── bidi.dart              # Resolve bidi levels
    │       ├── reorder.dart           # Visual reordering
    │       ├── mirror.dart            # Bidi mirror chars
    │       ├── bidi_mirror_table.dart
    │       └── bidi_bracket_table.dart
    │
    ├── footnotes/                     # Footnote engine (stub para MVP)
    │   ├── types.dart
    │   ├── collect_anchors.dart
    │   ├── numbering.dart
    │   ├── policy.dart
    │   └── format_counter.dart
    │
    ├── numbering/                     # List numbering
    │   ├── types.dart
    │   ├── list_collector.dart
    │   └── compute_counters.dart
    │
    ├── perf/                          # Performance tracing
    │   └── perf_trace.dart
    │
    ├── print/                         # Print backend (Canvas-based)
    │   ├── layout/                    # Geometric layout engine
    │   │   ├── layout_node.dart       # LayoutBox, BlockBox, LineBox, TextRunBox
    │   │   ├── page_box.dart          # PageBox
    │   │   ├── dispatch.dart          # layoutTree entry
    │   │   ├── bfc.dart               # Block Formatting Context
    │   │   ├── ifc.dart               # Inline Formatting Context
    │   │   ├── fragmentation.dart     # Page/column breaking
    │   │   ├── pagination.dart        # Multi-page layout
    │   │   ├── table_layout.dart      # Table layout (FC)
    │   │   ├── used_style.dart        # Used style resolution
    │   │   ├── virtual_layout_tree.dart
    │   │   ├── layout_incremental.dart
    │   │   ├── ifc_state.dart
    │   │   ├── intrinsic_sizes_pass.dart
    │   │   ├── collect_page_fields.dart
    │   │   ├── resolve_goto_destination.dart
    │   │   ├── pdf_outline.dart
    │   │   └── hyphenation/
    │   │       ├── liang.dart
    │   │       └── create_liang_hyphenator.dart
    │   ├── cursor/                    # Geometric cursor
    │   │   ├── hit_test.dart
    │   │   ├── cursor_position.dart
    │   │   ├── selection_geometry.dart
    │   │   ├── line_navigation.dart
    │   │   ├── line_bidi.dart
    │   │   ├── line_flatten.dart
    │   │   ├── visual_motion.dart
    │   │   ├── atomic_box_index.dart
    │   │   ├── comment_rects.dart
    │   │   └── suggestion_rects.dart
    │   ├── canvas_renderer.dart       # Canvas2D paint (81KB original!)
    │   ├── canvas_measurer.dart       # Browser canvas text measuring
    │   ├── canvas_shaper.dart         # Browser canvas text shaping
    │   ├── font_config.dart           # Font configuration
    │   ├── key_handler.dart           # Keyboard event mapping
    │   ├── html_parser.dart           # Browser DOM HTML parser
    │   ├── editor_controller.dart     # Main editor controller (116KB!)
    │   ├── dom_mirror.dart            # Accessibility DOM mirror
    │   ├── dom_mirror_host.dart       # Mirror host
    │   ├── dom_mirror_selection.dart  # Mirror selection
    │   ├── paint_cache.dart           # Paint caching
    │   ├── image_cache.dart           # Image loading/caching
    │   ├── offscreen_surface.dart     # Offscreen canvas
    │   ├── text_clusters.dart         # Text cluster utilities
    │   ├── pdf_export.dart            # PDF export (stub)
    │   ├── nav/                       # Navigation intents
    │   │   └── nav_intent.dart
    │   └── layout_driver/
    │       ├── layout_driver.dart
    │       └── layout_config.dart
    │
    ├── digital/                       # Digital backend (DOM-based)
    │   ├── render_to_dom.dart         # State → DOM rendering
    │   ├── computed_style_to_css.dart # ComputedStyle → CSS
    │   ├── digital_controller.dart    # Contenteditable controller
    │   ├── digital_reconciler.dart    # DOM reconciliation
    │   ├── digital_selection_bridge.dart
    │   ├── map_before_input.dart
    │   └── map_digital_key.dart
    │
    └── url_safety.dart                # URL validation
```

---

## Proposed Changes — Fases de Implementação

### Fase 0 — Infraestrutura e Tipos Base (~10 arquivos, ~800 linhas Dart)

Preparar o esqueleto do projeto com tipos fundamentais que todo o resto depende.

---

#### [NEW] [url_safety.dart](file:///c:/MyDartProjects/taleweaver/lib/src/url_safety.dart)
Portar `isOpenableLinkUrl`, `isExportSafeLinkUrl` — puras, sem dependências.

#### [NEW] [perf_trace.dart](file:///c:/MyDartProjects/taleweaver/lib/src/perf/perf_trace.dart)
Portar `markStart`, `markEnd`, `report`, `resetPerfTrace` — logging simples.

#### [NEW] [color.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/color.dart)
Tipo `Color` (typedef `String`).

#### [NEW] [length.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/length.dart)
Tipos `Length`, `LengthOrAuto`, `ComputedLength`, `ComputedLengthOrAuto` — sealed classes.

#### [NEW] [block_id.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block_id.dart)
`BlockId` (typedef `String`), `IdAllocator`, `productionAllocator`, `createTestAllocator`, `asBlockId`, `coerceBlockId`, `newListId`.

#### [NEW] [attrs.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/attrs.dart)
`ReadonlyAttrs` (typedef `Map<String, dynamic>`), `deepValueEqual`, `attrsEqual`, `mergeAttrs`.

#### [NEW] [inline_content.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/inline_content.dart)
`InlineContent`, `InlineItem`, `TextItem`, `EmbedItem`, funções utilitárias.

#### [NEW] [block.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block.dart)
`Block` class com `id`, `type`, `attrs`, `parentId`, `prevSiblingId`, `nextSiblingId`, `firstChildId`, `lastChildId`, `inlineContent`.

#### [NEW] [block_position.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block_position.dart)
`Position`, `Span`, `Selection` — tipos imutáveis + comparadores.

---

### Fase 1 — Modelo de Dados (substituição do Yjs) (~15 arquivos, ~2.500 linhas Dart)

Criar as classes que substituem Yjs com Maps nativos do Dart.

---

#### [NEW] [tw_doc.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/tw_doc.dart)
Classe `TwDoc` — substitui `Y.Doc`:
- Mantém maps nomeados: `blocks`, `embedContents`, `templateContents`, `listDefs`, `comments`, `suggestions`, `meta`
- Cada map é um `Map<String, Map<String, dynamic>>`
- Suporta transações (`transact()`) com batching de notificações
- Emite eventos `afterTransaction` para dirty-tracking
- Captura dirty block ids durante transações

#### [NEW] [tw_undo_manager.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/tw_undo_manager.dart)
Classe `TwUndoManager` — substitui `Y.UndoManager`:
- Mantém stacks de undo/redo como snapshots de deltas
- Cada StackItem armazena um diff (blocks alterados antes/depois)
- `undo()` e `redo()` aplicam deltas reversos
- `.meta` map por StackItem para SelectionEntry
- Coalescing de edits consecutivos (timeout-based)
- Transaction-origin filtering (para ignorar suggestion-resolve)

#### [NEW] [state.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/state.dart)
`State` container:
- `rootId: BlockId`
- Internal `TwDoc`
- Snapshot cache
- `createState()`, `getBlock()`, `getEmbedContent()`, `getTemplateContent()`, `resolveBlock()`
- `applyOperation()` — runs mutation fn within transaction, captures dirty ids, returns `OperationResult`
- `freshState()` — invalidates snapshot cache

#### [NEW] [snapshot.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/snapshot.dart)
Cache de snapshots `Block` — lê do `TwDoc.blocks` map e congela o resultado.

#### [NEW] [block_schema.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block_schema.dart)
Definição dos campos de um block (correspondência com chaves no TwDoc).

#### [NEW] [block_kinds.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block_kinds.dart)
Resolução container vs leaf, tipos conhecidos.

#### [NEW] [block_traversal.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/block_traversal.dart)
`nextBlockInDocOrder`, `prevBlockInDocOrder`, `ancestorChain`, `firstLeafBlock`, `lastLeafBlock`.

#### [NEW] [document_order.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/document_order.dart)
`compareBlocksInDocOrder`, `comparePositions`, `normalizeSpan`, `iterateSpan`, `iterateBlocksInSpan`.

#### [NEW] [span_iteration.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/span_iteration.dart)
Utilitários de iteração sobre spans.

#### [NEW] [initial_state.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/initial_state.dart)
`createEmptyDocument()` — cria um State com doc root + um parágrafo vazio.

#### [NEW] [history.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/history.dart)
`History` class usando `TwUndoManager`:
- `createHistory(state)`
- `commit(before, after)` — fecha a transação no UndoManager
- `undo()` / `redo()` → `UndoRedoResult { state, selection, dirtyIds }`
- Coalescing key support

#### [NEW] [build_document_from_tree.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/build_document_from_tree.dart)
`buildDocumentFromTree()` — constrói State a partir de uma árvore declarativa `BlockNode`.

#### [NEW] [page_config.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/page_config.dart)
`PageConfig`, `PageMargins`.

#### [NEW] [list_defs.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/list_defs.dart)
`ListDef`, `getListDefsForState`, `classifyListDef`.

---

### Fase 2 — Layer 3 Operations (~20 arquivos, ~4.000 linhas Dart)

Operações de mutação do estado do documento.

---

#### [NEW] [ops/insert_text.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/insert_text.dart)
`insertText(state, blockId, offset, text, attrs)` — insere texto no bloco.

#### [NEW] [ops/delete_range.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/delete_range.dart)
`deleteRange(state, span)` — deleta conteúdo dentro de um span.

#### [NEW] [ops/replace_range.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/replace_range.dart)
`replaceRange(state, span, items)`.

#### [NEW] [ops/split_block.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/split_block.dart)
`splitBlockAtPosition(state, position)` — divide um bloco em dois.

#### [NEW] [ops/merge_blocks.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/merge_blocks.dart)
`mergeAdjacentBlocks(state, blockId1, blockId2)`.

#### [NEW] [ops/insert_block.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/insert_block.dart)
`insertBlock(state, args)` — insere um bloco novo.

#### [NEW] [ops/remove_block.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/remove_block.dart)
`removeBlock(state, blockId)`.

#### [NEW] [ops/set_block_type.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/set_block_type.dart)
`setBlockType(state, blockId, type)`.

#### [NEW] [ops/set_block_attrs.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/set_block_attrs.dart)
`setBlockAttrs(state, blockId, attrs)` + `mergeBlockAttrs`.

#### [NEW] [ops/apply_attrs.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/apply_attrs.dart)
`applyAttrsToRange(state, span, attrs)` — aplica formatação inline a um range.

#### [NEW] [ops/create_table.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/create_table.dart)
`createTable(state, rows, cols)`.

#### [NEW] [ops/insert_table_row.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/insert_table_row.dart)
#### [NEW] [ops/insert_table_column.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/insert_table_column.dart)
#### [NEW] [ops/delete_table_row.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/delete_table_row.dart)
#### [NEW] [ops/delete_table_column.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/delete_table_column.dart)
#### [NEW] [ops/delete_table.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/delete_table.dart)
#### [NEW] [ops/merge_cells.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/merge_cells.dart)
#### [NEW] [ops/split_cell.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/ops/split_cell.dart)

---

### Fase 3 — Serialização (~7 arquivos, ~2.000 linhas Dart)

---

#### [NEW] [serialize/document_serializer.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/document_serializer.dart)
Interface `DocumentSerializer`, `SerializedDocument`.

#### [NEW] [serialize/serializer_registry.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/serializer_registry.dart)
`SerializerRegistry`, `createDefaultSerializerRegistry`.

#### [NEW] [serialize/json_serializer.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/json_serializer.dart)
Serialização JSON (human-readable). `createJsonDocumentSerializer`.

#### [NEW] [serialize/html_node.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/html_node.dart)
`HtmlNode`, `HtmlParser` interface — abstração para parsing HTML sem dependência de DOM.

#### [NEW] [serialize/html_encode.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/html_encode.dart)
`encodeHtml(state)` → HTML string. (~18KB original)

#### [NEW] [serialize/html_decode.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/html_decode.dart)
`decodeHtml(html, parser)` → State. (~23KB original). Usará `package:html` como o `HtmlParser`.

#### [NEW] [serialize/html_serializer.dart](file:///c:/MyDartProjects/taleweaver/lib/src/state/serialize/html_serializer.dart)
`createHtmlDocumentSerializer` wrapper.

---

### Fase 4 — Sistema de Estilos (~13 arquivos, ~2.500 linhas Dart)

---

#### [NEW] [styles/style.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/style.dart)
Tipo `Style` com TODAS as propriedades CSS suportadas (~7KB original): display, position, width/height, margins, paddings, borders, font-*, text-*, color, background, float, clear, break-*, list-style, etc.

#### [NEW] [styles/computed_style.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/computed_style.dart)
`ComputedStyle`, `INITIAL_COMPUTED_STYLE`.

#### [NEW] [styles/used_style.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/used_style.dart)
`UsedStyle` — estilo final com todas as lengths resolvidas.

#### [NEW] [styles/property_meta.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/property_meta.dart)
`PROPERTY_META` — metadata de cada propriedade CSS (inherited, initial value, etc.).

#### [NEW] [styles/physical_sides.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/physical_sides.dart)
`PhysicalBorderSides`, `resolveLogicalSides`.

#### [NEW] [styles/position.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/position.dart)
CSS positioning, `StackingContextRole`, `computeStackingContextRole`.

#### [NEW] [styles/writing_mode.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/writing_mode.dart)
`WritingMode`, `AxisMap`, `axisMapFor`, `logicalToPhysical`.

#### [NEW] [styles/tab_stops.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/tab_stops.dart)
`TabStop` type.

#### [NEW] [styles/column_config.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/column_config.dart)
`ColumnConfig`, `DEFAULT_COLUMN_CONFIG`.

#### [NEW] [styles/format_counter.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/format_counter.dart)
`formatCounter()` — formata contadores (1→"1", 1→"a", 1→"i", etc.).

#### [NEW] [styles/author_color.dart](file:///c:/MyDartProjects/taleweaver/lib/src/styles/author_color.dart)
Paleta de cores para autores.

---

### Fase 5 — Cascade + Components (~20 arquivos, ~3.000 linhas Dart)

---

#### [NEW] Todos os arquivos em `cascade/` e `components/` conforme a árvore acima
O cascade engine aplica attrs → computed styles usando o `AttrRegistry` (interpreters que mapeiam attrs do bloco para propriedades CSS). Os components definem a "view" de cada tipo de bloco (como um parágrafo, heading, tabela se traduz em RenderNodes com styles).

---

### Fase 6 — Render Tree (~10 arquivos, ~2.500 linhas Dart)

---

#### [NEW] Todos os arquivos em `render/`
Pipeline: `State` → `render()` produz `RenderOutput` com `RenderNode` tree (como uma virtual DOM, mas sem posicionamento geométrico). Cada `RenderNode` é `ElementBox` ou `TextBox` com `computedStyle`.

---

### Fase 7 — Layout Text Core + Cursor (~25 arquivos, ~5.000 linhas Dart)

---

#### [NEW] Todos os arquivos em `layout/` (incluindo uax14/ e uax9/)
O motor de texto: grapheme segmentation, line-break (UAX #14), bidirectional text (UAX #9), text shaping interface, text measurement, matrix math, intrinsic sizes.

#### [NEW] Todos os arquivos em `cursor/`
Modelo de seleção baseado em IDs de bloco (geometry-free).

---

### Fase 8 — Editor State Machine + Actions (~50 arquivos, ~6.000 linhas Dart)

---

#### [NEW] Todos os arquivos em `editor/` e `editor/actions/`
`EditorState` + `reduceEditor()` (o reducer Redux-like) + ~45 action handlers que transformam `EditorState`.

---

### Fase 9 — Print Backend: Layout Engine (~30 arquivos, ~8.000 linhas Dart)

O motor de layout geométrico que posiciona caixas na página.

---

#### [NEW] Todos os arquivos em `print/layout/`
Block Formatting Context (BFC), Inline Formatting Context (IFC), fragmentação, paginação, layout de tabelas, virtual layout tree.

#### [NEW] Todos os arquivos em `print/cursor/`
Hit-test, cursor position, selection geometry, line navigation.

#### [NEW] [print/layout_driver/](file:///c:/MyDartProjects/taleweaver/lib/src/print/layout_driver/)
`LayoutDriver`, `LayoutConfig`.

---

### Fase 10 — Print Backend: Canvas Rendering (~10 arquivos, ~5.000 linhas Dart)

---

#### [NEW] [print/canvas_renderer.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/canvas_renderer.dart)
`paintCanvas()`, `paintPage()` — pintura do documento no `<canvas>` usando `package:web` (`CanvasRenderingContext2D`). O original tem 81KB; será o arquivo mais complexo da portagem.

#### [NEW] [print/canvas_measurer.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/canvas_measurer.dart)
`createCanvasMeasurer()` — mede texto usando o canvas do browser.

#### [NEW] [print/canvas_shaper.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/canvas_shaper.dart)
`createCanvasShaper()` — text shaping via canvas.

#### [NEW] [print/font_config.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/font_config.dart)
Configuração de fontes.

#### [NEW] [print/paint_cache.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/paint_cache.dart)
Cache de paint para evitar repintura desnecessária.

#### [NEW] [print/image_cache.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/image_cache.dart)
Cache de imagens carregadas.

#### [NEW] [print/offscreen_surface.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/offscreen_surface.dart)
Canvas offscreen para medição.

---

### Fase 11 — Print Backend: Editor Controller + Keyboard (~5 arquivos, ~5.000 linhas Dart)

---

#### [NEW] [print/editor_controller.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/editor_controller.dart)
`EditorController` — o "mega-controller" que orquestra tudo: estado, layout, paint, seleção, input, find/replace, comments UI. O original tem **116KB** (~2700 linhas) e será o arquivo mais longo. Conecta:
- DOM events (keyboard, mouse, clipboard, IME) → EditorActions
- EditorState → Layout → Paint cycle
- Selection → Cursor rendering
- Tudo via `package:web`

#### [NEW] [print/key_handler.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/key_handler.dart)
`mapKeyEvent()` — mapeia KeyboardEvent para EditorAction.

#### [NEW] [print/dom_mirror.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/dom_mirror.dart)
DOM mirror para acessibilidade (stub inicial).

#### [NEW] [print/text_clusters.dart](file:///c:/MyDartProjects/taleweaver/lib/src/print/text_clusters.dart)
Utilidades para clusters de texto.

---

### Fase 12 — Digital Backend (opcional para MVP) (~7 arquivos, ~2.000 linhas Dart)

---

#### [NEW] Todos os arquivos em `digital/`
Modo contenteditable (DOM-based, browser faz o layout). Menos prioritário que o canvas mode.

---

### Fase 13 — Numbering + Footnotes + Misc (~10 arquivos, ~1.500 linhas Dart)

---

#### [NEW] Arquivos em `numbering/` e `footnotes/`
Numeração de listas e notas de rodapé.

---

### Fase 14 — Demo App (equivalente ao exemplo DOM/React)

---

#### [NEW] [web/index.html](file:///c:/MyDartProjects/taleweaver/web/index.html)
HTML host com `<canvas>` elements e toolbar.

#### [NEW] [web/main.dart](file:///c:/MyDartProjects/taleweaver/web/main.dart)
Entry point: inicializa `EditorController`, monta toolbar, conecta eventos.

#### [NEW] [web/toolbar.dart](file:///c:/MyDartProjects/taleweaver/web/toolbar.dart)
Barra de ferramentas com formatação (bold, italic, headings, etc.).

---

## Estratégia de Portagem TypeScript → Dart

### Padrões de Conversão

| TypeScript | Dart |
|---|---|
| `interface Foo { readonly x: T }` | `class Foo { final T x; const Foo({required this.x}); }` |
| `type A \| B \| C` (union) | `sealed class` ou enum |
| `Record<string, unknown>` | `Map<String, dynamic>` |
| `ReadonlyArray<T>` | `List<T>` (unmodifiable) |
| `Map<K, V>` | `Map<K, V>` |
| `Set<T>` | `Set<T>` |
| `null \| undefined` | `null` (Dart unifica) |
| `export function foo()` | Top-level function |
| `export type { X }` | N/A (Dart não tem type-only exports) |
| `Symbol('key')` | Private field ou `#` symbol |
| `Object.freeze()` | `UnmodifiableMapView` / `List.unmodifiable` |
| `instanceof` | `is` |
| `typeof x === 'string'` | `x is String` |
| `for...of` | `for (final x in iterable)` |
| `Array.from()` | `List.of()` ou `.toList()` |
| `?.` optional chaining | `?.` (mesmo no Dart) |
| `??` nullish coalescing | `??` (mesmo no Dart) |
| Template literals `` `${x}` `` | String interpolation `'$x'` |
| `Promise<T>` | `Future<T>` |
| Destructuring `const { a, b } = obj` | Acesso direto `obj.a, obj.b` |

### Padrões Específicos para APIs Web

| TypeScript (DOM) | Dart (package:web) |
|---|---|
| `document.createElement('div')` | `document.createElement('div') as HTMLDivElement` |
| `element.addEventListener('click', fn)` | `element.addEventListener('click', fn.toJS)` |
| `canvas.getContext('2d')` | `canvas.getContext('2d') as CanvasRenderingContext2D` |
| `ctx.fillRect(x, y, w, h)` | `ctx.fillRect(x, y, w, h)` |
| `event.preventDefault()` | `event.preventDefault()` |
| `window.requestAnimationFrame(fn)` | `window.requestAnimationFrame(fn.toJS)` |

### Substituição do Yjs — Detalhes

A interface que o core usa do Yjs:
1. **`Y.Doc`** → `TwDoc`: container com named maps
2. **`Y.Map`** → `Map<String, dynamic>` com observação
3. **`Y.Array`** → `List<dynamic>` com observação (pouco usado, apenas comments.replies)
4. **`Y.UndoManager`** → `TwUndoManager`: snapshot-based undo/redo
5. **`doc.transact(fn)`** → `TwDoc.transact(fn)`: agrupa mutações
6. **`doc.on('afterTransaction')`** → `TwDoc.afterTransaction` callback: dirty tracking
7. **Transaction origin** → `TwDoc.transact(fn, origin: 'suggestion-resolve')`: para filtrar undo

O modelo de "dirty ids" é crucial: cada mutação captura quais blockIds foram alterados, para que o render incremental reconstrua apenas os nós afetados.

---

## Estimativa de Esforço

| Fase | Arquivos | Linhas Dart (est.) | Complexidade |
|---|---|---|---|
| 0. Tipos Base | ~10 | ~800 | 🟢 Baixa |
| 1. Modelo de Dados | ~15 | ~2.500 | 🔴 Alta (substituição Yjs) |
| 2. Layer 3 Ops | ~20 | ~4.000 | 🟡 Média-Alta |
| 3. Serialização | ~7 | ~2.000 | 🟡 Média |
| 4. Estilos | ~13 | ~2.500 | 🟡 Média |
| 5. Cascade + Components | ~20 | ~3.000 | 🟡 Média |
| 6. Render Tree | ~10 | ~2.500 | 🟡 Média |
| 7. Layout Text + Cursor | ~25 | ~5.000 | 🔴 Alta (Unicode tables) |
| 8. Editor + Actions | ~50 | ~6.000 | 🟡 Média (repetitivo) |
| 9. Print Layout Engine | ~30 | ~8.000 | 🔴 Alta (BFC/IFC/Pagination) |
| 10. Canvas Rendering | ~10 | ~5.000 | 🔴 Alta (81KB renderer) |
| 11. Editor Controller | ~5 | ~5.000 | 🔴 Alta (116KB controller) |
| 12. Digital Backend | ~7 | ~2.000 | 🟡 Média (opcional) |
| 13. Numbering + Footnotes | ~10 | ~1.500 | 🟢 Baixa |
| 14. Demo App | ~3 | ~500 | 🟢 Baixa |
| **TOTAL** | **~235** | **~50.300** | |

---

## Verification Plan

### Automated Tests
```bash
# Testes unitários Dart
dart test

# Compilar para web
dart compile js web/main.dart -o web/main.dart.js

# Ou usar webdev
webdev serve
```

### Manual Verification
1. Abrir a demo no browser e verificar:
   - Digitação de texto funciona
   - Formatação (bold, italic, underline) funciona
   - Headings, listas, alinhamento funcionam
   - Tabelas são renderizadas
   - Imagens são exibidas
   - Undo/Redo funciona
   - Seleção e cursor funcionam
   - Paginação funciona (múltiplas "páginas" canvas)
   - Export/Import HTML funciona
2. Comparar visualmente com https://yuzhenmi.github.io/taleweaver/
