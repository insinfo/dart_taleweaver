# Taleweaver Dart Port - Task List

Checkpoint 2026-08-02: `WordPaginationController` deixou de agendar reflow
para transações somente de seleção. A medição continua sendo solicitada para
mudanças reais de conteúdo, seções, templates ou geometria, preservando a
paginação e reduzindo o custo de caret/Ribbon em documentos longos.

## Tarefa-pai — Portabilidade integral TypeScript → Dart

O demo agora exercita novamente os caminhos incrementais de
`DigitalDomReconciler` e `AccessibilityDomMirror`; o fallback visual estável
não é perdido quando nós keyed são substituídos por edições estruturais.
Suíte global, análise, compilação JS e E2E Chrome permanecem verdes.

Checkpoint 2026-08-02: o projeto de exemplo `examples/advanced_editor` foi
documentado e o entrypoint `web/` demonstra toolbar avançada, histórico,
formatação, espaçamento e espelho semântico acessível. O teste E2E opt-in
`test/e2e/advanced_editor_e2e_test.dart` usa `shelf_static` e `puppeteer` para
validar o fluxo no Chrome. A seleção inicial foi alinhada ao helper TypeScript
`initialSelectionForState`, escolhendo o primeiro leaf com `inlineContent` e
evitando ações de toolbar sobre containers. Validação: suíte global (321
testes, 1 skip opt-in), `dart analyze`, compilação JS e E2E Chrome verdes.
O fallback contenteditable visual também é sincronizado com o `InlineContent`
após cada dispatch, e o E2E verifica esse texto visível antes das demais ações
da toolbar.
Os eventos de seleção, `beforeinput`, IME, teclado, clipboard, paste e drop
agora leem o host visual estável, e o E2E cobre digitação textual no Chrome
com `sendCharacter`.
`reconcileForeignChange` também foi portado para colaboração: invalida
snapshots dirty, preserva seleção/histórico e publica `lastDirtyIds`; a suíte
global está em 325 testes verdes. `subscribeForeignChanges` foi adicionado
com filtro de origem, dirty IDs e unsubscribe idempotente; o mapa arquitetural
está em `docs/portability_architecture_map.md`. `runWithTransactionOrigin`
também foi portado com `Zone`, cobrindo origem ambient em operações aninhadas.

Checkpoint 2026-08-02: o reducer agora porta o caminho direto de paste
multilinha da referência, com normalização CRLF, replacement, split único,
blocos irmãos intermediários, caret final e undo único. A cobertura avançada
de paste sugerido/IME e demais pendências da portabilidade continua aberta.

O modo de sugestões também foi ligado ao paste via `suggestingAuthor`, usando
`replaceWithSuggestedFragment` para marcar inserções e registrar a sugestão.
`InsertTextAction` usa os caminhos equivalentes `mintInsertion` e
`replaceWithSuggestion`, com coalescing por autor.

