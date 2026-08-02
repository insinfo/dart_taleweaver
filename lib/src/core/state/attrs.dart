/// Open-schema attribute bag used at every level of the state tree.
///
/// Port of `attrs.ts`.
library;

// ---------------------------------------------------------------------------
// ReadonlyAttrs
// ---------------------------------------------------------------------------

/// Open-schema attribute bag. Used at every level of the state tree:
/// - `Block.attrs` (block-level attributes)
/// - `TextItem.attrs` (inline text styles)
/// - `EmbedItem.attrs` (attributes that wrap an embed, e.g. link)
///
/// Plugins register interpreters per attribute key with the cascade module
/// to translate these open-schema values into closed-schema ComputedStyle.
typedef ReadonlyAttrs = Map<String, dynamic>;

/// An empty, unmodifiable attrs map — canonical sentinel.
final ReadonlyAttrs emptyAttrs = const <String, dynamic>{};

// ---------------------------------------------------------------------------
// deepValueEqual
// ---------------------------------------------------------------------------

/// Default deep value equality for attribute comparison and run merging.
///
/// Compares primitives by `==`, Maps by recursive key/value walk, Lists
/// by element-wise compare. Returns false when types differ.
bool deepValueEqual(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepValueEqual(a[i], b[i])) return false;
    }
    return true;
  }

  if (a is Map && b is Map) {
    if (a is! List && b is! List) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k)) return false;
        if (!deepValueEqual(a[k], b[k])) return false;
      }
      return true;
    }
    return false;
  }

  return a == b;
}

// ---------------------------------------------------------------------------
// attrsEqual
// ---------------------------------------------------------------------------

/// A per-key equality function used by [AttrRegistry] interpreters.
typedef AttrEqualsFn = bool Function(dynamic a, dynamic b);

/// Compare two attribute bags for equality.
///
/// When [customEquals] is provided (map of attr key → custom equality fn),
/// consults each key's registered equality for custom per-key comparison.
/// Keys with no registered custom function fall back to [deepValueEqual].
bool attrsEqual(
  ReadonlyAttrs a,
  ReadonlyAttrs b, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (!b.containsKey(k)) return false;
    final eq = customEquals?[k] ?? deepValueEqual;
    if (!eq(a[k], b[k])) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// mergeAttrs
// ---------------------------------------------------------------------------

/// Merge incoming attrs into existing attrs.
///
/// - Keys with value `null` in [incoming] are REMOVED from the result.
/// - Other keys in [incoming] overwrite or add to [existing].
/// - Keys only in [existing] are preserved.
///
/// Returns a new map; never mutates the inputs.
ReadonlyAttrs mergeAttrs(ReadonlyAttrs existing, ReadonlyAttrs incoming) {
  final result = Map<String, dynamic>.of(existing);
  for (final key in incoming.keys) {
    if (incoming[key] == null) {
      result.remove(key);
    } else {
      result[key] = incoming[key];
    }
  }
  return Map<String, dynamic>.unmodifiable(result);
}
