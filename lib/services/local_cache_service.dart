import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App bo'yicha ma'lumotlarni (categories, products, tables, customers, va h.k.)
/// SharedPreferences'da keshlab boruvchi va instant (0-ms) yuklashni
/// ta'minlovchi xizmat.
class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;
  LocalCacheService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _asyncPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Synchronous prefs getter (agar allaqachon initsializatsiya qilingan bo'lsa)
  SharedPreferences? get prefs => _prefs;

  /// Service'ni avvaldan initsializatsiya qilish
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Kesh kaliti bo'yicha JSON ro'yxatni o'qib olish (masalan 'cache_products')
  Future<List<T>> getCachedList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(key);
      if (raw == null || raw.isEmpty) return <T>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <T>[];
      return decoded
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('LocalCacheService getCachedList ($key) xatoligi: $e');
      return <T>[];
    }
  }

  /// SharedPreferences xotirasi to'lib qolganda (QuotaExceededError)
  /// keraksiz yoki eskirgan kesh yozuvlarini tozalash
  Future<void> pruneCacheForQuota(SharedPreferences p) async {
    try {
      final keys = p.getKeys().toList();
      for (final k in keys) {
        if (k.startsWith('cache_reports_') ||
            k.startsWith('cache_customer_orders_') ||
            k.startsWith('flutter.cache_reports_') ||
            k.startsWith('flutter.cache_customer_orders_') ||
            k.endsWith('_time')) {
          await p.remove(k);
        }
      }
      // Agar hali ham to'liq bo'lsa, eski cheklar keshini ham tozalaymiz
      for (final k in keys) {
        if (k.startsWith('cache_receipts_') || k.startsWith('flutter.cache_receipts_')) {
          await p.remove(k);
        }
      }
    } catch (_) {}
  }

  Future<void> _pruneCacheForQuota(SharedPreferences p) => pruneCacheForQuota(p);

  /// Kesh kaliti bo'yicha JSON ro'yxatni saqlash
  Future<void> setCachedList<T>(
    String key,
    List<T> list,
    Map<String, dynamic> Function(T) toJson, {
    bool allowEmpty = true,
  }) async {
    try {
      final p = await _asyncPrefs;
      final existingRaw = p.getString(key);

      if (!allowEmpty && list.isEmpty && existingRaw != null && existingRaw.isNotEmpty && existingRaw != '[]') {
        // Mavjud keshni bo'sh ro'yxat bilan almashtirmaymiz (safeguard)
        return;
      }


      // Kesh hajmini chegaralash: Cheklar keshida eng so'nggi 80 ta saqlanadi
      Iterable<T> itemsToSave = list;
      if (key.contains('receipts') && list.length > 80) {
        itemsToSave = list.take(80);
      }

      final jsonList = itemsToSave.map((e) {
        final json = toJson(e);
        // Gigant Base64 rasmlar localStorage ni to'ldirib yubormasligi uchun
        if (key.contains('products')) {
          final img = json['imageUrl']?.toString();
          if (img != null && img.startsWith('data:image/') && img.length > 500) {
            json['imageUrl'] = null;
          }
        }
        return json;
      }).toList();

      final encoded = jsonEncode(jsonList);

      try {
        await p.setString(key, encoded);
        await p.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
      } catch (storageError) {
        // QuotaExceededError bo'lsa, eskirgan keshlarni tozalab qayta urinamiz
        await _pruneCacheForQuota(p);
        await p.setString(key, encoded);
      }
    } catch (e) {
      debugPrint('LocalCacheService setCachedList ($key) xatoligi: $e');
    }
  }

  /// Kesh kaliti bo'yicha JSON map saqlash (masalan tableOrders yoki settings)
  Future<Map<String, dynamic>?> getCachedMap(String key) async {
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('LocalCacheService getCachedMap ($key) xatoligi: $e');
    }
    return null;
  }

  /// Kesh kaliti bo'yicha JSON map saqlash
  Future<void> setCachedMap(String key, Map<String, dynamic> map) async {
    try {
      final p = await _asyncPrefs;
      final encoded = jsonEncode(map);
      try {
        await p.setString(key, encoded);
        await p.setInt('${key}_time', DateTime.now().millisecondsSinceEpoch);
      } catch (storageError) {
        await _pruneCacheForQuota(p);
        await p.setString(key, encoded);
      }
    } catch (e) {
      debugPrint('LocalCacheService setCachedMap ($key) xatoligi: $e');
    }
  }

  /// Kesh mavjudligini tekshirish
  Future<bool> hasCache(String key) async {
    final p = await _asyncPrefs;
    return p.containsKey(key);
  }

  /// Kesh vaqtini olish
  Future<DateTime?> getCacheTime(String key) async {
    final p = await _asyncPrefs;
    final ms = p.getInt('${key}_time');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Keshni tozalash
  Future<void> clearCache(String key) async {
    final p = await _asyncPrefs;
    await p.remove(key);
    await p.remove('${key}_time');
  }
}

