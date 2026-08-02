/// Component registry.
///
/// Port of `components/component-registry.ts`.
library;

import '../state/block_kinds.dart';
import 'component_definition.dart';
import 'document.dart';
import 'footnote_body.dart';
import 'heading.dart';
import 'horizontal_line.dart';
import 'image.dart';
import 'list_item.dart';
import 'paragraph.dart';
import 'section.dart';
import 'table.dart';
import 'table_cell.dart';
import 'table_of_contents.dart';
import 'table_row.dart';
import 'template_body.dart';

abstract class ComponentRegistry implements BlockKindResolver {
  void register(ComponentDefinition def);
  ComponentDefinition? get(String type);
  bool has(String type);

  @override
  Kind? getBlockKind(String type);
}

class ComponentRegistryImpl implements ComponentRegistry {
  final Map<String, ComponentDefinition> _defs = {};

  @override
  void register(ComponentDefinition def) {
    _defs[def.type] = def;
  }

  @override
  ComponentDefinition? get(String type) => _defs[type];

  @override
  bool has(String type) => _defs.containsKey(type);

  @override
  Kind? getBlockKind(String type) {
    final def = _defs[type];
    if (def == null) return null;
    if (def.kind == 'container') return Kind.container;
    if (def is LeafComponentDefinition) {
      return def.leafShape == 'inline-bearing'
          ? Kind.inlineBearingLeaf
          : Kind.atomicLeaf;
    }
    return null;
  }
}

ComponentRegistry createComponentRegistry() {
  return ComponentRegistryImpl();
}

ComponentRegistry createDefaultComponentRegistry() {
  final reg = createComponentRegistry();
  // Containers
  reg.register(documentComponent);
  reg.register(sectionComponent);
  reg.register(templateBodyComponent);
  reg.register(footnoteBodyComponent);
  reg.register(tableComponent);
  reg.register(tableRowComponent);
  reg.register(tableCellComponent);
  // Leaves
  reg.register(paragraphComponent);
  reg.register(headingComponent);
  reg.register(listItemComponent);
  reg.register(imageComponent);
  reg.register(horizontalLineComponent);
  reg.register(tableOfContentsComponent);
  return reg;
}
