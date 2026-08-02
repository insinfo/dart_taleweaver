import 'package:web/web.dart' as web;

import 'package:taleweaver/taleweaver.dart';

void main() {
  final host = web.document.querySelector('#app');
  if (host is! web.HTMLElement) return;
  host.textContent = '';
  host.appendChild(_buildToolbar());
  host.appendChild(_buildDocument());
}

web.HTMLElement _buildToolbar() {
  final toolbar = web.document.createElement('div') as web.HTMLElement;
  toolbar.setAttribute('role', 'toolbar');
  toolbar.setAttribute('aria-label', 'Formatting');
  for (final label in ['Undo', 'Redo', 'Bold', 'Italic']) {
    final button =
        web.document.createElement('button') as web.HTMLButtonElement;
    button.type = 'button';
    button.textContent = label;
    toolbar.appendChild(button);
  }
  return toolbar;
}

web.HTMLElement _buildDocument() {
  final state = createEmptyDocument(allocator: createTestAllocator('demo'));
  final paragraphId = getBlock(state, state.rootId)!.firstChildId!;
  final paragraph = web.document.createElement('div') as web.HTMLElement;
  paragraph.setAttribute('data-block-id', paragraphId.value);
  paragraph.contentEditable = 'true';
  paragraph.textContent = 'Taleweaver Dart';
  paragraph.setAttribute(
      'style', 'min-height: 1.5em; padding: 1rem; border: 1px solid #ccd3df;');
  return paragraph;
}
