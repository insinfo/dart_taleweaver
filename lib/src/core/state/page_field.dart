/// Page field types and constants.
///
/// Port of `page-field.ts`.
library;

import '../styles/format_counter.dart';

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

/// Resolves a page field for a concrete one-based page and document count.
///
/// Layout producers call this late, after pagination has converged, so a
/// template body can be cloned without mutating the editor state. Invalid
/// values deliberately fall back to decimal, matching the insertion and
/// render contracts.
String resolvePageFieldText({
  required String fieldKind,
  required int pageNumber,
  required int pageCount,
  String numberStyle = 'decimal',
}) {
  final value = fieldKind == 'page-count' ? pageCount : pageNumber;
  final safeValue = value < 1 ? 1 : value;
  final style = isPageFieldNumberStyle(numberStyle) ? numberStyle : 'decimal';
  return formatCounter(safeValue, style);
}
