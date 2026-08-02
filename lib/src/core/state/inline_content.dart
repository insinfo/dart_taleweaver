/// Inline content of a leaf block: styled text runs and inline embed items.
///
/// Port of `inline-content.ts`.
library;

import 'attrs.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Inline content of a leaf block: an ordered sequence of styled text runs
/// and inline embed items.
class InlineContent {
  final List<InlineItem> items;

  const InlineContent(this.items);

  /// An empty inline content with no items.
  static const empty = InlineContent([]);

  @override
  String toString() => 'InlineContent(${items.length} items)';
}

/// A single item in inline content: either [TextItem] or [EmbedItem].
sealed class InlineItem {
  const InlineItem();

  /// The attrs that wrap this item (formatting for text, link/comment for embeds).
  ReadonlyAttrs get attrs;
}

/// A run of styled text. `text` is in UTF-16 code units.
class TextItem extends InlineItem {
  final String text;
  @override
  final ReadonlyAttrs attrs;

  const TextItem({required this.text, this.attrs = const {}});

  Map<String, dynamic> toJson() => {
        'text': text,
        if (attrs.isNotEmpty) 'attrs': Map<String, dynamic>.of(attrs),
      };

  @override
  String toString() => 'TextItem("$text", attrs: $attrs)';
}

/// An inline embed (image, mention, equation, footnote-anchor, hard-break, etc.).
///
/// Counts as exactly one cursor position. [properties] carries primitive embed
/// data inline, OR a contentBlockId reference for substantial-content embeds.
/// [attrs] carries attributes that *wrap* the embed (e.g., link, comment-range).
class EmbedItem extends InlineItem {
  final String embedType;
  @override
  final ReadonlyAttrs attrs;
  final Map<String, dynamic> properties;

  const EmbedItem({
    required this.embedType,
    this.attrs = const {},
    this.properties = const {},
  });

  Map<String, dynamic> toJson() => {
        'embed': embedType,
        if (attrs.isNotEmpty) 'attrs': Map<String, dynamic>.of(attrs),
        if (properties.isNotEmpty) 'props': Map<String, dynamic>.of(properties),
      };

  @override
  String toString() => 'EmbedItem($embedType, attrs: $attrs)';
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Embed-type discriminant for an inline image.
const String inlineImageEmbedType = 'inline-image';

/// Hard line break (`<br>`) embed type.
const String hardBreakEmbedType = 'hard-break';

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

/// Total length of inline content, in Position.offset units.
///
/// Each text item contributes `text.length` (UTF-16 code units).
/// Each embed item contributes 1 (single cursor position).
int inlineContentLength(InlineContent content) {
  var total = 0;
  for (final item in content.items) {
    total += switch (item) {
      TextItem(:final text) => text.length,
      EmbedItem() => 1,
    };
  }
  return total;
}

/// Result of [findItemAtOffset].
class ItemAtOffset {
  final int itemIndex;
  final int withinItem;

  const ItemAtOffset({required this.itemIndex, required this.withinItem});

  @override
  String toString() => 'ItemAtOffset(index: $itemIndex, within: $withinItem)';
}

/// Locate the inline item containing [offset].
///
/// [withinItem] is the offset into that item (0 for embed items,
/// char-offset for text items).
///
/// Returns `itemIndex == items.length, withinItem == 0` when offset equals
/// the total inline-content length (end-of-block).
ItemAtOffset findItemAtOffset(InlineContent content, int offset) {
  final total = inlineContentLength(content);
  if (offset < 0 || offset > total) {
    throw RangeError(
        'findItemAtOffset: offset $offset out of range [0, $total]');
  }

  var cursor = 0;
  for (var i = 0; i < content.items.length; i++) {
    final item = content.items[i];
    final itemLen = switch (item) {
      TextItem(:final text) => text.length,
      EmbedItem() => 1,
    };
    if (offset < cursor + itemLen) {
      return ItemAtOffset(itemIndex: i, withinItem: offset - cursor);
    }
    cursor += itemLen;
  }
  return ItemAtOffset(itemIndex: content.items.length, withinItem: 0);
}

/// The attrs of the run containing the char at [offset].
///
/// Falls back to `{}` when offset lands at end-of-content.
ReadonlyAttrs attrsAtOffset(InlineContent content, int offset) {
  final result = findItemAtOffset(content, offset);
  if (result.itemIndex < content.items.length) {
    return content.items[result.itemIndex].attrs;
  }
  return const {};
}

/// Merge adjacent text items with equal attrs into a single item,
/// and drop zero-length text items.
///
/// Embed items act as barriers and are not merged with their neighbors.
///
/// [customEquals] is threaded through to [attrsEqual] so interpreters
/// with custom per-key equality can opt into custom run-merge equality.
///
/// Returns a fresh list; never mutates the input.
List<InlineItem> mergeAdjacentTextItems(
  List<InlineItem> items, {
  Map<String, AttrEqualsFn>? customEquals,
}) {
  final out = <InlineItem>[];
  TextItem? pending;

  for (final item in items) {
    switch (item) {
      case TextItem(:final text, :final attrs):
        // Drop zero-length text items.
        if (text.isEmpty) continue;
        if (pending != null &&
            attrsEqual(pending.attrs, attrs, customEquals: customEquals)) {
          pending = TextItem(text: pending.text + text, attrs: pending.attrs);
        } else {
          if (pending != null) out.add(pending);
          pending = item;
        }
      case EmbedItem():
        if (pending != null) {
          out.add(pending);
          pending = null;
        }
        out.add(item);
    }
  }
  if (pending != null) out.add(pending);
  return out;
}

/// Partition [content.items] at [offset] into `[leftItems, rightItems]`.
///
/// - Clean boundary: pure list slice, no item splitting.
/// - Mid-text: split that text item into left and right halves.
/// - Mid-embed: throws (unreachable per [findItemAtOffset] contract).
(List<InlineItem>, List<InlineItem>) splitInlineContentAtOffset(
  InlineContent content,
  int offset,
) {
  final items = content.items;
  final result = findItemAtOffset(content, offset);
  final itemIndex = result.itemIndex;
  final withinItem = result.withinItem;

  if (withinItem == 0) {
    return (
      List<InlineItem>.of(items.sublist(0, itemIndex)),
      List<InlineItem>.of(items.sublist(itemIndex)),
    );
  }

  final straddle = items[itemIndex];
  if (straddle is! TextItem) {
    throw StateError(
      'splitInlineContentAtOffset: offset falls inside non-text item '
      'at index $itemIndex (kind="${straddle.runtimeType}")',
    );
  }

  final leftHead = TextItem(
    text: straddle.text.substring(0, withinItem),
    attrs: straddle.attrs,
  );
  final rightHead = TextItem(
    text: straddle.text.substring(withinItem),
    attrs: straddle.attrs,
  );
  return (
    [...items.sublist(0, itemIndex), leftHead],
    [rightHead, ...items.sublist(itemIndex + 1)],
  );
}
