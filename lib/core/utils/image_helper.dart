// lib/core/utils/image_helper.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:horaextra_app/core/config/api_config.dart';

/// Helper para URLs de imagens e widgets de imagem com cache.
///
/// Uso do método estático (compatível com o código existente):
///   ImageHelper.getFullImageUrl(category.imageUrl)
///
/// Caso o código legado use instância (imageHelper.getFullImageUrl(...)),
/// basta criar: final imageHelper = ImageHelper();
class ImageHelper {
  // Singleton opcional para compatibilidade com código que usa instância
  static final ImageHelper _instance = ImageHelper._internal();
  factory ImageHelper() => _instance;
  ImageHelper._internal();

  // ── Método principal (estático E de instância) ────────────────────────────

  /// Converte um path relativo retornado pela API em URL completa.
  ///
  /// Exemplos:
  ///   "/uploads/categories/img.jpeg" → "https://horaextra-backend-production.up.railway.app/uploads/categories/img.jpeg"
  ///   "http://..." → retorna sem alteração
  ///   null / "" → retorna ""
  static String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';

    final trimmed = path.trim();

    // ✅ Já é URL completa (http, https, data)
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }

    // ✅ Path relativo — usar base URL do ApiConfig
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${ApiConfig.baseUrl}$cleanPath';
  }

  /// Gera URL para avatar com timestamp para forçar recarregamento
  static String getAvatarUrl(String? photoUrl, {int? timestamp}) {
    final baseUrl = getFullImageUrl(photoUrl);
    if (baseUrl.isEmpty) return '';

    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    return '$baseUrl?t=$ts';
  }

  /// Alias de instância — mantém compatibilidade se o código usa
  /// `imageHelper.getFullImageUrl(...)` em vez do método estático.
  String call(String? path) => ImageHelper.getFullImageUrl(path);
}

// ── Widgets ───────────────────────────────────────────────────────────────

/// Widget de imagem de rede com cache em disco, placeholder e fallback.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final double fallbackIconSize;
  final Color? fallbackIconColor;
  final Color? fallbackBackgroundColor;
  final int? refreshKey; // ✅ Para forçar recarregamento

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackIconSize = 32,
    this.fallbackIconColor,
    this.fallbackBackgroundColor,
    this.refreshKey,
  });

  @override
  Widget build(BuildContext context) {
    final url = ImageHelper.getFullImageUrl(imageUrl);

    // ✅ Adicionar timestamp se houver refreshKey
    final finalUrl =
        refreshKey != null && url.isNotEmpty ? '$url?refresh=$refreshKey' : url;

    if (finalUrl.isEmpty) return _fallback(context);

    final image = CachedNetworkImage(
      imageUrl: finalUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth:
          (width != null && width!.isFinite) ? (width! * 2).toInt() : null,
      memCacheHeight:
          (height != null && height!.isFinite) ? (height! * 2).toInt() : null,
      placeholder: (_, __) => _placeholder(context),
      errorWidget: (_, __, error) {
        debugPrint('⚠️ Imagem falhou: $finalUrl | $error');
        return _fallback(context);
      },
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder(BuildContext context) => Container(
        width: width,
        height: height,
        color: fallbackBackgroundColor ??
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.4),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _fallback(BuildContext context) => Container(
        width: width,
        height: height,
        color: fallbackBackgroundColor ??
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
        child: Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: fallbackIconColor ??
              Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      );
}

/// Widget de avatar circular com cache.
class AppNetworkAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final int? refreshKey; // ✅ Para forçar recarregamento
  final VoidCallback? onTap;

  const AppNetworkAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person_outline,
    this.refreshKey,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = ImageHelper.getFullImageUrl(imageUrl);
    final size = radius * 2;

    // ✅ Adicionar timestamp se houver refreshKey
    final finalUrl =
        refreshKey != null && url.isNotEmpty ? '$url?refresh=$refreshKey' : url;

    if (finalUrl.isEmpty) {
      return _buildFallbackAvatar(context);
    }

    final avatar = CachedNetworkImage(
      imageUrl: finalUrl,
      memCacheWidth: size.toInt(),
      memCacheHeight: size.toInt(),
      imageBuilder: (_, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        child: onTap != null ? const SizedBox.expand() : null,
      ),
      placeholder: (_, __) => CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => _buildFallbackAvatar(context),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildFallbackAvatar(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(fallbackIcon, size: radius, color: Colors.grey.shade500),
    );
  }
}

/// Widget para imagem de rede sem cache (para avatares que precisam atualizar rápido)
class AppNetworkImageSimple extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? refreshKey;

  const AppNetworkImageSimple({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.refreshKey,
  });

  @override
  Widget build(BuildContext context) {
    final url = ImageHelper.getFullImageUrl(imageUrl);

    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.person_outline, size: 30, color: Colors.grey),
      );
    }

    // ✅ Adicionar timestamp para forçar recarregamento
    final finalUrl = refreshKey != null ? '$url?t=$refreshKey' : url;

    return Image.network(
      finalUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
      ),
    );
  }
}
