import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _tokenKey = 'zavero_auth_token';
  static const _refreshTokenKey = 'zavero_refresh_token';
  static const _userKey = 'zavero_current_user';

  static const _directorTokenKey = 'zavero_director_auth_token';
  static const _directorRefreshTokenKey = 'zavero_director_refresh_token';
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
      connectTimeout: const Duration(seconds: 35),
      receiveTimeout: const Duration(seconds: 35),
      sendTimeout: const Duration(seconds: 35),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.baseUrl = _baseUrl;
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        if (targetCafeId != null && targetCafeId!.isNotEmpty) {
          options.headers['x-cafe-id'] = targetCafeId;
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

          if (!isAlreadyRetry && !isAuthEndpoint && _refreshToken != null && _refreshToken!.isNotEmpty) {
            try {
              final refreshResponse = await _dio.post(
                '$_baseUrl/auth/refresh',
                data: {'refreshToken': _refreshToken},
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
              await clearToken();
            }
          }
        }
        handler.next(err);
      },
    ));
  }

  String get baseUrl => _baseUrl;
  String get socketUrl => _baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

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
    try {
      final isDirectorContext = kIsWeb && (Uri.base.fragment.contains('director') || Uri.base.path.contains('director'));
      final activeTokenKey = isDirectorContext ? _directorTokenKey : _tokenKey;
      final activeRefreshKey = isDirectorContext ? _directorRefreshTokenKey : _refreshTokenKey;

      _token = await _storage.read(key: activeTokenKey);
      _refreshToken = await _storage.read(key: activeRefreshKey);
      if (_token == null || _token!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString(activeTokenKey);
        _refreshToken = prefs.getString(activeRefreshKey);
      }
      // Agar director kontekstida topilmasa, umumiy tokenga fallback qilamiz
      if (isDirectorContext && (_token == null || _token!.isEmpty)) {
        _token = await _storage.read(key: _tokenKey);
        _refreshToken = await _storage.read(key: _refreshTokenKey);
        if (_token == null || _token!.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          _token = prefs.getString(_tokenKey);
          _refreshToken = prefs.getString(_refreshTokenKey);
        }
      }
    } catch (e) {
      debugPrint('ApiClient init xatoligi: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString(_tokenKey);
        _refreshToken = prefs.getString(_refreshTokenKey);
      } catch (_) {}
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
    final keyToUse = isDirector ? _directorTokenKey : _tokenKey;
    final refreshKeyToUse = isDirector ? _directorRefreshTokenKey : _refreshTokenKey;

    try {
      await _storage.write(key: keyToUse, value: token);
      if (_refreshToken != null) {
        await _storage.write(key: refreshKeyToUse, value: _refreshToken);
      }
      await _storage.write(key: _tokenKey, value: token);
      if (_refreshToken != null) {
        await _storage.write(key: _refreshTokenKey, value: _refreshToken);
      }
    } catch (e) {
      debugPrint('ApiClient setToken xatoligi: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyToUse, token);
      if (_refreshToken != null) {
        await prefs.setString(refreshKeyToUse, _refreshToken!);
      }
      await prefs.setString(_tokenKey, token);
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
    } catch (_) {}
  }

  Future<void> clearToken({bool isDirector = false}) async {
    _token = null;
    _refreshToken = null;
    targetCafeId = null;
    final isDirectorContext = isDirector ||
        (kIsWeb && (Uri.base.fragment.contains('director') || Uri.base.path.contains('director')));
    try {
      if (isDirectorContext) {
        await _storage.delete(key: _directorTokenKey);
        await _storage.delete(key: _directorRefreshTokenKey);
        await _storage.delete(key: _directorUserKey);
      }
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _refreshTokenKey);
      await _storage.delete(key: _userKey);
    } catch (e) {
      debugPrint('ApiClient clearToken xatoligi: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDirectorContext) {
        await prefs.remove(_directorTokenKey);
        await prefs.remove(_directorRefreshTokenKey);
        await prefs.remove(_directorUserKey);
      }
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userKey);
    } catch (_) {}
  }

  /// So'nggi tizimga kirgan foydalanuvchi JSON'ini mahalliy saqlash (offline fallback uchun).
  Future<void> cacheUserJson(Map<String, dynamic> userJson, {bool isDirector = false}) async {
    final encoded = jsonEncode(userJson);
    final isDirectorUser = isDirector || userJson['role'] == 'director';
    final keyToUse = isDirectorUser ? _directorUserKey : _userKey;

    try {
      await _storage.write(key: keyToUse, value: encoded);
      await _storage.write(key: _userKey, value: encoded);
    } catch (e) {
      debugPrint('ApiClient cacheUserJson xatoligi: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyToUse, encoded);
      await prefs.setString(_userKey, encoded);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> readCachedUserJson({bool isDirector = false}) async {
    final isDirectorContext = isDirector ||
        (kIsWeb && (Uri.base.fragment.contains('director') || Uri.base.path.contains('director')));
    final keyToUse = isDirectorContext ? _directorUserKey : _userKey;

    try {
      String? raw = await _storage.read(key: keyToUse);
      if (raw == null || raw.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(keyToUse);
      }
      if (raw == null || raw.isEmpty) {
        raw = await _storage.read(key: _userKey);
        if (raw == null || raw.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          raw = prefs.getString(_userKey);
        }
      }
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ApiClient readCachedUserJson xatoligi: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(keyToUse) ?? prefs.getString(_userKey);
        if (raw != null && raw.isNotEmpty) {
          return jsonDecode(raw) as Map<String, dynamic>;
        }
      } catch (_) {}
      return null;
    }
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
