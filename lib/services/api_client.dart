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
  static const _userKey = 'zavero_current_user';

  /// Backend serverless / cloud manzili (Render: https://zavero.onrender.com/api).
  /// --dart-define=API_BASE_URL=... orqali o'zgartirish mumkin.
  static String _defaultBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return 'https://zavero.onrender.com/api';
  }

  late Dio _dio;
  String _baseUrl = _defaultBaseUrl();
  String? _token;
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
        handler.next(options);
      },
    ));
  }

  String get baseUrl => _baseUrl;
  String get socketUrl => _baseUrl.replaceAll(RegExp(r'/api/?$'), '');
  String? get token => _token;

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
          if (savedUrl.contains('family-cafe-backend-eu.onrender.com') ||
              savedUrl.contains('localhost:3000') ||
              savedUrl.contains('10.0.2.2:3000')) {
            await prefs.remove('custom_api_base_url');
            _baseUrl = _defaultBaseUrl();
          } else {
            _baseUrl = savedUrl;
          }
        }
      } catch (_) {}
    }
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('ApiClient init xatoligi: $e');
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

  Future<void> setToken(String token) async {
    _token = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (e) {
      debugPrint('ApiClient setToken xatoligi: $e');
    }
  }

  Future<void> clearToken() async {
    _token = null;
    targetCafeId = null;
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    } catch (e) {
      debugPrint('ApiClient clearToken xatoligi: $e');
    }
  }

  /// So'nggi tizimga kirgan foydalanuvchi JSON'ini mahalliy saqlash (offline fallback uchun).
  Future<void> cacheUserJson(Map<String, dynamic> userJson) async {
    try {
      await _storage.write(key: _userKey, value: jsonEncode(userJson));
    } catch (e) {
      debugPrint('ApiClient cacheUserJson xatoligi: $e');
    }
  }

  Future<Map<String, dynamic>?> readCachedUserJson() async {
    try {
      final raw = await _storage.read(key: _userKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('ApiClient readCachedUserJson xatoligi: $e');
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
      code = data['code']?.toString();
    } else if (e.response != null) {
      message = 'Server xatoligi (${e.response?.statusCode}).';
    }
    return ApiException(message, statusCode: e.response?.statusCode, code: code);
  }

  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? query}) async {
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
}
