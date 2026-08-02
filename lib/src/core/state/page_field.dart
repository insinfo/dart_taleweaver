/// Page field types and constants.
///
/// Port of `page-field.ts`.
library;

const String pageFieldEmbedType = 'page-field';

const int pageFieldReservedGlyphs = 2;

const _pageFieldKinds = {'page-number', 'page-count'};

const _pageFieldNumberStyles = {
  'decimal',
  'lower-alpha',
  'upper-alpha',
  'lower-roman',
  'upper-roman',
};

bool isPageFieldNumberStyle(dynamic value) {
  return value is String && _pageFieldNumberStyles.contains(value);
}

bool isPageFieldKind(dynamic value) {
  return value is String && _pageFieldKinds.contains(value);
}
