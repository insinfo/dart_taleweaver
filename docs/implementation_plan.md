# Portagem Taleweaver: TypeScript → Dart Puro

Portar o motor de processador de texto **Taleweaver** (TypeScript, monorepo com 4 pacotes, ~80.000 linhas de código fonte em ~415 arquivos) para **Dart puro** usando apenas `web: ^1.1.1` e, se necessário, `html: ^0.15.4` como dependências (sem `dart:html`).

O objetivo deste plano é a portabilidade integral de `referencias/yjs-main` e `referencias/taleweaver-main`, sem gambiarras, atalhos ou um MVP descartável. Cada fase só pode ser marcada como concluída quando a implementação Dart cobrir o contrato da referência e tiver testes equivalentes; itens ainda não portados permanecem explicitamente pendentes.

se nesessario veja as referencias D:\EuroOfficeNative\DocumentServer D:\libreoffice\core-master C:\MyDartProjects\itext\referencias\itext-dotnet-develop  C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java  C:\MyDartProjects\pdfbox_dart\referencias\pdfbox-java\fontbox\src C:\MyDartProjects\pdf.js\referencia\pdf.js-master C:\MyDartProjects\poe\referencias\poi C:\MyDartProjects\canvas-editor-port\referencias C:\MyDartProjects\canvas-editor-port\resources\word.example C:\MyDartProjects\canvas-editor-port\resources\google-docs execute um teste de cada vez pare de executar testes em paralelo esta travando o computador

### Estado da portabilidade

Checkpoint incremental: a renderização de embeds `cross-reference` agora usa o resolvedor portado para produzir `TextBox` em modos `number`, `text` e `page`; `renderState`, `renderCascadedState`, `renderCascadedIncremental` e `renderDocumentToDom` aceitam/propagam o índice opcional de páginas e a regressão de página one-based foi validada. A árvore de acessibilidade também preserva marcadores geometry-free para todos os modos de cross-reference. Suíte global: 230 testes, `dart analyze` limpo e compilação JS aprovada. A integração incremental completa do pipeline, políticas avançadas de renumeração e a reconciliação fina do contenteditable continuam pendentes.

Checkpoint incremental: `AccessibilityDomMirror.reconcile` passou a preservar a identidade da raiz semântica montada e a substituir somente seus filhos. Isso evita invalidar foco/referências de tecnologia assistiva a cada transação do editor; o ciclo `mount`/`reconcile`/`destroy` continua validado pela compilação JS e pela suíte global de 230 testes.

Checkpoint incremental: os dados en-US de Knuth–Liang da referência agora estão disponíveis em `hyphenation_en_us.dart`, incluindo aliases `en`/`en-us`, exceções canônicas e fábrica `createDefaultLiangHyphenator`. A regressão específica e a suíte global (230 testes) validam o algoritmo com dados reais; padrões de outros idiomas e shaping HarfBuzz continuam pendentes.

Checkpoint incremental: `YWebSocketProvider` adiciona transporte de rede browser-native sobre `YDocProvider`, com framing base64 V1/V2, sincronização no evento `open`, descarte lifecycle-safe e tolerância a frames inválidos. `dart analyze`, compilação JS e os 230 testes continuam verdes.

Checkpoint incremental: `web/main.dart` agora monta o estado inicial através de `DigitalDomReconciler` e reconcilia o render tree real a cada edição, mantendo o parágrafo keyed/contenteditable e a ponte de seleção/eventos DOM. A compilação JS e os 230 testes permanecem aprovados.

Checkpoint incremental: os listeners browser de `beforeinput`, composição IME e teclado foram delegados ao wrapper do editor; eles resolvem o parágrafo keyed atual a cada evento e sobrevivem à substituição de nós pelo reconciler. `dart analyze`, compilação JS e os 230 testes continuam verdes.

Checkpoint incremental: o cursor/hit-test de print agora expõe `atomicBlockIndex` e `hitTestAtomicBlock`, indexando imagens e linhas horizontais por retângulo físico e `BlockId` antes do fallback textual. A regressão cobre hit dentro/fora de imagem; suíte global de 230 testes, análise e compilação JS aprovadas.

Checkpoint incremental: `hitTestPage` aceita opcionalmente `State` e integra o hit-test atômico antes do caminho textual, preservando compatibilidade das chamadas existentes. A regressão cobre a entrada pública e a suíte global permanece em 230 testes.

Checkpoint incremental: `canvas_export.dart` adiciona exportação síncrona para data URL e assíncrona para `Blob`, com MIME (`png`/`jpeg`/`webp`) e qualidade validados. A API é browser-native e desacoplada da pintura; compilação JS e os 230 testes permanecem verdes.

Checkpoint incremental: `AccessibilityDomMirror.reconcile` agora executa diff recursivo keyed por `data-block-id` e posicional para runs/text nodes, preservando descendentes semânticos focados e atualizando atributos stale. A compilação JS e a suíte global de 230 testes permanecem aprovadas.

Checkpoint incremental: snapshots internos do `YUndoManager` agora incluem `YStructStore.pendingDeletes`, restaurando tombstones causais corretamente em undo/redo. A regressão dedicada e a suíte global de 230 testes confirmam a semântica.

Checkpoint incremental: o mesmo snapshot agora preserva também `YStructStore.skips`, evitando perda de intervalos causais ao restaurar undo/redo; a regressão cobre `pendingDeletes` e skips simultaneamente. A suíte global permanece em 230 testes.

Checkpoint incremental: a igualdade de snapshots do `YUndoManager` agora considera `pendingDeletes` e `skips`, portanto transações que alteram somente intervalos causais geram StackItem e podem ser desfeitas/refeitas. A regressão interval-only e a suíte global de 230 testes estão verdes.

Checkpoint incremental: o DOM mirror de acessibilidade agora expõe `data-suggestion`, `aria-roledescription`, `data-field-kind` e `data-field-key` nos runs correspondentes, preservando metadados de sugestões/campos para tecnologia assistiva e listeners. `dart analyze`, compilação JS e 230 testes continuam verdes.

Checkpoint incremental: os runs de acessibilidade agora preservam também os IDs reais de `insertionSuggestionId`/`deletionSuggestionId` e `properties.commentId`; o mirror materializa `data-suggestion-id` e `data-comment-id` sem perder offsets ou identidade durante o diff recursivo. A regressão dedicada, `dart analyze`, compilação JS e a suíte global (231 testes) estão verdes.

Checkpoint incremental: o scanner de comentários usa pilha de IDs para restaurar corretamente o comentário externo após marcadores aninhados, mantendo `inComment` e `data-comment-id` determinísticos. A suíte global permanece em 231 testes, com análise e compilação JS aprovadas.

Checkpoint incremental: a árvore de acessibilidade agora calcula ordinais de listas com o mesmo `computeCounters` do render tree e o DOM mirror emite `value` nos `<li>` ordenados, preservando também esses dados em `resolveAccessibilityFields`. A regressão existente confirma o primeiro ordinal; análise, compilação JS e 231 testes seguem verdes.

Checkpoint incremental: `buildAccessibilityTree` agora aceita `SuggestionView.suggesting`, `finalView` e `originalView`, filtrando runs invisíveis com `itemVisibleInView` sem alterar os offsets UTF-16 literais. Regressões cobrem exclusão/inserção sugeridas; `dart analyze`, compilação JS e a suíte global (232 testes) estão verdes.

Checkpoint incremental: `DigitalDomReconciler` e `AccessibilityDomMirror` agora aceitam a mesma `SuggestionView`, propagando a projeção escolhida para DOM visual e semântico sem alterar a API padrão (`suggesting`). Análise, compilação JS e 232 testes permanecem verdes.

Checkpoint incremental: snapshots internos do `YUndoManager` passaram a usar uma representação tipada de `YMap`/`YArray`/`YText`, restaurando a topologia de tipos compartilhados aninhados em undo/redo em vez de degradá-la para JSON simples. Regressão dedicada, análise, compilação JS e a suíte global (233 testes) estão verdes.

Checkpoint incremental: o host `web/main.dart` agora trata eventos nativos `paste` e `drop`, lê `text/plain`, sincroniza a seleção DOM e despacha `PasteTextAction` com `preventDefault`, complementando o caminho `beforeinput`/IME. Análise, compilação JS e 233 testes permanecem verdes.

Checkpoint incremental: o `CanvasShaper` agora usa métricas reais `actualBoundingBox*` do Canvas para ascent/descent/cap-height/x-height, com fallback heurístico compatível quando o navegador não fornece valores positivos. A análise, compilação JS e a suíte global (233 testes) permanecem verdes.