Os caminhos de delete backward/forward/word agora usam
`markDeletion`/`deleteRangeOrSuggest` em modo de sugestões, preservando texto,
caret e fallback direto por contexto.
Formatação inline agora usa `markFormatting`, com proposta separada dos attrs
vivos e fallback direto fora de contexto.
`DeleteWordAction` também respeita seleção não colapsada antes do cálculo de
fronteira por palavra.
Os listeners browser de `copy`/`cut` agora seguem o contrato TypeScript de
`preventDefault`, `text/plain` e `DeleteRangeAction`.
`DigitalEditorController` agora encaminha `EditorConfig` ao reducer, incluindo
configuração de sugestões no host.

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
  - `[x]` `delete_table_column.dart`
  - `[x]` `delete_table_column_span_aware.dart`
  - `[x]` `delete_table_row.dart`
  - `[x]` `delete_table_row_span_aware.dart`
  - `[x]` `insert_blocks_after.dart`
  - `[x]` `insert_comment_markers.dart`
  - `[x]` `insert_cross_reference.dart`
  - `[x]` `insert_footnote.dart`
  - `[x]` `insert_inline_image.dart`
  - `[x]` `insert_items.dart`
  - `[x]` `insert_new_blocks.dart`
  - `[x]` `insert_page_field.dart`
  - `[x]` `insert_tab.dart`
  - `[x]` `insert_table_column.dart`
  - `[x]` `insert_table_column_span_aware.dart`
  - `[x]` `insert_table_row.dart`
  - `[x]` `insert_table_row_span_aware.dart`
  - `[x]` `insert_template_body.dart`
  - `[x]` `merge_block_attrs.dart`
  - `[x]` `merge_cells.dart`
  - `[x]` `merge_section.dart`
  - `[x]` `reparent_children.dart`
  - `[x]` `replace_block_with_text.dart`
  - `[x]` `replace_matches.dart`
  - `[x]` `find_matches.dart` (busca visível com offsets UTF-16, mapa de origem para folds Unicode e whole-word por letras/números Unicode)
  - `[x]` `replace_with_suggestion.dart`
  - `[x]` `section_break.dart`
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
- `[ ]` CRDT Yjs completo e compatibilidade de updates (resolução semântica avançada, snapshots/relative positions completas e colaboração ainda pendentes)
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
- `[x]` Codec V1/V2 byte-compatível com Yjs para GC/Skip/ContentDeleted/ContentString/ContentAny, merge e convergência
- `[x]` Operações locais de Array/Text geram structs e updates
- `[x]` Operações locais de YMap geram ContentAny keyed items e DeleteSet
- `[x]` `YDoc.onUpdate` com batching, origem e ordem de structs
- `[x]` Store CRDT com `ID`, `Item`, `GC` e `Skip`
- `[x]` Updates V1/V2 e merge byte-compatíveis com Yjs no subconjunto implementado
- `[x]` Fragmentação e deleção parcial de itens preservando clocks e DeleteSet
- `[x]` Replay remoto de YText/YArray, origins básicos e fila de pending structs
- `[x]` Aplicação de DeleteSet remoto na materialização de Text/Array/Map
- `[x]` Content refs V1/V2: Binary, Embed, Format, Type e Doc
- `[x]` Cobertura de sobreposições já integradas e sufixos causais de GC/Skip/Text/Array
- `[x]` Ordenação determinística de inserções concorrentes de YText por `YId`
- `[x]` Ordenação determinística de inserções concorrentes de YArray por `YId` e origin/rightOrigin
- `[x]` Tombstones de YArray contra ressurreição de updates remotos obsoletos
- `[x]` Tombstones de YText contra ressurreição de ContentString remoto obsoleto
- `[x]` Fragmentação de segmentos de YText/YArray em deleções parciais, preservando clocks sobreviventes e rejeitando replay duplicado
- `[x]` Detecção de payload divergente para o mesmo `YId`
- `[/]` Resolução de conflitos semânticos (ordenação determinística por `YId`, tombstones e deletes remotos fora de ordem em `YMap`/`YArray`/`YText`, inserções vazias como no-op sem clocks/eventos, transação automática para `YArray.delete` fora de `transact`, atributos materializados de `YText` via `insert`/`format`/`toDelta` com offsets UTF-16 inclusive surrogate pairs, emissão local e aplicação remota de `YFormatContent` em fronteira causal com abertura/fechamento básico por `null`, pareamento de marcadores entregues fora de ordem e fila para marcadores que chegam antes do texto, resolução de owner root por chave no replay, round-trip V1/V2 de âncoras internas a segmentos agrupados, fallback por `rightOrigin` após deleção da origem e convergência de formatos concorrentes sobrepostos, `pendingDeletes` para DeleteSet anterior ao struct, tipos compartilhados aninhados via `ContentType` com parent causal, updates posteriores e deleções nested convergentes em Map/Array/Text, origem preservada em `applyUpdate`/`applyUpdateV2` para filtros de UndoManager e observadores colaborativos, `YDocProvider`/`InMemoryYDocHub` com state-vector sync V1/V2, `YWebSocketProvider` browser-native com sync inicial e framing base64, `mergeUpdatesV2`, `encodeStateVectorFromUpdate`/`V2` e `diffUpdate`/`V2` com filtragem causal, no-op sem clocks novos e peers tardios, além de `YAwareness` com clocks/tombstones/listeners/lifecycle de desconexão, wire format binário lib0/Yjs, `YAwarenessProvider` e `InMemoryAwarenessHub` multi-peer de teste com sincronização de peers tardios portados; interleaving causal mais complexo e conflitos semânticos completos entre tipos ainda pendentes)
- `[x]` Regressão de colaboração para `YMap` aninhado em `YArray`, com peer tardio e mutação posterior convergente
- `[x]` Emissão causal do conteúdo inicial de tipos compartilhados integrados em parent item (`YMap`/`YArray`/`YText`)
- `[x]` Handshake de `InMemoryYDocHub` sem eco de structs recém-recebidos, incluindo regressão de tipos nested pré-preenchidos mistos
- `[x]` Regressão V2 do handshake com tipos nested pré-preenchidos (`YMap` + `YText`)
- `[x]` Handshake de `InMemoryAwarenessHub` sem eco de estados de presença recém-recebidos
- `[x]` Diff de updates por state vector para V1/V2 (subconjunto de structs)
- `[/]` Snapshots serializáveis (state vector + DeleteSet), framing binário V1/V2 (`encodeSnapshot`/`decodeSnapshot`), `equalSnapshots`/`snapshotContainsUpdate` causal em updates V1/V2 (inclusive structs apagados depois), membership de updates, `createDocFromSnapshot` e relative positions root/nested (round-trip interno UTF-16, associações `-1/0/1`, parent item causal, prioridade sobre chaves colidentes, restore de itens deletados após o boundary, cópia materializada de atributos aninhados, emissão causal de atributos de `YText` pré-integrado e snapshots internos tipados de `YMap`/`YArray`/`YText` portados; integração colaborativa avançada ainda pendente)
- `[x]` `createDocFromSnapshot` preserva a topologia de tipos compartilhados nested no boundary causal
- `[x]` Relative positions baseline para YText raiz, JSON e resolução local
- `[x]` Relative positions ancoradas em `YId`, com associação preservada (`assoc`), âncoras internas de segmentos e fronteira sobrevivente após inserções/deleções locais/remotas
- `[/]` UndoManager compatível (snapshots tipados preservando tipos compartilhados aninhados e `YText.toDelta` com atributos, `pendingDeletes`/`skips`, igualdade causal para transações interval-only, origins rastreados, undo/redo, stack depth, `stopCapturing`, coalescing temporal, escopos aninhados, reconstrução de índices causais root/nested após restore e integração automática de `YDoc.transact`/mutações diretas de `YText`/`YMap`/`YArray` portados; semântica colaborativa avançada ainda pendente)
- `[x]` Regressão de undo/redo dentro de `YText` embutido em `YArray`, preservando a topologia compartilhada em snapshots tipados
- `[x]` Lifecycle explícito de `YUndoManager.dispose()` com remoção de observers
- `[x]` UndoManager baseline para snapshots do YStructStore e valores materializados compartilhados, com rastreamento padrão do origin local e exclusão de peers remotos
- `[/]` Portar a suíte completa de `referencias/yjs-main/tests` (suíte TypeScript de referência executada: 306 casos; equivalência Dart ainda pendente)

