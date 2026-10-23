import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Rasmlarni mahalliy diskka hamda operativ xotiraga (RAM) keshlab beruvchi
/// yuqori unumdorli servis.
/// 3G/4G tarmoqda sekin yoki internet umuman bo'lmaganda ham disk keshidagi
/// rasmlar 0-ms kechikish bilan darhol ko'rsatiladi.
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, Future<Uint8List?>> _pendingDownloads = {};
  Directory? _cacheDir;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 10),
  ));

  Future<Directory?> get _asyncCacheDir async {
    if (_cacheDir != null) return _cacheDir;
    try {
      if (kIsWeb) return null;
      final temp = await getTemporaryDirectory();
      _cacheDir = Directory('${temp.path}/image_cache');
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      return _cacheDir;
    } catch (e) {
      debugPrint('ImageCacheService init error: $e');
      return null;
    }
  }

  String _keyToFileName(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  /// Berilgan URL bo'yicha rasm byte-larini qaytaradi:
  /// 1. RAM Memory cache (0-ms)
  /// 2. Web SharedPreferences / Disk cache (0-5ms)
  /// 3. Network fetch (background, timeouts bilan)
  Future<Uint8List?> getImageBytes(String rawUrl) async {
    if (rawUrl.trim().isEmpty) return null;

    // 1. Data URL bo'lsa darhol baytlarini qaytaramiz
    if (rawUrl.startsWith('data:image/')) {
      try {
        final commaIdx = rawUrl.indexOf(',');
        if (commaIdx >= 0) {
          final b64 = rawUrl.substring(commaIdx + 1);
          return base64Decode(b64);
        }
        return Uri.parse(rawUrl).data?.contentAsBytes();
      } catch (e) {
        return null;
      }
    }

    final url = ApiClient().resolveImageUrl(rawUrl);

    // 2. RAM Memory Cache (0 ms)
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }

    // 3. Pending download bo'lsa
    if (_pendingDownloads.containsKey(url)) {
      return await _pendingDownloads[url];
    }

    final completer = Completer<Uint8List?>();
    _pendingDownloads[url] = completer.future;

    try {
      final bytes = await _loadFromDiskOrNetwork(url);
      if (bytes != null && bytes.isNotEmpty) {
        if (_memoryCache.length > 120) {
          _memoryCache.remove(_memoryCache.keys.first);
        }
        _memoryCache[url] = bytes;
      }
      completer.complete(bytes);
      return bytes;
    } catch (e) {
      completer.complete(null);
      return null;
    } finally {
      _pendingDownloads.remove(url);
    }
  }

  Future<Uint8List?> _loadFromDiskOrNetwork(String url) async {
    // A. Web platformasi uchun kesh va yuklash
    if (kIsWeb) {
      final cacheKey = 'img_cache_${_keyToFileName(url)}';
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedB64 = prefs.getString(cacheKey);
        if (cachedB64 != null && cachedB64.isNotEmpty) {
          try {
            return base64Decode(cachedB64);
          } catch (_) {}
        }
      } catch (_) {}

      // Tarmoq orqali yuklash
      try {
        final res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          final bytes = Uint8List.fromList(res.data!);
          // Web xotiraga (SharedPreferences) 150KB gacha bo'lgan rasmlarni oflayn uchun keshlaymiz
          if (bytes.length < 150 * 1024) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString(cacheKey, base64Encode(bytes)).catchError((_) => false);
            }).catchError((_) {});
          }
          return bytes;
        }
      } catch (e) {
        // Internet yo'q yoki yuklab bo'lmadi
      }
      return null;
    }

    // B. Mobil va Desktop uchun faylli disk kesh
    final dir = await _asyncCacheDir;
    if (dir != null) {
      final fileName = _keyToFileName(url);
      final file = File('${dir.path}/$fileName');

      // Disk keshida bormi?
      if (await file.exists()) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        } catch (_) {}
      }

      // Aks holda tarmoqdan yuklaymiz
      try {
        final res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          final bytes = Uint8List.fromList(res.data!);
          // Diskka saqlab qo'yamiz (offline va kelasi safar uchun)
          file.writeAsBytes(bytes).catchError((e) {
            debugPrint('ImageCacheService write error: $e');
            return file;
          });
          return bytes;
        }
      } catch (e) {
        debugPrint('ImageCacheService network fetch error ($url): $e');
      }
    }
    return null;
  }

  /// RAM keshini tozalash (xotira yetishmovchiligida)
  void clearMemoryCache() {
    _memoryCache.clear();
  }
}