Checkpoint incremental: o `YUndoManager` agora tem regressão equivalente a `testUndoInEmbed` da referência, restaurando edições feitas dentro de um `YText` embutido em `YArray` sem degradar o tipo compartilhado. `dart analyze`, compilação JS e a suíte global (234 testes) permanecem verdes.

Checkpoint incremental: o hit-test textual agora percorre todos os `TextRunBox` de uma linha e calcula offsets UTF-16 acumulados por span, em vez de retornar sempre o primeiro run. A regressão de inline runs, análise, compilação JS e a suíte global (235 testes) permanecem verdes.

Checkpoint incremental: a colaboração in-memory agora tem regressão de tipos compartilhados aninhados (`YMap` dentro de `YArray`), cobrindo sincronização de peer tardio e atualização posterior do filho com convergência V1. A análise, compilação JS e a suíte global (236 testes) permanecem verdes.

Checkpoint incremental: ao integrar um tipo compartilhado já materializado, o parent item agora é criado primeiro e seus valores iniciais são emitidos como structs causais nested; `YMap` e `YText` pré-preenchidos em `YArray` convergem em peer tardio sem alterar o wire format. A análise, compilação JS e as regressões V1/V2 de colaboração permanecem verdes.

Checkpoint incremental: a ordem do handshake de `InMemoryYDocHub` foi corrigida para capturar o full update local do novo peer antes de aplicar o sync remoto; isso evita ecoar structs recém-recebidos e elimina conflitos de payload em `YMap`/`YText` nested. A regressão cobre tipos pré-preenchidos mistos, `dart analyze`, compilação JS e a suíte global (237 testes) permanecem verdes.

Checkpoint incremental: `InMemoryAwarenessHub` agora usa a mesma ordem de handshake, evitando eco de estados de presença recém-recebidos e preservando clocks/tombstones durante joins tardios. Os testes de awareness, análise, compilação JS e a suíte global (237 testes) permanecem verdes.

Checkpoint incremental: o hit-test, caret e seleção de print agora respeitam a direção `rtl` de cada `TextRunBox`, espelhando a fração física e normalizando retângulos invertidos. A regressão RTL, análise, compilação JS e a suíte global (238 testes) permanecem verdes.

Checkpoint incremental: a colaboração de tipos nested pré-preenchidos foi validada também no handshake V2 (`YMap` + `YText` em `YArray`), mantendo convergência e clocks sem eco. Análise, compilação JS e a suíte global (239 testes) permanecem verdes.

Checkpoint incremental: o caret e o hit-test de print agora mapeiam `vertical-lr`/`vertical-rl` pelo eixo inline físico Y e pelo eixo de bloco físico X, mantendo offsets UTF-16 e altura do bloco. A regressão vertical, análise, compilação JS e a suíte global (240 testes) permanecem verdes; seleção vertical avançada continua pendente.

Checkpoint incremental: a seleção de print agora fragmenta linhas verticais usando a faixa física X do bloco e a faixa Y do eixo inline, incluindo direção RTL na posição inline. A regressão vertical de seleção, análise, compilação JS e a suíte global (241 testes) permanecem verdes.

Checkpoint incremental: hit-test e caret verticais agora espelham também o eixo inline quando a linha é RTL, cobrindo `vertical-lr` com offsets UTF-16. A regressão vertical RTL, análise, compilação JS e a suíte global (242 testes) permanecem verdes.

Checkpoint incremental: `createDocFromSnapshot` agora recria as declarações de tipos raiz antes do replay causal e não degrada materializações nested para JSON; `YMap`/`YArray`/`YText` preservam sua topologia no boundary. Regressões de snapshot, análise, compilação JS e a suíte global (243 testes) permanecem verdes.

Checkpoint incremental: o reducer agora cobre `EXPAND_DOCUMENT_BOUNDARY` com foco contextual, preserva o anchor, e `SET_CONTAINER_WIDTH` como ação inerte sem histórico. Regressões de editor, análise, compilação JS e a suíte global (245 testes) permanecem verdes.

Checkpoint incremental: `ESCAPE` agora reconhece seleção colapsada de folhas atômicas pelo registry padrão e move o caret para o próximo bloco textual quando existe, mantendo no-op seguro na borda do documento. A regressão de objeto, análise, compilação JS e a suíte global (247 testes) permanecem verdes.

Checkpoint incremental: `YUndoManager.dispose()` agora remove observers de transação e limpa stacks, impedindo captura após o lifecycle de destruição. A regressão de lifecycle, análise, compilação JS e a suíte global (248 testes) permanecem verdes.

Também foi corrigida a aplicação das ações de alinhamento, espaçamento, indentação de parágrafos e indentação de listas para seleções que abrangem múltiplas folhas: cada bloco elegível recebe sua própria alteração, com filtros de `list-item`, clamp de indentação e uma captura de histórico transacional compartilhada, em equivalência com os handlers TypeScript.
Os valores de espaçamento de parágrafo agora seguem a validação TypeScript: números finitos não negativos são aplicados, enquanto valores negativos, infinitos, `NaN` e arestas inválidas limpam ou ignoram a operação corretamente.
Foi adicionada a ponte `dom_mirror.dart` para transformar a árvore de acessibilidade em um subtree `package:web` visualmente oculto e AT-visível, com roles semânticos, offsets UTF-16, links sanitizados, noteref, imagens inline, sugestões, ênfases e resolução de campos/cross-references.
O ciclo browser agora também possui `AccessibilityDomMirror` com `mount`/`reconcile`/`destroy`, mantendo a árvore semântica atualizável em paralelo ao renderer visual.
O entrypoint `web/main.dart` passou a montar esse mirror ao lado do contenteditable e reconciliá-lo em cada notificação síncrona do `DigitalEditorController`, cobrindo a integração visual/semântica do demo.
O Canvas renderer passou a aceitar bandas opcionais de realce para matches, comentários e sugestões, com cores ativa/inativa e ordem de composição abaixo da seleção e do texto, alinhado ao `canvas-renderer.ts`.
O reconciler browser agora reconcilia a lista completa de `childNodes`, combinando chaves estáveis para blocos com reconciliação posicional de elementos e text nodes não-keyed; isso evita perder conteúdo inline quando os dois tipos coexistem.
No núcleo Yjs, `YStructStore` agora retém `pendingDeletes` quando um DeleteSet chega antes do struct e reaplica os intervalos ao materializar o struct; os cenários V1 e V2 fora de ordem têm regressão dedicada. Suíte global: 230 testes.
O teste de codec também confirma que a reordenação causal não reintroduz o conteúdo apagado após o replay remoto.
`deleteSet` inclui esses intervalos pendentes ao reencodar o estado, permitindo que peers intermediários retransmitam o tombstone antes de receber o struct correspondente.

Checkpoint mais recente: integração de hifenização automática Knuth–Liang no produtor IFC, com pontos de quebra condicionados a `hyphens: auto`/idioma, largura de hífen sintético e metadado preservado no `LineBox` para pintura Canvas; coalescing temporal de histórico no reducer do editor permanece validado.

O `YUndoManager` também passou a agrupar capturas aninhadas em uma única entrada externa e oferece `transact`, fechando a captura mesmo quando a operação lança exceção; os testes cobrem commit, undo e cleanup do escopo pai.

Também foi adicionado o ciclo browser `DigitalDomReconciler` (`mount`/`reconcile`/`destroy`) em módulo separado para não contaminar os testes VM com `dart:js_interop`; o diff keyed e a ponte de seleção continuam reutilizáveis, e a aplicação incremental agora também reconcilia subárvores não-keyed por posição, preservando nós de texto/elementos compatíveis.
O adaptador browser também expõe `applyKeyedDomOrder`, que aplica remoções, inserções e reordenação por chave em um `Element` real.

