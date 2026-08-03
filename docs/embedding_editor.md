# Incorporando o editor Taleweaver

`TaleweaverEditor` é a superfície pronta para uso: ele cria e destrói seu
próprio ribbon, réguas, página, barra de estado, diálogos e área editável.
O aplicativo fornece somente um `HTMLElement` hospedeiro e opções. Não deve
copiar o CSS ou a marcação interna do editor.

A title bar é opcional e vem desativada por padrão, para que a aplicação
incorporadora mantenha sua própria navegação. Para usar a barra de documento
com nome e atalhos, defina `showTitleBar: true`.

## Aplicação Dart web

```dart
import 'package:taleweaver/taleweaver.dart';
import 'package:web/web.dart' as web;

void main() {
  final host = web.document.querySelector('#editor');
  if (host is! web.HTMLElement) return;

  TaleweaverEditor.mount(
    host,
    options: const TaleweaverEditorOptions(
      documentTitle: 'Contrato',
      height: 'calc(100vh - 24px)',
      initialText: 'Comece a escrever.',
    ),
  );
}
```

O HTML da aplicação contém apenas o host:

```html
<main id="editor"></main>
```

## JavaScript puro

Para uma aplicação que não usa Dart diretamente, compile a entrada pequena da
biblioteca uma vez e carregue o arquivo gerado. Ela instala
`globalThis.Taleweaver`; a página continua tendo somente o host.

```powershell
dart compile js web/taleweaver_editor_js.dart -o web/taleweaver_editor_js.js
```

```html
<main id="editor"></main>
<script src="taleweaver_editor_js.js"></script>
```

Monte o editor passando apenas o elemento e opções JSON simples:

```js
const host = document.querySelector('#editor');
if (!host) throw new Error('Host #editor ausente.');

const editor = Taleweaver.mount(host, {
  mode: 'editor',                 // ou 'viewer'
  appearance: 'word',             // ou 'compact'
  documentView: 'paginated',      // ou 'continuous'
  width: '100%',
  height: 'calc(100vh - 24px)',
  documentTitle: 'Contrato',
  showToolbar: true,
  showRulers: true,
  showStatusBar: true,
  showTitleBar: false,
  initialText: 'Comece a escrever.',
  zoom: 1,
  page: {
    width: 595.28,
    height: 841.89,
    margins: { top: 56.7, right: 56.7, bottom: 56.7, left: 56.7 },
  },
  themeVariables: {
    '--tw-accent': '#6b21a8',
    '--tw-canvas': '#ece8f4',
  },
  assets: {
    editorStylesheetUrl: 'packages/taleweaver/assets/taleweaver_word_editor.css',
    iconStylesheetUrl: 'packages/taleweaver/assets/taleweaver_word_icons.css',
    iconFontFamily: 'Taleweaver Office Icons',
  },
});
```

O handle tem ciclo de vida explícito e uma lista pequena de comandos seguros:

```js
editor.execute('bold');
editor.execute('heading', { level: 2 });
editor.execute('list', { type: 'ordered' });
editor.execute('table', { rows: 3, cols: 4 });
editor.execute('textBox', { text: 'Observação', width: 220 });
editor.execute('shape', { kind: 'ellipse', text: 'Aprovar' });
editor.execute('pageBreak');
editor.execute('paste', { text: 'Texto vindo da aplicação.' });

editor.setZoom(1.25);
editor.setDocumentView('continuous');
editor.setMode('viewer');
const texto = editor.getText();
editor.destroy();
```

`focus`, `destroy`, `setMode`, `setDocumentView`, `setZoom`,
`setDocumentTitle`, `setRulersVisible`, `setStatusBarVisible` e `execute`
retornam `true` quando a operação foi aceita e `false` para um handle já
destruído, uma opção inválida ou um comando indisponível no modo de leitura.
As opções desta fachada são propositalmente JSON — sem HTML interno, CSS
copiado, callbacks ou objetos de ação arbitrários. A guia **Arquivo** já abre
e exporta o subconjunto Quill Delta suportado pela biblioteca; importação DOCX
continua exigindo um adaptador explícito do host, pois a fachada não finge
interpretar um formato que ela não implementa integralmente.

O CSS do shell Word e a fonte de ícones não ficam em strings Dart. Por padrão
o componente inclui, no ownerDocument do host, links deduplicados para estes
assets delimitados por .tw-editor:

~~~
packages/taleweaver/assets/taleweaver_word_editor.css
packages/taleweaver/assets/taleweaver_word_icons.css
~~~

Assim a chamada de montagem continua sendo única. Aplicações com CSP, SSR ou
pipeline próprio também podem pré-carregar os dois links no HTML e desligar a
injeção automática:

