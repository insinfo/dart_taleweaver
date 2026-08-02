/// Browser DOM mirror for the geometry-free accessibility tree.
library;

import 'package:web/web.dart' as web;

import '../url_safety.dart';
import 'accessibility.dart';

const String accessibilityBrokenCrossReferenceText =
    'Error! Reference source not found.';

/// Resolve virtual field runs without mutating the source accessibility tree.
AccessibilityNode resolveAccessibilityFields(
    AccessibilityNode node, Map<String, String> resolvedFields) {
  List<AccessibilityTextRun>? text;
  if (node.text != null) {
    text = <AccessibilityTextRun>[];
    for (final run in node.text!) {
      if (run.fieldKey == null) {
        text.add(run);
        continue;
      }
      final resolvedRun = AccessibilityTextRun(
        text: _resolveFieldText(run, resolvedFields),
        sourceOffsetStart: run.sourceOffsetStart,
        sourceOffsetEnd: run.sourceOffsetEnd,
        emphasis: run.emphasis,
        link: run.link,
        noteref: run.noteref,
        imageAlt: run.imageAlt,
        fieldKind: run.fieldKind,
        fieldKey: run.fieldKey,
        suggestion: run.suggestion,
        suggestionId: run.suggestionId,
        commentId: run.commentId,
        inComment: run.inComment,
      );
      text.add(resolvedRun);
    }
    if (text.length == node.text!.length &&
        List.generate(text.length, (i) => identical(text![i], node.text![i]))
            .every((same) => same)) {
      text = node.text;
    }
  }
  final children = <AccessibilityNode>[
    for (final child in node.children)
      resolveAccessibilityFields(child, resolvedFields),
  ];
  final childrenUnchanged = children.length == node.children.length &&
      List.generate(
              children.length, (i) => identical(children[i], node.children[i]))
          .every((same) => same);
  if (identical(text, node.text) && childrenUnchanged) return node;
  return AccessibilityNode(
    role: node.role,
    sourceBlockId: node.sourceBlockId,
    name: node.name,
    level: node.level,
    listOrdered: node.listOrdered,
    listOrdinal: node.listOrdinal,
    text: text,
    children: childrenUnchanged ? node.children : children,
  );
}

String _resolveFieldText(
    AccessibilityTextRun run, Map<String, String> resolvedFields) {
  final value = resolvedFields[run.fieldKey];
  if (value == null) return run.text;
  // Only the page-number cross-reference uses an unresolved-value placeholder
  // in the TypeScript mirror. Number/text modes are allowed to resolve to an
  // intentionally empty string (for example when the target has no label).
  if (value.isEmpty && run.fieldKind == 'cross-ref-page') {
    return accessibilityBrokenCrossReferenceText;
  }
  return value;
}

/// Build a detached, visually-hidden but assistive-technology-visible DOM
/// subtree. The caller owns mounting and reconciliation of the returned root.
web.Element buildAccessibilityDomMirror(
    AccessibilityNode node, web.Document document,
    {Map<String, String>? resolvedFields}) {
  final resolved = resolvedFields == null
      ? node
      : resolveAccessibilityFields(node, resolvedFields);
  return _buildElement(resolved, document);
}