No editor geometry-free foram adicionadas ações verificáveis de `SELECT_ALL`, limites do documento, `DELETE_WORD` e `SPLIT_NODE`, usando as primitivas de cursor/operação já portadas e mantendo undo/dirty tracking.
Também foi ligado `SET_BLOCK_TYPE` ao `ComponentRegistry` padrão, com transação, dirty tracking e teste de alteração de heading.
`TOGGLE_LIST` agora converte folhas entre `paragraph` e `list-item`, cria/remove `listId` e preserva o histórico transacional.
No CRDT, `YArray` passou a carregar `origin`/`rightOrigin` e ordenar inserções remotas concorrentes deterministicamente por `YId`, com teste de convergência.
Deleções remotas e locais de `YArray` agora preservam tombstones para rejeitar a ressurreição de structs obsoletos.
`YText` recebeu a mesma proteção para `ContentString`, preservando a convergência após deleções remotas.
O `YUndoManager` agora segue o default do Yjs de rastrear apenas `origin == null`, ignorando transações de peers quando nenhum conjunto explícito de origins é fornecido.
Na geometria de print, seleções agora são fragmentadas em retângulos por linha dentro da página, além do caso same-line; a travessia entre páginas permanece explicitamente pendente.
O renderer Canvas passou a aceitar seleção e caret e pintar os retângulos/linha de cursor sobre cada `PageBox`, além da pintura de conteúdo e imagens já existente.
`LineBox` agora registra `offsetStart` UTF-16, permitindo que caret e seleção mantenham offsets corretos quando a paginação inicia uma nova página.
`caretRectForPosition` aceita `CaretAffinity` e escolhe deterministicamente o lado anterior/posterior de uma quebra suave.
O render tree passou a calcular contadores de listas a partir de `collectListEvents`/`ListDef`, entregando marcadores ordenados aos componentes `list-item`; o teste de renderização cobre `1.`.
O índice determinístico de numeração de notas de rodapé agora percorre as âncoras em ordem documental; a inserção de âncora/body também foi corrigida para preservar `InlineContent` nos snapshots. A renderização completa dos corpos e a resolução de referências continuam pendentes.
Foi adicionado `renderFootnoteBody`, que renderiza explicitamente uma raiz de `embedContents` com a mesma árvore de componentes; integração dessa saída ao layout/paginação e políticas de renumeração ainda permanecem pendentes.
`findMatches` deixou de ser stub: agora pesquisa folhas em ordem documental, respeita case/whole-word e converte o texto visível (incluindo embeds de largura zero) para offsets UTF-16 usados por replace/selection.
O reducer do editor agora cobre `TOGGLE_STYLE` e `CLEAR_FORMATTING`, removendo/alternando attrs inline com captura de histórico e teste de undo compatível com a ação.
Também foram portadas as ações de apresentação inline `SET_LINK`, `SET_TEXT_COLOR`, `SET_HIGHLIGHT`, `SET_FONT_SIZE`, `SET_FONT_FAMILY` e `SET_TEXT_TRANSFORM`, todas usando a mesma operação transacional de spans.
O reducer também cobre `SET_LIST_TYPE` e `SET_LIST_RESTART`, com atualização da definição compartilhada e do override de contador por item.
As ações de ciclo de comentários (`ADD_COMMENT`, `RESOLVE_COMMENT`, `REOPEN_COMMENT`, `DELETE_COMMENT` e `ADD_REPLY`) agora estão ligadas ao reducer, usando os marcadores inline e registros transacionais existentes.
As ações de resolução de sugestões (`ACCEPT_SUGGESTION`, `REJECT_SUGGESTION`, `ACCEPT_ALL_SUGGESTIONS` e `REJECT_ALL_SUGGESTIONS`) também foram ligadas ao reducer e às operações de resolução existentes.
O demo web agora compartilha um único `DigitalEditorController` entre toolbar e host `contenteditable`, com botões Undo/Redo/Bold/Italic realmente despachando ações e mantendo o fluxo síncrono do reducer.
O host browser também captura pontos de seleção do único text node antes de `beforeinput`/`keydown` e restaura a seleção após cada atualização, mantendo offsets UTF-16 e evitando que `textContent` destrua o caret. Quando disponível, a ponte browser invoca `InputEvent.getTargetRanges()` via JS interop e projeta `StaticRange` para `Selection` antes do mapeamento puro.
O reducer passou a despachar inserção de footnote, cross-reference, page field e tab através das operações Layer 3 correspondentes; a seleção permanece ancorada no caret atual enquanto a resolução geométrica desses embeds segue no backend de layout.
`INSERT_TABLE` também foi ligado ao reducer, utilizando a operação de criação de subárvore com allocator determinístico; a seleção interna da primeira célula e as ações de linhas/colunas continuam como próxima integração estrutural.
As ações `INSERT_TABLE_ROW`, `INSERT_TABLE_COLUMN`, `DELETE_TABLE_ROW`, `DELETE_TABLE_COLUMN` e `DELETE_TABLE` agora resolvem `TableContext` pelo caret e reutilizam as operações span-aware existentes.
`INSERT_INLINE_IMAGE` também foi conectado ao reducer, preservando `src`, dimensões e alt text no `EmbedItem` e cobrindo a ponte para o cache/pintura Canvas já portados.
As ações `SET_IMAGE_SIZE`, `SET_IMAGE_WRAP` e `SET_IMAGE_ALT` agora atualizam attrs de blocos de imagem por `mergeBlockAttrs`, alimentando o componente de imagem, cascade e metadata do renderer.
`SPLIT_CELL` foi ligado ao reducer via `TableContext`, completando a operação estrutural de desdobramento já portada; merge de seleção retangular permanece dependente de uma seleção de células explícita no backend.
`MERGE_CELLS` agora aceita um `CellRange` explícito no reducer e reutiliza o planejador de merge existente, cobrindo a operação geometry-free sem presumir uma seleção visual.
As ações `INSERT_HORIZONTAL_LINE` e `INSERT_TABLE_OF_CONTENTS` agora inserem blocos atômicos no fluxo de irmãos, usando os attrs padrão de TOC e os componentes/render metadata já portados.
`SECTION_BREAK` e `MERGE_SECTION` também foram expostos no reducer, preservando a seleção no novo primeiro leaf após quebra e delegando reparenting/dirty tracking ao estado.
`INSERT_HEADER` e `INSERT_FOOTER` agora criam corpos de template e ligam seus IDs ao section/root ativo, completando o fluxo de edição de cabeçalho/rodapé no state layer.

O código ativo está em `lib/src/`. A antiga árvore `lib/src` não é uma segunda implementação: ela foi substituída pela organização `core` e não deve ser reintroduzida como compatibilidade artificial. A fundação de estado já possui as operações Layer 3 e os componentes/cascade iniciais, mas a portabilidade ainda não está completa.

**Última etapa concluída:** transações `TwDoc`/`applyOperation`, núcleo Yjs Dart local com relative positions, snapshots serializáveis e UndoManager baseline para store e valores materializados compartilhados, `YMap` keyed ContentAny com resolução determinística de conflitos remotos por `YId` e tombstones contra ressurreição de updates antigos, codecs de updates V1 e V2 byte a byte para `GC`, `Skip`, `ContentDeleted`, `ContentBinary`, `ContentString`, `ContentEmbed`, `ContentFormat`, `ContentType`, `ContentDoc` e `ContentAny` (incluindo canais RLE V2, DeleteSet diferencial, diff por state vector e vetores equivalentes ao Yjs 13.6.18), aplicação remota em `YText`/`YArray`/`YMap`, posicionamento causal básico por origin/rightOrigin, fila de pending structs, convergência de sobreposições cobertas/sufixos e fragmentação/deleção parcial preservando clocks para texto e arrays, render tree recursivo inicial, cascade com conversão tipada de lengths, short-circuit incremental por conjunto dirty vazio, cursor geometry-free, seleção geométrica same-line, intrinsic text sizing, mock Hyphenator, adaptadores bidirecionais `TextShaper`/`TextMeasurer`, cursor geometry baseline, tabelas Unicode 16.0.0 completas para UAX #14 (incluindo conjuntos auxiliares) e UAX #9 (classes, espelhamento e brackets), serialização JSON/HTML validada, reducer `EditorState` inicial, controller digital síncrono para beforeinput/teclas, diff keyed puro para reconciler digital, `ImageBox` e cache de elementos Canvas com pintura de imagens carregadas, modelo geométrico/IFC/BFC/paginação/hit-test textual base do print, renderer Canvas com cor/fonte/background, mapeamento digital de input/teclas, operações de irmãos `insertBlocksAfter` com encadeamento validado, operações de tabela com inserção/remoção de linhas e colunas e ajuste span-aware de linhas/colunas, divisão de seções implícitas com reparenting de filhos, merge de células/seções, cross-references, replace-with-suggestion e replace-block-with-text, e entrypoint web compilável. Tudo está coberto pela suíte Dart e validação `dart compile js`; editor integral, resolução semântica avançada do Yjs, cascade/render incremental completo, canvas completo, aplicação DOM integral do reconciler, e colaboração ainda permanecem pendentes.

