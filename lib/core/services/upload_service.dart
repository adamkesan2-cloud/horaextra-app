// lib/core/services/upload_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:horaextra_app/core/config/api_config.dart';
import 'package:horaextra_app/core/providers/auth_provider.dart';

/// Resultado de upload com URL retornada pelo servidor
class UploadResult {
  final String url;
  final int originalBytes;
  final int compressedBytes;

  const UploadResult({
    required this.url,
    required this.originalBytes,
    required this.compressedBytes,
  });

  double get savingPercent => originalBytes > 0
      ? ((originalBytes - compressedBytes) / originalBytes * 100)
      : 0;
}

class UploadService {
  final AuthProvider _authProvider;

  /// Qualidade JPEG (0–100). 72 = ótimo equilíbrio qualidade/tamanho.
  static const int _quality = 72;

  /// Dimensão máxima (largura ou altura). Imagens maiores são redimensionadas.
  static const int _maxDimension = 1024;

  UploadService(this._authProvider);

  // ── Upload com compressão automática (File) ───────────────────────────────

  Future<UploadResult> uploadImage(
    File file, {
    String fieldName = 'image',
  }) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Não autenticado');

    final originalSize = await file.length();
    debugPrint('📸 Upload iniciado: ${p.basename(file.path)}');
    debugPrint('   Original: ${_fmt(originalSize)}');

    final compressed = await _compressFile(file);
    debugPrint('   Comprimido: ${_fmt(compressed.length)}');
    debugPrint('   Economia: ${_saving(originalSize, compressed.length)}%');

    final request =
        http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadImage))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(http.MultipartFile.fromBytes(
            fieldName,
            compressed,
            filename: '${p.basenameWithoutExtension(file.path)}_c.jpg',
          ));

    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 30)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final url = _extractUrl(response.body);
      debugPrint('✅ Upload concluído: $url');
      return UploadResult(
          url: url,
          originalBytes: originalSize,
          compressedBytes: compressed.length);
    }

    throw Exception('Erro no upload: ${response.statusCode}');
  }

  // ── Upload com compressão automática (Bytes — Web/Mobile) ─────────────────

  Future<UploadResult> uploadImageBytes(
    Uint8List bytes,
    String filename, {
    String fieldName = 'image',
  }) async {
    final token = await _authProvider.getToken();
    if (token == null) throw Exception('Não autenticado');

    final originalSize = bytes.length;
    debugPrint(
        '📸 Upload (bytes): $filename | Original: ${_fmt(originalSize)}');

    final compressed = await _compressBytes(bytes);
    debugPrint(
        '   Comprimido: ${_fmt(compressed.length)} | Economia: ${_saving(originalSize, compressed.length)}%');

    final request =
        http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadImage))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(http.MultipartFile.fromBytes(fieldName, compressed,
              filename: filename));

    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 30)),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final url = _extractUrl(response.body);
      debugPrint('✅ Upload concluído: $url');
      return UploadResult(
          url: url,
          originalBytes: originalSize,
          compressedBytes: compressed.length);
    }

    throw Exception('Erro no upload: ${response.statusCode}');
  }

  // ── Compressão ────────────────────────────────────────────────────────────

  Future<Uint8List> _compressFile(File file) async {
    if (kIsWeb) return file.readAsBytes();
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
      return result ?? file.readAsBytesSync();
    } catch (e) {
      debugPrint('⚠️ Compressão falhou, usando original: $e');
      return file.readAsBytesSync();
    }
  }

  Future<Uint8List> _compressBytes(Uint8List bytes) async {
    if (kIsWeb) return bytes;
    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
    } catch (e) {
      debugPrint('⚠️ Compressão falhou: $e');
      return bytes;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  String _saving(int original, int compressed) => original > 0
      ? ((original - compressed) / original * 100).toStringAsFixed(1)
      : '0';

  /// Extrai a URL da resposta JSON do servidor.
  /// Suporta os campos mais comuns; adapte ao seu backend se necessário.
  String _extractUrl(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['url'] ??
              json['image_url'] ??
              json['imageUrl'] ??
              json['path'] ??
              '')
          .toString();
    } catch (_) {
      return body.trim();
    }
  }

  Future<String?> uploadCategoryImage({required Uint8List imageBytes, required String fileName, required String categoryName}) async {}
}
