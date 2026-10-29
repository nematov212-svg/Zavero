import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class PinSecurityService {
  static final PinSecurityService _instance = PinSecurityService._internal();
  factory PinSecurityService() => _instance;
  PinSecurityService._internal();

  static const String _kDirectorPinKey = 'zavero_director_pin_code';
  static const String _kDirectorUserKey = 'zavero_director_saved_user_json';

  static const String _kCafePinKey = 'zavero_cafe_pin_code';
  static const String _kCafeUserKey = 'zavero_cafe_saved_user_json';

  static const String _kUserPinKeyPrefix = 'zavero_user_pin_';
  static const String _kUserSavedPrefix = 'zavero_user_saved_';
  static const String _kActiveLockedUidKey = 'zavero_active_locked_user_id';

  Future<String?> getDirectorPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDirectorPinKey);
  }

  Future<String?> getCafePin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCafePinKey);
  }

  Future<String?> getUserPin(dynamic userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_kUserPinKeyPrefix$userId');
  }

  Future<bool> hasUserPin(dynamic userId) async {
    final pin = await getUserPin(userId);
    return pin != null && pin.isNotEmpty;
  }

  Future<bool> hasAnyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final dPin = prefs.getString(_kDirectorPinKey);
    final cPin = prefs.getString(_kCafePinKey);
    if ((dPin != null && dPin.isNotEmpty) || (cPin != null && cPin.isNotEmpty)) {
      return true;
    }
    final activeUid = prefs.getString(_kActiveLockedUidKey);
    if (activeUid != null) {
      final uPin = prefs.getString('$_kUserPinKeyPrefix$activeUid');
      if (uPin != null && uPin.isNotEmpty) return true;
    }
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_kUserPinKeyPrefix)) {
        final val = prefs.getString(key);
        if (val != null && val.isNotEmpty) return true;
      }
    }
    return false;
  }

  Future<void> saveUserPin(String pin, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = user.id.toString();
    await prefs.setString('$_kUserPinKeyPrefix$uid', pin.trim());
    await prefs.setString('$_kUserSavedPrefix$uid', jsonEncode(user.toJson()));
    await prefs.setString(_kActiveLockedUidKey, uid);
    // Also save as cafe pin fallback
    await prefs.setString(_kCafePinKey, pin.trim());
    await prefs.setString(_kCafeUserKey, jsonEncode(user.toJson()));
  }

  Future<void> removeUserPin(dynamic userId) async {
    final prefs = await SharedPreferences.getInstance();
    final uid = userId.toString();
    await prefs.remove('$_kUserPinKeyPrefix$uid');
    await prefs.remove('$_kUserSavedPrefix$uid');
    final active = prefs.getString(_kActiveLockedUidKey);
    if (active == uid) {
      await prefs.remove(_kActiveLockedUidKey);
    }
    await prefs.remove(_kCafePinKey);
    await prefs.remove(_kCafeUserKey);
  }

  Future<void> saveDirectorPin(String pin, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDirectorPinKey, pin.trim());
    await prefs.setString(_kDirectorUserKey, jsonEncode(user.toJson()));
  }

  Future<void> removeDirectorPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDirectorPinKey);
    await prefs.remove(_kDirectorUserKey);
  }

  Future<void> saveCafePin(String pin, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCafePinKey, pin.trim());
    await prefs.setString(_kCafeUserKey, jsonEncode(user.toJson()));
  }

  Future<void> removeCafePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCafePinKey);
    await prefs.remove(_kCafeUserKey);
  }

  Future<Map<String, dynamic>> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final clean = enteredPin.trim();

    // 1. Check active user pin
    final activeUid = prefs.getString(_kActiveLockedUidKey);
    if (activeUid != null) {
      final uPin = prefs.getString('$_kUserPinKeyPrefix$activeUid');
      if (uPin != null && uPin == clean) {
        final uStr = prefs.getString('$_kUserSavedPrefix$activeUid') ?? prefs.getString(_kCafeUserKey);
        if (uStr != null && uStr.isNotEmpty) {
          try {
            final user = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(uStr) as Map));
            return {
              'success': true,
              'role': user.role.name,
              'user': user,
            };
          } catch (_) {}
        }
      }
    }

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_kUserPinKeyPrefix)) {
        final val = prefs.getString(key);
        if (val == clean) {
          final uid = key.replaceFirst(_kUserPinKeyPrefix, '');
          final uStr = prefs.getString('$_kUserSavedPrefix$uid') ?? prefs.getString(_kCafeUserKey);
          if (uStr != null && uStr.isNotEmpty) {
            try {
              final user = AppUser.fromJson(Map<String, dynamic>.from(jsonDecode(uStr) as Map));
              return {
                'success': true,
                'role': user.role.name,
                'user': user,
              };
            } catch (_) {}
          }
        }
      }
    }

    // 2. Check director pin
    final dPin = prefs.getString(_kDirectorPinKey);
    if (dPin != null && dPin == clean) {
      final userStr = prefs.getString(_kDirectorUserKey);
      if (userStr != null && userStr.isNotEmpty) {
        try {
          final userJson = Map<String, dynamic>.from(jsonDecode(userStr) as Map);
          final user = AppUser.fromJson(userJson);
          return {
            'success': true,
            'role': 'director',
            'user': user,
          };
        } catch (_) {}
      }
    }

    // 3. Check cafe pin
    final cPin = prefs.getString(_kCafePinKey);
    if (cPin != null && cPin == clean) {
      final userStr = prefs.getString(_kCafeUserKey);
      if (userStr != null && userStr.isNotEmpty) {
        try {
          final userJson = Map<String, dynamic>.from(jsonDecode(userStr) as Map);
          final user = AppUser.fromJson(userJson);
          return {
            'success': true,
            'role': 'cafe',
            'user': user,
          };
        } catch (_) {}
      }
    }

    return {'success': false, 'message': 'PIN kod noto‘g‘ri'};
  }
}
