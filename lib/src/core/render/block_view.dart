/// Render-time view of a single block.
///
/// Port of `render/block-view.ts`.
library;

import '../numbering/types.dart';
import '../state/attrs.dart';
import '../state/block_id.dart';
import '../state/inline_content.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import '../styles/computed_style.dart';

abstract class BlockViewBase {
  BlockId get id;
  String get type;
  ReadonlyAttrs get attrs;
  ComputedStyle get computedStyle;
}

class ContainerBlockView implements BlockViewBase {
  final String kind = 'container';
  
  @override
  final BlockId id;
  @override
  final String type;
  @override
  final ReadonlyAttrs attrs;
  @override
  final ComputedStyle computedStyle;

  const ContainerBlockView({
    required this.id,
    required this.type,
    required this.attrs,
    required this.computedStyle,
  });
}

class LeafBlockView implements BlockViewBase {
  final String kind = 'leaf';
  
  @override
  final BlockId id;
  @override
  final String type;
  @override
  final ReadonlyAttrs attrs;
  @override
  final ComputedStyle computedStyle;
  
  final InlineContent inlineContent;

  const LeafBlockView({
    required this.id,
    required this.type,
    required this.attrs,
    required this.computedStyle,
    required this.inlineContent,
  });
}

typedef BlockView = BlockViewBase;

abstract class RenderContext {
  State get state;
  
  String? footnoteNumber(BlockId contentBlockId);
  CounterValue? counterValue(String scopeKey, BlockId blockId);
  
  SuggestionView get suggestionView;
}
