/// JSON-safe properties shared by editable text boxes and simple shapes.
///
/// These values deliberately stay separate from CSS objects: document state
/// stores only strings and finite numbers, while components translate them to
/// render styles. That makes drawing blocks safe for JSON/binary persistence,
/// collaboration, and non-browser render backends.
library;

enum DrawingShapeKind {
  rectangle,
  ellipse,
  line;

  String get value => switch (this) {
        DrawingShapeKind.rectangle => 'rectangle',
        DrawingShapeKind.ellipse => 'ellipse',
        DrawingShapeKind.line => 'line',
      };

  static DrawingShapeKind? fromValue(dynamic value) => switch (value) {
        'rectangle' => DrawingShapeKind.rectangle,
        'ellipse' => DrawingShapeKind.ellipse,
        'line' => DrawingShapeKind.line,
        _ => null,
      };
}

enum DrawingAlignment {
  inlineStart,
  center,
  inlineEnd;

  String get value => switch (this) {
        DrawingAlignment.inlineStart => 'inline-start',
        DrawingAlignment.center => 'center',
        DrawingAlignment.inlineEnd => 'inline-end',
      };

  static DrawingAlignment? fromValue(dynamic value) => switch (value) {
        'inline-start' => DrawingAlignment.inlineStart,
        'center' => DrawingAlignment.center,
        'inline-end' => DrawingAlignment.inlineEnd,
        _ => null,
      };
}

/// Plain-data presentation values for an editable drawing block.
///
/// The persisted representation uses the keys emitted by [toJson]. Text is
/// intentionally not duplicated here: text-bearing drawings keep their text
/// in normal [InlineContent], so keyboard editing, comments and formatting
/// work exactly as they do in a paragraph.
class DrawingProperties {
  final double width;
  final double height;
  final DrawingAlignment alignment;
  final String fill;
  final String outline;
  final double outlineWidth;

  const DrawingProperties({
    required this.width,
    required this.height,
    required this.alignment,
    required this.fill,
    required this.outline,
    required this.outlineWidth,
  });

  static const textBoxDefaults = DrawingProperties(
    width: 180,
    height: 72,
    alignment: DrawingAlignment.inlineStart,
    fill: '#ffffff',
    outline: '#1f4e79',
    outlineWidth: 1,
  );

  static const rectangleDefaults = DrawingProperties(
    width: 160,
    height: 96,
    alignment: DrawingAlignment.inlineStart,
    fill: '#d9eaf7',
    outline: '#1f4e79',
    outlineWidth: 1,
  );

  static const ellipseDefaults = DrawingProperties(
    width: 144,
    height: 96,
    alignment: DrawingAlignment.inlineStart,
    fill: '#e7def7',
    outline: '#5d3f8c',
    outlineWidth: 1,
  );

  static const lineDefaults = DrawingProperties(
    width: 180,
    height: 18,
    alignment: DrawingAlignment.inlineStart,
    fill: 'transparent',
    outline: '#1f4e79',
    outlineWidth: 2,
  );

  static DrawingProperties defaultsFor(DrawingShapeKind kind) => switch (kind) {
        DrawingShapeKind.rectangle => rectangleDefaults,
        DrawingShapeKind.ellipse => ellipseDefaults,
        DrawingShapeKind.line => lineDefaults,
      };

  /// Reads tolerant imported data without ever passing a malformed CSS value
  /// to a renderer. Reducer-created documents are stricter and reject invalid
  /// actions before persistence.
  factory DrawingProperties.fromAttrs(
    Map<String, dynamic> attrs, {
    required DrawingProperties fallback,
  }) {
    double readDimension(String key, double defaultValue) {
      final value = attrs[key];
      if (value is num && isDrawingDimension(value)) return value.toDouble();
      return defaultValue;
    }

    double readOutlineWidth(double defaultValue) {
      final value = attrs['outlineWidth'];
      if (value is num && isDrawingOutlineWidth(value)) {
        return value.toDouble();
      }
      return defaultValue;
    }

    String readColor(String key, String defaultValue) {
      final value = attrs[key];
      return value is String && isSafeDrawingColor(value)
          ? value.trim()
          : defaultValue;
    }

    return DrawingProperties(
      width: readDimension('width', fallback.width),
      height: readDimension('height', fallback.height),
      alignment:
          DrawingAlignment.fromValue(attrs['alignment']) ?? fallback.alignment,
      fill: readColor('fill', fallback.fill),
      outline: readColor('outline', fallback.outline),
      outlineWidth: readOutlineWidth(fallback.outlineWidth),
    );
  }

  /// JSON primitives only; do not put a [DrawingProperties] instance in a
  /// block attrs map because the state serializers intentionally reject such
  /// host-only values.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'alignment': alignment.value,
        'fill': fill,
        'outline': outline,
        'outlineWidth': outlineWidth,
      };
}

bool isDrawingDimension(num value) =>
    value.isFinite && value > 0 && value <= 10000;

bool isDrawingOutlineWidth(num value) =>
    value.isFinite && value >= 0 && value <= 256;

/// Allows conventional CSS colors while refusing token separators, URLs, and
/// arbitrary declarations. This is especially important because the digital
/// renderer writes these values into an inline style attribute.
bool isSafeDrawingColor(String value) {
  final color = value.trim();
  if (color.isEmpty || color.length > 80) return false;
  return RegExp(
    r'^(?:transparent|none|currentColor|#[0-9a-fA-F]{3,8}|[A-Za-z]{1,32}|(?:rgb|rgba|hsl|hsla)\([0-9.,%+\-\s]+\))$',
  ).hasMatch(color);
}
