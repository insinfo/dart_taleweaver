/// Browser assets used by the embeddable Word editor.
///
/// The editor never embeds CSS source in Dart.  A host can keep the default
/// package assets, point these URLs at a branded distribution, or set either
/// URL to null after loading its own stylesheet.
library;

import 'package:web/web.dart' as web;

import 'word_editor_icons.dart';

/// Package-asset contract for [TaleweaverEditor].
///
/// URLs are deliberately plain URLs rather than bundled strings so AngularDart
/// and plain Dart applications can host, cache and replace the presentation
/// layer independently from editor logic.
class TaleweaverEditorAssets {
  static const String defaultEditorStylesheetUrl =
      'packages/taleweaver/assets/taleweaver_word_editor.css';
  static const String defaultIconStylesheetUrl =
      'packages/taleweaver/assets/taleweaver_word_icons.css';
  static const String defaultIconFontFamily = 'Taleweaver Office Icons';

  /// Stylesheet for layout, Word chrome and document page presentation.
  ///
  /// Set to null when the host supplies an equivalent stylesheet itself.
  final String? editorStylesheetUrl;

  /// Stylesheet that declares the icon font with @font-face.
  ///
  /// It contains no bitmap/icon data; the font files are independent package
  /// assets. Set to null when the host provides a replacement icon font.
  final String? iconStylesheetUrl;

  /// CSS font family applied to command icon elements.
  ///
  /// A replacement font can use the documented codepoints exposed by
  /// [TaleweaverEditorIcon], or an application can provide an icon resolver.
  final String iconFontFamily;

  /// Resolves the private-use glyph used for every semantic ribbon icon.
  ///
  /// Supply this together with [iconFontFamily] when the host uses a font
  /// with its own codepoint map.
  final TaleweaverEditorIconResolver iconResolver;

  const TaleweaverEditorAssets({
    this.editorStylesheetUrl = defaultEditorStylesheetUrl,
    this.iconStylesheetUrl = defaultIconStylesheetUrl,
    this.iconFontFamily = defaultIconFontFamily,
    this.iconResolver = taleweaverOfficeIconGlyph,
  });

  /// Uses no automatically injected stylesheets.
  ///
  /// This is useful when an application emits its CSS through a framework
  /// asset pipeline or wants a completely custom Word chrome theme.
  const TaleweaverEditorAssets.hostManaged({
    this.iconFontFamily = defaultIconFontFamily,
    this.iconResolver = taleweaverOfficeIconGlyph,
  })  : editorStylesheetUrl = null,
        iconStylesheetUrl = null;
}

/// Reference-counted stylesheets shared by every editor mounted into one
/// browser document.  The lease removes only links created by this package;
/// host-owned links are never touched.
final class TaleweaverEditorAssetLease {
  TaleweaverEditorAssetLease(this._registry, this._urls);

  final _TaleweaverEditorAssetRegistry _registry;
  final List<String> _urls;
  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    for (final url in _urls) {
      _registry.release(url);
    }
  }
}

final class _TaleweaverEditorAssetRegistry {
  _TaleweaverEditorAssetRegistry(this.document);

  final web.Document document;
  final Map<String, ({web.HTMLLinkElement link, int references})> _links = {};

  TaleweaverEditorAssetLease acquire(TaleweaverEditorAssets assets) {
    final urls = <String>[
      if (assets.editorStylesheetUrl case final String url when url.isNotEmpty)
        url,
      if (assets.iconStylesheetUrl case final String url when url.isNotEmpty)
        url,
    ];
    for (final url in urls) {
      final existing = _links[url];
      if (existing != null) {
        _links[url] =
            (link: existing.link, references: existing.references + 1);
        continue;
      }
      final link = document.createElement('link') as web.HTMLLinkElement
        ..rel = 'stylesheet'
        ..href = url
        ..setAttribute('data-taleweaver-editor-asset', url);
      (document.head ?? document.documentElement)?.appendChild(link);
      _links[url] = (link: link, references: 1);
    }
    return TaleweaverEditorAssetLease(this, urls);
  }

  void release(String url) {
    final existing = _links[url];
    if (existing == null) return;
    if (existing.references > 1) {
      _links[url] = (link: existing.link, references: existing.references - 1);
      return;
    }
    existing.link.remove();
    _links.remove(url);
  }
}

final Expando<_TaleweaverEditorAssetRegistry> _assetRegistries =
    Expando<_TaleweaverEditorAssetRegistry>('taleweaverEditorAssetRegistry');

TaleweaverEditorAssetLease acquireTaleweaverEditorAssets(
  web.Document document,
  TaleweaverEditorAssets assets,
) {
  var registry = _assetRegistries[document];
  registry ??= _TaleweaverEditorAssetRegistry(document);
  _assetRegistries[document] = registry;
  return registry.acquire(assets);
}
