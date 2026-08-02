library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'layout/layout_box.dart';
import 'layout/page_box.dart';
import 'canvas_export.dart';
import '../styles/computed_style.dart';
import '../state/block_position.dart';
import 'cursor/hit_test.dart';

class MatchHighlightRect extends SelectionRect {
  final bool active;
  const MatchHighlightRect(super.x, super.y, super.width, super.height,
      {this.active = false});
}

class CommentHighlightRect extends SelectionRect {
  final String commentId;
  final bool active;
  const CommentHighlightRect(super.x, super.y, super.width, super.height,
      {required this.commentId, this.active = false});
}

class SuggestionHighlightRect extends SelectionRect {
  final String suggestionId;
  final bool active;
  const SuggestionHighlightRect(super.x, super.y, super.width, super.height,
      {required this.suggestionId, this.active = false});
}

const matchHighlightFill = 'rgba(255, 213, 0, 0.40)';
const activeMatchHighlightFill = 'rgba(255, 138, 0, 0.55)';
const commentHighlightFill = 'rgba(255, 199, 110, 0.35)';
const activeCommentHighlightFill = 'rgba(255, 167, 38, 0.55)';
const suggestionHighlightFill = 'rgba(45, 178, 168, 0.30)';
const activeSuggestionHighlightFill = 'rgba(20, 150, 140, 0.50)';

/// Exports a canvas using the browser's native encoder.
String canvasToDataUrl(web.HTMLCanvasElement canvas,
    {String format = 'image/png', double? quality}) {
  final type = validateCanvasImageFormat(format);
  return quality == null
      ? canvas.toDataURL(type)
      : canvas.toDataURL(type, quality.toJS);
}

/// Exports a canvas as a browser [Blob]. A null result is preserved when the
/// browser encoder declines the conversion.
Future<web.Blob?> canvasToBlob(web.HTMLCanvasElement canvas,
    {String format = 'image/png', double? quality}) {
  final type = validateCanvasImageFormat(format);
  final completer = Completer<web.Blob?>();
  final callback = ((web.Blob? blob) {
    if (!completer.isCompleted) completer.complete(blob);
  }).toJS;
  if (quality == null) {
    canvas.toBlob(callback, type);
  } else {
    canvas.toBlob(callback, type, quality.toJS);
  }
  return completer.future;
}

/// Per-renderer image element cache. The browser adapter can await image
/// loading and repaint once [HTMLImageElement.complete] becomes true.
class CanvasImageCache {
  final Map<String, web.HTMLImageElement> _images = {};
  final Map<String, List<void Function()>> _listeners = {};

  web.HTMLImageElement? getOrCreate(web.Document document, String src) {
    if (src.isEmpty) return null;
    return _images.putIfAbsent(src, () {
      final image = document.createElement('img') as web.HTMLImageElement;
      image.addEventListener(
          'load',
          ((web.Event _) {
            final listeners =
                _listeners.remove(src) ?? const <void Function()>[];
            for (final listener in List<void Function()>.of(listeners)) {
              listener();
            }
          }).toJS);
      image.addEventListener(
          'error',
          ((web.Event _) {
            // Keep the failed image cached, but release callbacks so a
            // permanently bad source cannot accumulate repaint listeners.
            _listeners.remove(src);
          }).toJS);
      image.src = src;
      return image;
    });
  }

  bool contains(String src) => _images.containsKey(src);

  /// Registers a repaint callback for an image that is not loaded yet.
  /// Returns immediately when the cached image is already complete.
  void onLoaded(String src, web.Document document, void Function() listener) {
    if (src.isEmpty) return;
    final image = getOrCreate(document, src);
    if (image == null) return;
    if (image.complete) {
      listener();
    } else {
      _listeners.putIfAbsent(src, () => []).add(listener);
    }
  }

  void clear() {
    _images.clear();
    _listeners.clear();
  }
}

void paintPage(web.CanvasRenderingContext2D context, PageBox page,
    {CanvasImageCache? imageCache,
    web.Document? document,
    Position? selectionAnchor,
    Position? selectionFocus,
    Position? caretPosition,
    Iterable<MatchHighlightRect> matchHighlights = const [],
    Iterable<CommentHighlightRect> commentHighlights = const [],
    Iterable<SuggestionHighlightRect> suggestionHighlights = const [],
    String selectionColor = 'rgba(80, 140, 255, 0.28)',
    String caretColor = '#1d4ed8'}) {
  context.save();
  try {
    _paintHighlightBand(context, suggestionHighlights, suggestionHighlightFill,
        activeSuggestionHighlightFill);
    _paintHighlightBand(context, commentHighlights, commentHighlightFill,
        activeCommentHighlightFill);
    _paintHighlightBand(
        context, matchHighlights, matchHighlightFill, activeMatchHighlightFill);
    if (selectionAnchor != null && selectionFocus != null) {
      context.save();
      context.fillStyle = selectionColor.toJS;
      for (final rect
          in selectionRectsForRange(page, selectionAnchor, selectionFocus)) {
        context.fillRect(rect.x, rect.y, rect.width, rect.height);
      }
      context.restore();
    }
    for (final child in _pageChildren(page)) {
      _paintBox(context, child, page.x, page.y,
          imageCache: imageCache, document: document);
    }
    if (caretPosition != null) {
      final caret = caretRectForPosition(page, caretPosition);
      if (caret != null) {
        context.save();
        context.fillStyle = caretColor.toJS;
        context.fillRect(caret.x, caret.y, 1, caret.height);
        context.restore();
      }
    }
  } finally {
    context.restore();
  }
}

