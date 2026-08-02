/// Bounded width convergence for layout-dependent page fields.
///
/// The driver is deliberately pure control flow. A caller supplies a layout
/// pass that receives reservation overrides and reports the page count plus
/// the widest resolved value for each field. Reservations only grow, so the
/// result is safe even when the page count changes after a template wraps.
library;

import '../../render/render_node.dart';
import '../../state/page_field.dart';

const int maxFieldConvergenceIterations = 5;
const double fieldWidthEpsilon = 0.01;

class ConvergenceField {
  final String embedKey;
  final double reservedWidth;

  const ConvergenceField(this.embedKey, this.reservedWidth);
}

/// Extracts page-field placeholders from a rendered template tree.
///
/// Keys are stable inline render keys (`block/inline/index`), matching the
/// identity used by the TypeScript field-convergence driver.
List<ConvergenceField> collectPageFields(RenderNode root,
    {double reservedWidth = 2.0}) {
  final result = <ConvergenceField>[];
  void visit(RenderNode node) {
    if (node is ElementBox) {
      final metadata = node.metadata;
      if (metadata?.embedType == pageFieldEmbedType &&
          isPageFieldKind(metadata?.fieldKind)) {
        result.add(ConvergenceField(node.key, reservedWidth));
      }
      for (final child in node.children) visit(child);
    }
  }

  visit(root);
  return result;
}

class ConvergenceIteration {
  final int pageCount;
  final Map<String, double> maxValueWidthByKey;

  ConvergenceIteration(this.pageCount, Map<String, double> widths)
      : maxValueWidthByKey = Map.unmodifiable(widths);
}

class FieldConvergenceOutcome<T extends ConvergenceIteration> {
  final T result;
  final Map<String, double> grownWidths;
  final int iterations;
  final bool converged;

  FieldConvergenceOutcome({
    required this.result,
    required Map<String, double> grownWidths,
    required this.iterations,
    required this.converged,
  }) : grownWidths = Map.unmodifiable(grownWidths);
}

Map<String, double>? _growReservations(List<ConvergenceField> fields,
    Map<String, double> grownWidths, Map<String, double> measured) {
  var grew = false;
  final next = Map<String, double>.of(grownWidths);
  for (final field in fields) {
    final reserved = grownWidths[field.embedKey] ?? field.reservedWidth;
    final needed = measured[field.embedKey] ?? 0;
    if (needed > reserved + fieldWidthEpsilon) {
      next[field.embedKey] = needed;
      grew = true;
    }
  }
  return grew ? next : null;
}

FieldConvergenceOutcome<T> runFieldConvergence<T extends ConvergenceIteration>(
    List<ConvergenceField> fields,
    T Function(Map<String, double> grownWidths) runIteration,
    {int maxIterations = maxFieldConvergenceIterations}) {
  final cap = maxIterations < 1 ? 1 : maxIterations;
  final seenCounts = <int>{};
  var grownWidths = <String, double>{};
  var result = runIteration(grownWidths);
  var iterations = 1;
  var converged = false;

  while (iterations < cap) {
    final grown =
        _growReservations(fields, grownWidths, result.maxValueWidthByKey);
    if (grown == null) {
      converged = true;
      break;
    }
    final pinned = seenCounts.contains(result.pageCount);
    seenCounts.add(result.pageCount);
    grownWidths = grown;
    result = runIteration(grownWidths);
    iterations++;
    if (pinned) break;
  }

  return FieldConvergenceOutcome(
      result: result,
      grownWidths: grownWidths,
      iterations: iterations,
      converged: converged);
}
