// lib/core/services/_ws_io.dart
// Implementação mobile/desktop usando web_socket_channel

import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '_ws_stub.dart';

class _IoWsClient implements WsClient {
  final WebSocketChannel _channel;
  final _controller = StreamController<String>.broadcast();

  _IoWsClient(String url)
      : _channel = WebSocketChannel.connect(Uri.parse(url)) {
    _channel.stream.listen(
      (data) => _controller.add(data.toString()),
      onError: (e) => _controller.addError(e),
      onDone: () => _controller.close(),
    );
  }

  @override
  Stream<String> get messages => _controller.stream;

  @override
  void send(String data) => _channel.sink.add(data);

  @override
  void close() {
    _channel.sink.close();
    _controller.close();
  }
}

WsClient createWsClient(String url) => _IoWsClient(url);