~~~dart
const TaleweaverEditorOptions(
  assets: TaleweaverEditorAssets.hostManaged(
    iconFontFamily: 'Minha Fonte de Ícones',
    iconResolver: meuMapaDeIcones,
  ),
)
~~~

Ou podem substituir URLs por arquivos com hash/CDN sem tocar na UI:

~~~dart
const TaleweaverEditorOptions(
  assets: TaleweaverEditorAssets(
    editorStylesheetUrl: 'assets/editor-word.min.css',
    iconStylesheetUrl: 'assets/minha-fonte-office.css',
    iconFontFamily: 'Minha Fonte de Ícones',
    iconResolver: meuMapaDeIcones,
  ),
)
~~~

O contrato semântico TaleweaverEditorIcon e os codepoints padrão ficam em
word_editor_icons.dart; uma fonte alternativa usa o próprio resolver. Em um
deploy com dart compile js, publique também lib/assets/** sob
packages/taleweaver/assets/** (ou informe URLs próprias como acima).

A fonte padrão é gerada somente de SVGs vetoriais do toolbar do Document
Editor do ONLYOFFICE. O código-fonte, a atribuição CC BY-SA 4.0 e a
proveniência individual estão em lib/assets/icons/taleweaver/. Para
regenerá-la, execute:

~~~powershell
powershell -ExecutionPolicy Bypass -File tool/generate_taleweaver_icon_font.ps1
~~~

O script recusa PNG, JPEG, base64 e SVGs com imagens incorporadas; ele gera
WOFF2, WOFF, TTF e o mapa de codepoints em lib/assets/fonts/.

Para adaptar a identidade visual sem copiar esse CSS, passe variáveis do tema
na própria opção. Elas afetam somente aquela instância; as métricas físicas da
folha continuam vindo de `pageConfig` e do documento.

```dart
const TaleweaverEditorOptions(
  themeVariables: {
    '--tw-accent': '#6b21a8',
    '--tw-accent-dark': '#4c1d95',
    '--tw-canvas': '#ece8f4',
    '--tw-paper': '#ffffff',
  },
)
```

O tamanho inicial do papel também é uma opção da biblioteca — por exemplo,
para A4 em vez do padrão Letter — e pode depois ser alterado pelo documento:

```dart
const TaleweaverEditorOptions(
  pageConfig: PageConfig(
    width: 595.28,  // A4, em pontos
    height: 841.89,
    margins: PageMargins(top: 56.7, right: 56.7, bottom: 56.7, left: 56.7),
  ),
)
```

## Modos de apresentação

```dart
// Word completo, página com margem, ribbon e régua.
const TaleweaverEditorOptions(
  appearance: TaleweaverEditorAppearance.word,
  documentView: TaleweaverDocumentView.paginated,
);

// Leitura selecionável, sem aceitar entrada do usuário.
const TaleweaverEditorOptions(mode: TaleweaverEditorMode.viewer);

// Fluxo web contínuo, sem a folha simulada.
const TaleweaverEditorOptions(
  documentView: TaleweaverDocumentView.continuous,
);
```

O modo `paginated` usa um único DOM `contenteditable` autoritativo e uma
cadeia de paginação browser-flow interna: texto longo pode atravessar páginas
por linha, cada página tem intervalo visual próprio, e cabeçalhos/rodapés são
projetados novamente com os campos `PAGE`/`NUMPAGES` corretos. Isso preserva
seleção, IME, copiar/colar e reconciliação incremental sem clonar blocos do
documento. O backend Canvas continua sendo o caminho separado para
impressão/exportação de geometria determinística.

No layout de impressão, a régua horizontal é alinhada com a folha e permite
arrastar ou usar o teclado para alterar margens e recuos. Essas alterações
despacham ações do documento, entram em undo/redo e sobrevivem à serialização.
O seletor no canto alterna o tipo de tabulação; clique na régua para criar um
stop e use o menu de contexto do marcador para removê-lo. A guia **Layout**
também oferece diálogos de margens e de tamanho do papel em centímetros.

## Arquivo: Delta e DOCX

A guia **Arquivo** contém **Abrir Delta**, **Exportar Delta** e **Abrir DOCX**.
Sem configuração adicional, Delta abre um JSON de operações (`[...]` ou
`{ "ops": [...] }`) e baixa `<nome>.delta.json`. O codec preserva parágrafos,
títulos, alinhamento, listas ordered/bullet e as marcas inline usuais
(negrito, itálico, sublinhado, tachado, link, cor, fundo, fonte e tamanho).
Ele rejeita explicitamente tabelas, embeds, templates, comentários, sugestões
e change-Deltas de `retain`/`delete`, em vez de descartar conteúdo.

Para controlar armazenamento, telemetria ou usar um conversor próprio,
substitua os callbacks. O callback de DOCX deve construir um `EditorState` e
usar `replaceDocument`; isso mantém todos os hosts montados sincronizados sem
editar o DOM diretamente.

```dart
import 'dart:convert';

TaleweaverEditor.mount(
  host,
  options: TaleweaverEditorOptions(
    onOpenDocx: (request) async {
      final imported = await myDocxConverter.read(request.file);
      request.editor.replaceDocument(imported);
    },
    onExportDelta: (request) {
      final json = jsonEncode({'ops': encodeQuillDelta(request.state.state)});
      saveText('proposta.delta.json', json);
    },
  ),
);
```

`onOpenDelta` substitui o fluxo Delta nativo; use-o somente quando precisar
de um armazenamento ou dialeto próprio. `onExportDelta` tem precedência sobre
o download nativo; o callback genérico `onExport` continua disponível para
integrações legadas que multiplexam formatos.

## Integração controlada e ciclo de vida

```dart
late final TaleweaverEditor editor;

editor = TaleweaverEditor.mount(
  host,
  options: TaleweaverEditorOptions(
    controller: mySharedController,
    documentTitle: 'Proposta',
    onChanged: (state) => saveDraft(state),
    onSelectionChanged: updateInspector,
    onModeChanged: updateReadOnlyBadge,
    onDocumentViewChanged: persistViewPreference,
    onZoomChanged: persistZoom,
    onTitleChanged: persistTitle,
    onExport: (state, format) {
      if (format == binaryFormat) {
        final bytes = createBinaryDocumentSerializer().encode(state);
        saveBytes(bytes);
      }
    },
  ),
);

// Quando a tela/componente for desmontado:
editor.destroy();
```

`onChanged` é chamado somente por alterações no documento. Para observar
também movimentos de seleção, use `onStateChanged` e/ou
`onSelectionChanged`. Um `controller` não pode ser combinado com
`initialText` ou `initialEditorState`: a biblioteca lança `ArgumentError` em
vez de ignorar uma das fontes de estado.

Quando você fornece um `controller`, ele também é dono do `EditorConfig` do
reducer. Para permitir comandos de orientação de página, por exemplo, crie-o
com `DigitalEditorController(config: EditorConfig(pageConfig: ...))`; a shell
desabilita esse comando quando o controlador externo não define `PageConfig`.

Use `setMode`, `setDocumentView`, `setZoom`, `setDocumentTitle`,
`setRulersVisible` e `setStatusBarVisible` para atualizar o shell sem
remontar o documento.

Se um provedor colaborativo escreve no `TwDoc` compartilhado fora do
controller, reconcilie-o explicitamente para atualizar todos os hosts sem
incluir a mudança no undo local:

```dart
final stopForeignChanges = subscribeForeignChanges(
  controller.editor.state,
  localOrigin,
  controller.reconcileForeignChange,
);

// No descarte do provedor/tela:
stopForeignChanges();
```

## AngularDart

O pacote não depende de AngularDart. Monte depois que o elemento da view
existir e destrua com o componente; o editor usa `package:web`, portanto o
host é somente um `web.HTMLElement`.

```dart
import 'dart:html' as html;
import 'package:ngdart/angular.dart';
import 'package:web/web.dart' as web;
import 'package:taleweaver/taleweaver.dart';

class DocumentComponent implements AfterViewInit, OnDestroy {
  @ViewChild('editorHost')
  html.DivElement? editorHost;
  late final TaleweaverEditor editor;

  @override
  void ngAfterViewInit() {
    final host = editorHost;
    if (host == null) throw StateError('Host AngularDart ausente.');
    editor = TaleweaverEditor.mount(
      // O nó browser é o mesmo objeto JS; o cast fica na aplicação Angular,
      // mantendo a biblioteca livre de dart:html/AngularDart.
      (host as Object) as web.HTMLElement,
      options: const TaleweaverEditorOptions(
        documentTitle: 'Documento AngularDart',
        height: '720px',
      ),
    );
  }

  @override
  void ngOnDestroy() => editor.destroy();
}
```

O template correspondente precisa apenas do elemento de destino:

```html
<div #editorHost></div>
```

## Superfície sem ribbon

Use `DigitalEditorHost` somente quando a aplicação realmente precisa de uma
superfície DOM mínima e vai fornecer comandos próprios. Para a experiência
Word use `TaleweaverEditor`; não é necessário recriar ribbon, CSS ou eventos
de `contenteditable` no projeto consumidor.
