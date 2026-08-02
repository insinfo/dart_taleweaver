library;

import '../components/component_definition.dart';
import '../components/component_registry.dart';
import '../state/inline_content.dart';
import '../state/block_id.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import '../numbering/types.dart';
import '../styles/property_meta.dart';
import '../styles/style.dart';
import 'block_view.dart';
import 'render_node.dart';

class RenderOutput {
  final RenderNode root;
  const RenderOutput(this.root);
}

class _RenderContext implements RenderContext {
  @override
  final State state;
  @override
  final SuggestionView suggestionView;
  const _RenderContext(this.state, this.suggestionView);

  @override
  String? footnoteNumber(dynamic contentBlockId) => null;

  @override
  CounterValue? counterValue(String scopeKey, BlockId blockId) => null;
}

RenderOutput renderState(State state, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting}) {
  final context = _RenderContext(state, suggestionView);
  return RenderOutput(_renderBlock(state, state.rootId, registry, context));
}

RenderNode _renderBlock(State state, dynamic id, ComponentRegistry registry,
    _RenderContext context) {
  final block = getBlock(state, id);
  if (block == null) throw StateError('render: block "$id" not found');
  final definition = registry.get(block.type);
  if (definition == null)
    throw StateError('render: unknown block type "${block.type}"');
  final children = <RenderNode>[];
  if (block.firstChildId != null) {
    var child = getBlock(state, block.firstChildId!);
    while (child != null) {
      children.add(_renderBlock(state, child.id, registry, context));
      child = child.nextSiblingId == null
          ? null
          : getBlock(state, child.nextSiblingId!);
    }
  }
  if (block.inlineContent != null) {
    for (var index = 0; index < block.inlineContent!.items.length; index++) {
      final item = block.inlineContent!.items[index];
      if (!itemVisibleInView(item, context.suggestionView)) continue;
      if (item is TextItem) {
        children.add(createTextBox('${block.id.value}/inline/$index',
            const Style(), item.text, item.attrs['link'] as String?));
      } else if (item is EmbedItem) {
        children.add(createElementBox(
            '${block.id.value}/inline/$index', const Style(), const []));
      }
    }
  }
  final viewStyle = initialComputedStyle;
  if (definition is ContainerComponentDefinition) {
    return definition.render(
        ContainerBlockView(
            id: block.id,
            type: block.type,
            attrs: block.attrs,
            computedStyle: viewStyle),
        context,
        children);
  }
  if (definition is LeafComponentDefinition) {
    return definition.render(
        LeafBlockView(
            id: block.id,
            type: block.type,
            attrs: block.attrs,
            computedStyle: viewStyle,
            inlineContent: block.inlineContent ?? InlineContent.empty),
        context,
        children);
  }
  throw StateError('render: unsupported component definition');
}
