// lib/core/services/_ws_web.dart
// Implementação Web usando dart:html — sem dependência de dart:io
// Evita o erro "Unsupported operation: Platform._version" no browser

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import '_ws_stub.dart';

class _WebWsClient implements WsClient {
  final html.WebSocket _ws;
  final _controller = StreamController<String>.broadcast();

  _WebWsClient(String url) : _ws = html.WebSocket(url) {
    _ws.onMessage.listen((event) {
      _controller.add(event.data as String);
    });
    _ws.onError.listen((e) => _controller.addError(e));
    _ws.onClose.listen((_) => _controller.close());
  }

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String data) {
    if (_ws.readyState == html.WebSocket.OPEN) _ws.send(data);
  }

  @override
  void close() {
    _ws.close();
    _controller.close();
  }
}

WsClient createWsClient(String url) => _WebWsClient(url);
