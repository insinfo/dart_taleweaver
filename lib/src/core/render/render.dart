library;

import '../components/component_definition.dart';
import '../components/component_registry.dart';
import '../state/inline_content.dart';
import '../state/page_field.dart';
import '../state/block.dart';
import '../state/block_id.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import '../state/ops/insert_cross_reference.dart';
import '../numbering/types.dart';
import '../numbering/list_collector.dart';
import '../state/list_defs.dart';
import '../styles/format_counter.dart';
import '../styles/property_meta.dart';
import '../styles/style.dart';
import 'block_view.dart';
import 'footnote_numbering.dart';
import 'layout_metadata.dart';
import 'render_node.dart';
import 'resolve_cross_reference.dart';

class RenderOutput {
  final RenderNode root;
  const RenderOutput(this.root);
}

class _RenderContext implements RenderContext {
  @override
  final State state;
  @override
  final SuggestionView suggestionView;
  late final Map<BlockId, CounterValue> _counters;
  late final Map<BlockId, String> _footnotes;
  final Map<BlockId, int>? pageNumbers;
  final int? pageNumber;
  final int? pageCount;

  _RenderContext(this.state, this.suggestionView, this.pageNumbers,
      {this.pageNumber, this.pageCount})
      : _counters = _buildCounters(state),
        _footnotes = buildFootnoteNumberIndex(state, pageByBlock: pageNumbers);

  @override
  String? footnoteNumber(dynamic contentBlockId) => _footnotes[
      contentBlockId is BlockId ? contentBlockId : BlockId('$contentBlockId')];

  @override
  CounterValue? counterValue(String scopeKey, BlockId blockId) =>
      _counters[blockId];
}

Map<BlockId, CounterValue> _buildCounters(State state) {
  final defs = getListDefsForState(state);
  final counters = <String, List<int>>{};
  final result = <BlockId, CounterValue>{};
  for (final event in collectListEvents(state)) {
    final levels = counters.putIfAbsent(event.scopeKey, () => <int>[]);
    while (levels.length <= event.level) levels.add(0);
    if (event.breakBefore) {
      for (var i = event.level; i < levels.length; i++) levels[i] = 0;
    }
    final value = event.override ?? (levels[event.level] + 1);
    levels[event.level] = value;
    for (var i = event.level + 1; i < levels.length; i++) levels[i] = 0;
    final def = defs[event.scopeKey];
    final style = def != null && event.level < def.levels.length
        ? def.levels[event.level].style
        : 'decimal';
    result[event.blockId] = CounterValue(
      value: value,
      formatted: formatCounter(value, style),
    );
  }
  return result;
}

RenderOutput renderState(State state, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting,
    Map<BlockId, int>? pageNumbers}) {
  final context = _RenderContext(state, suggestionView, pageNumbers);
  return RenderOutput(_renderBlock(state, state.rootId, registry, context));
}

/// Render a footnote body rooted in `embedContents`.
///
/// Footnote bodies are intentionally outside the main document traversal, so
/// callers that lay out footnotes can render them with the same component and
/// style context without accidentally including other embed trees.
RenderOutput renderFootnoteBody(
    State state, BlockId bodyRootId, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting}) {
  final context = _RenderContext(state, suggestionView, null);
  return RenderOutput(
      _renderTreeBlock(state, bodyRootId, registry, context, getEmbedContent));
}

/// Render a header/footer body rooted in `templateContents`.
///
/// The layout producer can reuse this output for either named PageBox slot;
/// keeping the tree traversal separate prevents template blocks from leaking
/// into the main document body.
RenderOutput renderTemplateBody(
    State state, BlockId bodyRootId, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting,
    Map<BlockId, int>? pageNumbers,
    int? pageNumber,
    int? pageCount}) {
  final context = _RenderContext(state, suggestionView, pageNumbers,
      pageNumber: pageNumber, pageCount: pageCount);
  return RenderOutput(_renderTreeBlock(
      state, bodyRootId, registry, context, getTemplateContent));
}

RenderNode _renderBlock(State state, dynamic id, ComponentRegistry registry,
    _RenderContext context) {
  return _renderTreeBlock(state, id, registry, context, getBlock);
}

RenderNode _renderTreeBlock(State state, dynamic id, ComponentRegistry registry,
    _RenderContext context, Block? Function(State, BlockId) readBlock) {
  final block = readBlock(state, id as BlockId);
  if (block == null) throw StateError('render: block "$id" not found');
  final definition = registry.get(block.type);
  if (definition == null)
    throw StateError('render: unknown block type "${block.type}"');
  final children = <RenderNode>[];
  if (block.firstChildId != null) {
    var child = readBlock(state, block.firstChildId!);
    while (child != null) {
      children
          .add(_renderTreeBlock(state, child.id, registry, context, readBlock));
      child = child.nextSiblingId == null
          ? null
          : readBlock(state, child.nextSiblingId!);
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
        final text = context.inlineEmbedText(item);
        children.add(text == null
            ? createElementBox(
                '${block.id.value}/inline/$index',
                const Style(),
                const [],
                LayoutBoxMetadata(
                    image: _inlineImageMetadata(item),
                    embedType: item.embedType,
                    fieldKind: item.properties['fieldKind'] as String?,
                    numberStyle: item.properties['numberStyle'] as String?,
                    refMode: item.properties['refMode'] as String?,
                    targetId: item.properties['targetId'] as String?))
            : createTextBox(
                '${block.id.value}/inline/$index', const Style(), text, null));
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

ImageMetadata? _inlineImageMetadata(EmbedItem item) {
  if (item.embedType != inlineImageEmbedType) return null;
  final src = item.properties['src'];
  final width = item.properties['width'];
  final height = item.properties['height'];
  if (src is! String || width is! num || height is! num) return null;
  final alt = item.properties['alt'];
  return ImageMetadata(
      src: src,
      width: width.toDouble(),
      height: height.toDouble(),
      alt: alt is String ? alt : null);
}

extension on _RenderContext {
  String? inlineEmbedText(EmbedItem item) {
    if (item.embedType == pageFieldEmbedType) {
      if (pageNumber == null || pageCount == null) return null;
      final kind = item.properties['fieldKind'];
      final style = item.properties['numberStyle'];
      if (kind is! String) return null;
      return resolvePageFieldText(
          fieldKind: kind,
          pageNumber: pageNumber!,
          pageCount: pageCount!,
          numberStyle: style is String ? style : 'decimal');
    }
    if (item.embedType != crossReferenceEmbedType) return null;
    final target = item.properties['targetId'];
    final mode = item.properties['refMode'];
    if (target is! String || mode is! String) return brokenCrossReferenceText;
    return resolveCrossReference(
      state,
      _counters,
      CrossReferenceProps(targetId: BlockId(target), refMode: mode),
      view: suggestionView,
      pageNumbers: pageNumbers,
    );
  }
}
