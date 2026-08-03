part of taleweaver_word_editor;

/// File-ribbon bridge for DOCX adapters and the built-in Quill-Delta codec.
///
/// The editor owns the native file chooser and lifecycle. Quill Delta is a
/// supported, strict text interchange built into the package; DOCX remains an
/// explicit adapter because accepting a DOCX without a full converter would
/// silently lose unsupported document structure.
extension _TaleweaverEditorFileCommands on TaleweaverEditor {
  void _requestOpenDocx() {
    _requestOpenFile(
      format: 'docx',
      accept:
          '.docx,application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      callback: options.onOpenDocx,
      missingAdapterMessage:
          'Configure onOpenDocx para importar este arquivo DOCX.',
    );
  }

  void _requestOpenDelta() {
    _requestOpenFile(
      format: 'delta',
      accept: '.json,application/json,text/json',
      callback: options.onOpenDelta ?? _openBuiltInDelta,
      missingAdapterMessage: '',
    );
  }

  void _requestOpenFile({
    required String format,
    required String accept,
    required TaleweaverEditorOpenFileCallback? callback,
    required String missingAdapterMessage,
  }) {
    if (_destroyed) return;
    if (callback == null) {
      _statusState.textContent = missingAdapterMessage;
      return;
    }
    final input = _document.createElement('input') as web.HTMLInputElement
      ..className = 'tw-editor__file-input'
      ..type = 'file'
      ..accept = accept;
    root.appendChild(input);
    input.addEventListener(
      'change',
      ((web.Event _) {
        final file = input.files?.item(0);
        input.remove();
        if (file == null) return;
        unawaited(_openSelectedFile(callback, file, format));
      }).toJS,
    );
    input.click();
  }

  Future<void> _openSelectedFile(
    TaleweaverEditorOpenFileCallback callback,
    web.File file,
    String format,
  ) async {
    if (_destroyed) return;
    _statusState.textContent =
        'Abrindo ${format == 'docx' ? 'DOCX' : 'Delta'}…';
    try {
      await callback(TaleweaverEditorFileRequest(
        editor: this,
        file: file,
        format: format,
      ));
      if (_destroyed) return;
      _dirty = false;
      _setSaveState('Carregado');
      focus();
    } catch (_) {
      if (_destroyed) return;
      _statusState.textContent =
          'Não foi possível abrir ${format == 'docx' ? 'o DOCX' : 'o Delta'}.';
    }
  }

  void _requestExportDelta() {
    final callback = options.onExportDelta;
    if (callback != null) {
      unawaited(_exportDelta(callback));
      return;
    }
    // Preserve the existing generic export integration as a useful fallback
    // for hosts that already multiplex serializers by format.
    final generic = options.onExport;
    if (generic != null) {
      generic(editorState, 'quill-delta');
      _setSaveState('Delta exportado');
      return;
    }
    _exportBuiltInDelta();
  }

  /// Imports the supported document-Delta subset without requiring a host
  /// callback. The codec rejects structures it cannot preserve instead of
  /// turning a table, embed or tracked change into incomplete plain text.
  Future<void> _openBuiltInDelta(TaleweaverEditorFileRequest request) async {
    const maxDeltaBytes = 10 * 1024 * 1024;
    if (request.file.size > maxDeltaBytes) {
      throw ArgumentError.value(
          request.file.size, 'file', 'Delta files are limited to 10 MB.');
    }
    final text = await _readTextFile(request.file);
    final decoded = decodeQuillDelta(jsonDecode(text));
    request.editor.replaceDocument(_editorStateForImportedDelta(decoded));
  }

  Future<String> _readTextFile(web.File file) {
    final completer = Completer<String>();
    final reader = web.FileReader();
    reader.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
            StateError('The selected Delta file could not be read.'));
      }
    }).toJS;
    reader.onload = ((web.Event _) {
      final result = reader.result;
      if (result == null || !result.isA<JSString>()) {
        if (!completer.isCompleted) {
          completer.completeError(
              StateError('The selected Delta file did not contain text.'));
        }
        return;
      }
      if (!completer.isCompleted)
        completer.complete((result as JSString).toDart);
    }).toJS;
    reader.readAsText(file, 'UTF-8');
    return completer.future;
  }

  EditorState _editorStateForImportedDelta(State state) {
    final first = iterateLeafBlocksInDocumentOrder(state).firstWhere(
      (block) => block.inlineContent != null,
      orElse: () =>
          throw StateError('Delta did not produce an editable block.'),
    );
    final position = Position(blockId: first.id, offset: 0);
    return EditorState(
      state: state,
      selection: Selection(anchor: position, focus: position),
      history: createHistory(state),
      containerWidth: editorState.containerWidth,
    );
  }

  void _exportBuiltInDelta() {
    if (_destroyed) return;
    try {
      final json = const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'ops': encodeQuillDelta(editorState.state),
      });
      final blob = web.Blob(
        <JSAny>[json.toJS].toJS,
        web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
      );
      final url = web.URL.createObjectURL(blob);
      final download = _document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = _deltaDownloadName();
      root.appendChild(download);
      download.click();
      download.remove();
      web.URL.revokeObjectURL(url);
      _setSaveState('Delta exportado');
    } catch (_) {
      if (!_destroyed) {
        _statusState.textContent =
            'O documento contém recursos que o Delta não pode preservar.';
      }
    }
  }

  String _deltaDownloadName() {
    final base = documentTitle.trim().isEmpty
        ? 'documento'
        : documentTitle.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return '$base.delta.json';
  }

  Future<void> _exportDelta(
      TaleweaverEditorDeltaExportCallback callback) async {
    if (_destroyed) return;
    _statusState.textContent = 'Exportando Delta…';
    try {
      await callback(TaleweaverEditorExportRequest(
        editor: this,
        state: editorState,
        format: 'quill-delta',
      ));
      if (!_destroyed) _setSaveState('Delta exportado');
    } catch (_) {
      if (!_destroyed) {
        _statusState.textContent = 'Não foi possível exportar o Delta.';
      }
    }
  }
}
