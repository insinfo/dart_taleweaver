/// The `taleweaver-html` human-friendly `DocumentSerializer<String>`.
///
/// Port of `serialize/html-serializer.ts`.
library;

import '../block_id.dart';
import '../state.dart';
import 'document_serializer.dart';
import 'html_node.dart';
import 'html_encode.dart';
import 'html_decode.dart';

/// Stable registry key for the human-friendly HTML format.
const htmlFormat = 'taleweaver-html';

class _HtmlDocumentSerializer implements DocumentSerializer<String> {
  final IdAllocator allocator;
  final HtmlParser parseHtml;

  _HtmlDocumentSerializer({
    required this.allocator,
    required this.parseHtml,
  });

  @override
  String get format => htmlFormat;

  @override
  String encode(State state) => encodeHtml(state);

  @override
  State decode(String data) => decodeHtml(data, allocator, parseHtml);
}

/// Construct the `taleweaver-html` serializer.
DocumentSerializer<String> createHtmlDocumentSerializer({
  required IdAllocator allocator,
  required HtmlParser parseHtml,
}) {
  return _HtmlDocumentSerializer(
    allocator: allocator,
    parseHtml: parseHtml,
  );
}
