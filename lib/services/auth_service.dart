import 'dart:async';

import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'cloud_service.dart';
import 'socket_service.dart';

/// Firebase `User` o'rniga ishlatiladigan yengil sessiya modeli.
/// Faqat backend JWT orqali tasdiqlangan foydalanuvchi haqida minimal
/// ma'lumot (uid, email, username) saqlaydi.
class SessionUser {
  final String uid;
  final String? email;
  final String? username;

  const SessionUser({required this.uid, this.email, this.username});
}

/// Backend REST API (JWT) + Socket.IO orqali autentifikatsiya va profil boshqaruvi.
/// Har bir foydalanuvchi o'z `cafeId` workspace'iga kiradi.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _api = ApiClient();
  final CloudService _cloudService = CloudService();

  final StreamController<SessionUser?> _sessionController =
      StreamController<SessionUser?>.broadcast();

  SessionUser? _currentSession;

  Stream<SessionUser?> get authStateChanges => _sessionController.stream;

  /// Firebase davridagi nom bilan qoladi — main.dart shu nomni chaqiradi.
  SessionUser? get currentFirebaseUser => _currentSession;

  /// Login yoki emailni backend `username` formatiga o'tkazish
  String normalizeEmail(String input) {
    final trimmed = input.trim().toLowerCase().replaceAll(' ', '_');
    if (trimmed.contains('@')) return trimmed;
    return '$trimmed@zavero.pos';
  }

  /// Username dan barqaror cafeId hosil qilish (masalan: cafe1, cafe2)
  String resolveCafeId(String loginOrEmail) {
    final raw = loginOrEmail.contains('@')
        ? loginOrEmail.split('@').first
        : loginOrEmail.trim();
    return raw
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  void _applySession(Map<String, dynamic> userJson, String token) {
    _currentSession = SessionUser(
      uid: '${userJson['id']}',
      email: userJson['email'] as String?,
      username: userJson['username'] as String?,
    );
    _sessionController.add(_currentSession);
    final cafeId = userJson['cafeId'] as String? ?? '';
    if (cafeId.isNotEmpty) {
      SocketService().connect(token: token, cafeId: cafeId);
    }
  }

  /// Tizimga kirish — POST /api/auth/login
  Future<AppUser> login(String loginOrEmail, String password) async {
    final cleanInput = loginOrEmail.trim().toLowerCase();
    try {
      final response = await _api.post('/auth/login', body: {
        'username': cleanInput,
        'password': password,
      }).timeout(const Duration(seconds: 25));
      final token = response['token'] as String;
      final userJson = Map<String, dynamic>.from(response['user'] as Map);

      if (response['isBlocked'] == true) {
        userJson['isBlocked'] = true;
      }
      if (response['isExpired'] == true) {
        userJson['isExpired'] = true;
      }
      if (response['cafe'] is Map) {
        final c = response['cafe'] as Map;
        userJson['cafeName'] = c['name']?.toString() ?? '';
        userJson['receiptName'] = c['receiptName']?.toString() ?? '';
        userJson['cafeEndDate'] = c['endDate']?.toString();
      }

      await _api.setToken(token);
      await _api.cacheUserJson(userJson);
      _applySession(userJson, token);
      return AppUser.fromJson(userJson);
    } catch (e) {
      // 🛡️ OFFLINE RETRIEVAL: Agar internet bo'lmasa, keshdagi sessiyadan yuklaymiz
      final isNetwork = e is TimeoutException ||
          e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('failed host lookup') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('clientexception') ||
          (e is ApiException && ((e.statusCode ?? 0) == 0 || (e.statusCode ?? 0) >= 500));

      if (isNetwork) {
        final cached = await _api.readCachedUserJson();
        if (cached != null) {
          final uName = (cached['username'] ?? '').toString().toLowerCase();
          final uEmail = (cached['email'] ?? '').toString().toLowerCase();
          if (uName == cleanInput || uEmail == cleanInput) {
            _applySession(cached, _api.token ?? 'offline_token');
            return AppUser.fromJson(cached);
          }
        }
      }

      if (e is ApiException) {
        throw Exception(e.message);
      }
      throw Exception(e.toString());
    }
  }

  /// Yangi cafe account ochish — POST /api/auth/register
  Future<AppUser> register({
    required String name,
    String surname = '',
    required String loginOrEmail,
    required String password,
    String phone = '',
    UserRole role = UserRole.admin,
  }) async {
    final cleanUsername = resolveCafeId(loginOrEmail);
    if (password.trim().length < 3) {
      throw Exception('Parol kamida 3 ta belgidan iborat bo\'lishi kerak');
    }

    try {
      final response = await _api.post('/auth/register', body: {
        'username': cleanUsername,
        'password': password.trim(),
        'name': name.trim().isEmpty ? cleanUsername : name.trim(),
        'surname': surname.trim(),
        'phone': phone.trim(),
        'role': role.name,
      });
      final token = response['token'] as String;
      final userJson = Map<String, dynamic>.from(response['user'] as Map);
      await _api.setToken(token);
      await _api.cacheUserJson(userJson);
      _applySession(userJson, token);
      // Eski Firestore oqimida register keyin initializeNewCafe chaqirilardi —
      // endi backend register paytida avtomatik seed qiladi, shuning uchun
      // bu yerda hech narsa qilinmaydi (metod pastda no-op sifatida saqlanadi).
      await _cloudService.initializeNewCafe(userJson['cafeId'] as String? ?? cleanUsername);
      return AppUser.fromJson(userJson);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  /// Backendda parolni tiklash email orqali qo'llab-quvvatlanmaydi.
  Future<void> sendPasswordReset(String email) async {
    throw Exception(
        'Parolni email orqali tiklash hozircha qo\'llab-quvvatlanmaydi. Administratordan yangi parol so\'rang.');
  }

  Future<void> logout() async {
    await _api.clearToken();
    SocketService().disconnect();
    _currentSession = null;
    _sessionController.add(null);
  }

  /// GET /api/auth/me — saqlangan token bilan joriy foydalanuvchini olish
  Future<AppUser?> getCurrentUserDetails() async {
    if (_api.token == null || _api.token!.isEmpty) return null;
    try {
      final response = await _api.get('/auth/me');
      final userJson = Map<String, dynamic>.from(response['user'] as Map);
      await _api.cacheUserJson(userJson);
      _applySession(userJson, _api.token!);
      return AppUser.fromJson(userJson);
    } catch (e) {
      debugPrint('getCurrentUserDetails xatoligi: $e');
      return null;
    }
  }

  Future<void> changePassword(String newPassword) async {
    if (newPassword.trim().length < 3) {
      throw Exception('Parol kamida 3 ta belgidan iborat bo\'lishi kerak');
    }
    try {
      await _api.put('/auth/password', body: {'newPassword': newPassword.trim()});
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<AppUser> changeCredentials({
    String? oldLogin,
    required String oldPassword,
    String? newLogin,
    String? newPassword,
  }) async {
    if (oldPassword.trim().isEmpty) {
      throw Exception('Eski parolni kiriting');
    }
    try {
      final response = await _api.put('/auth/change-credentials', body: {
        if (oldLogin != null && oldLogin.trim().isNotEmpty) 'oldLogin': oldLogin.trim(),
        'oldPassword': oldPassword.trim(),
        if (newLogin != null && newLogin.trim().isNotEmpty) 'newLogin': newLogin.trim(),
        if (newPassword != null && newPassword.trim().isNotEmpty) 'newPassword': newPassword.trim(),
      });

      final token = response['token'] as String?;
      final userJson = Map<String, dynamic>.from(response['user'] as Map);
      if (token != null && token.isNotEmpty) {
        await _api.setToken(token);
        _applySession(userJson, token);
      }
      await _api.cacheUserJson(userJson);
      return AppUser.fromJson(userJson);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateUserProfile({
    required String uid,
    required String name,
    String surname = '',
    required String username,
    String phone = '',
  }) async {
    try {
      await _api.put('/auth/profile', body: {
        'name': name.trim(),
        'surname': surname.trim(),
        'username': username.trim(),
        'phone': phone.trim(),
      });
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> updateProfile({
    required String name,
    String? surname,
    String? phone,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (surname != null) body['surname'] = surname;
    if (phone != null) body['phone'] = phone;
    try {
      await _api.put('/auth/profile', body: body);
    } on ApiException catch (e) {
      throw Exception(e.message);
    }
  }
}
