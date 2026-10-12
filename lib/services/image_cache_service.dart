import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
  /// 2. Disk cache (0-5ms)
  /// 3. Network fetch (background, timeouts bilan)
  Future<Uint8List?> getImageBytes(String url) async {
    if (url.isEmpty) return null;

    // 1. Data URL bo'lsa
    if (url.startsWith('data:image/')) {
      try {
        return Uri.parse(url).data?.contentAsBytes();
      } catch (e) {
        return null;
      }
    }

    // 2. RAM Memory Cache
    if (_memoryCache.containsKey(url)) {
      return _memoryCache[url];
    }

    // 3. Pending download bo'lsa (bir vaqtda 10 ta vidjet bir xil rasmni so'rasa, 1 marta yuklanadi)
    if (_pendingDownloads.containsKey(url)) {
      return await _pendingDownloads[url];
    }

    final completer = Completer<Uint8List?>();
    _pendingDownloads[url] = completer.future;

    try {
      final bytes = await _loadFromDiskOrNetwork(url);
      if (bytes != null && bytes.isNotEmpty) {
        // Limited memory cache (max 100 ta rasm RAM'da saqlanadi, RAM to'lmasligi uchun)
        if (_memoryCache.length > 100) {
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
    if (kIsWeb) {
      try {
        final res = await _dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) return Uint8List.fromList(res.data!);
      } catch (_) {}
      return null;
    }

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
