/// Property metadata and initial computed style.
///
/// Port of `styles/property-meta.ts`.
library;

import 'computed_style.dart';
import 'length.dart';
import 'position.dart';
import 'style.dart';
import 'writing_mode.dart';

class PropertyMeta {
  final bool inherits;
  const PropertyMeta({required this.inherits});
}

const emptyTransform = <TransformFn>[];
const centerLength = ComputedLength.percent(50);
const centerTransformOrigin = TransformOrigin(x: Length.percent(50), y: Length.percent(50));

const propertyMeta = <String, PropertyMeta>{
  'display':         PropertyMeta(inherits: false),

  'writingMode':     PropertyMeta(inherits: true),
  'direction':       PropertyMeta(inherits: true),

  'inlineSize':      PropertyMeta(inherits: false),
  'blockSize':       PropertyMeta(inherits: false),
  'minInlineSize':   PropertyMeta(inherits: false),
  'minBlockSize':    PropertyMeta(inherits: false),
  'maxInlineSize':   PropertyMeta(inherits: false),
  'maxBlockSize':    PropertyMeta(inherits: false),
  'boxSizing':       PropertyMeta(inherits: false),

  'marginBlockStart':  PropertyMeta(inherits: false),
  'marginBlockEnd':    PropertyMeta(inherits: false),
  'marginInlineStart': PropertyMeta(inherits: false),
  'marginInlineEnd':   PropertyMeta(inherits: false),

  'paddingBlockStart':  PropertyMeta(inherits: false),
  'paddingBlockEnd':    PropertyMeta(inherits: false),
  'paddingInlineStart': PropertyMeta(inherits: false),
  'paddingInlineEnd':   PropertyMeta(inherits: false),

  'borderBlockStartWidth':  PropertyMeta(inherits: false),
  'borderBlockEndWidth':    PropertyMeta(inherits: false),
  'borderInlineStartWidth': PropertyMeta(inherits: false),
  'borderInlineEndWidth':   PropertyMeta(inherits: false),
  'borderBlockStartStyle':  PropertyMeta(inherits: false),
  'borderBlockEndStyle':    PropertyMeta(inherits: false),
  'borderInlineStartStyle': PropertyMeta(inherits: false),
  'borderInlineEndStyle':   PropertyMeta(inherits: false),
  'borderBlockStartColor':  PropertyMeta(inherits: false),
  'borderBlockEndColor':    PropertyMeta(inherits: false),
  'borderInlineStartColor': PropertyMeta(inherits: false),
  'borderInlineEndColor':   PropertyMeta(inherits: false),

  'backgroundColor': PropertyMeta(inherits: false),

  'fontFamily':     PropertyMeta(inherits: true),
  'fontSize':       PropertyMeta(inherits: true),
  'fontWeight':     PropertyMeta(inherits: true),
  'fontStyle':      PropertyMeta(inherits: true),
  'underline':      PropertyMeta(inherits: false),
  'lineThrough':    PropertyMeta(inherits: false),
  'lineHeight':     PropertyMeta(inherits: true),
  'color':          PropertyMeta(inherits: true),

  'whiteSpace':    PropertyMeta(inherits: true),
  'verticalAlign': PropertyMeta(inherits: false),

  'textAlign':           PropertyMeta(inherits: true),
  'textIndent':          PropertyMeta(inherits: true),
  'textWrap':            PropertyMeta(inherits: true),
  'hyphens':             PropertyMeta(inherits: true),
  'language':            PropertyMeta(inherits: true),
  'hyphenateLimitChars': PropertyMeta(inherits: true),
  'overflowWrap':        PropertyMeta(inherits: true),
  'letterSpacing':       PropertyMeta(inherits: true),
  'wordSpacing':         PropertyMeta(inherits: true),
  'textTransform':       PropertyMeta(inherits: true),
  'fontFeatureSettings': PropertyMeta(inherits: true),
  'tabStops':            PropertyMeta(inherits: false),
  'defaultTabStop':      PropertyMeta(inherits: true),

  'float': PropertyMeta(inherits: false),
  'clear': PropertyMeta(inherits: false),

  'breakBefore': PropertyMeta(inherits: false),
  'breakAfter':  PropertyMeta(inherits: false),
  'breakInside': PropertyMeta(inherits: false),

  'widows':  PropertyMeta(inherits: true),
  'orphans': PropertyMeta(inherits: true),

  'listStyleType':     PropertyMeta(inherits: true),
  'listStylePosition': PropertyMeta(inherits: true),

  'markerText':        PropertyMeta(inherits: false),

  'position':         PropertyMeta(inherits: false),
  'insetBlockStart':  PropertyMeta(inherits: false),
  'insetBlockEnd':    PropertyMeta(inherits: false),
  'insetInlineStart': PropertyMeta(inherits: false),
  'insetInlineEnd':   PropertyMeta(inherits: false),
  'zIndex':           PropertyMeta(inherits: false),
  'transform':        PropertyMeta(inherits: false),
  'transformOrigin':  PropertyMeta(inherits: false),
  'opacity':          PropertyMeta(inherits: false),
};

