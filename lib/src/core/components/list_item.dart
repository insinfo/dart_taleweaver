/// List item component.
///
/// Port of `components/list-item.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/format_counter.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

const double baseListIndent = 30.0;
const double levelStep = 30.0;

final Set<String> _bulletGlyphs = {
  formatCounter(1, 'disc'),
  formatCounter(1, 'circle'),
  formatCounter(1, 'square'),
};

class ListItemComponent implements LeafComponentDefinition {
  @override
  final String type = 'list-item';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'inline-bearing';
  @override
  final String? splitFollowOnType = null;

  const ListItemComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final levelRaw = view.attrs['listLevel'];
    final level = (levelRaw is num && levelRaw.isFinite && levelRaw > 0)
        ? levelRaw.floor()
        : 0;

    final listIdRaw = view.attrs['listId'];
    final listId = listIdRaw is String ? listIdRaw : '';

    final counter = context.counterValue(listId, view.id);
    String? markerText;
    bool? ordered;

    if (counter != null) {
      final isBullet = _bulletGlyphs.contains(counter.formatted);
      markerText = isBullet ? counter.formatted : '${counter.formatted}.';
      ordered = !isBullet;
    }

    final writingMode = writingModeFromAttrs(view.attrs['writingMode']);
    final language = langFromAttrs(view.attrs['lang']);
    final textAlign = textAlignFromAttrs(view.attrs['textAlign']);
    final lineHeight = lineHeightFromAttrs(view.attrs['lineHeight']);
    final marginInlineStart =
        marginInlineStartFromAttrs(view.attrs['marginInlineStart']);
    final marginBlockStart =
        marginBlockStartFromAttrs(view.attrs['marginBlockStart']);
    final marginBlockEnd =
        marginBlockEndFromAttrs(view.attrs['marginBlockEnd']);
    final tabStops = tabStopsFromAttrs(view.attrs['tabStops']);

    final style = Style(
      display: Display.listItem,
      paddingInlineStart: Length.px(baseListIndent + level * levelStep),
      markerText: markerText,
      writingMode: writingMode,
      language: language,
      textAlign: textAlign,
      lineHeight: lineHeight,
      tabStops: tabStops,
      marginInlineStart: marginInlineStart != null
          ? LengthOrAuto.length(Length.px(marginInlineStart))
          : null,
      marginBlockStart: marginBlockStart != null
          ? LengthOrAuto.length(Length.px(marginBlockStart))
          : null,
      marginBlockEnd: marginBlockEnd != null
          ? LengthOrAuto.length(Length.px(marginBlockEnd))
          : null,
    );

    return createElementBox(
      view.id.value,
      style,
      inlineRenderNodes,
      ordered != null
          ? LayoutBoxMetadata(
              list:
                  ListMetadata(level: level, listId: listId, ordered: ordered))
          : null,
    );
  }
}

const listItemComponent = ListItemComponent();
