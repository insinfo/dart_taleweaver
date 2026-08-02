/// Browser WebSocket transport for Yjs updates.
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'collaboration.dart';
import 'doc.dart';

/// Connects a [YDocProvider] to a WebSocket endpoint.
///
/// Updates are sent as base64 text frames rather than raw `ArrayBuffer`s so
/// the adapter works with servers that expose a text-only room protocol and
/// remains independent of browser-specific binary conversion APIs. The
/// payload itself is still the exact V1/V2 Yjs update produced by the core.
class YWebSocketProvider {
  late final web.WebSocket socket;
  late final YDocProvider provider;
  final void Function()? onOpen;
  final void Function()? onClose;
  bool _disposed = false;

  YWebSocketProvider({
    required YDoc doc,
    required String url,
    bool v2 = false,
    Object origin = 'websocket',
    this.onOpen,
    this.onClose,
  }) {
    socket = web.WebSocket(url);
    provider = YDocProvider(
      doc: doc,
      v2: v2,
      origin: origin,
      send: (update) {
        if (_disposed || socket.readyState != web.WebSocket.OPEN) return;
        socket.send(base64Encode(update).toJS);
      },
    );
    socket.onopen = ((web.Event _) {
      if (_disposed) return;
      provider.sync();
      onOpen?.call();
    }).toJS;
    socket.onmessage = ((web.MessageEvent event) {
      if (_disposed) return;
      final payload = event.data;
      if (payload is! JSString) return;
      try {
        provider.receive(base64Decode(payload.toDart));
      } on Object {
        // Ignore malformed room frames; the socket remains usable for later
        // valid updates and the CRDT state is never partially mutated.
      }
    }).toJS;
    socket.onclose = ((web.Event _) {
      if (_disposed) return;
      onClose?.call();
    }).toJS;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    provider.dispose();
    if (socket.readyState == web.WebSocket.OPEN ||
        socket.readyState == web.WebSocket.CONNECTING) {
      socket.close();
    }
  }
}
