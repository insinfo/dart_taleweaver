/// Registry of document serializers.
///
/// Port of `serialize/serializer-registry.ts`.
library;

import 'binary_serializer.dart';
import 'document_serializer.dart';

/// Registry of document serializers, keyed by `serializer.format`.
abstract class SerializerRegistry {
  void register(DocumentSerializer serializer);
  DocumentSerializer? get(String format);
  bool has(String format);
}

class _SerializerRegistryImpl implements SerializerRegistry {
  final Map<String, DocumentSerializer> _serializers = {};

  @override
  void register(DocumentSerializer serializer) {
    _serializers[serializer.format] = serializer;
  }

  @override
  DocumentSerializer? get(String format) {
    return _serializers[format];
  }

  @override
  bool has(String format) {
    return _serializers.containsKey(format);
  }
}

/// An empty registry; tests register only the serializers under test.
SerializerRegistry createSerializerRegistry() {
  return _SerializerRegistryImpl();
}

/// A registry pre-populated with the built-in serializers.
SerializerRegistry createDefaultSerializerRegistry() {
  final reg = createSerializerRegistry();
  reg.register(createBinaryDocumentSerializer());
  return reg;
}
