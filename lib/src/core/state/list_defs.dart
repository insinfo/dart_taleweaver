/// List definitions.
///
/// Port of `list-defs.ts`.
library;

import 'state.dart';
import 'tw_doc.dart';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Per-level numbering configuration for a list.
class ListLevelConfig {
  final String style;
  final int start;
  final String restart;

  const ListLevelConfig({
    required this.style,
    required this.start,
    required this.restart,
  });
}

/// Per-list numbering config: one entry per nesting level.
class ListDef {
  final List<ListLevelConfig> levels;

  const ListDef({required this.levels});
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _bulletStyles = <String>{'disc', 'circle', 'square'};

// ---------------------------------------------------------------------------
// Classification
// ---------------------------------------------------------------------------

/// Classify a list def as 'ordered' or 'unordered' by its level-0 marker style.
String classifyListDef(ListDef def) {
  if (def.levels.isEmpty) return 'ordered';
  final style = def.levels[0].style;
  return _bulletStyles.contains(style) ? 'unordered' : 'ordered';
}

// ---------------------------------------------------------------------------
// State Access
// ---------------------------------------------------------------------------

/// All list defs as a plain Map, resolved from a State.
Map<String, ListDef> getListDefsForState(State state) {
  final out = <String, ListDef>{};
  for (final entry in state.doc.listDefs.entries) {
    final listId = entry.key;
    final map = entry.value;
    final levelsRaw = map['levels'] as List?;
    if (levelsRaw != null) {
      final levels = <ListLevelConfig>[];
      for (final raw in levelsRaw) {
        if (raw is Map) {
          levels.add(ListLevelConfig(
            style: raw['style'] as String? ?? 'decimal',
            start: raw['start'] as int? ?? 1,
            restart: raw['restart'] as String? ?? 'none',
          ));
        }
      }
      out[listId] = ListDef(levels: levels);
    }
  }
  return out;
}

/// Write a list definition in the current transaction.
void writeListDefInTx(TwDoc doc, String listId, ListDef def) {
  doc.listDefs[listId] = {
    'levels': def.levels.map((l) => {
      'style': l.style,
      'start': l.start,
      'restart': l.restart,
    }).toList(),
  };
}
