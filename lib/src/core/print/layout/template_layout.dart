/// Minimal deterministic materialization of a cascaded template render tree.
///
/// Template bodies are block-oriented. This adapter preserves each direct
/// rendered child as a block-level layout box and flattens its inline text for
/// the existing IFC/BFC text measurer. Rich block/table fragmentation remains
/// owned by the normal layout producer; this function supplies the geometry
/// boundary needed by named page slots.
library;

import '../../layout/hyphenator.dart';
import '../../layout/text_shaper.dart';
import '../../render/render_node.dart';
import '../../state/block_id.dart';
import '../../styles/computed_style.dart';
import '../../styles/style.dart';
import 'bfc.dart';
import 'layout_box.dart';
import 'table_layout.dart';

BlockBox layoutTemplateRenderNode({
  required RenderNode root,
  required TextShaper shaper,
  required double inlineSize,
  required ComputedStyle fallbackStyle,
  Hyphenator? hyphenator,
}) {
  final children = <LayoutBox>[];
  if (root is ElementBox) {
    var leftFloat = 0.0;
    var rightFloat = 0.0;
    var flowOffset = 0.0;
    var floatBottom = 0.0;
    var leftFloatBottom = 0.0;
    var rightFloatBottom = 0.0;
    for (final child in root.children) {
      if (child is ElementBox &&
          (child.metadata?.columnWidths != null ||
              child.style.display == Display.table)) {
        children.add(
            _layoutTable(child, shaper, inlineSize, fallbackStyle, hyphenator));
        continue;
      }
      final image = child is ElementBox ? child.metadata?.image : null;
      if (image != null) {
        final style =
            child.computedStyle ?? root.computedStyle ?? fallbackStyle;
        var offset = flowOffset;
        final float = child.style.float ?? style.float;
        final isFloat = float != Float.none;
        if (isFloat && leftFloat + rightFloat + image.width > inlineSize) {
          // A new float cannot share the current line with the existing
          // floats.  Start a fresh float band below their bottom edge.
          offset = floatBottom > flowOffset ? floatBottom : flowOffset;
          leftFloat = 0;
          rightFloat = 0;
          flowOffset = offset;
        }
        final x =
            float == Float.inlineEnd ? inlineSize - image.width : leftFloat;
        children.add(ImageBox(
            key: child.key,
            inlineOffset: 0,
            blockOffset: offset,
            inlineSize: image.width,
            blockSize: image.height,
            x: x,
            y: offset,
            width: image.width,
            height: image.height,
            writingMode: style.writingMode,
            direction: style.direction,
            computedStyle: style,
            src: image.src,
            alt: image.alt));
        if (isFloat) {
          floatBottom = floatBottom > offset + image.height
              ? floatBottom
              : offset + image.height;
          if (float == Float.inlineEnd) {
            rightFloat += image.width;
            rightFloatBottom = rightFloatBottom > offset + image.height
                ? rightFloatBottom
                : offset + image.height;
          } else {
            leftFloat += image.width;
            leftFloatBottom = leftFloatBottom > offset + image.height
                ? leftFloatBottom
                : offset + image.height;
          }
        } else {
          flowOffset = offset + image.height;
        }
        continue;
      }
      final text = _textContent(child);
      if (text.isEmpty) continue;
      if (flowOffset >= floatBottom && floatBottom > 0) {
        leftFloat = 0;
        rightFloat = 0;
      }
      final style = child.computedStyle ?? root.computedStyle ?? fallbackStyle;
      final clear = child.style.clear ?? style.clear;
      if (clear != Clear.none) {
        final clearBottom = switch (clear) {
          Clear.inlineStart => leftFloatBottom,
          Clear.inlineEnd => rightFloatBottom,
          Clear.both => floatBottom,
          Clear.none => 0.0,
        };
        flowOffset = flowOffset > clearBottom ? flowOffset : clearBottom;
      }
      final availableInline = (inlineSize - leftFloat - rightFloat)
          .clamp(1.0, inlineSize)
          .toDouble();
      final laidOut = layoutBlockText(
          key: child.key,
          text: text,
          ownerBlockId: BlockId(_ownerKey(child.key)),
          shaper: shaper,
          style: style,
          inlineSize: availableInline,
          blockOffset: flowOffset,
          hyphenator: hyphenator);
      children.add(_offsetInline(laidOut, leftFloat));
      flowOffset += laidOut.blockSize;
    }
  } else {
    final text = _textContent(root);
    if (text.isNotEmpty) {
      children.add(layoutBlockText(
          key: root.key,
          text: text,
          ownerBlockId: BlockId(_ownerKey(root.key)),
          shaper: shaper,
          style: root.computedStyle ?? fallbackStyle,
          inlineSize: inlineSize,
          hyphenator: hyphenator));
    }
  }
  final style = root.computedStyle ?? fallbackStyle;
  final blockSize = children.fold<double>(0, (max, box) {
    final bottom = box.blockOffset + box.blockSize;
    return bottom > max ? bottom : max;
  });
  return BlockBox(
      key: root.key,
      inlineOffset: 0,
      blockOffset: 0,
      inlineSize: inlineSize,
      blockSize: blockSize,
      x: 0,
      y: 0,
      width: inlineSize,
      height: blockSize,
      writingMode: style.writingMode,
      direction: style.direction,
      computedStyle: style,
      children: children);
}