void paintCanvas(web.HTMLCanvasElement canvas, Iterable<PageBox> pages,
    {CanvasImageCache? imageCache,
    web.Document? document,
    Position? selectionAnchor,
    Position? selectionFocus,
    Position? caretPosition,
    Iterable<MatchHighlightRect> matchHighlights = const [],
    Iterable<CommentHighlightRect> commentHighlights = const [],
    Iterable<SuggestionHighlightRect> suggestionHighlights = const [],
    String selectionColor = 'rgba(80, 140, 255, 0.28)',
    String caretColor = '#1d4ed8'}) {
  final context = canvas.getContext('2d');
  if (context is! web.CanvasRenderingContext2D) {
    throw StateError('CanvasRenderingContext2D is unavailable');
  }
  context.clearRect(0, 0, canvas.width.toDouble(), canvas.height.toDouble());
  for (final page in pages) {
    paintPage(context, page,
        imageCache: imageCache,
        document: document,
        selectionAnchor: selectionAnchor,
        selectionFocus: selectionFocus,
        caretPosition: caretPosition,
        matchHighlights: matchHighlights,
        commentHighlights: commentHighlights,
        suggestionHighlights: suggestionHighlights,
        selectionColor: selectionColor,
        caretColor: caretColor);
  }
}

void _paintHighlightBand(web.CanvasRenderingContext2D context,
    Iterable<SelectionRect> rects, String inactive, String active) {
  final values = List<SelectionRect>.of(rects);
  if (values.isEmpty) return;
  context.fillStyle = inactive.toJS;
  for (final rect in values) {
    if (rect is MatchHighlightRect && rect.active ||
        rect is CommentHighlightRect && rect.active ||
        rect is SuggestionHighlightRect && rect.active) {
      continue;
    }
    context.fillRect(rect.x, rect.y, rect.width, rect.height);
  }
  context.fillStyle = active.toJS;
  for (final rect in values) {
    if (rect is MatchHighlightRect && rect.active ||
        rect is CommentHighlightRect && rect.active ||
        rect is SuggestionHighlightRect && rect.active) {
      context.fillRect(rect.x, rect.y, rect.width, rect.height);
    }
  }
}

void _paintBox(web.CanvasRenderingContext2D context, LayoutBox box,
    double parentX, double parentY,
    {CanvasImageCache? imageCache, web.Document? document}) {
  final x = parentX + box.x;
  final y = parentY + box.y;
  final style = box.computedStyle;
  if (box is ImageBox && imageCache != null && document != null) {
    final image = imageCache.getOrCreate(document, box.src);
    if (image == null) return;
    if (image.complete) {
      context.drawImage(image, x, y, box.width, box.height);
    }
    return;
  }
  if (style is ComputedStyle &&
      style.backgroundColor.isNotEmpty &&
      style.backgroundColor != 'transparent') {
    context.fillStyle = style.backgroundColor.toJS;
    context.fillRect(x, y, box.width, box.height);
  }
  if (box is TextRunBox) {
    if (style is ComputedStyle) {
      context.fillStyle = style.color.toJS;
      final size = style.fontSize is num ? style.fontSize as num : 16;
      context.font = '${size}px ${style.fontFamily}';
    }
    context.fillText(box.text, x, y + box.height);
    return;
  }
  if (box is PageBox ||
      box is BlockBox ||
      box is LineBox ||
      box is TableBox ||
      box is TableRowBox ||
      box is TableCellBox) {
    final children = switch (box) {
      PageBox() => _pageChildren(box),
      BlockBox(:final children) => children,
      LineBox(:final children) => children,
      TableBox(:final children) => children,
      TableRowBox(:final children) => children,
      TableCellBox(:final children) => children,
      _ => const <LayoutBox>[],
    };
    for (final child in children) {
      _paintBox(context, child, x, y,
          imageCache: imageCache, document: document);
    }
    if (box is LineBox && box.endsWithHyphen) {
      if (style is ComputedStyle) {
        context.fillStyle = style.color.toJS;
        final size = style.fontSize is num ? style.fontSize as num : 16;
        context.font = '${size}px ${style.fontFamily}';
      }
      context.fillText(
          '-',
          x +
              box.width -
              (style is ComputedStyle
                  ? (style.fontSize is num ? (style.fontSize as num) * .5 : 8)
                  : 8),
          y + box.height);
    }
  }
}

/// Return body children plus a named slot when a caller supplied the modern
/// PageBox shape. Older pagination results still flatten slot children into
/// [PageBox.children], so identity checks avoid painting them twice.
List<LayoutBox> _pageChildren(PageBox page) {
  final result = <LayoutBox>[...page.children];
  for (final slot in [page.headerSlot, page.footerSlot, page.footnoteSlot]) {
    if (slot == null) continue;
    final flattened = slot.children.any(
        (child) => page.children.any((existing) => identical(existing, child)));
    if (!flattened) result.add(slot);
  }
  return result;
}
