/// Heading component.
///
/// Port of `components/heading.ts`.
library;

import '../render/block_view.dart';
import '../render/layout_metadata.dart';
import '../render/render_node.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

const Map<int, double> headingFontSizes = {
  1: 32.0,
  2: 28.0,
  3: 24.0,
  4: 20.0,
  5: 18.0,
  6: 16.0,
};

int _levelFromAttrs(dynamic level) {
  if (level == 1 ||
      level == 2 ||
      level == 3 ||
      level == 4 ||
      level == 5 ||
      level == 6) {
    return level as int;
  }
  return 1;
}

class HeadingComponent implements LeafComponentDefinition {
  @override
  final String type = 'heading';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'inline-bearing';
  @override
  final String? splitFollowOnType = 'paragraph';

  const HeadingComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final level = _levelFromAttrs(view.attrs['level']);
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
      display: Display.block,
      fontWeight: FontWeight.bold,
      fontSize: Length.px(headingFontSizes[level]!),
      marginBlockStart: marginBlockStart != null
          ? LengthOrAuto.length(Length.px(marginBlockStart))
          : LengthOrAuto.length(const Length.em(0.67)),
      marginBlockEnd: marginBlockEnd != null
          ? LengthOrAuto.length(Length.px(marginBlockEnd))
          : LengthOrAuto.length(const Length.em(0.67)),
      writingMode: writingMode,
      language: language,
      textAlign: textAlign,
      lineHeight: lineHeight,
      tabStops: tabStops,
      marginInlineStart: marginInlineStart != null
          ? LengthOrAuto.length(Length.px(marginInlineStart))
          : null,
    );

    return createElementBox(
      view.id.value,
      style,
      inlineRenderNodes,
      LayoutBoxMetadata(headingLevel: level),
    );
  }
}

const headingComponent = HeadingComponent();
