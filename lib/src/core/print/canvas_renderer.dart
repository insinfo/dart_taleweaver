library;

import 'package:web/web.dart' as web;

import 'layout/layout_box.dart';
import 'layout/page_box.dart';

void paintPage(web.CanvasRenderingContext2D context, PageBox page) {
  context.save();
  try {
    for (final child in page.children) {
      _paintBox(context, child, page.x, page.y);
    }
  } finally {
    context.restore();
  }
}

void paintCanvas(web.HTMLCanvasElement canvas, Iterable<PageBox> pages) {
  final context = canvas.getContext('2d');
  if (context is! web.CanvasRenderingContext2D) {
    throw StateError('CanvasRenderingContext2D is unavailable');
  }
  context.clearRect(0, 0, canvas.width.toDouble(), canvas.height.toDouble());
  for (final page in pages) {
    paintPage(context, page);
  }
}

void _paintBox(web.CanvasRenderingContext2D context, LayoutBox box,
    double parentX, double parentY) {
  final x = parentX + box.x;
  final y = parentY + box.y;
  if (box is TextRunBox) {
    context.fillText(box.text, x, y + box.height);
    return;
  }
  if (box is PageBox || box is BlockBox || box is LineBox) {
    final children = switch (box) {
      PageBox(:final children) => children,
      BlockBox(:final children) => children,
      LineBox(:final children) => children,
      _ => const <LayoutBox>[],
    };
    for (final child in children) {
      _paintBox(context, child, x, y);
    }
  }
}
