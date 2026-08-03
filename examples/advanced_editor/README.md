# Taleweaver Advanced Editor example

Este exemplo usa o demo browser em `../../web` para demonstrar o editor Dart
embarcável com shell Word (ribbon, réguas, página, status), contenteditable,
seleção UTF-16, undo/redo, formatação, listas, tabelas, templates de
header/footer e mirror de acessibilidade. O entrypoint da aplicação apenas
monta `TaleweaverEditor`; toda a UI pertence à biblioteca.

Para uso em Dart web ou AngularDart, veja
[`docs/embedding_editor.md`](../../docs/embedding_editor.md).

## Executar

Na raiz do repositório:

```powershell
dart compile js web/main.dart -o web/main.dart.js
webdev serve web
```

Abra o endereço exibido pelo `webdev`.

## E2E no Chrome

O teste `test/e2e/advanced_editor_e2e_test.dart` sobe `web/` com Shelf e
controla o Chrome usando Puppeteer. Ele é opt-in porque precisa de um Chrome:

```powershell
$env:RUN_E2E='1'
dart test test/e2e/advanced_editor_e2e_test.dart
```

Os testes unitários continuam independentes do navegador:

```powershell
dart test
```
