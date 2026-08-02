/// Browser-independent canvas export format validation.
library;

const supportedCanvasImageFormats = {
  'image/png',
  'image/jpeg',
  'image/webp',
};

bool isSupportedCanvasImageFormat(String format) =>
    supportedCanvasImageFormats.contains(format);

String validateCanvasImageFormat(String format) {
  if (!isSupportedCanvasImageFormat(format)) {
    throw ArgumentError.value(
        format, 'format', 'expected image/png, image/jpeg, or image/webp');
  }
  return format;
}
