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

  Future<String?> getDirectorPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDirectorPinKey);
  }

  Future<String?> getCafePin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCafePinKey);
  }

  Future<bool> hasAnyPin() async {
    final prefs = await SharedPreferences.getInstance();
    final dPin = prefs.getString(_kDirectorPinKey);
    final cPin = prefs.getString(_kCafePinKey);
    return (dPin != null && dPin.isNotEmpty) || (cPin != null && cPin.isNotEmpty);
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
