/// Link-URL safety predicates shared by the two places a hyperlink URL leaves
/// the engine: the DOM controller's Cmd/Ctrl-click navigation and the
/// `taleweaver-html` export's `<a href>` emission.
///
/// The threat: a `link` attr is document content and can arrive from an
/// untrusted source (paste / decode / programmatic SET_LINK). A `javascript:`
/// / `data:` / `vbscript:` URL must never be navigated to, nor emitted into
/// exported HTML where a downstream consumer could open it and execute script.
/// We use an ALLOWLIST of safe schemes (not a denylist) so a novel dangerous
/// scheme is rejected by default.
library;

/// Schemes safe to navigate to AND to emit in an `<a href>`.
const _safeUrlSchemes = <String>{'http', 'https', 'mailto', 'tel'};

/// Regex matching an RFC 3986 scheme: `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`.
final _schemeRe = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):');

/// Extract the leading scheme of [url] (lowercased), or `null` when it has
/// none (a relative path, fragment, or scheme-relative `//host` URL).
///
/// Browsers ignore ASCII control characters and spaces when resolving a scheme
/// (they strip tab/newline from a URL entirely and trim leading control/space),
/// so `"java\tscript:"` and `"  javascript:"` both resolve to the `javascript`
/// scheme. We strip every ASCII char <= 0x20 for the check (the original string
/// is what gets emitted/opened) to defeat that obfuscation.
String? _schemeOf(String url) {
  final buf = StringBuffer();
  for (var i = 0; i < url.length; i++) {
    if (url.codeUnitAt(i) > 0x20) buf.writeCharCode(url.codeUnitAt(i));
  }
  final normalized = buf.toString();
  final match = _schemeRe.firstMatch(normalized);
  if (match == null) return null;
  final scheme = match.group(1);
  if (scheme == null) {
    throw StateError(
      'url-safety: scheme capture group unexpectedly absent on a matched URL',
    );
  }
  return scheme.toLowerCase();
}

/// True iff [url] is safe to NAVIGATE to (open in a new tab). Requires an
/// explicit safe scheme: a relative / scheme-less URL returns `false` (there is
/// nothing meaningful to open from a document editor).
bool isOpenableLinkUrl(String url) {
  final scheme = _schemeOf(url);
  return scheme != null && _safeUrlSchemes.contains(scheme);
}

/// True iff [url] is safe to EMIT in an exported `<a href>`. Permits safe-scheme
/// URLs AND relative / scheme-less URLs (a relative link is legitimate in
/// exported HTML and carries no executable scheme); rejects only URLs whose
/// explicit scheme is not in the safe allowlist (`javascript:` / `data:` /
/// `vbscript:` / `file:` / …).
bool isExportSafeLinkUrl(String url) {
  final scheme = _schemeOf(url);
  return scheme == null || _safeUrlSchemes.contains(scheme);
}
