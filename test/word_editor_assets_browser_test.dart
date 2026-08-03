@TestOn('browser')

import 'package:taleweaver/taleweaver.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

String _customIconGlyph(TaleweaverEditorIcon _) => String.fromCharCode(0xea01);

void main() {
  test('mounts external CSS and icon-font assets without a Dart style string',
      () {
    final host = _appendHost();
    final linksBefore =
        web.document.querySelectorAll('[data-taleweaver-editor-asset]').length;
    final editor = TaleweaverEditor.mount(host);
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    final links =
        web.document.querySelectorAll('[data-taleweaver-editor-asset]');
    expect(links.length, linksBefore + 2);
    final hrefs = <String>[
      for (var index = 0; index < links.length; index++)
        (links.item(index) as web.HTMLLinkElement).href,
    ];
    expect(
      hrefs.any((href) => href
          .endsWith('/packages/taleweaver/assets/taleweaver_word_editor.css')),
      isTrue,
    );
    expect(
      hrefs.any((href) => href
          .endsWith('/packages/taleweaver/assets/taleweaver_word_icons.css')),
      isTrue,
    );

    final icon =
        editor.root.querySelector('[data-command="bold"] .tw-editor__icon')
            as web.HTMLElement;
    expect(icon.getAttribute('data-tw-icon'), 'bold');
    expect(
        icon.textContent, taleweaverOfficeIconGlyph(TaleweaverEditorIcon.bold));
    expect(editor.root.style.getPropertyValue('--tw-icon-font'),
        TaleweaverEditorAssets.defaultIconFontFamily);
  });

  test('allows a host to own CSS and replace the icon font contract', () {
    final host = _appendHost();
    final linksBefore =
        web.document.querySelectorAll('[data-taleweaver-editor-asset]').length;
    final editor = TaleweaverEditor.mount(
      host,
      options: const TaleweaverEditorOptions(
        assets: TaleweaverEditorAssets.hostManaged(
          iconFontFamily: 'Aplicação Office Icons',
          iconResolver: _customIconGlyph,
        ),
      ),
    );
    addTearDown(() {
      editor.destroy();
      host.remove();
    });

    expect(
      web.document.querySelectorAll('[data-taleweaver-editor-asset]').length,
      linksBefore,
    );
    expect(editor.root.style.getPropertyValue('--tw-icon-font'),
        'Aplicação Office Icons');
    final icon =
        editor.root.querySelector('[data-command="bold"] .tw-editor__icon')
            as web.HTMLElement;
    expect(icon.textContent, String.fromCharCode(0xea01));
  });
}

web.HTMLElement _appendHost() {
  final host = web.document.createElement('div') as web.HTMLElement;
  web.document.body!.appendChild(host);
  return host;
}
