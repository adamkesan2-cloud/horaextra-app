// lib/data/models/service/upload_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:horaextra_app/core/providers/auth_provider.dart';

class UploadService {
  final AuthProvider authProvider;

  // ── Supabase Storage config ───────────────────────────────────────────────
  static const String _supabaseUrl = 'https://enebxldzesysuqkffknb.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVuZWJ4bGR6ZXN5c3Vxa2Zma25iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQyNDg0NjMsImV4cCI6MjA4OTgyNDQ2M30.YXF05V0xlWvCiB-hMSvGgQws52WpP9cP4MMTGgDd9S8';
  static const String _bucket = 'categories';

  UploadService(this.authProvider);

  Future<String?> uploadCategoryImage({
    required Uint8List imageBytes,
    required String fileName,
    required String categoryName,
  }) async {
    try {
      // Gerar nome único para o ficheiro
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = _getExtension(fileName);
      final safeName =
          categoryName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final storagePath = '$safeName\_$timestamp.$ext';

      debugPrint('📤 Supabase Storage upload');
      debugPrint('   Bucket: $_bucket');
      debugPrint('   Path: $storagePath');
      debugPrint(
          '   Tamanho: ${(imageBytes.length / 1024).toStringAsFixed(1)}KB');

      final mimeType = _getMimeType(ext);

      // Upload para Supabase Storage via REST API
      final uri = Uri.parse(
        '$_supabaseUrl/storage/v1/object/$_bucket/$storagePath',
      );

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_supabaseAnonKey',
          'apikey': _supabaseAnonKey,
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        body: imageBytes,
      );

      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Resposta: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Construir URL pública
        final publicUrl =
            '$_supabaseUrl/storage/v1/object/public/$_bucket/$storagePath';
        debugPrint('✅ Upload concluído: $publicUrl');
        return publicUrl;
      } else {
        debugPrint(
            '❌ Erro Supabase: ${response.statusCode} — ${response.body}');

        // Tentar parsear erro
        try {
          final error = jsonDecode(response.body);
          debugPrint('   Mensagem: ${error['message'] ?? error['error']}');
        } catch (_) {}

        return null;
      }
    } catch (e) {
      debugPrint('❌ Excepção no upload Supabase: $e');
      return null;
    }
  }

  String _getExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) return parts.last.toLowerCase();
    return 'jpg';
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }
}
