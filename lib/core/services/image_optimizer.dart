// lib/core/services/image_optimizer.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:horaextra_app/core/constants/app_colors.dart';

class ImageOptimizer {
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  static const int _maxMemoryCacheSize = 30; // 30 imagens em memória

  // Cache em memória para imagens pequenas
  static final Map<String, ui.Image> _memoryCache = {};
  static final List<String> _cacheOrder = [];

  static Widget buildOptimizedImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double? cacheWidth,
    double? cacheHeight,
    bool isThumbnail = false,
  }) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder(width, height);
    }

    // Para thumbnails, usar cache mais agressivo
    if (isThumbnail) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: cacheWidth?.toInt() ?? 100,
        memCacheHeight: cacheHeight?.toInt() ?? 100,
        maxWidthDiskCache: 500,
        maxHeightDiskCache: 500,
        placeholder: (context, url) => _buildShimmer(width, height),
        errorWidget: (context, url, error) => _buildPlaceholder(width, height),
      );
    }

    // Para imagens normais
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: cacheWidth?.toInt(),
      memCacheHeight: cacheHeight?.toInt(),
      maxWidthDiskCache: 1200,
      maxHeightDiskCache: 1200,
      placeholder: (context, url) => _buildShimmer(width, height),
      errorWidget: (context, url, error) => _buildPlaceholder(width, height),
    );
  }

  static Widget _buildShimmer(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.grey200,
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.grey400),
        ),
      ),
    );
  }

  static Widget _buildPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: AppColors.grey100,
      child: Icon(
        Icons.broken_image_rounded,
        color: AppColors.grey400,
        size: (width ?? 100) * 0.3,
      ),
    );
  }

  static String getOptimizedUrl(String url, {int width = 400}) {
    if (url.isEmpty) return url;

    // Se a URL já tem parâmetros de query
    if (url.contains('?')) {
      return '$url&w=$width&q=75';
    }
    return '$url?w=$width&q=75';
  }

  static Future<Uint8List?> compressImage({
    required Uint8List bytes,
    int quality = 75,
    int targetWidth = 800,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: targetWidth,
        minWidth: targetWidth,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('Erro ao comprimir imagem: $e');
      return bytes;
    }
  }

  static void clearMemoryCache() {
    _memoryCache.clear();
    _cacheOrder.clear();
  }
}

// Extension para facilitar o uso em BuildContext
extension ImageOptimizerExtension on BuildContext {
  String getOptimizedImageUrl(String url, {int width = 400}) {
    return ImageOptimizer.getOptimizedUrl(url, width: width);
  }
}