## Fase 3 — Layer 4 View / Layout Adapters
- `[/]` `layout_adapters` e `view_trees` (TextShaper/TextMeasurer e keyed digital diff portados; view tree/layout adapters completos pendentes)

## Fase 7 — Cursor geometry-free
- `[x]` Grapheme boundaries e word boundaries em offsets UTF-16
- `[x]` Movimento por caractere e palavra entre blocos folha
- `[x]` Seleção de palavra e expansão de seleção
- `[x]` Predicados de seleção e seleção de objetos
- `[/]` Equivalência completa com todos os testes TS de cursor (navegação por palavra preserva offsets globais entre runs/embeds e movimento por caractere cobre embeds e fronteiras entre blocos; suíte geométrica de cursor/print ainda pendente)

## Fase 7 — Layout text core
- `[x]` Grapheme segmentation compartilhada com cursor e shaper
- `[x]` Tokenização de white-space e mandatory line breaks
- `[x]` Text transform com mapeamento source/display
- `[x]` Mat2D affine, composição, aplicação e inversão
- `[x]` TextShaper/TextMeasurer e mock shaper
- `[x]` Text spacing e break opportunities básicas
- `[x]` UAX #14 com tabela Unicode 16.0.0 completa (ranges gerados da referência TS)
- `[x]` UAX #14 conjuntos auxiliares East Asian Wide, pictographic-Cn e Pi/Pf QU
- `[x]` Regras adicionais UAX #14 LB1/LB6–LB30 (combining, numeric, RI, Korean e quotation baselines)
- `[x]` UAX #9 bidi com tabela Unicode 16.0.0 completa (ranges gerados da referência TS)
- `[x]` UAX #9 tabelas completas de espelhamento e pares de brackets Unicode 16.0.0
- `[x]` Intrinsic sizes min-content/max-content baseados no TextShaper
- `[x]` Interface `Hyphenator` e mock determinístico para testes
- `[/]` Hyphenation e shaping Canvas (adaptador `createCanvasShaper`, métricas Canvas reais com fallback, matcher Knuth–Liang com padrões/exceções/índices UTF-16, dados en-US da referência com aliases `en`/`en-us` e integração de pontos `hyphens: auto` no produtor IFC com metadado de hífen sintético portados; dados de outros idiomas e shaping HarfBuzz ainda pendentes)
- `[x]` UAX #9 baseline: classes, paragraph direction, níveis básicos, reorder L2 e mirrors básicos