**Próxima etapa obrigatória:** implementar resolução de conflitos semânticos avançados além do baseline `YMap` (incluindo integração entre tipos), completar a integração de snapshots/relative positions/UndoManager ao histórico colaborativo e portar a suíte de referência. A interoperabilidade JavaScript atualmente cobre os wire formats V1/V2, diff por state vector no subconjunto modelado, ordenação determinística de inserções concorrentes de texto e todos os content refs modelados acima, além de replay remoto básico, fragmentação/deleção parcial, tombstones fora de ordem em mapas e snapshots serializáveis; ainda não constitui colaboração completa.

**Validação de referência:** a suíte TypeScript de `referencias/yjs-main/tests` foi executada localmente após instalar suas dependências (`node ./tests/index.js --repetition-time 1`) e concluiu os 306 casos disponíveis; isso confirma a referência, mas não substitui a equivalência Dart ainda pendente.

---

Checkpoint incremental posterior: `InMemoryAwarenessHub` foi adicionado como transporte determinístico multi-peer para validar convergência de presença entre providers conectados; a suíte Dart agora totaliza 190 testes, com `dart analyze`, compilação JS e `git diff --check` aprovados.

Checkpoint incremental posterior: o `InMemoryAwarenessHub` agora faz sincronização completa ao conectar peers tardios, preservando a presença existente e propagando o estado do novo peer; a suíte Dart totaliza 191 testes, com análise e compilação JS aprovadas.

Checkpoint incremental posterior: `paginateBlockWithFootnotes` agora localiza anchors recursivamente em subárvores de tabelas/células/embeds, evitando perda de corpos de footnote quando o host não é filho direto da página; teste de regressão adicionado e suíte Dart totaliza 192 testes.

Checkpoint incremental posterior: a paginação de footnotes agora desconta o espaço ocupado pelo conteúdo principal antes de posicionar corpos, carregando-os para páginas de continuação quando o slot inferior está cheio; teste de overflow/carry adicionado e suíte Dart totaliza 193 testes.

Checkpoint incremental posterior: `findMatches` deixou de depender de lowercasing sem mapa de origem; a busca agora preserva offsets UTF-16 mesmo quando o fold Unicode expande, reconhece whole-word por letras/números Unicode e cobre esses casos com regressões. Suíte Dart totaliza 195 testes, com análise e compilação JS aprovadas.

Checkpoint incremental posterior: adicionada a projeção pública `buildAccessibilityTree`, com nós ARIA geometry-free para documento, parágrafos, headings, listas, tabelas, imagens, separadores, TOC, footnotes e templates, além de runs inline com offsets literais, links, ênfase, noteref e alt de imagens. Teste inicial adicionado; suíte Dart totaliza 196 testes.

Checkpoint incremental posterior: a árvore de acessibilidade agora agrupa runs contíguos de `list-item` em um nó `list`, preservando a indicação ordered/unordered e os filhos listitem; regressão adicionada e suíte Dart totaliza 197 testes.

Checkpoint incremental posterior: runs de acessibilidade agora expõem page-number/page-count/cross-reference-page como markers geometry-free, preservam field keys, estado de comentários e origem de sugestões; regressão de page field adicionada e suíte Dart totaliza 198 testes.

Checkpoint incremental posterior: `YMap` agora serializa valores `YMap`/`YArray`/`YText` aninhados como `ContentType`, preserva o parent item causal e materializa o tipo remoto no mapa pai; updates posteriores do tipo aninhado convergem e `YTypeContent` possui igualdade determinística. Suíte Dart totaliza 199 testes.

Checkpoint incremental posterior: a semântica aninhada foi estendida a `YArray` e `YText`, preservando runs primitivos compactos, emitindo `ContentType` por tipo compartilhado, derivando parents por `origin/rightOrigin` e validando criação + updates posteriores em V2. Suíte Dart totaliza 201 testes.

Checkpoint incremental posterior: `applyUpdate` e `applyUpdateV2` agora preservam a origem fornecida pelo transporte ao abrir a transação remota (com fallback explícito para `remote`), permitindo que filtros de origem do `YUndoManager` e observadores colaborativos distingam peers sem perder a semântica V1/V2. Regressão V1/V2 adicionada; suíte Dart totaliza 203 testes, com `dart format`, `dart analyze`, suíte completa, compilação JS e `git diff --check` aprovados.

Checkpoint incremental posterior: adicionado `YDocProvider` com state-vector frontier e `InMemoryYDocHub` para transporte determinístico de updates V1/V2, sincronização completa de peers tardios e propagação de origem remota; regressões de convergência multi-peer V1 e V2 adicionadas. Suíte Dart totaliza 205 testes.

Checkpoint incremental posterior: a navegação de palavras do cursor agora calcula o último início de palavra em offsets globais ao atravessar múltiplos `TextItem`s, contando embeds como fronteiras de uma unidade; regressão de retorno entre runs e embed adicionada. A integração provider/UndoManager também confirma que updates recebidos de peers não entram no histórico local. Suíte Dart totaliza 207 testes.

Checkpoint incremental posterior: snapshots agora expõem `equalSnapshots` e `snapshotContainsUpdate` para updates decodificados ou bytes V1/V2, verificando structs e DeleteSet contra a fronteira causal; regressão de equivalência e contenção adicionada. Suíte Dart totaliza 208 testes.

Checkpoint incremental posterior: adicionada a API pública `emptySnapshot`, equivalente à fronteira causal zero do Yjs, com regressão de igualdade e rejeição de updates não contidos. Suíte Dart totaliza 209 testes.

Checkpoint incremental posterior: snapshots agora também codificam/decodificam o framing binário V1 compatível (`DeleteSet` seguido de `StateVector`), mantendo materialização apenas no JSON; round-trip com deleções validado. Suíte Dart totaliza 210 testes.

Checkpoint incremental posterior: o mesmo framing de snapshots foi disponibilizado pelo encoder/decoder V2 de `IdSet`, com DeleteSet diferencial (sem o container de canais dos updates); round-trip V2 com deleções validado. Suíte Dart totaliza 211 testes.

Checkpoint incremental posterior: `resolveCrossReference` agora resolve `refMode: page` quando recebe um índice `BlockId → pageIndex`, retorna página 1-based e mantém a mensagem de referência quebrada quando o alvo não foi paginado; duas regressões adicionadas. Suíte Dart totaliza 213 testes.

Checkpoint incremental posterior: `buildPageIndex` agora extrai o primeiro `pageIndex` de owners em `BlockBox`/`LineBox`, inclusive em descendentes aninhados, para alimentar cross-references de página após a paginação. Suíte Dart totaliza 214 testes.

Checkpoint incremental posterior: a atribuição de footnotes em subárvores agora também reconhece `ownerBlockId` quando o key visual do layout é decorado, evitando perda de anchors em tabelas/linhas compostas; regressão existente foi endurecida sem alterar a contagem da suíte.

Checkpoint incremental posterior: `snapshotContainsUpdate` agora usa contenção causal por state vector, não visibilidade, permitindo reconhecer updates cujos structs foram apagados posteriormente; regressão alinhada aos casos Yjs adicionada. Suíte Dart totaliza 215 testes.

Checkpoint incremental posterior: aliases públicos `snapshotContainsUpdateV1` e `snapshotContainsUpdateV2` foram adicionados para espelhar diretamente a API Yjs, preservando a função unificada; validação focada passou sem alteração na contagem.

Checkpoint incremental posterior: deleções remotas agora resolvem o owner causal aninhado antes da raiz, preservando a materialização de `YText`/`YArray` nested; regressão V2 de inserção + deleção convergente adicionada. Suíte Dart totaliza 216 testes.

Checkpoint incremental posterior: `YDocProvider.encodeSync` agora compara state vectors e retorna payload vazio sem clocks novos, evitando retransmissão de updates vazios; regressão de no-op adicionada. Suíte Dart totaliza 217 testes.

Checkpoint incremental posterior: `InMemoryAwarenessHub.disconnect` agora publica tombstone de remoção antes de retirar o provider, evitando presença stale nos peers; regressão de lifecycle adicionada. Suíte Dart totaliza 218 testes.

Checkpoint incremental posterior: a equivalência de cursor recebeu regressões da referência para movimento de caractere através de embeds (unidade lógica) e travessia entre blocos adjacentes; suíte Dart totaliza 220 testes.

