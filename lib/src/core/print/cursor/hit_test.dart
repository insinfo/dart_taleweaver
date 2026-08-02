library;

import '../../state/block_position.dart';
import '../layout/layout_box.dart';
import '../layout/page_box.dart';

Position? hitTestPage(PageBox page, double x, double y) {
  for (final child in page.children) {
    if (child is! LineBox || child.ownerBlockId == null) continue;
    final lineY = page.y + child.y;
    if (y < lineY || y > lineY + child.height) continue;
    for (final leaf in child.children) {
      if (leaf is! TextRunBox) continue;
      final left = page.x + child.x + leaf.x;
      final localX = (x - left).clamp(0, leaf.width);
      final units = leaf.text.isEmpty
          ? 0
          : (localX / leaf.width * leaf.offsetLength).round();
      return Position(
          blockId: child.ownerBlockId!,
          offset: units.clamp(0, leaf.offsetLength));
    }
    return Position(blockId: child.ownerBlockId!, offset: 0);
  }
  return null;
}
