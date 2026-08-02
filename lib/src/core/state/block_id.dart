/// Block identity and allocation.
///
/// Port of `block-id.ts`. In TypeScript, `BlockId` is a branded string;
/// in Dart we use an extension type for zero-cost wrapping with type safety.
library;

import 'dart:math';

// ---------------------------------------------------------------------------
// BlockId
// ---------------------------------------------------------------------------

/// An opaque identifier for a block in the document tree.
///
/// Implemented as an extension type over [String] for zero-cost wrapping:
/// no extra allocation at runtime, but the type system prevents passing an
/// arbitrary String where a BlockId is expected.
extension type const BlockId(String value) implements String {}

/// Brand a string already known to be a BlockId.
BlockId asBlockId(String value) => BlockId(value);

/// Coerce an open-schema value to a [BlockId].
///
/// A [String] is kept (branded as a BlockId); anything else becomes `null`.
/// Used where block-id references ride through untyped channels.
BlockId? coerceBlockId(Object? value) {
  return value is String ? BlockId(value) : null;
}

// ---------------------------------------------------------------------------
// IdAllocator
// ---------------------------------------------------------------------------

/// Allocates [BlockId]s. Production uses UUID v4; tests inject a
/// deterministic counter-based allocator via [createTestAllocator].
abstract interface class IdAllocator {
  BlockId allocate();
}

/// Production allocator — generates UUID v4 identifiers.
final IdAllocator productionAllocator = _UuidAllocator();

/// Mint a fresh list id. List ids are a plain-string namespace, DISTINCT
/// from block ids. Minting here co-locates id generation with the
/// block-id allocator.
String newListId() => _generateUuid();

/// Creates a deterministic allocator for tests.
///
/// Each call to `allocate()` returns `$prefix-$n` where n increments from 0.
IdAllocator createTestAllocator([String prefix = 'blk']) {
  return _TestAllocator(prefix);
}

// ---------------------------------------------------------------------------
// Private implementations
// ---------------------------------------------------------------------------

class _UuidAllocator implements IdAllocator {
  @override
  BlockId allocate() => BlockId(_generateUuid());
}

class _TestAllocator implements IdAllocator {
  final String _prefix;
  int _n = 0;

  _TestAllocator(this._prefix);

  @override
  BlockId allocate() => BlockId('$_prefix-${_n++}');
}

/// Simple UUID v4 generator (no external dependency).
String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Set version (4) and variant (10xx) bits per RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');

  return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
      '${hex(bytes[4])}${hex(bytes[5])}-'
      '${hex(bytes[6])}${hex(bytes[7])}-'
      '${hex(bytes[8])}${hex(bytes[9])}-'
      '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}'
      '${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
}