Checkpoint incremental posterior: `caretRectForPosition` agora percorre recursivamente tabelas, rows e cells, acumulando offsets físicos até a `LineBox`; regressão de caret nested adicionada. Suíte Dart totaliza 221 testes.

Checkpoint incremental posterior: `selectionRectsForRange` agora usa a mesma travessia recursiva, preservando offsets físicos em tabelas/cells nested; regressão de highlight nested adicionada. Suíte Dart totaliza 222 testes.

Checkpoint incremental posterior: `selectionRectsAcrossPages` agora fragmenta seleções entre owners de blocos diferentes, usando a ordem dos owners encontrados nas páginas e preservando apenas os trechos de início/fim; regressão multi-bloco adicionada. Suíte Dart totaliza 223 testes.

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

Checkpoint recente: o reducer Dart agora cobre `SET_TEXT_ALIGN`, `SET_LINE_SPACING`, `SET_PARAGRAPH_SPACING`, `INDENT`, `OUTDENT`, `LIST_INDENT`, `LIST_OUTDENT` e `INSERT_IMAGE`, usando os mesmos atributos de bloco da referência TypeScript. A demo web também expõe alinhamento, espaçamento e indentação na toolbar. O mapeamento puro de `DigitalInputEvent` agora aceita `targetRanges` projetados para `Selection`, usando-os como fallback para replacement, cut/drag e deleções de linha, preservando o contrato DOM sem acoplamento a `dart:html`. A resolução semântica de `YMap` agora também conserva tombstones quando deletes remotos chegam antes do item, bloqueando ressurreição fora de ordem; `YArray` e `YText` também rejeitam replay de ranges deletados que chegam antes dos structs. Relative positions agora passam a matriz de posições internas/associações `-1/0/1` da referência, preservando offsets UTF-16 em segmentos e inserções concorrentes; os índices causais de `YText` também são reconstruídos a partir do `YStructStore` após undo/redo baseado em snapshot, mantendo âncoras resolvíveis. Snapshots agora expõem `containsStruct` e `createDocFromSnapshot`, reidratando itens deletados depois do boundary, preservando uma cópia materializada aninhada e reconstruindo um documento isolado no estado causal capturado. A geometria de seleção pode agregar fragmentos entre páginas sem perder a ordem documental; hit-test textual agora percorre tabelas aninhadas e o print backend expõe hit-test recursivo de imagens para interação. `YUndoManager` agora integra automaticamente `YDoc.transact` e mutações diretas de `YText`/`YMap`/`YArray`, incluindo transações estruturais sem eventos e filtragem de origins. A camada `YAwareness` fornece presença local/remota com clocks monotônicos, tombstones de remoção, listeners e updates JSON determinísticos, wire format binário lib0/Yjs com varuints e `YAwarenessProvider` para conectar um callback de transporte sem acoplar a rede ao core. `dart analyze`, suíte completa (189 testes), testes digitais e compilação JS passaram.

O backend de print agora também expõe `createCanvasShaper`, adaptado ao `CanvasRenderingContext2D.measureText`, com clusters grapheme, spacing, métricas heurísticas compatíveis e oportunidades UAX #14. Os padrões en-US curados da referência foram portados para `enUsPatternSet`/`createDefaultLiangHyphenator`; dados de outros idiomas e shaping HarfBuzz continuam explicitamente pendentes.

O reducer também passou a expor `REPLACE_MATCH`, `REPLACE_ALL` e `SET_TAB_STOPS`, reutilizando os planejadores transacionais de substituição e os attrs de tabulação da cascade.

Também foram adicionados `TOGGLE_SECTION_LANDSCAPE` e `SET_SECTION_COLUMNS`, persistindo overrides de geometria no section ativo ou no root sem introduzir dependências de layout no reducer.

O `DigitalDomReconciler.reconcile` deixou de substituir sempre a raiz: quando o tipo coincide, ele preserva e reordena elementos keyed por `data-block-id`, copia attrs e reconcilia subárvores recursivamente; apenas nós não-keyed são reconstruídos.

O mapeamento digital agora segue também os casos da referência para `insertCompositionText`, drop, replacement/delete ranges, word/line deletion, atalhos de formatação, Tab em listas e Enter como `SPLIT_NODE`; ranges DOM concretos continuam dependentes da ponte de seleção do host.

`DELETE_RANGE` agora também colapsa sempre no início normalizado do span, corrigindo replacement/drag com seleção DOM invertida antes da inserção subsequente.

No CRDT, `YText` e `YArray` agora fragmentam segmentos em deleções parciais locais e remotas, preservando IDs/clocks dos prefixos e sufixos sobreviventes e rejeitando replay do item original; os codecs V1/V2 e testes de convergência continuam verdes.

O `YUndoManager` recebeu janela de captura temporal, `stopCapturing`, stack depth, exposição de stacks somente-leitura e quebra automática da cadeia em undo/redo, aproximando o comportamento do `Y.UndoManager` sem perder o filtro de origins.

O IFC passou a consumir as oportunidades `soft`/`hard` produzidas pelo UAX #14, preferindo o último ponto de whitespace que cabe na linha e removendo corretamente o caractere de quebra obrigatória do `TextRunBox`; os testes de wrap por palavra e newline foram adicionados.

O produtor IFC agora também recebe um `Hyphenator` opcional, injeta oportunidades interiores para `hyphens: auto` com idioma e registra `LineBox.endsWithHyphen`; o renderer Canvas pinta o hífen sintético sem alterar offsets UTF-16. O `YUndoManager` agrupa escopos de captura aninhados em uma entrada única, mantém undo/redo e coalescing temporal e expõe `transact` com cleanup garantido. Relative positions agora ancoram caracteres internos de segmentos e preservam `assoc`, cobrindo a diferença left/right da referência em inserções concorrentes.

Checkpoint incremental: o reducer/editor action agora porta `INSERT_NODE` com validação pelo registry configurável e construção recursiva de subárvores de containers e folhas, preservando attrs, conteúdo inline, dirty IDs e captura de undo/redo. A regressão estrutural, `dart format`, `dart analyze`, compilação JS, `git diff --check` e a suíte global de 256 testes permanecem verdes.

Checkpoint incremental: a seleção across-pages do print layer agora respeita também o eixo inline de writing modes verticais, emitindo retângulos físicos com largura/altura trocadas e direção RTL normalizada, em equivalência com a geometria same-page; a regressão vertical multi-página foi adicionada.

Checkpoint incremental: a projeção de acessibilidade agora resolve o texto exibido de embeds de cross-reference nos modos `number`, `text` e `page` via o mesmo resolvedor de render, mantendo `fieldKind`/`fieldKey` e o placeholder de erro da referência quando o alvo não existe.

Checkpoint incremental: a árvore de acessibilidade deixou de degradar tipos de bloco desconhecidos para `document` e agora lança erro explícito, preservando a guarda de exaustividade da referência TypeScript; regressão dedicada adicionada.

Checkpoint incremental: a ponte `dom_mirror.dart` foi alinhada ao `dom-mirror.ts` na resolução de campos (placeholder somente para `cross-ref-page`) e na identidade de notas (`doc-footnote` agora recebe o `id` do bloco-fonte). `dart format`, `dart analyze`, suíte global de 256 testes, compilação JS e `git diff --check` permanecem verdes.

Checkpoint incremental: `AccessibilityDomMirror` agora configura o host com os atributos de edição acessível (`contenteditable`, `role=textbox`, `aria-multiline`, `tabIndex` e clip visual) e oferece `focus()`, alinhando o ciclo de host ao `dom-mirror-host.ts`; montagem/reconciliação/destruição permanecem estáveis. Validação: `dart analyze`, 256 testes, compilação JS e `git diff --check` verdes.

Checkpoint incremental: `resolveAccessibilityFields` agora preserva por referência nós, listas de runs e filhos que não sofreram alteração, espelhando `resolveTreeFields` e evitando churn desnecessário no reconciler/AT. Validação: `dart format`, `dart analyze`, 256 testes, compilação JS e `git diff --check` verdes.

Checkpoint incremental: o codec Yjs agora expõe `mergeUpdatesV2`/`YStructUpdateCodec.mergeV2`, decodificando e reencodando o framing channel-compressed V2 sem misturá-lo ao caminho V1. A regressão cobre deduplicação, aplicação remota e preservação do framing; `dart analyze`, compilação JS e a suíte global de 257 testes estão verdes.

Checkpoint incremental: foram portadas também as APIs públicas `encodeStateVectorFromUpdate`/`V2` e `diffUpdate`/`V2`, com filtragem de structs parcialmente sobrepostos e DeleteSet pelo frontier causal. Regressões V1/V2, `dart format`, `dart analyze`, compilação JS e a suíte global de 258 testes estão verdes.

