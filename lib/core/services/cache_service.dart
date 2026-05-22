// lib/core/services/cache_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static const String _cachePrefix = 'horaextra_';
  static const int _maxCacheSize = 100;
  static const Duration _defaultTtl = Duration(minutes: 30);

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memoryCache = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    _cleanExpired();
  }

  void _cleanExpired() {
    final now = DateTime.now();
    _memoryCache.removeWhere((_, entry) => entry.isExpired(now));
  }

  Future<void> cacheData(String key, dynamic data,
      {Duration? ttl, String? etag}) async {
    if (!_isInitialized) await init();

    final entry = _CacheEntry(
      data: data,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
      etag: etag,
    );

    _memoryCache[key] = entry;

    if (_shouldPersist(key)) {
      await _prefs?.setString(
        _cachePrefix + key,
        jsonEncode({
          'data': data,
          'expiresAt': entry.expiresAt.toIso8601String(),
          'etag': etag,
        }),
      );
    }

    if (_memoryCache.length > _maxCacheSize) {
      _trimCache();
    }
  }

  bool _shouldPersist(String key) {
    return key.contains('/categories') ||
        key.contains('/services') ||
        key.contains('/user');
  }

  void _trimCache() {
    final sorted = _memoryCache.entries.toList()
      ..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));

    final toRemove = sorted.sublist(_maxCacheSize);
    for (final entry in toRemove) {
      _memoryCache.remove(entry.key);
    }
  }

  dynamic getCached(String key) {
    if (!_isInitialized) return null;

    _cleanExpired();
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired(DateTime.now())) {
      return entry.data;
    }

    _memoryCache.remove(key);
    return null;
  }

  bool isFresh(String key) {
    if (!_isInitialized) return false;
    final entry = _memoryCache[key];
    if (entry == null) return false;
    return !entry.isExpired(DateTime.now());
  }

  String? getEtag(String key) {
    if (!_isInitialized) return null;
    final entry = _memoryCache[key];
    return entry?.etag;
  }

  void invalidatePattern(String pattern) {
    _memoryCache.removeWhere((key, _) => key.contains(pattern));
  }

  List<T> getCachedList<T>(
      String key, T Function(Map<String, dynamic>) fromJson) {
    final data = getCached(key);
    if (data is List) {
      return data
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    await _prefs?.remove(_cachePrefix + key);
  }

  Future<void> clear() async {
    _memoryCache.clear();
    if (_prefs != null) {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          await _prefs?.remove(key);
        }
      }
    }
  }

  Future<void> clearExpired() async {
    _cleanExpired();
    if (_prefs != null) {
      final keys = _prefs!.getKeys();
      for (final key in keys) {
        if (key.startsWith(_cachePrefix)) {
          final value = _prefs?.getString(key);
          if (value != null) {
            try {
              final json = jsonDecode(value);
              final expiresAt = DateTime.parse(json['expiresAt'] as String);
              if (expiresAt.isBefore(DateTime.now())) {
                await _prefs?.remove(key);
              }
            } catch (_) {}
          }
        }
      }
    }
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  final String? etag;

  _CacheEntry({
    required this.data,
    required this.expiresAt,
    this.etag,
  });

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
}
