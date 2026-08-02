library;

import '../state/block_position.dart';

typedef CaretAffinity = String;

bool isCollapsedSelection(Selection selection) => isCollapsed(selection);

bool cursorSelectionsEqual(Selection a, Selection b) =>
    (positionsEqual(a.anchor, b.anchor) && positionsEqual(a.focus, b.focus)) ||
    (positionsEqual(a.anchor, b.focus) && positionsEqual(a.focus, b.anchor));