Checkpoint incremental: `PageBox` agora possui o slot nomeado `footnoteSlot` (`BlockBox?`), e `paginateBlockWithFootnotes` materializa o wrapper geométrico do slot por página. A paginação deixou de duplicar corpos em `children`; consumidores foram migrados para o campo nomeado. Regressão verifica identidade e conteúdo do slot; `dart analyze`, compilação JS e 258 testes permanecem verdes.

Checkpoint incremental: o Canvas renderer agora aceita páginas produzidas apenas com o campo nomeado `footnoteSlot` e o pinta sem duplicação. `dart analyze`, compilação JS e 258 testes permanecem verdes; hit-test/line collection nomeados seguem como próximo subbloco.

Checkpoint incremental: o hit-test/caret/selection de print agora percorre `PageBox.footnoteSlot` como representação canônica do corpo de nota. Validação: `dart analyze`, suíte global de 258 testes, compilação JS e `git diff --check` verdes.

Checkpoint incremental: a descoberta de páginas/âncoras e o cálculo de área de conteúdo da paginação agora distinguem o slot nomeado do corpo principal, incluindo slots canônicos quando `children` não os contém e evitando descontá-los duas vezes em páginas legadas. Validação completa permanece em 258 testes verdes.

Checkpoint incremental: `PageBox` passou a expor também `headerSlot` e `footerSlot` nomeados, com travessia compartilhada de Canvas, cursor, seleção, índice de páginas e paginação. Os slots permanecem nulos até o produtor de templates ser ligado, mas o contrato estrutural agora coincide com `page-box.ts`; 258 testes, análise e compilação JS verdes.

Checkpoint incremental: `renderTemplateBody` agora renderiza raízes de `templateContents` isoladamente, em paralelo a `renderFootnoteBody`, preservando o contexto de numeração/cross-reference e evitando vazamento para a árvore principal. Regressão de header template adicionada; `dart analyze`, compilação JS e a suíte global de 259 testes estão verdes.

Checkpoint incremental: `renderCascadedTemplateBody` agora aplica o cascade ao output isolado de templates, oferecendo ao futuro produtor de slots o mesmo contrato de estilos resolvidos do corpo principal. Regressão de pipeline adicionada; `dart analyze`, compilação JS e a suíte global de 260 testes permanecem verdes.

Checkpoint incremental: cross-references em modo `page` permanecem como marcadores geometry-free (`fieldKind`/`fieldKey`, texto vazio), enquanto `number`/`text` usam a resolução textual prevista; a distinção foi coberta por regressões dedicadas.

Checkpoint incremental: containers `section` agora são transparentes na árvore de acessibilidade, com os filhos spliced no pai e fronteiras de agrupamento de listas preservadas; uma seção usada como raiz continua sendo rejeitada explicitamente.

Checkpoint incremental: corpos `template-body` agora são classificados semanticamente por seus vínculos `headerBlockId`/`footerBlockId`, produzindo `banner` para cabeçalho e `contentinfo` para rodapé, com fallback defensivo compatível com a referência.

Checkpoint incremental: o mapeamento digital de teclado agora despacha `EscapeAction` para `Escape`, em equivalência com `map-digital-key.ts`, permitindo que o controller atravesse a seleção de objetos atômicos.

Checkpoint incremental: `Backspace`, `Delete` e `Enter` deixaram de ser despachados pelo `keydown`; o mapper agora devolve `null` e deixa esses edits exclusivamente para `beforeinput`, evitando mutações duplicadas conforme o contrato digital da referência.

Checkpoint incremental: o mapper `beforeinput` agora respeita o boundary de paste nativo (`insertFromPaste` não duplica a ClipboardEvent), usa `targetRanges` para word-delete e aceita `dataTransfer` como fallback do replacement, alinhando os casos F9/C1 da referência.

Checkpoint incremental: `deleteByCut`/`deleteByDrag` agora consomem exclusivamente a seleção corrente do controller, enquanto `targetRanges` permanece reservado às deleções word/line, reproduzindo a separação de responsabilidades do mapper TypeScript.

Checkpoint incremental: `mapDigitalKey`/`DigitalEditorController` agora recebem o contexto `mac`, escolhendo Meta no macOS/iOS e Ctrl nas demais plataformas, com o host web derivando o valor do user-agent conforme a referência.

As operações de cursor também expõem `findNextContentBlock`/`findPrevContentBlock` como equivalentes públicos às helpers TypeScript, mantendo o salto sobre containers estruturais.

A paginação agora oferece `paginateBlockWithFootnotes`: atribui anchors à página hospedeira, materializa corpos num slot inferior e carrega corpos excedentes para páginas de continuação sem descartá-los. O teste cobre a reserva e o deslocamento do corpo.

Relative positions também registram a fronteira visível de anchors apagados em deleções locais/remotas, permitindo que a posição siga o limite sobrevivente em vez de retornar ao offset histórico; o caso de deleção inicial foi adicionado aos testes equivalentes.

O print layer recebeu o adaptador `assignPrintTableGrid` e `distributeColumnIntrinsics`, portando a resolução de `rowSpan`/`colSpan` e a distribuição CSS Tables de min/max-content para células spanning.

A composição geométrica foi completada com `TableBox`, `TableRowBox` e `TableCellBox`: tracks são convertidos em offsets, spans ocupam a soma correta de colunas/linhas e os filhos internos permanecem pintáveis pelo Canvas.

O controller digital e `web/main.dart` agora tratam composição IME: eventos intermediários são suprimidos, `compositionend` com texto comita uma única inserção e payload nulo/cancelamento não cria mutação.

`CanvasImageCache` agora oferece `onLoaded`, disparando callbacks quando uma imagem assíncrona termina de carregar (ou imediatamente para cache completo), permitindo que hosts agendem repaint sem polling.

O reducer também cobre `SET_FOOTNOTE_POLICY`, validando independentemente reset (`continuous`, `restart-per-section`, `restart-per-page`) e formato de contador antes de escrever os attrs document-wide no root.

Foi adicionado `LiangHyphenator`/`PatternSet` com compilação de padrões TeX, exceções, floors 2/2, fallback por idioma primário, memoização limitada e mapeamento correto de índices quando o token contém U+00AD; a conexão ao produtor IFC e os pacotes de dados por idioma continuam como próximo passo.

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
| 12. Digital Backend | ~7 | ~2.000 | 🟡 Média  |
| 13. Numbering + Footnotes | ~10 | ~1.500 | 🟢 Baixa |
| 14. Demo App | ~3 | ~500 | 🟢 Baixa |
| **TOTAL** | **~235** | **~50.300** | |

---

## Verification Plan

### Checkpoint 2026-08-02 — clipboard nativo do demo web

- `web/main.dart` agora trata `copy` e `cut` nativos no wrapper do editor: sincroniza a seleção DOM em offsets UTF-16, escreve `text/plain` no `ClipboardEvent` e, no corte, despacha `DeleteRangeAction` exatamente sobre a seleção corrente.
- Validação: `dart format`, `dart analyze`, suíte completa (`260` testes), testes digitais focados e compilação JS concluídos sem erros.
- A integração DOM/widget completa e a composição IME avançada permanecem pendentes; localizar o próximo item executável antes de encerrar a sessão.

### Checkpoint 2026-08-02 — extração canônica para copy/cut

- O demo deixou de recortar `textContent` apenas do parágrafo DOM: `copy`/`cut` usam `extractText` do estado com `builtinEmbedSerializer`, preservando separadores e embeds e aceitando spans não-colapsados entre blocos; `cut` continua despachando `DeleteRangeAction`.
- `extract_text.dart` foi exposto pelo entrypoint público para manter a integração web sobre o mesmo contrato usado pelo render/cascade.
- Revalidação: análise limpa, testes focados (`43` casos), suíte global (`260` testes) e compilação JS aprovadas.

### Checkpoint 2026-08-02 — sincronização de seleção DOM

- O host web registra `document.selectionchange`, sincroniza âncora/foco para posições UTF-16 e evita redispatch quando a seleção estrutural não mudou, cobrindo a ponte usada por teclado, clipboard e `beforeinput`.
- Validação final do bloco: `dart format`, `dart analyze`, suíte global (`260` testes) e `dart compile js` concluídos com sucesso.

### Checkpoint 2026-08-02 — produtor de slots de template na paginação

