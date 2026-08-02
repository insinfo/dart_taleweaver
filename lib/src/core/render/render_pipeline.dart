library;

import '../cascade/cascade_pass.dart';
import '../components/component_registry.dart';
import '../state/state.dart';
import '../state/suggestions.dart';
import 'render.dart';
import 'render_node.dart';

RenderNode renderCascadedState(State state, ComponentRegistry registry,
    {SuggestionView suggestionView = SuggestionView.suggesting}) {
  return cascadePass(
      renderState(state, registry, suggestionView: suggestionView).root);
}

RenderNode renderCascadedIncremental(
    {required State state,
    required ComponentRegistry registry,
    required RenderNode? oldRender,
    required RenderNode? oldCascaded,
    SuggestionView suggestionView = SuggestionView.suggesting}) {
  final next =
      renderState(state, registry, suggestionView: suggestionView).root;
  return cascadePassIncremental(next, oldRender, oldCascaded);
}
