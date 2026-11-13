import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_storage.dart';

/// Backend so'rovi muvaffaqiyatsiz bo'lganda tashlanadigan xatolik.
/// [statusCode] va ixtiyoriy [code] (masalan "TABLE_BUSY") saqlanadi —
/// shu orqali servicelar backend qaytargan aniq xatolik turini aniqlay oladi.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => message;
}

/// Backend REST API bilan ishlash uchun yagona Dio wrapper.
/// - Base URL konfiguratsiya qilinadi (dev: 10.0.2.2:3000, prod: Vercel yoki serverless domen)
/// - Har bir so'rovga avtomatik `Authorization: Bearer <token>` qo'shadi
/// - Tokenni flutter_secure_storage'da saqlaydi



class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const _storage = FlutterSecureStorage();
  static const _userKey = 'zavero_current_user';
  static const _directorUserKey = 'zavero_director_current_user';

  /// Backend bulut API manzili (Railway)
  /// --dart-define=API_BASE_URL=... orqali o'zgartirish mumkin.
  static const String _railwayBaseUrl =
      'https://zavero-backend-production-7dc9.up.railway.app/api';

  static String _defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        // Faqat Railway domeniga xizmat ko'rsatilayotgan bo'lsa o'sha manzilni ishlatamiz.
        // localhost / file:// da har doim Railway'dan foydalanamiz.
        if (origin.isNotEmpty &&
            !origin.startsWith('file:') &&
            !origin.contains('localhost') &&
            !origin.contains('127.0.0.1') &&
            !origin.contains('0.0.0.0')) {
          return '$origin/api';
        }
      } catch (_) {}
    }
    return _railwayBaseUrl;
  }

  late Dio _dio;
  String _baseUrl = _defaultBaseUrl();
  String? _token;
  String? _refreshToken;
  String? targetCafeId;

  final Map<String, Future<Map<String, dynamic>>> _pendingGetFutures = {};

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 18),
      receiveTimeout: const Duration(seconds: 22),
      sendTimeout: const Duration(seconds: 18),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        options.baseUrl = _baseUrl;
        final isDirectorContext = kIsWeb &&
            (Uri.base.fragment.contains('director') || Uri.base.path.contains('director'));

        // 1. Agar _token xotirada bo'sh bo'lsa, TokenStorage'dan zudlik bilan tiklashga urinamiz
        if (_token == null || _token!.isEmpty) {
          _token = await TokenStorage().getToken(isDirector: isDirectorContext);
          _refreshToken = await TokenStorage().getRefreshToken(isDirector: isDirectorContext);
        }

        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        if (targetCafeId != null && targetCafeId!.isNotEmpty) {
          options.headers['x-cafe-id'] = targetCafeId;
        }

        // Qurilma turini aniqlash (backend loglari va chek manbalari uchun)
        if (!options.headers.containsKey('x-device-type')) {
          if (kIsWeb) {
            options.headers['x-device-type'] = 'web';
          } else {
            // Android tablet / mobile
            options.headers['x-device-type'] = 'tablet';
          }
        }

        // Agar so'rov avtorizatsiya talab qilsa va token bo'lmasa, tarmoqqa chiqmasdan xatolik qaytaramiz
        final p = options.path;
        final isPublic = p.startsWith('/auth/login') ||
            p.startsWith('/auth/register') ||
            p.startsWith('/auth/refresh') ||
            p.contains('/health') ||
            p.startsWith('/menu') ||
            p.startsWith('/qr');

        if (!isPublic && (_token == null || _token!.isEmpty)) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'success': false, 'message': 'Avtorizatsiyadan o\'tilmagan. Token topilmadi.'},
              ),
              type: DioExceptionType.badResponse,
              error: ApiException('Avtorizatsiyadan o\'tilmagan. Token topilmadi.', statusCode: 401),
            ),
          );
          return;
        }

        handler.next(options);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode == 401) {
          final isAlreadyRetry = err.requestOptions.extra['isRetry'] == true;
          final isAuthEndpoint = err.requestOptions.path.contains('/auth/login') ||
              err.requestOptions.path.contains('/auth/refresh') ||
              err.requestOptions.path.contains('/auth/register');

          if (!isAlreadyRetry && !isAuthEndpoint) {
            final activeRefresh = _refreshToken ?? await TokenStorage().getRefreshToken();
            if (activeRefresh != null && activeRefresh.isNotEmpty) {
              try {
                final refreshResponse = await _dio.post(
                  '$_baseUrl/auth/refresh',
                  data: {'refreshToken': activeRefresh},
                  options: Options(extra: {'isRetry': true}),
                );
                final data = _asMap(refreshResponse.data);
                final newToken = data['token'] as String?;
                final newRefreshToken = data['refreshToken'] as String?;
                if (newToken != null && newToken.isNotEmpty) {
                  await setToken(newToken, refreshToken: newRefreshToken);

                  final retryOptions = err.requestOptions;
                  retryOptions.headers['Authorization'] = 'Bearer $newToken';
                  retryOptions.extra['isRetry'] = true;

                  final response = await _dio.fetch(retryOptions);
                  handler.resolve(response);
                  return;
                }
              } catch (_) {
                // Faqat refresh endpointi 401 yoki 403 bergandagina tokenni tozalaymiz (tarmoq xatosida emas)
                if (err.response?.statusCode == 401 || err.response?.statusCode == 403) {
                  await clearToken();
                }
              }
            }
          }
        }
        handler.next(err);
      },
    ));
  }

  String get baseUrl => _baseUrl;
  String get socketUrl => _baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  String? get token => _token ?? TokenStorage().token;
  String? get refreshToken => _refreshToken ?? TokenStorage().refreshToken;
  bool get isAuthenticated => (_token != null && _token!.isNotEmpty) || TokenStorage().hasToken;

  /// Resurs (rasm) havolasini to'liq HTTPS / Backend URL formatiga o'tkazadi.
  /// Localhost (127.0.0.1, 10.0.2.2, 192.168...) hamda nisbiy yo'llarni (/api/upload/..., /uploads/...)
  /// doimiy backend manzili (socketUrl) ga o'tkazadi.
  String resolveImageUrl(String? rawUrl) {
    if (rawUrl == null) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('data:image/') || trimmed.startsWith('assets/')) {
      return trimmed;
    }

    final localHostPattern = RegExp(
      r'^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.\d+\.\d+|0\.0\.0\.0)(:\d+)?',
      caseSensitive: false,
    );

    if (localHostPattern.hasMatch(trimmed)) {
      final pathPart = trimmed.replaceFirst(localHostPattern, '');
      final cleanPath = pathPart.startsWith('/') ? pathPart : '/$pathPart';
      return '$socketUrl$cleanPath';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (socketUrl.startsWith('https://') && trimmed.startsWith('http://')) {
        return trimmed.replaceFirst('http://', 'https://');
      }
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return '$socketUrl$trimmed';
    }

    return '$socketUrl/$trimmed';
  }

  /// Ilova ishga tushganda chaqiriladi: saqlangan tokenni xotiraga yuklaydi.
  Future<void> init({String? overrideBaseUrl}) async {
    if (overrideBaseUrl != null && overrideBaseUrl.isNotEmpty) {
      _baseUrl = overrideBaseUrl;
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedUrl = prefs.getString('custom_api_base_url');
        if (savedUrl != null && savedUrl.isNotEmpty) {
          // Eski, nostandart yoki local IP (localhost, 127.0.0.1, 10.0.2.2, 192.168) larni tozalab,
          // barcha qurilmalarda YAGONA Production Railway manzilini ta'minlaymiz.
          final isInvalidUrl = savedUrl.contains('onrender.com') ||
              savedUrl.contains('localhost') ||
              savedUrl.contains('127.0.0.1') ||
              savedUrl.contains('10.0.2.2') ||
              savedUrl.contains('192.168.') ||
              savedUrl.contains('0.0.0.0') ||
              savedUrl.contains('app.zavero.uz');
          if (isInvalidUrl) {
            await prefs.remove('custom_api_base_url');
            _baseUrl = _defaultBaseUrl();
          } else {
            _baseUrl = savedUrl;
          }
        }
      } catch (_) {}
    }
    final isDirectorContext = kIsWeb && (Uri.base.fragment.contains('director') || Uri.base.path.contains('director'));
    try {
      await TokenStorage().init();
      _token = await TokenStorage().getToken(isDirector: isDirectorContext);
      _refreshToken = await TokenStorage().getRefreshToken(isDirector: isDirectorContext);
    } catch (e) {
      debugPrint('ApiClient init TokenStorage ogohlantirish: $e');
    }
  }

  void setBaseUrl(String url) => _baseUrl = url;

  Future<void> saveCustomBaseUrl(String url) async {
    _baseUrl = url.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_api_base_url', _baseUrl);
    } catch (e) {
      debugPrint('ApiClient saveCustomBaseUrl xatoligi: $e');
    }
  }

  Future<void> setToken(String token, {String? refreshToken, bool isDirector = false}) async {
    _token = token;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    await TokenStorage().saveTokens(
      token: token,
      refreshToken: refreshToken,
      isDirector: isDirector,
      cafeId: targetCafeId,
    );
  }

  Future<void> clearToken({bool isDirector = false}) async {
    _token = null;
    _refreshToken = null;
    targetCafeId = null;
    await TokenStorage().clearTokens(isDirector: isDirector);
  }

  /// So'nggi tizimga kirgan foydalanuvchi JSON'ini mahalliy saqlash (offline fallback uchun).
  Future<void> cacheUserJson(Map<String, dynamic> userJson, {bool isDirector = false}) async {
    final encoded = jsonEncode(userJson);
    final isDirectorUser = isDirector || userJson['role'] == 'director';
    final keyToUse = isDirectorUser ? _directorUserKey : _userKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyToUse, encoded);
      await prefs.setString(_userKey, encoded);
    } catch (_) {}

    unawaited(() async {
      try {
        await _storage
            .write(key: keyToUse, value: encoded)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
        await _storage
            .write(key: _userKey, value: encoded)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
      } catch (_) {}
    }());
  }

  Future<Map<String, dynamic>?> readCachedUserJson({bool isDirector = false}) async {
    final isDirectorContext = isDirector ||
        (kIsWeb && (Uri.base.fragment.contains('director') || Uri.base.path.contains('director')));
    final keyToUse = isDirectorContext ? _directorUserKey : _userKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      var raw = prefs.getString(keyToUse);
      if (raw == null || raw.isEmpty) {
        raw = prefs.getString(_userKey);
      }
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    try {
      var raw = await _storage
          .read(key: keyToUse)
          .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
      if (raw == null || raw.isEmpty) {
        raw = await _storage
            .read(key: _userKey)
            .timeout(const Duration(milliseconds: 1000), onTimeout: () => null);
      }
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    return null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  ApiException _toApiException(DioException e) {
    final data = e.response?.data;
    String message = 'Tarmoq xatoligi. Internet aloqasini tekshiring.';
    String? code;
    if (data is Map) {
      message = data['message']?.toString() ?? message;
      code = data['code']?.toString() ?? data['error']?.toString();
    } else if (e.response != null) {
      message = 'Server xatoligi (${e.response?.statusCode}).';
    }
    return ApiException(message, statusCode: e.response?.statusCode, code: code);
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
    // cafeId=local_default so'rovlarini to'xtatamiz
    if (path.contains('cafeId=local_default') || query?['cafeId'] == 'local_default') {
      debugPrint('ℹ️ [ApiClient] "local_default" so\'rovi bekor qilindi ($path)');
      return <String, dynamic>{'hasStation': false, 'isPrinterReady': false, 'success': false};
    }

    final cacheKey = '$path?${query != null ? jsonEncode(query) : ''}';

    // Bir vaqtning o'zida yuborilgan bir xil GET so'rovini qayta yubormaymiz (Deduplication)
    if (_pendingGetFutures.containsKey(cacheKey)) {
      return await _pendingGetFutures[cacheKey]!;
    }

    final future = _executeGetWithRetry(path, query: query);
    _pendingGetFutures[cacheKey] = future;

    try {
      final res = await future;
      return res;
    } finally {
      _pendingGetFutures.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _executeGetWithRetry(String path,
      {Map<String, dynamic>? query}) async {
    int attempts = 0;
    const maxAttempts = 2;
    while (true) {
      attempts++;
      try {
        final res = await _dio.get(path, queryParameters: query);
        return _asMap(res.data);
      } on DioException catch (e) {
        final isNetworkGlitch = e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError;
        if (isNetworkGlitch && attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        throw _toApiException(e);
      }
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic body}) async {
    try {
      final res = await _dio.post(path, data: body);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> put(String path, {dynamic body}) async {
    try {
      final res = await _dio.put(path, data: body);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic body}) async {
    try {
      final res = await _dio.patch(path, data: body);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return _asMap(res.data);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Rasm faylini (File yoki Uint8List byte'larini) POST /upload orqali multipart yuborish. Backend URL qaytaradi.
  Future<String?> uploadImage(dynamic fileOrBytes, {String? filename}) async {
    try {
      MultipartFile multipartFile;
      if (kIsWeb) {
        if (fileOrBytes is Uint8List) {
          multipartFile = MultipartFile.fromBytes(fileOrBytes, filename: filename ?? 'upload.jpg');
        } else if (fileOrBytes is List<int>) {
          multipartFile = MultipartFile.fromBytes(fileOrBytes, filename: filename ?? 'upload.jpg');
        } else {
          return null;
        }
      } else {
        if (fileOrBytes is File) {
          multipartFile = await MultipartFile.fromFile(fileOrBytes.path);
        } else if (fileOrBytes is Uint8List || fileOrBytes is List<int>) {
          multipartFile = MultipartFile.fromBytes(fileOrBytes as List<int>, filename: filename ?? 'upload.jpg');
        } else {
          return null;
        }
      }
      final formData = FormData.fromMap({
        'image': multipartFile,
      });
      final res = await _dio.post('/upload', data: formData);
      final data = _asMap(res.data);
      return data['url'] as String?;
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Backend ping — GET /health (base URL'dan /api siz).
  Future<Map<String, dynamic>?> health() async {
    try {
      final res = await _dio.get('$socketUrl/health');
      return _asMap(res.data);
    } catch (e) {
      return null;
    }
  }

  /// ⚡ Ultra-yengil ping (HEAD / bo'sh GET, keep-alive orqali qayta ishlatiladi)
  Future<bool> pingFast() async {
    const pingHeaders = kIsWeb ? null : {'Connection': 'keep-alive'};
    try {
      final res = await _dio.get(
        '$socketUrl/ping',
        options: Options(
          responseType: ResponseType.plain,
          headers: pingHeaders,
        ),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      try {
        final res = await _dio.get(
          '$socketUrl/health',
          options: Options(
            responseType: ResponseType.plain,
            headers: pingHeaders,
          ),
        ).timeout(const Duration(seconds: 5));
        return res.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  /// GET /api/sync/bootstrap — Oflayn rejim uchun to'liq boshlang'ich ma'lumotlar
  Future<Map<String, dynamic>> syncBootstrap() async {
    return await get('/sync/bootstrap');
  }

  /// GET /api/sync/changes?since=<ISO_DATE> — Delta o'zgarishlar
  Future<Map<String, dynamic>> syncChanges(DateTime since) async {
    return await get('/sync/changes', query: {'since': since.toIso8601String()});
  }

  /// POST /api/sync/push — Batch amallarni yuborish
  Future<Map<String, dynamic>> syncPush(List<Map<String, dynamic>> operations) async {
    return await post('/sync/push', body: {'operations': operations});
  }
}