LayoutBox _offsetInline(LayoutBox source, double delta) {
  if (delta == 0) return source;
  if (source is BlockBox) {
    return BlockBox(
        key: source.key,
        inlineOffset: source.inlineOffset + delta,
        blockOffset: source.blockOffset,
        inlineSize: source.inlineSize,
        blockSize: source.blockSize,
        x: source.x + delta,
        y: source.y,
        width: source.width,
        height: source.height,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        children: source.children
            .map((child) => _offsetInline(child, delta))
            .toList(),
        ownerBlockId: source.ownerBlockId);
  }
  if (source is LineBox) {
    return LineBox(
        key: source.key,
        inlineOffset: source.inlineOffset + delta,
        blockOffset: source.blockOffset,
        inlineSize: source.inlineSize,
        blockSize: source.blockSize,
        x: source.x + delta,
        y: source.y,
        width: source.width,
        height: source.height,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        children: source.children
            .map((child) => _offsetInline(child, delta))
            .toList(),
        baseline: source.baseline,
        ownerBlockId: source.ownerBlockId,
        offsetStart: source.offsetStart,
        endsWithHyphen: source.endsWithHyphen);
  }
  if (source is TextRunBox) {
    return TextRunBox(
        key: source.key,
        inlineOffset: source.inlineOffset + delta,
        blockOffset: source.blockOffset,
        inlineSize: source.inlineSize,
        blockSize: source.blockSize,
        x: source.x + delta,
        y: source.y,
        width: source.width,
        height: source.height,
        writingMode: source.writingMode,
        direction: source.direction,
        computedStyle: source.computedStyle,
        usedStyle: source.usedStyle,
        text: source.text,
        offsetLength: source.offsetLength);
  }
  return source;
}

TableBox _layoutTable(ElementBox table, TextShaper shaper, double inlineSize,
    ComputedStyle fallbackStyle, Hyphenator? hyphenator) {
  final style = table.computedStyle ?? fallbackStyle;
  final rows = <List<TableCellInput>>[];
  for (final row in table.children.whereType<ElementBox>()) {
    final cells = <TableCellInput>[];
    for (final cell in row.children.whereType<ElementBox>()) {
      final cellStyle = cell.computedStyle ?? fallbackStyle;
      final text = _textContent(cell);
      final box = layoutBlockText(
          key: cell.key,
          text: text,
          ownerBlockId: BlockId(_ownerKey(cell.key)),
          shaper: shaper,
          style: cellStyle,
          inlineSize: inlineSize,
          hyphenator: hyphenator);
      cells.add(
          TableCellInput(BlockId(_ownerKey(cell.key)), box, cell.metadata));
    }
    if (cells.isNotEmpty) rows.add(cells);
  }
  return composeTableLayout(
      key: table.key,
      rows: rows,
      inlineSize: inlineSize,
      writingMode: style.writingMode,
      direction: style.direction,
      columnWidths: table.metadata?.columnWidths,
      headerRowCount: table.metadata?.headerRowCount ?? 0,
      computedStyle: style);
}

String _textContent(RenderNode node) {
  if (node is TextBox) return node.text;
  if (node is ElementBox) {
    final parts = <String>[];
    for (final child in node.children) {
      final text = _textContent(child);
      if (text.isNotEmpty) parts.add(text);
    }
    // Element children represent block/container boundaries in a template;
    // text runs remain contiguous because they are TextBox children directly.
    final hasElementChild = node.children.any((child) => child is ElementBox);
    return parts.join(hasElementChild ? '\n' : '');
  }
  return '';
}

String _ownerKey(String key) {
  final slash = key.indexOf('/');
  return slash < 0 ? key : key.substring(0, slash);
}
