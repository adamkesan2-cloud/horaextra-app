// lib/core/services/image_picker_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:image_picker_web/image_picker_web.dart';

class ImagePickerService {
  // Para Web
  static Future<ImagePickResult?> pickImage() async {
    try {
      final html.File? file = await ImagePickerWeb.getImageAsFile();
      if (file != null) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();

        reader.onLoadEnd.listen((_) {
          completer.complete(reader.result as Uint8List);
        });

        reader.readAsArrayBuffer(file);
        final bytes = await completer.future;

        return ImagePickResult(
          bytes: bytes,
          name: file.name,
        );
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
    }
    return null;
  }
}

class ImagePickResult {
  final Uint8List bytes;
  final String name;

  ImagePickResult({
    required this.bytes,
    required this.name,
  });
}