web.Element _buildElement(AccessibilityNode node, web.Document document) {
  final element = switch (node.role) {
    AccessibilityRole.document => document.createElement('div'),
    AccessibilityRole.paragraph => document.createElement('p'),
    AccessibilityRole.list =>
      document.createElement(node.listOrdered == true ? 'ol' : 'ul'),
    AccessibilityRole.listitem => document.createElement('li'),
    AccessibilityRole.table => document.createElement('table'),
    AccessibilityRole.row => document.createElement('tr'),
    AccessibilityRole.cell => document.createElement('td'),
    AccessibilityRole.columnheader => document.createElement('th'),
    AccessibilityRole.heading => document.createElement(
        'h${node.level != null && node.level! >= 1 && node.level! <= 6 ? node.level : 1}'),
    AccessibilityRole.image => document.createElement('span'),
    AccessibilityRole.separator => document.createElement('hr'),
    AccessibilityRole.navigation => document.createElement('nav'),
    AccessibilityRole.banner => document.createElement('header'),
    AccessibilityRole.contentinfo => document.createElement('footer'),
    AccessibilityRole.footnote => document.createElement('section'),
  };

  switch (node.role) {
    case AccessibilityRole.document:
      element.setAttribute('role', 'document');
      element.setAttribute('style',
          'position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;padding:0;border:0');
    case AccessibilityRole.columnheader:
      element.setAttribute('scope', 'col');
    case AccessibilityRole.image:
      element.setAttribute('role', 'img');
      element.setAttribute('aria-label', node.name ?? '');
    case AccessibilityRole.navigation:
      if (node.name != null && node.name!.isNotEmpty) {
        element.setAttribute('aria-label', node.name!);
      }
    case AccessibilityRole.footnote:
      element.setAttribute('role', 'doc-footnote');
      if (node.sourceBlockId != null) {
        element.id = node.sourceBlockId!.value;
      }
    default:
      break;
  }
  if (node.role == AccessibilityRole.listitem && node.listOrdinal != null) {
    element.setAttribute('value', '${node.listOrdinal}');
  }
  if (node.sourceBlockId != null) {
    element.setAttribute('data-block-id', node.sourceBlockId!.value);
  }
  if (node.text != null) {
    for (final run in node.text!) {
      element.appendChild(_buildRun(run, document));
    }
  }
  for (final child in node.children) {
    element.appendChild(_buildElement(child, document));
  }
  return element;
}

web.Element _buildRun(AccessibilityTextRun run, web.Document document) {
  final web.Element wrapper;
  if (run.imageAlt != null) {
    wrapper = document.createElement('span');
    wrapper.setAttribute('role', 'img');
    wrapper.setAttribute('aria-label', run.imageAlt!);
  } else if (run.noteref != null) {
    wrapper = document.createElement('a');
    wrapper.setAttribute('role', 'doc-noteref');
    wrapper.setAttribute('href', '#${run.noteref!.value}');
  } else if (run.link != null) {
    wrapper = document.createElement('a');
    if (isExportSafeLinkUrl(run.link!)) {
      wrapper.setAttribute('href', run.link!);
    }
  } else if (run.suggestion == 'insertion') {
    wrapper = document.createElement('ins');
  } else if (run.suggestion == 'deletion') {
    wrapper = document.createElement('del');
  } else {
    wrapper = document.createElement('span');
  }
  wrapper.setAttribute('data-offset-start', '${run.sourceOffsetStart}');
  wrapper.setAttribute('data-offset-end', '${run.sourceOffsetEnd}');
  if (run.inComment) wrapper.setAttribute('data-in-comment', 'true');
  if (run.suggestion != null) {
    wrapper.setAttribute('data-suggestion', run.suggestion!);
    if (run.suggestionId != null) {
      wrapper.setAttribute('data-suggestion-id', run.suggestionId!);
    }
    wrapper.setAttribute(
        'aria-roledescription',
        run.suggestion == 'deletion'
            ? 'Suggested deletion'
            : 'Suggested insertion');
  }
  if (run.commentId != null) {
    wrapper.setAttribute('data-comment-id', run.commentId!);
  }
  if (run.fieldKind != null) {
    wrapper.setAttribute('data-field-kind', run.fieldKind!);
  }
  if (run.fieldKey != null) {
    wrapper.setAttribute('data-field-key', run.fieldKey!);
  }
  if (run.imageAlt == null) {
    web.Node inner = document.createTextNode(run.text);
    for (final emphasis in const [
      'strikethrough',
      'underline',
      'italic',
      'bold',
    ]) {
      if (!(run.emphasis?.contains(emphasis) ?? false)) continue;
      final tag = switch (emphasis) {
        'bold' => 'strong',
        'italic' => 'em',
        'underline' => 'u',
        _ => 's',
      };
      final element = document.createElement(tag);
      element.appendChild(inner);
      inner = element;
    }
    wrapper.appendChild(inner);
  }
  return wrapper;
}
