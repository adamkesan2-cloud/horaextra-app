// lib/core/services/_ws_stub.dart
// Interface comum — usada como fallback se nenhuma plataforma for detectada

abstract class WsClient {
  Stream<String> get messages;
  void send(String data);
  void close();
}

WsClient createWsClient(String url) =>
    throw UnsupportedError('Plataforma WS não suportada');
