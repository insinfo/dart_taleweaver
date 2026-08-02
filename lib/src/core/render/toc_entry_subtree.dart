/// Table of contents entry subtree builder.
///
/// Port of `render/toc-entry-subtree.ts`.
library;

import '../components/table_of_contents_attrs.dart';
import '../state/block_id.dart';
import '../state/ops/insert_cross_reference.dart';
import '../state/outline.dart';
import '../state/page_field.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import '../styles/tab_stops.dart';
import 'layout_metadata.dart';
import 'render_node.dart';

List<ElementBox> buildTocEntrySubtree(
  List<OutlineEntry> outline,
  TocAttrs attrs,
  BlockId tocId,
) {
  final levels = Set<int>.from(attrs.levels);
  final boxes = <ElementBox>[];

  int i = 0;
  for (final entry in outline) {
    if (!levels.contains(entry.level)) continue;

    final headingId = entry.blockId;
    final level = entry.level;
    final text = entry.text;

    final entryKey = '${tocId.value}/entry/$i';

    final textRun = createTextBox('$entryKey/text', {}, text);

    final style = Style(
      display: Display.block,
      marginInlineStart: Length.px((level - 1) * attrs.indentStep.toDouble()),
      tabStops: attrs.showPageNumbers
          ? [
              TabStop(
                position: const Length.px(0),
                alignment: TabAlignment.contentEdge,
                leader: attrs.leader,
              )
            ]
          : null,
    );

    final children = attrs.showPageNumbers
        ? [textRun, _buildTabBox(entryKey), _buildPageAtom(tocId, i, headingId)]
        : [textRun];

    boxes.add(createElementBox(
      entryKey,
      style,
      children,
      LayoutBoxMetadata(
        tocEntry: true,
        navTarget: headingId.value,
      ),
    ));

    i++;
  }

  return boxes;
}

ElementBox _buildTabBox(String entryKey) {
  return createElementBox(
    '$entryKey/tab',
    const Style(display: Display.inlineBlock, inlineSize: Length.px(0)),
    [],
    LayoutBoxMetadata(embedType: 'tab'),
  );
}

ElementBox _buildPageAtom(BlockId tocId, int i, BlockId headingId) {
  final atomKey = '${tocId.value}/toc/$i';
  return createElementBox(
    atomKey,
    const Style(display: Display.inlineBlock),
    [createTextBox('$atomKey/0', {}, '0' * pageFieldReservedGlyphs)],
    LayoutBoxMetadata(
      embedType: crossReferenceEmbedType,
      refMode: 'page',
      targetId: headingId.value,
      numberStyle: 'decimal',
    ),
  );
}
