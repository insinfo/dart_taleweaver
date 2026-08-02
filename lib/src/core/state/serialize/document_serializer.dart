/// Document (de)serialization interfaces.
///
/// Port of `serialize/document-serializer.ts`.
library;

import '../state.dart';

/// A pluggable document (de)serializer. One per wire format.
/// `encode`/`decode` are INVERSES for round-trippable formats.
/// Any dependencies a serializer needs are injected at CONSTRUCTION, NOT passed per call.
abstract class DocumentSerializer<TWire> {
  /// Stable format id, e.g. "taleweaver-json" or "taleweaver-html". The registry key.
  String get format;

  /// Serialize a document State to the wire format.
  TWire encode(State state);

  /// Reconstruct a document State from the wire format.
  State decode(TWire source);
}

/// Thrown by serializeDocument/deserializeDocument when no serializer is registered for `format`.
class UnknownSerializerFormatError extends Error {
  final String format;

  UnknownSerializerFormatError(this.format);

  @override
  String toString() =>
      'UnknownSerializerFormatError: No document serializer registered for format "$format"';
}

/// Thrown by a serializer's decode when the wire data is structurally invalid.
class MalformedDocumentError extends Error {
  final String format;

  MalformedDocumentError(this.format);

  @override
  String toString() =>
      'MalformedDocumentError: Malformed document for format "$format"';
}