## Fase 8 — Editor state machine
- `[x]` EditorState, EditorAction e reducer geometry-free básicos
- `[x]` Inserção de texto, seleção, movimento de palavra e expansão
- `[x]` Delete range/backward/forward básico
- `[x]` Apply formatting action para spans inline
- `[x]` Integração inicial com History undo/redo (inclui coalescing temporal de inserções/remoções, quebra por seleção/comando e descarte de no-op)
- `[/]` Portar todas as ações e coalescing da referência (incluindo alinhamento, geometria de colunas com `ColumnRule`, dimensões de tabela com guard ragged/no-op, delete-table com caret de replacement e espaçamento de linha/parágrafo com validação de valores e no-op sem histórico para entradas inválidas, normalização/ordenação de tab-stops, validação de alvo/dimensões/wrap canônico em ações de imagem, indentação de parágrafos/listas aplicada a seleções multi-folha, replacement match/all com cursor/atributos equivalentes e override de orientação condicionado a page-config/seção ativa; ações estruturais e políticas avançadas restantes ainda pendentes)
- `[x]` Ações `EXPAND_DOCUMENT_BOUNDARY` e `SET_CONTAINER_WIDTH` ligadas ao reducer
- `[x]` Ação `ESCAPE` reconhece seleção de objetos atômicos e preserva no-op na borda
- `[x]` Ação `INSERT_NODE` valida tipos pelo registry e insere subárvores recursivas
- `[x]` `INSERT_NODE` aceita registry de componentes configurável via `EditorConfig`
- `[x]` `INSERT_NODE` participa da captura de histórico e expõe dirty IDs no undo
- `[/]` Paste, formatting, tabelas, imagens, comentários e sugestões (incluída também inserção de imagem, linha horizontal e TOC em bloco com parágrafo de landing, replacement de seleções por imagem inline, tab, tabela, cross-reference e footnote com caret após o embed/corpo, campos de página restritos a template, header/footer idempotentes e undo único; paste/formatação, ciclo de comentários/sugestões, embeds, criação/edição estrutural e interação completa de imagens ainda pendentes)

