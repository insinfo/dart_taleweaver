import 'package:test/test.dart';
import 'package:taleweaver/src/core/state/page_field.dart';

void main() {
  test('page fields resolve one-based page and document values', () {
    expect(
        resolvePageFieldText(
            fieldKind: 'page-number', pageNumber: 3, pageCount: 12),
        '3');
    expect(
        resolvePageFieldText(
            fieldKind: 'page-count', pageNumber: 3, pageCount: 12),
        '12');
  });

  test('page fields share counter styles and fall back safely', () {
    expect(
        resolvePageFieldText(
            fieldKind: 'page-number',
            pageNumber: 4,
            pageCount: 9,
            numberStyle: 'upper-roman'),
        'IV');
    expect(
        resolvePageFieldText(
            fieldKind: 'page-number',
            pageNumber: 4,
            pageCount: 9,
            numberStyle: 'unknown'),
        '4');
  });
}