- `paginateBlock` e `paginateBlockWithFootnotes` agora aceitam `headerSlot` e `footerSlot` nomeados, repetindo os mesmos corpos em páginas normais e páginas de continuação, sem inseri-los em `PageBox.children`.
- A reserva de footnotes continua baseada somente no corpo principal; slots nomeados permanecem disponíveis para pintura, cursor, selection e índice de páginas.
- Regressão adicionada para duas páginas com header/footer. Validação: `dart format`, `dart analyze`, suíte global (`261` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — resolução tardia de page-fields

- `resolvePageFieldText` agora resolve `page-number`/`page-count` com página e contagem one-based, reutilizando `formatCounter` para decimal, alpha e roman e fazendo fallback decimal para estilos inválidos.
- A API foi exportada pelo entrypoint público e coberta por regressões; ela é deliberadamente pura para ser usada por clones de template durante layout por página.
- Validação: `dart format`, `dart analyze`, suíte focada, suíte global (`263` testes) e compilação JS aprovados.

### Checkpoint 2026-08-02 — page-fields no render de templates

- `renderTemplateBody` e `renderCascadedTemplateBody` aceitam `pageNumber`/`pageCount`; embeds `page-field` são materializados como `TextBox` com o valor one-based e o estilo solicitado antes da cascata/layout.
- A regressão renderiza um header com `upper-roman` e confirma `IV`; isso mantém a substituição isolada do estado e pronta para clonagem por página.
- Validação: `dart format`, `dart analyze`, suíte global (`264` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — driver de convergência de largura

- `field_convergence.dart` porta o driver puro F-3 da referência: reservas de page-field crescem somente quando a largura resolvida excede a reserva, com tolerância `0.01`, limite de cinco passagens e retorno consistente entre a iteração final e as larguras aplicadas.
- Regressões cobrem crescimento até fixpoint, cap de iterações e documento sem fields. Validação: `dart format`, `dart analyze`, suíte global (`267` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — coleta de placeholders no render tree

- Embeds `page-field` não resolvidos preservam agora metadata de tipo, field kind, estilo numérico e chave inline no `ElementBox`; `collectPageFields` percorre templates e produz as reservas estáveis consumidas pelo driver F-3.
- A regressão confirma a chave `block/inline/index` e a reserva configurável. Validação: `dart format`, `dart analyze`, suíte global (`268` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — paginação conectada à convergência F-3

- `paginateBlockWithFieldConvergence` agora conecta o driver às passagens físicas: o callback recebe as reservas, produz o `BlockBox`/slots daquele passe, a função pagina e mede `pageCount`, e o resultado final mantém páginas e larguras da mesma iteração.
- Regressão cobre crescimento de reserva, mudança de quantidade de páginas e pareamento da saída final. Validação: `dart format`, `dart analyze`, suíte global (`269` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — materialização geométrica de templates

- `layoutTemplateRenderNode` transforma um `RenderNode` de template em `BlockBox`, preservando filhos diretos, texto inline, `ComputedStyle`, writing mode/direction e hifenizador, usando a mesma medição IFC/BFC do corpo principal.
- A API foi exportada e exercitada com um header criado no `State`, renderizado e convertido em geometria de slot. Validação: `dart format`, `dart analyze`, suíte global (`270` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — integração automática de slots renderizados

- `paginateBlockWithTemplateSlots` recebe `RenderNode` de header/footer, chama `layoutTemplateRenderNode` e instala os `BlockBox` resultantes em `PageBox.headerSlot`/`footerSlot` em todas as páginas, mantendo o corpo sem duplicação.
- Regressão confirma a materialização automática sem montagem manual de slots. Validação: `dart format`, `dart analyze`, suíte global (`271` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — slots de template por página

- `paginateBlockWithPerPageTemplateSlots` calcula a contagem total do corpo e chama fábricas de header/footer com `(pageNumber, pageCount)` one-based, materializando cada slot individualmente antes de devolvê-lo no `PageBox` correspondente.
- Regressão confirma slots `header-1`/`header-2` em duas páginas. Validação: `dart format`, `dart analyze`, suíte global (`272` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — caminho State → slots por página

- `paginateBlockWithStateTemplateSlots` recebe IDs de corpos no `State`, chama `renderTemplateBody` com página/contagem one-based e materializa cada resultado no `PageBox` correspondente.
- Regressão cria um header real com `page-number` e confirma valores `1`/`2` nas duas páginas. Validação: `dart format`, `dart analyze`, suíte global (`273` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — reserva de insets para templates

- `paginateBlockWithStateTemplateSlots` mede as alturas máximas de header/footer, recalcula margens úteis e repagina até três passagens para estabilizar mudanças de page-count; o corpo é deslocado abaixo do header e o footer é ancorado no fundo do content box.
- Regressão confirma que o primeiro corpo não sobrepõe o header. Validação: `dart format`, `dart analyze`, suíte global (`273` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — offsets de slots na API genérica

- `paginateBlockWithPerPageTemplateSlots` agora posiciona header no topo e footer no fim do content box, além de materializá-los por página; consumidores que já possuem `RenderNode` recebem a mesma geometria sem sobreposição.
- Regressão confirma o offset final do footer. Validação: `dart format`, `dart analyze`, suíte global (`273` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — imagens inline em templates

- Embeds `inline-image` agora preservam `ImageMetadata` no render tree; `layoutTemplateRenderNode` materializa `ImageBox` com src, dimensões, alt e offset, evitando descartar imagens sem texto em headers/footers.
- Regressão cobre imagem inline dentro de slot. Validação: `dart format`, `dart analyze`, suíte global (`274` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — fronteiras de blocos aninhados

- `layoutTemplateRenderNode` preserva fronteiras de `ElementBox` aninhados como separadores `\n`, mantendo runs inline contíguos e delegando a quebra hard-break ao IFC existente.
- Regressão cobre dois parágrafos dentro de um container. Validação: `dart format`, `dart analyze`, suíte global (`275` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — tabelas em corpos de template

- `layoutTemplateRenderNode` agora reconhece `table`/`table-row`/`table-cell`, converte células em `TableCellInput` e reutiliza `composeTableLayout`, preservando larguras de colunas e metadata de spans.
- A reserva de inset da API State desloca também `TableBox` sem alterar coordenadas relativas de rows/cells; regressão estrutural cobre a materialização da tabela.
- Validação: `dart format`, `dart analyze`, suíte global (`276` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — fragmentação de tabelas por rows

- `paginateBlock` agora divide `TableBox` em fragmentos nas fronteiras de `TableRowBox` quando a tabela excede a altura útil da página; widths e coordenadas relativas das cells são preservados em cada fragmento.
- Regressão cobre três rows distribuídas em duas páginas. A fragmentação de blocos ricos, floats e repetição de cabeçalho de tabela continua pendente.

### Checkpoint 2026-08-02 — fragmentação de BlockBox rico

- `paginateBlock` também particiona `BlockBox` aninhado com múltiplos filhos nos limites dos filhos quando excede a altura útil, mantendo estilo, owner e geometria interna dos fragments.
- Validação parcial deste bloco: `dart format`, `dart analyze` e testes de paginação aprovados; a suíte global e compilação JS serão executadas no fechamento da sessão.

### Checkpoint 2026-08-02 — repetição de cabeçalho de tabela

- `TableBox.headerRowCount` é propagado da metadata do render tree; ao fragmentar uma tabela, as rows de cabeçalho são repetidas nos fragments subsequentes.
- Regressão cobre cabeçalho repetido na segunda página. Validação: `dart format`, `dart analyze`, suíte global (`277` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — fragmentação de corpos de footnote

- `paginateBlockWithFootnotes` agora divide corpos grandes nos limites de filhos/linhas, posiciona o fragmento que cabe no slot corrente e carrega o restante para páginas seguintes, preservando `ownerBlockId` e sem descartar conteúdo.
- Regressão cobre um corpo oversized distribuído por múltiplas páginas. Validação: `dart format`, `dart analyze`, suíte global (`278` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — políticas de numeração de footnotes

- `buildFootnoteNumberIndex` agora lê `footnoteNumberingFormat`/`footnoteNumberingReset` do root, formata decimal/alpha/romano e aceita contexto de página para resets por página; reset por seção usa o ancestral `section`/`sectionId` mais próximo.
- `RenderContext` propaga o mapa de páginas para o índice, permitindo que renderizações com paginação usem `restart-per-page`.
- Regressão cobre `upper-roman`; integração com páginas concretas pode fornecer `pageByBlock` ao índice.

### Checkpoint 2026-08-02 — exportação Canvas

- O renderer Canvas agora expõe `canvasToDataUrl` e `canvasToBlob`, usando os encoders nativos do browser e validando explicitamente `image/png`, `image/jpeg` e `image/webp`.
- A validação de formatos foi isolada em módulo browser-independent com regressão unitária; compilação JS cobre as APIs `toDataURL`/`toBlob`.
- `CanvasImageCache` ignora `src` vazio, evitando alocações e tentativas de carga repetidas para imagens sanitizadas sem origem.
- Falhas de carga liberam listeners pendentes sem remover a entrada cacheada, evitando acúmulo de callbacks em fontes inválidas.
- Validação final: `dart format`, `dart analyze`, suíte global (`280` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — toolbar de templates e page-fields

- A demo web agora liga botões de header, footer, page-number e page-count ao mesmo `DigitalEditorController`, além das ações de formatação já existentes.
- Validação: `dart format`, `dart analyze` e compilação JS aprovados; a suíte global permanece verde (`280` testes).

### Checkpoint 2026-08-02 — no-op de inserções vazias Yjs

- `YArray.insert` e `YText.insert` agora retornam no-op após validar a posição quando a entrada está vazia, sem criar structs, tombstones ou eventos; posições inválidas continuam lançando `RangeError`.
- Regressão adicionada em `yjs_core_test.dart`. Validação: `dart format`, `dart analyze`, suíte global (`281` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — atributos materializados de YText

- `YText.insert` preserva atributos por unidades UTF-16; `YText.format` aplica/remover chaves em ranges e `YText.toDelta` coalesce runs adjacentes com atributos equivalentes.
- Regressão cobre inserção, formatação e remoção de atributo. Validação: `dart format`, `dart analyze`, suíte global (`282` testes), compilação JS e `git diff --check` aprovados. A codificação/aplicação causal completa de marcadores `YFormatContent` remotos permanece explicitamente pendente.

### Checkpoint 2026-08-02 — aplicação remota básica de YFormatContent

- `YDoc.applyRemoteItem` agora reconhece `YFormatContent`, resolve o owner `YText` e aplica o marcador na fronteira causal indicada por `origin`/`rightOrigin`.
- Regressão cobre marcador remoto após um item de texto e fechamento com `value: null`. Validação: `dart format`, `dart analyze`, suíte global (`284` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — emissão causal de marcadores YText

- `YText.format` agora emite itens `YFormatContent` de abertura/fechamento no update local, ancorados por `origin`/`rightOrigin`; a aplicação remota usa `recordCausal: false` para não ecoar updates.
- Regressão preserva a projeção `toDelta`, confirma structs de formato no store e valida round-trip V1/V2 com âncoras dentro de segmentos de texto agrupados.
- Validação: `dart format`, `dart analyze`, suíte global (`285` testes), compilação JS e `git diff --check` aprovados; interleaving concorrente complexo e a máquina completa de atribuições ainda permanecem pendentes.

### Checkpoint 2026-08-02 — fallback causal de YFormatContent

- `YText.applyRemoteFormat` agora usa `rightOrigin` quando a origem primária foi removida ou compactada, preservando a fronteira visível após deleções remotas.
- Regressão cobre marcador remoto com origem tombstonada. Validação: `dart format`, `dart analyze`, suíte global (`286` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — interleaving concorrente de formatos YText

- Regressão multi-peer aplica intervalos `bold` e `italic` sobrepostos em ordens intercaladas e confirma convergência de `toDelta` com atributos compostos.
- Validação: `dart format`, `dart analyze`, suíte global (`287` testes), compilação JS e `git diff --check` aprovados. A máquina completa de atribuições da referência ainda permanece pendente.

### Checkpoint 2026-08-02 — atributos em tipos YText nested pré-integrados

- `emitInitialStructs` agora serializa os runs de atributos de um `YText` que já possuía conteúdo/formatação antes de ser integrado em `YMap`/`YArray`, emitindo marcadores causais no mesmo parent item.
- Regressão de `createDocFromSnapshot` confirma que os atributos são preservados após replay causal. Validação: `dart format`, `dart analyze`, suíte global (`288` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — restauração de atributos no YUndoManager

- `snapshotShared`/`restoreSharedSnapshot` agora transportam `YText.toDelta`; `rebuildIndexes` reaplica os marcadores causais após restaurar o store, preservando formatação inline em undo/redo.
- Regressão cobre undo de texto formatado. Validação: `dart format`, `dart analyze`, suíte global (`289` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — reconstrução nested de índices de formato

- `YText.rebuildIndexes` resolve o parent causal nested por `YId` e reaplica os marcadores de formato após restore, cobrindo undo/redo de `YText` em mapas e arrays.
- Regressão nested adicionada. Validação: `dart format`, `dart analyze`, suíte global (`290` testes), compilação JS e `git diff --check` aprovados.
- A suíte TypeScript de referência (`node ./tests/index.js --repetition-time 1`) também foi reexecutada sem falhas nos 306 casos disponíveis.

### Checkpoint 2026-08-02 — relative positions nested por parent item

- `YRelativePosition.toJson` agora inclui o `typeItem` causal de tipos nested; a desserialização percorre `YMap`/`YArray` e prioriza essa identidade sobre chaves de raiz colidentes.
- Regressões cobrem `YText` em array e colisão entre chave nested e root. Validação: `dart format`, `dart analyze`, suíte global (`292` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — validação de alinhamento no reducer

- `SetTextAlignAction` agora aceita somente os valores do contrato (`start`, `end`, `left`, `right`, `center`, `justify`); valores inválidos retornam no-op sem iniciar captura de histórico.
- Regressão cobre alinhamento inválido. Validação: `dart format`, `dart analyze`, suíte global (`293` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — validação de geometria de colunas

- `SetSectionColumnsAction` agora rejeita contagens menores que 1 e gaps negativos ou não finitos antes de iniciar histórico, preservando o estado em entradas inválidas.
- Regressão cobre geometria inválida. Validação: `dart format`, `dart analyze`, suíte global (`294` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — validação de espaçamentos do reducer

- `SetLineSpacingAction` rejeita valores não finitos/não positivos e `SetParagraphSpacingAction` rejeita edges desconhecidos antes da captura de histórico.
- Regressão cobre ambos os no-ops inválidos. Validação: `dart format`, `dart analyze`, suíte global (`295` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — normalização de tab-stops no reducer

- `SetTabStopsAction` agora normaliza posições negativas/não finitas para zero e ordena os stops antes de persistir os attrs, alinhando a entrada do reducer ao interpretador de cascade.
- Regressão cobre posições fora de ordem e negativas. Validação: `dart format`, `dart analyze`, suíte global (`296` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — validação de dimensões de tabela

- `InsertTableAction` rejeita dimensões menores que `1x1` antes de iniciar captura de histórico, preservando no-op determinístico em entradas inválidas.
- Regressão cobre linhas zero. Validação: `dart format`, `dart analyze`, suíte global (`297` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — seleção DOM em subárvores formatadas

- `_targetRanges`, sincronização de seleção e restauração do caret no demo web agora percorrem descendentes DOM, acumulando offsets UTF-16 através de spans, links, marcadores e text nodes aninhados.
- Validação: `dart format`, `dart analyze`, suíte global (`297` testes), compilação JS e `git diff --check` aprovados.

### Checkpoint 2026-08-02 — fidelidade UTF-16 de YText em surrogate pairs

- Regressões equivalentes à referência TypeScript confirmam que `YText.format` pode dividir pares surrogate nos offsets UTF-16 especificados e que os marcadores preservam essa divisão em updates V1/V2.
- Validação: `dart format`, `dart analyze`, suíte global (`299` testes), compilação JS e `git diff --check` aprovados.

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
### Checkpoint — floats no layout de templates

O materializador `layoutTemplateRenderNode` agora honra `float: inline-start` e
`float: inline-end` em imagens: posiciona o objeto no lado físico correto,
reserva sua largura para o fluxo subsequente e desloca recursivamente
`BlockBox`/`LineBox`/`TextRunBox` para manter a geometria coerente. A regressão
de narrowing e deslocamento foi adicionada. Validação: `dart format`,
`dart analyze`, suíte global (`301` testes), compilação JS e `git diff --check`.
`clear: inline-start`, `inline-end` e `both` agora reposicionam o fluxo abaixo
da borda inferior do float correspondente; colisão e políticas completas de
floats multi-linha ainda permanecem pendentes.
