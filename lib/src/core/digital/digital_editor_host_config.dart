/// Configuration and callbacks for a browser-backed digital editor surface.
library;

import 'package:web/web.dart' as web;

import '../cascade/attr_registry.dart';
import '../components/component_registry.dart';
import '../editor/editor_state.dart';
import '../state/block_id.dart';
import '../state/block_position.dart';
import '../state/suggestions.dart';

/// Called after the controller transitions to a new editor state.
typedef DigitalEditorHostStateCallback = void Function(EditorState state);

/// Called when the selection represented by the host changes.
typedef DigitalEditorHostSelectionCallback = void Function(Selection selection);

/// Optional lifecycle callback for the editor's actual contenteditable surface.
typedef DigitalEditorHostSurfaceCallback = void Function(
    web.HTMLElement surface);

/// Browser-only options for [DigitalEditorHost].
///
/// This intentionally contains no toolbar, ruler, pagination, or styling
/// decisions.  It is the small DOM boundary that a Dart, AngularDart, or JS
/// application can mount inside its own UI.
class DigitalEditorHostConfig {
  /// Components used to render the document. Defaults to the built-in registry.
  final ComponentRegistry? componentRegistry;

  /// Attribute interpreters used to render the document. Defaults to built-ins.
  final AttrRegistry? attrRegistry;

  /// Core editor options used if [DigitalEditorHost.mount] creates a controller.
  final EditorConfig editorConfig;

  /// Initial controller state used when the caller does not pass a controller.
  final EditorState? initialEditorState;

  /// The document used for DOM creation and `selectionchange` observation.
  ///
  /// `mount`'s explicit `document` argument takes precedence, followed by the
  /// owner document of the mount container.
  final web.Document? document;

  /// The window supplying the browser Selection API.
  final web.Window? window;

  /// Optional template-body root from `State.templateContents` to render.
  ///
  /// Supplying this turns the host into an editable header/footer surface that
  /// shares its [DigitalEditorController] with the main document host.
  final BlockId? templateBodyId;

  /// Concrete field values used while rendering a template surface.
  final int templatePageNumber;
  final int templatePageCount;

  /// Whether the surface is a selectable read-only viewer.
  final bool readOnly;

  /// Projection to use for tracked changes.
  final SuggestionView suggestionView;

  /// Optional class placed on the generated contenteditable surface.
  final String? surfaceClassName;

  /// Optional accessible name placed on the generated surface.
  final String? ariaLabel;

  /// Extra attributes placed on the generated surface.
  ///
  /// `contenteditable`, `role`, `aria-multiline`, and `aria-readonly` remain
  /// host-owned and are refreshed whenever [DigitalEditorHost.setReadOnly] is
  /// called.
  final Map<String, String> surfaceAttributes;

  /// Tab index for a read-only or editable surface. Defaults to zero.
  final int tabIndex;

  /// Explicit platform override for command-key handling. When absent, the
  /// host detects macOS/iOS from the selected window's navigator.
  final bool? mac;

  /// Fires when the document tree changes.
  ///
  /// Selection-only transitions deliberately do not invoke this callback. Use
  /// [onSelectionChange] for selection, or [onStateChange] when an integration
  /// needs to observe every reducer transition.
  final DigitalEditorHostStateCallback? onChange;

  /// Fires for every effective editor-state transition, including selection
  /// changes. If both this and [onChange] are supplied, a document mutation
  /// invokes both callbacks; a selection-only transition invokes only this.
  final DigitalEditorHostStateCallback? onStateChange;

  /// Fires whenever the current model selection changes.
  final DigitalEditorHostSelectionCallback? onSelectionChange;

  /// Lifecycle callbacks for the generated surface.
  final DigitalEditorHostSurfaceCallback? onMount;
  final DigitalEditorHostSurfaceCallback? onDestroy;
  final DigitalEditorHostSurfaceCallback? onFocus;
  final DigitalEditorHostSurfaceCallback? onBlur;

  /// Observational browser event callbacks. They do not replace the host's
  /// editing pipeline and are called before its corresponding action is
  /// dispatched.
  final void Function(web.InputEvent event)? onBeforeInput;
  final void Function(web.KeyboardEvent event)? onKeyDown;
  final void Function(web.ClipboardEvent event)? onCopy;
  final void Function(web.ClipboardEvent event)? onCut;
  final void Function(web.ClipboardEvent event)? onPaste;
  final void Function(web.DragEvent event)? onDrop;
  final void Function(web.CompositionEvent event)? onCompositionStart;
  final void Function(web.CompositionEvent event)? onCompositionEnd;

  const DigitalEditorHostConfig({
    this.componentRegistry,
    this.attrRegistry,
    this.editorConfig = const EditorConfig(),
    this.initialEditorState,
    this.document,
    this.window,
    this.templateBodyId,
    this.templatePageNumber = 1,
    this.templatePageCount = 1,
    bool readOnly = false,
    bool? readonly,
    this.suggestionView = SuggestionView.suggesting,
    this.surfaceClassName,
    this.ariaLabel,
    this.surfaceAttributes = const {},
    this.tabIndex = 0,
    this.mac,
    this.onChange,
    this.onStateChange,
    this.onSelectionChange,
    this.onMount,
    this.onDestroy,
    this.onFocus,
    this.onBlur,
    this.onBeforeInput,
    this.onKeyDown,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.onDrop,
    this.onCompositionStart,
    this.onCompositionEnd,
  }) : readOnly = readonly ?? readOnly;

  /// Portuguese/TypeScript-style spelling retained as a convenience alias.
  bool get readonly => readOnly;

  /// Short aliases for integrations that use the names from the renderer.
  ComponentRegistry? get components => componentRegistry;
  AttrRegistry? get attrs => attrRegistry;
}
