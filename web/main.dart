import 'package:taleweaver/taleweaver.dart';
import 'package:web/web.dart' as web;

/// An embedding application only supplies a host and options. The editor owns
/// its DOM, scoped styles, ribbon, rulers, document surface and lifecycle.
void main() {
  final host = web.document.querySelector('#app');
  if (host is! web.HTMLElement) return;

  TaleweaverEditor.mount(
    host,
    options: const TaleweaverEditorOptions(
      documentTitle: 'Taleweaver — Editor Word',
      // A aplicação de demonstração escolhe mostrar a title bar; integrações
      // comuns começam sem ela por padrão.
      showTitleBar: true,
      height: 'calc(100vh - 16px)',
      initialText:
          'Este documento demonstra o editor Taleweaver incorporado em uma aplicação Dart.',
    ),
  );
}
