/// Paragraph component.
///
/// Port of `components/paragraph.ts`.
library;

import '../render/block_view.dart';
import '../render/render_node.dart';
import '../styles/length.dart';
import '../styles/style.dart';
import 'component_definition.dart';
import 'leaf_style_attrs.dart';

bool _isWhiteSpace(dynamic value) {
  return value == 'normal' ||
      value == 'nowrap' ||
      value == 'pre' ||
      value == 'pre-wrap' ||
      value == 'pre-line' ||
      value == 'break-spaces';
}

WhiteSpace? _whiteSpaceFromAttrs(dynamic value) {
  if (_isWhiteSpace(value)) {
    if (value == 'normal') return WhiteSpace.normal;
    if (value == 'nowrap') return WhiteSpace.nowrap;
    if (value == 'pre') return WhiteSpace.pre;
    if (value == 'pre-wrap') return WhiteSpace.preWrap;
    if (value == 'pre-line') return WhiteSpace.preLine;
    if (value == 'break-spaces') return WhiteSpace.breakSpaces;
  }
  return null;
}

class ParagraphComponent implements LeafComponentDefinition {
  @override
  final String type = 'paragraph';
  @override
  final String kind = 'leaf';
  @override
  final String leafShape = 'inline-bearing';
  @override
  final String? splitFollowOnType = null;

  const ParagraphComponent();

  @override
  RenderNode render(
    covariant LeafBlockView view, // actually LeafBlockView, we use covariant if needed, but it's LeafBlockView in interface
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  ) {
    final whiteSpace = _whiteSpaceFromAttrs(view.attrs['whiteSpace']);
    final writingMode = writingModeFromAttrs(view.attrs['writingMode']);
    final language = langFromAttrs(view.attrs['lang']);
    final textAlign = textAlignFromAttrs(view.attrs['textAlign']);
    final lineHeight = lineHeightFromAttrs(view.attrs['lineHeight']);
    final marginInlineStart = marginInlineStartFromAttrs(view.attrs['marginInlineStart']);
    final marginBlockStart = marginBlockStartFromAttrs(view.attrs['marginBlockStart']);
    final marginBlockEnd = marginBlockEndFromAttrs(view.attrs['marginBlockEnd']);
    final tabStops = tabStopsFromAttrs(view.attrs['tabStops']);

    final style = Style(
      display: Display.block,
      marginBlockEnd: marginBlockEnd != null
          ? Length.px(marginBlockEnd)
          : const Length.em(0.5),
      whiteSpace: whiteSpace,
      writingMode: writingMode,
      language: language,
      textAlign: textAlign,
      lineHeight: lineHeight,
      tabStops: tabStops,
      marginInlineStart: marginInlineStart != null ? Length.px(marginInlineStart) : null,
      marginBlockStart: marginBlockStart != null ? Length.px(marginBlockStart) : null,
    );

    return createElementBox(view.id.value, style, inlineRenderNodes);
  }
}

const paragraphComponent = ParagraphComponent();