## Fase 9 — Print layout geometry
- `[x]` LayoutBox, BlockBox, TextRunBox, LineBox e PageBox base
- `[x]` Page size, margins, page gap e content geometry
- `[/]` BFC/IFC, fragmentation, pagination e table layout (IFC prefere oportunidades UAX #14 soft, respeita mandatory line breaks, integra pontos automáticos de hifenização e agora possui grid de spans/sizing intrínseco de colunas, composição `TableBox`/`TableRowBox`/`TableCellBox`, fragmentação de tabelas por fronteiras de rows com repetição de `headerRowCount`, fragmentação de `BlockBox` rico por filhos e fragmentação/carry de corpos de footnote no print layer; `PageBox.headerSlot`/`footerSlot`/`footnoteSlot` nomeados e wrapper geométrico por página são a representação canônica, a paginação aceita e repete header/footer nomeados, `layoutTemplateRenderNode` e APIs de slots renderizados/por página/State materializam corpos em `BlockBox`, preservam imagens inline e fronteiras de elementos aninhados, reservam insets e ancoram header/footer sem sobreposição, com pintura/cursor/selection e descoberta de âncoras distinguindo slots do corpo sem duplicação; floats inline-start/inline-end de imagens com narrowing, deslocamento do fluxo, `clear` lateral/ambos, nova faixa para colisão e liberação após a borda inferior foram portados, mas políticas completas multi-linha ainda pendentes)
- `[/]` Cursor geométrico, hit-test e selection geometry (caret/hit-test textual em linhas e tabelas aninhadas, entrada pública `hitTestPage` com prioridade para índice/hit-test de objetos atômicos por retângulo físico, caret e selection recursivos com offsets físicos acumulados, seleções entre blocos diferentes e páginas, offsets de linha, afinidade before/after, seleção same-line/multi-line por página e agregação de fragmentos entre páginas — inclusive eixo inline vertical — e travessia do `PageBox.footnoteSlot` nomeado portados; interação completa ainda pendente)
- `[x]` Hit-test textual acumulando offsets através de múltiplos `TextRunBox` na mesma linha
- `[x]` Hit-test, caret e seleção RTL por `TextRunBox`, com fração física espelhada
- `[x]` Hit-test e caret verticais nos eixos físicos de `vertical-lr`/`vertical-rl`
- `[x]` Seleção vertical por faixa de bloco X e eixo inline Y, com direção RTL
- `[x]` Espelhamento RTL no hit-test/caret de linhas verticais
- `[x]` IFC/BFC baseline para texto medido por clusters e quebra por largura
- `[x]` Paginação baseline por altura útil em `PageBox`
- `[x]` Hit-test textual baseline para PageBox/LineBox/TextRunBox
- `[x]` Cursor geometry baseline por PageBox/LineBox/TextRunBox

## Fase 12 — Digital backend
- `[x]` Conversão inicial de ComputedStyle para CSS inline
- `[x]` Ponte inicial RenderNode -> `package:web` DOM
- `[x]` Mapeamento puro de beforeinput e atalhos digitais para EditorAction
- `[x]` Controller síncrono de editor para dispatch de beforeinput/teclas e listeners
- `[x]` Ação de paste de texto e mapeamento `insertFromPaste`
- `[x]` Selection bridge serializável entre pontos DOM e posições UTF-16
- `[x]` Render State/RenderNode para `package:web` DOM
- `[/]` Reconciler incremental e selection bridge (diff keyed, bridge puro, ciclo real mount/reconcile/destroy, aplicação keyed de nós em `package:web`, patch fino recursivo por `data-block-id`, demo web montado no render tree real, reconciliação posicional de subárvores não-keyed e text nodes misturados, propagação compartilhada de `SuggestionView` visual/semântica, captura/restauração de seleção do host em subárvores DOM aninhadas e listener global `selectionchange` com deduplicação estrutural portados; listeners/semântica completa de todos os widgets DOM ainda pendentes)
- `[/]` beforeinput/key mapping e controller contenteditable (insert/delete/history, deletion de embeds atômicos nas fronteiras, replacement com fallback `dataTransfer`/target ranges, paste nativo sem duplicação, drop, word/line delete, cut/drag ancorados na seleção corrente, format shortcuts, modificador primário Ctrl/Meta por plataforma, `Escape`, Tab/list context, edição Backspace/Delete/Enter delegada exclusivamente a `beforeinput`, listeners delegados no wrapper, composição IME com commit único, paste/drop nativos de `text/plain` e extração browser de `StaticRange` para `targetRanges` portados; composição avançada com reconciliação ainda pendente)

## Fase 10 — Canvas renderer
- `[x]` Pintura recursiva de PageBox/BlockBox/LineBox/TextRunBox via `package:web`
- `[x]` Estilos básicos (cor, fonte e background) no renderer Canvas
- `[/]` Imagens, seleção, cursor, cache e rendering completo (ImageBox/cache com proteção contra `src` vazio e erros de carga, pintura de imagens, materialização de imagens inline em templates, seleção multi-line, cursor Canvas, callbacks `onLoaded` para repaint assíncrono, bandas de realce de matches/comentários/sugestões, hífen sintético, índice de objetos atômicos, suporte de pintura ao `PageBox.footnoteSlot` nomeado, hit-test recursivo de imagens e exportação data URL/Blob com formatos `png`/`jpeg`/`webp` validados portados; interação completa e hit regions avançadas ainda pendentes)

## Fase 4 — Componentes
- `[x]` `components` e `registry` base (document, paragraph, heading, lists, tables, embeds)
- `[/]` Árvore de acessibilidade geometry-free (roles ARIA principais, agrupamento de listas com ordinais `value`, seções transparentes com fronteiras de agrupamento preservadas, projeções `suggesting`/`finalView`/`originalView` com offsets literais, runs inline, markers de page/cross-reference para modos number/text/page com texto resolvido, comentários, IDs reais de comentários/sugestões (`data-comment-id`/`data-suggestion-id`) e campos expostos por atributos semânticos, corpos de footnote/template com distinção `banner`/`contentinfo`, ponte DOM mirror `package:web` com offsets/links/ênfases, placeholder de erro restrito a `cross-ref-page`, `id` em `doc-footnote`, host editável/focável com `role=textbox` e `aria-multiline`, resolução sem churn por identidade de nós/filhos inalterados, raiz e descendentes keyed estáveis durante `reconcile` e ciclo `mount`/`reconcile`/`destroy` portados; listeners DOM e cobertura integral de sugestões/cross-references ainda pendentes)

## Fase 6 — Render tree
- `[x]` RenderState recursivo via ComponentRegistry
- `[x]` ElementBox/TextBox para blocos e inline content
- `[x]` Pipeline render -> cascade e cascade incremental inicial
- `[/]` Cascade completo, incremental render, footnotes, TOC e cross-references (incluída ação validada `SET_FOOTNOTE_POLICY`; cascade base/incremental, numbering de listas, índice determinístico de numeração de âncoras de footnote com formatos e resets por root/seção/página, inserção de bloco TOC com attrs padrão, `renderFootnoteBody` para raízes de `embedContents`, `renderTemplateBody`/`renderCascadedTemplateBody` para raízes de `templateContents`, reserva/carry e fragmentação de corpos em `paginateBlockWithFootnotes`, slots de template repetidos e distintos por página, `resolvePageFieldText`, materialização tardia de page-fields em `TextBox` por página, metadata/coleção de placeholders estáveis, driver de convergência F-3 e APIs de paginação convergente/per-page/State, `layoutTemplateRenderNode` para materialização básica de corpos, imagens inline, fronteiras de elementos aninhados e tabelas com rows/cells/spans, reserva de insets e ancoragem de slots, atribuição recursiva de anchors em subárvores, desconto do espaço principal antes do slot inferior, `buildPageIndex`, resolução de cross-reference por página via índice paginado e materialização de embeds cross-reference como `TextBox` em todo o pipeline render/cascade/DOM; integração incremental completa, layout rico/fragmentação dos corpos de template a partir do estado ainda pendente e resolução avançada ainda pendentes)
- `[x]` Conversão tipada de Length -> ComputedLength no compose/flatten cascade

## Fase 14 — Demo web
- `[x]` `web/index.html`
- `[x]` `web/main.dart` com toolbar, host contenteditable inicial e mirror semântico montado/reconciliado com raiz estável
- `[x]` Entry point compila com `dart compile js`
- `[x]` Integração inicial do controller com eventos DOM `beforeinput`/`keydown`
- `[/]` Integração completa do reducer/editor com eventos DOM (toolbar compartilhando controller, ações editoriais incluindo header/footer e page-number/page-count, alinhamento/espaçamento/indentação, captura/restauração de seleção, render tree keyed via `DigitalDomReconciler` e atualização do accessibility mirror ligadas; listeners nativos de `paste`/`drop`/`copy`/`cut` com `text/plain`, extração canônica `extractText`/`builtinEmbedSerializer` e corte via `DeleteRangeAction`, replacement de seleção por imagem inline com undo único e invalidação correta do cache após undo/redo; widgets adicionais, composição IME avançada e reconciliação contenteditable fina ainda pendentes)