final initialComputedStyle = ComputedStyle(
  display: Display.inline,

  writingMode: WritingMode.horizontalTb,
  direction: Direction.ltr,

  inlineSize: const ComputedLengthOrAuto.auto(),
  blockSize: const ComputedLengthOrAuto.auto(),
  minInlineSize: const ComputedPxLength(0),
  minBlockSize: const ComputedPxLength(0),
  maxInlineSize: 'none',
  maxBlockSize: 'none',
  boxSizing: BoxSizing.contentBox,

  marginBlockStart: const ComputedLengthValue(ComputedPxLength(0)), // wait, it's 0 in TS, meaning px
  marginBlockEnd: const ComputedLengthValue(ComputedPxLength(0)),
  marginInlineStart: const ComputedLengthValue(ComputedPxLength(0)),
  marginInlineEnd: const ComputedLengthValue(ComputedPxLength(0)),

  paddingBlockStart: const ComputedPxLength(0),
  paddingBlockEnd: const ComputedPxLength(0),
  paddingInlineStart: const ComputedPxLength(0),
  paddingInlineEnd: const ComputedPxLength(0),

  borderBlockStartWidth: 0,
  borderBlockEndWidth: 0,
  borderInlineStartWidth: 0,
  borderInlineEndWidth: 0,
  borderBlockStartStyle: BorderStyle.none,
  borderBlockEndStyle: BorderStyle.none,
  borderInlineStartStyle: BorderStyle.none,
  borderInlineEndStyle: BorderStyle.none,
  borderBlockStartColor: 'currentColor',
  borderBlockEndColor: 'currentColor',
  borderInlineStartColor: 'currentColor',
  borderInlineEndColor: 'currentColor',

  backgroundColor: 'transparent',

  fontFamily: 'sans-serif',
  fontSize: 16,
  fontWeight: FontWeight.normal,
  fontStyle: FontStyle.normal,
  underline: false,
  lineThrough: false,
  lineHeight: 1.2,
  color: '#000',

  whiteSpace: WhiteSpace.normal,
  verticalAlign: VerticalAlign.baseline,

  textAlign: TextAlign.start,
  textIndent: const ComputedPxLength(0),
  textWrap: TextWrap.wrap,
  hyphens: Hyphens.manual,
  language: '',
  hyphenateLimitChars: const [5, 2, 2],
  overflowWrap: OverflowWrap.normal,
  letterSpacing: 'normal',
  wordSpacing: 'normal',
  textTransform: TextTransform.none,
  fontFeatureSettings: const [],
  tabStops: const [],
  defaultTabStop: 48,

  float: Float.none,
  clear: Clear.none,

  breakBefore: BreakBefore.auto,
  breakAfter: BreakAfter.auto,
  breakInside: BreakInside.auto,

  widows: 2,
  orphans: 2,

  listStyleType: ListStyleType.disc,
  listStylePosition: ListStylePosition.outside,

  markerText: null,

  position: Position.staticPosition,
  insetBlockStart: 'auto',
  insetBlockEnd: 'auto',
  insetInlineStart: 'auto',
  insetInlineEnd: 'auto',
  zIndex: 'auto',
  transform: emptyTransform,
  transformOrigin: centerTransformOrigin,
  opacity: 1,
);
