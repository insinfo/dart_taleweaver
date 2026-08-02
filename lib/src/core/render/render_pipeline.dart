library;

import '../cascade/cascade_pass.dart';
import '../components/component_registry.dart';
import '../state/state.dart';
import '../state/block_id.dart';
import '../state/suggestions.dart';
import 'render.dart';
import 'render_node.dart';

RenderNode renderCascadedState(State state, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting,
    Map<BlockId, int>? pageNumbers}) {
  return cascadePass(renderState(state, registry,
          suggestionView: suggestionView, pageNumbers: pageNumbers)
      .root);
}

/// Cascade a header/footer template body without traversing the main tree.
RenderNode renderCascadedTemplateBody(
    State state, BlockId bodyRootId, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting,
    Map<BlockId, int>? pageNumbers,
    int? pageNumber,
    int? pageCount}) {
  return cascadePass(renderTemplateBody(
    state,
    bodyRootId,
    registry,
    suggestionView: suggestionView,
    pageNumbers: pageNumbers,
    pageNumber: pageNumber,
    pageCount: pageCount,
  ).root);
}

RenderNode renderCascadedIncremental(
    {required State state,
    required ComponentRegistry registry,
    required RenderNode? oldRender,
    required RenderNode? oldCascaded,
    Set<BlockId>? dirtyIds,
    SuggestionView suggestionView = SuggestionView.suggesting,
    Map<BlockId, int>? pageNumbers}) {
  if (dirtyIds != null && dirtyIds.isEmpty && oldCascaded != null) {
    return oldCascaded;
  }
  final next = renderState(state, registry,
          suggestionView: suggestionView, pageNumbers: pageNumbers)
      .root;
  return cascadePassIncremental(next, oldRender, oldCascaded);
}
