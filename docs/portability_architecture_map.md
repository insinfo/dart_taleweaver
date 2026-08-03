# Mapa arquitetural da portabilidade TypeScript → Dart

Este documento registra as decisões usadas para preservar comportamento
observável, em vez de traduzir sintaxe linha a linha.

| Conceito TypeScript | Equivalente Dart | Diferença inevitável / decisão |
|---|---|---|
| `State` sobre `Y.Doc` | `State` sobre `TwDoc` + `SnapshotCache` | O Dart expõe snapshots imutáveis e mantém mutações somente em transações do `TwDoc`; `freshState` troca o cache sem trocar o documento causal. |
| `EditorState` e reducer puro | `EditorState` + `reduceEditor` | A dispatch é síncrona; `History`, seleção e `lastDirtyIds` preservam identidade quando o contrato exige no-op. |
| `Y.Doc`/`Y.Map`/`Y.Array`/`Y.Text` | `YDoc`/`YMap`/`YArray`/`YText` próprios | Não há equivalente Dart direto para os tipos Yjs; os codecs V1/V2, IDs, tombstones, origins e snapshots são modelados explicitamente. |
| `Uint8Array` e wire format lib0 | `Uint8List` e codecs binários Dart | A representação de bytes é diferente na API, mas os bytes, ordem e validações do protocolo são mantidos. |
| `ReadonlySet`, `Map`, objetos estruturais | `Set`, `Map`, classes imutáveis | Entradas externas são copiadas nos limites públicos quando necessário para evitar mutação acidental. |
| `DOM`/`HTMLElement`/`Selection` | `package:web`, `HTMLElement`, `Selection` browser-native | Não existe DOM na VM; adapters browser ficam isolados em módulos `dart:js_interop`/`package:web` e não contaminam testes VM. |
| React/host lifecycle | `DigitalDomReconciler` + listeners síncronos | O lifecycle é explícito (`mount`, `reconcile`, `destroy`); identidade keyed usa `data-block-id`. |
| `contenteditable` e `beforeinput` | `DigitalEditorController` + `web.Event` | Eventos são convertidos em `EditorAction`; ranges DOM são traduzidos para offsets UTF-16 antes do reducer. |
| Promises/event loop | `Future`, callbacks e listeners | O reducer permanece síncrono; I/O browser/rede/imagem usa `Future`/callbacks e preserva a ordem de notificação observável. |
| `runWithTransactionOrigin`/ambient transaction context | `runWithTransactionOrigin` sobre `Zone` | A zona carrega a origem sem variável global; transações explícitas continuam tendo precedência. |
| `try/finally` transacional | `try/finally` em `TwDoc.transact`/UndoManager | Cleanup de captura, observers e listeners ocorre mesmo quando a operação lança. |
| `Error`/`RangeError`/validações JS | `StateError`, `RangeError`, `ArgumentError` | Cada fronteira mantém validação e falha; diferenças de tipo são documentadas e testadas, sem retornar valores fictícios. |
| Garbage collection JS | GC do Dart | Não há equivalente direto para finalizers de DOM; lifecycle explícito remove listeners, caches e nós em `destroy`. |
| `CanvasRenderingContext2D` | `package:web` Canvas + renderer Dart | O backend de print mantém geometria independente do browser; pintura é adapter e pode ser validada por contratos geométricos na VM. |
| Testes Vitest/JSDOM/Puppeteer | `package:test` + `puppeteer`/`shelf_static` | Contratos sem DOM rodam na VM; fluxos UI são opt-in com `RUN_E2E=1` e servidos por `shelf`. |

## Fluxo de dados

1. Evento local ou update remoto chega ao controller/provider.
2. O mapper valida e produz `EditorAction` ou dirty IDs.
3. O reducer muta o `TwDoc` somente dentro de transação, captura histórico e
   cria snapshots novos.
4. O `EditorState` preserva seleção/histórico e publica `lastDirtyIds`.
5. Render, layout, reconciler DOM e mirror de acessibilidade consomem o novo
   estado; nenhum deles muta o documento durante a leitura.

## Concorrência e memória

O núcleo é single-isolate e determinístico. Convergência remota é obtida por
`YId`, origins, right origins, DeleteSets e tombstones; updates recebidos não
entram no undo local. Caches de snapshots são invalidados por dirty IDs e
descartados em `freshState`; adapters browser liberam nós/listeners em
`destroy`.

## APIs públicas e cobertura

As funções públicas portadas são exportadas por `lib/taleweaver.dart` quando
fazem parte da superfície do pacote. Cada módulo novo deve possuir teste de
contrato Dart e comparação com o teste ou helper TypeScript correspondente;
diferenças de ambiente browser/VM permanecem explícitas no teste e no plano de
implementação.
