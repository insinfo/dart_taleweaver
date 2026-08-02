/// Walk the render tree and produce a new tree where every node carries
/// a populated `computedStyle`.
///
/// Port of `cascade/cascade-pass.ts`.
library;

import '../perf/perf_trace.dart';
import '../render/render_node.dart';
import '../styles/computed_style.dart';
import 'compose.dart';
import 'flatten_lengths.dart';

RenderNode cascadePass(RenderNode root) {
  final t = markStart('cascadePass');
  try {
    return _cascadeNode(root, null);
  } finally {
    markEnd('cascadePass', t);
  }
}

RenderNode _cascadeNode(RenderNode node, ComputedStyle? parentComputed) {
  final baseComputed = composeComputed(node.style, parentComputed);
  final computed = flattenLengths(baseComputed);

  if (node is TextBox) {
    return node.copyWith(computedStyle: computed);
  } else if (node is ElementBox) {
    final newChildren = node.children.map((c) => _cascadeNode(c, computed)).toList(growable: false);
    return node.copyWith(
      computedStyle: computed,
      children: newChildren,
    );
  }
  
  throw StateError('Unknown node type');
}

RenderNode cascadePassIncremental(
  RenderNode newRoot,
  RenderNode? oldRoot,
  RenderNode? oldCascadedRoot,
) {
  final t = markStart('cascadePassIncremental');
  try {
    return _cascadeNodeIncremental(newRoot, oldRoot, oldCascadedRoot, null, null);
  } finally {
    markEnd('cascadePassIncremental', t);
  }
}

RenderNode _cascadeNodeIncremental(
  RenderNode newNode,
  RenderNode? oldNode,
  RenderNode? oldCascaded,
  ComputedStyle? parentComputed,
  ComputedStyle? oldParentComputed,
) {
  if (oldNode != null &&
      oldCascaded != null &&
      identical(newNode, oldNode) &&
      identical(parentComputed, oldParentComputed)) {
    return oldCascaded;
  }

  final baseComputed = composeComputed(newNode.style, parentComputed);
  var computed = flattenLengths(baseComputed);

  final oldComputed = oldCascaded?.computedStyle;
  if (oldComputed != null && computedStylesEqual(computed, oldComputed)) {
    computed = oldComputed;
  }

  if (newNode is TextBox) {
    return newNode.copyWith(computedStyle: computed);
  } else if (newNode is ElementBox) {
    final oldChildren = (oldNode is ElementBox) ? oldNode.children : const <RenderNode>[];
    final oldCascadedChildren = (oldCascaded is ElementBox) ? oldCascaded.children : const <RenderNode>[];
    
    final oldByKey = <String, _OldNodes>{};
    for (var i = 0; i < oldChildren.length; i++) {
      if (i < oldCascadedChildren.length) {
        oldByKey[oldChildren[i].key] = _OldNodes(
          node: oldChildren[i],
          cascaded: oldCascadedChildren[i],
        );
      }
    }

    final oldComputedForRecurse = oldCascaded?.computedStyle;
    final newChildren = newNode.children.map((child) {
      final prev = oldByKey[child.key];
      return _cascadeNodeIncremental(
        child,
        prev?.node,
        prev?.cascaded,
        computed,
        oldComputedForRecurse,
      );
    }).toList(growable: false);

    return newNode.copyWith(
      computedStyle: computed,
      children: newChildren,
    );
  }

  throw StateError('Unknown node type');
}

class _OldNodes {
  final RenderNode node;
  final RenderNode cascaded;
  const _OldNodes({required this.node, required this.cascaded});
}

// In TS it uses a reflection-like walk of PROPERTY_META.
// In Dart we can just do equality checks on the fields. 
// Since our ComputedStyle class is an immutable struct, we just implement `==` on it.
bool computedStylesEqual(ComputedStyle a, ComputedStyle b) {
  return identical(a, b) || a == b;
}
