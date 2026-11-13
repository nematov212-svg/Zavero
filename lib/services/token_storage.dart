import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ZAVERO TOKEN STORAGE (Universal & Resilient)
/// 
/// Android planshetlar, telefonlar, desktop va web uchun YAGONA tokenni saqlash xizmati.
/// 
/// Muammo:
/// Android planshetlarda (ayniqsa ekran qulfi o'rnatilmagan yoki arzon POS qurilmalarda)
/// Android Keystore / FlutterSecureStorage ba'zan cheksiz qotib (deadlock) qoladi,
/// bu esa ilovani muzlatib, tokenni o'qish/saqlashni to'xtatib qo'yardi.
/// 
/// Yechim:
/// 1. Xotira (In-memory cache): 0 millisekundda sinxron javob beradi.
/// 2. SharedPreferences: Asosiy ishonchli doimiy xotira (hech qachon qotmaydi, barcha Androidlarda 100% ishlaydi).
/// 3. FlutterSecureStorage: Qo'shimcha xavfsizlik qatlami, lekin qat'iy 1200ms timeout bilan va xatolar ushlanadi.
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  static const _storage = FlutterSecureStorage();

  static const String keyAuthToken = 'zavero_auth_token';
  static const String keyRefreshToken = 'zavero_refresh_token';
  static const String keyDirectorToken = 'zavero_director_auth_token';
  static const String keyDirectorRefreshToken = 'zavero_director_refresh_token';
  static const String keyActiveCafeId = 'zavero_active_cafe_id';
  static const String keyUserPinToken = 'zavero_pin_saved_token';

  // Synchronous In-Memory Cache
  String? _cachedToken;
  String? _cachedRefreshToken;
  String? _cachedDirectorToken;
  String? _cachedDirectorRefreshToken;
  String? _cachedCafeId;
  bool _isInitialized = false;

  String? get token => _cachedToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get directorToken => _cachedDirectorToken;
  String? get directorRefreshToken => _cachedDirectorRefreshToken;
  String? get cafeId => _cachedCafeId;
  bool get hasToken => (_cachedToken != null && _cachedToken!.isNotEmpty) ||
      (_cachedDirectorToken != null && _cachedDirectorToken!.isNotEmpty);

  /// Ilova yuklanganda tokenni tezkor xotiraga olish
  Future<void> init() async {
    if (_isInitialized && _cachedToken != null && _cachedToken!.isNotEmpty) {
      return;
    }

    try {
      // 1. SharedPreferences orqali zudlik bilan (0-5ms) o'qiymiz
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString(keyAuthToken);
      _cachedRefreshToken = prefs.getString(keyRefreshToken);
      _cachedDirectorToken = prefs.getString(keyDirectorToken);
      _cachedDirectorRefreshToken = prefs.getString(keyDirectorRefreshToken);
      _cachedCafeId = prefs.getString(keyActiveCafeId);

      // Agar PIN tokeni mavjud bo'lsa va auth token bo'sh bo'lsa, zaxiradan tiklaymiz
      if (_cachedToken == null || _cachedToken!.isEmpty) {
        final pinToken = prefs.getString(keyUserPinToken);
        if (pinToken != null && pinToken.isNotEmpty) {
          _cachedToken = pinToken;
          await prefs.setString(keyAuthToken, pinToken);
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [TokenStorage] SharedPreferences init ogohlantirish: $e');
    }

    // 2. Agar hali ham token topilmagan bo'lsa, FlutterSecureStorage'dan qat'iy timeout bilan o'qiymiz
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      try {
        final secToken = await _storage
            .read(key: keyAuthToken)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        if (secToken != null && secToken.isNotEmpty) {
          _cachedToken = secToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(keyAuthToken, secToken);
        }
      } catch (e) {
        debugPrint('ℹ️ [TokenStorage] FlutterSecureStorage read bypass: $e');
      }
    }
  }

  /// Tokenni olish: avval xotiradan, keyin SharedPreferences'dan, keyin SecureStorage'dan
  Future<String?> getToken({bool isDirector = false}) async {
    final keyToUse = isDirector ? keyDirectorToken : keyAuthToken;
    final cached = isDirector ? _cachedDirectorToken : _cachedToken;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var val = prefs.getString(keyToUse);
      if ((val == null || val.isEmpty) && !isDirector) {
        val = prefs.getString(keyUserPinToken);
      }
      if (val != null && val.isNotEmpty) {
        if (isDirector) {
          _cachedDirectorToken = val;
        } else {
          _cachedToken = val;
        }
        return val;
      }
    } catch (_) {}

    try {
      final secVal = await _storage
          .read(key: keyToUse)
          .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
      if (secVal != null && secVal.isNotEmpty) {
        if (isDirector) {
          _cachedDirectorToken = secVal;
        } else {
          _cachedToken = secVal;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyToUse, secVal);
        return secVal;
      }
    } catch (_) {}

    // Agar direktor so'rovi bo'lsa va topilmasa, umumiy tokenga qaraymiz
    if (isDirector && _cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    return null;
  }

  /// Refresh tokenni olish
  Future<String?> getRefreshToken({bool isDirector = false}) async {
    final keyToUse = isDirector ? keyDirectorRefreshToken : keyRefreshToken;
    final cached = isDirector ? _cachedDirectorRefreshToken : _cachedRefreshToken;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(keyToUse);
      if (val != null && val.isNotEmpty) {
        if (isDirector) {
          _cachedDirectorRefreshToken = val;
        } else {
          _cachedRefreshToken = val;
        }
        return val;
      }
    } catch (_) {}

    try {
      final secVal = await _storage
          .read(key: keyToUse)
          .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
      if (secVal != null && secVal.isNotEmpty) {
        if (isDirector) {
          _cachedDirectorRefreshToken = secVal;
        } else {
          _cachedRefreshToken = secVal;
        }
        return secVal;
      }
    } catch (_) {}

    return null;
  }

  /// Tokenlarni saqlash:
  /// 1. Zudlik bilan xotiraga yoziladi (0ms)
  /// 2. Zudlik bilan SharedPreferences'ga yoziladi (bloklanmaydi)
  /// 3. Fon rejimida FlutterSecureStorage'ga timeout bilan yoziladi
  Future<void> saveTokens({
    required String token,
    String? refreshToken,
    bool isDirector = false,
    String? cafeId,
  }) async {
    // 1. In-memory update
    if (isDirector) {
      _cachedDirectorToken = token;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _cachedDirectorRefreshToken = refreshToken;
      }
    } else {
      _cachedToken = token;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        _cachedRefreshToken = refreshToken;
      }
      if (cafeId != null && cafeId.isNotEmpty) {
        _cachedCafeId = cafeId;
      }
    }

    final keyToUse = isDirector ? keyDirectorToken : keyAuthToken;
    final refreshKeyToUse = isDirector ? keyDirectorRefreshToken : keyRefreshToken;

    // 2. SharedPreferences (Eng ishonchli va tezkor)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyToUse, token);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(refreshKeyToUse, refreshToken);
      }
      // Agar umumiy token bo'lsa yoki PIN zaxirasi bo'lsa
      await prefs.setString(keyAuthToken, token);
      await prefs.setString(keyUserPinToken, token);
      if (cafeId != null && cafeId.isNotEmpty) {
        await prefs.setString(keyActiveCafeId, cafeId);
      }
    } catch (e) {
      debugPrint('⚠️ [TokenStorage] SharedPreferences write error: $e');
    }

    // 3. FlutterSecureStorage fon rejimida timeout bilan
    unawaited(() async {
      try {
        await _storage
            .write(key: keyToUse, value: token)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _storage
              .write(key: refreshKeyToUse, value: refreshToken)
              .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        }
        await _storage
            .write(key: keyAuthToken, value: token)
            .timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
      } catch (e) {
        debugPrint('ℹ️ [TokenStorage] FlutterSecureStorage write bypass: $e');
      }
    }());
  }

  /// Tokenlarni tozalash
  Future<void> clearTokens({bool isDirector = false}) async {
    if (isDirector) {
      _cachedDirectorToken = null;
      _cachedDirectorRefreshToken = null;
    } else {
      _cachedToken = null;
      _cachedRefreshToken = null;
      _cachedCafeId = null;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDirector) {
        await prefs.remove(keyDirectorToken);
        await prefs.remove(keyDirectorRefreshToken);
      } else {
        await prefs.remove(keyAuthToken);
        await prefs.remove(keyRefreshToken);
        await prefs.remove(keyUserPinToken);
        await prefs.remove(keyActiveCafeId);
      }
    } catch (_) {}

    unawaited(() async {
      try {
        if (isDirector) {
          await _storage
              .delete(key: keyDirectorToken)
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
          await _storage
              .delete(key: keyDirectorRefreshToken)
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
        } else {
          await _storage
              .delete(key: keyAuthToken)
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
          await _storage
              .delete(key: keyRefreshToken)
              .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
        }
      } catch (_) {}
    }());
  }
}
