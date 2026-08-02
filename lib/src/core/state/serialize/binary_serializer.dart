/// Internal document serializer (lossless serialization of TwDoc).
///
/// Port of `serialize/binary-serializer.ts`.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../block_id.dart';
import '../state.dart';
import '../tw_doc.dart';
import 'document_serializer.dart';

const String binaryFormat = 'taleweaver-binary';

class _BinaryDocumentSerializer implements DocumentSerializer<Uint8List> {
  @override
  String get format => binaryFormat;

  @override
  Uint8List encode(State state) {
    // Dump the entire internal state of TwDoc to JSON.
    final jsonStr = jsonEncode(state.doc.toJson());
    return utf8.encoder.convert(jsonStr);
  }

  @override
  State decode(Uint8List source) {
    try {
      final jsonStr = utf8.decoder.convert(source);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final doc = TwDoc.fromJson(data);
      
      final rootIdVal = doc.meta['rootId'];
      if (rootIdVal == null || rootIdVal is! String) {
        throw MalformedDocumentError(binaryFormat);
      }
      
      return createState(rootId: BlockId(rootIdVal), doc: doc);
    } catch (e) {
      if (e is MalformedDocumentError) rethrow;
      throw MalformedDocumentError(binaryFormat);
    }
  }
}

/// The v1 document serializer: a lossless round-trip backed by JSON representation
/// of the internal [TwDoc] map structures.
DocumentSerializer<Uint8List> createBinaryDocumentSerializer() {
  return _BinaryDocumentSerializer();
}
