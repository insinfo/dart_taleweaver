/// Component definitions.
///
/// Port of `components/component-definition.ts`.
library;

import '../render/block_view.dart';
import '../render/render_node.dart';

abstract class ComponentDefinition {
  String get type;
  String get kind;
}

abstract class ContainerComponentDefinition implements ComponentDefinition {
  @override
  String get kind => 'container';

  RenderNode render(
    ContainerBlockView view,
    RenderContext context,
    List<RenderNode> childRenderNodes,
  );
}

abstract class LeafComponentDefinition implements ComponentDefinition {
  @override
  String get kind => 'leaf';
  
  String get leafShape; // "inline-bearing" | "atomic"
  String? get splitFollowOnType;

  RenderNode render(
    LeafBlockView view,
    RenderContext context,
    List<RenderNode> inlineRenderNodes,
  );
}
