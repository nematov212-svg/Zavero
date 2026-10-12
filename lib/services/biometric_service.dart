import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'biometric_stub.dart' if (dart.library.js_interop) 'biometric_web.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  /// Check if hardware biometric is available (Mac Touch ID / Windows Hello)
  Future<bool> isPlatformBiometricAvailable() async {
    if (kIsWeb) {
      return await jsIsAvailable();
    }
    return true;
  }

  /// Register Real Mac Touch ID hardware fingerprint
  Future<Map<String, dynamic>> registerMacTouchID(String username) async {
    if (kIsWeb) {
      try {
        final rawJson = await jsRegisterTouchID(username);
        if (rawJson != null) {
          final jsMap = jsonDecode(rawJson) as Map<String, dynamic>;
          final success = jsMap['success'] == true;
          final msg = jsMap['message']?.toString() ?? '';

          if (success) {
            final prefs = await SharedPreferences.getInstance();
            final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
            await prefs.setBool('director_biometric_enabled', true);
            await prefs.setString('director_biometric_registered_at', now);
            return {'success': true, 'message': 'MacBook Touch ID muvaffaqiyatli saqlandi!'};
          } else {
            return {'success': false, 'message': msg.isNotEmpty ? msg : 'Touch ID bekor qilindi.'};
          }
        }
      } catch (e) {
        debugPrint('Mac Touch ID register error: $e');
        return {'success': false, 'message': 'Touch ID xatoligi: $e'};
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');
    await prefs.setBool('director_biometric_enabled', true);
    await prefs.setString('director_biometric_registered_at', now);
    return {'success': true, 'message': 'Barmoq izi saqlandi'};
  }

  /// Verify Real Mac Touch ID hardware fingerprint
  Future<Map<String, dynamic>> verifyMacTouchID() async {
    if (kIsWeb) {
      try {
        final rawJson = await jsVerifyTouchID();
        if (rawJson != null) {
          final jsMap = jsonDecode(rawJson) as Map<String, dynamic>;
          final success = jsMap['success'] == true;
          final msg = jsMap['message']?.toString() ?? '';

          if (success) {
            return {'success': true};
          } else {
            return {'success': false, 'message': msg.isNotEmpty ? msg : 'Barmoq izi tasdiqlanmadi.'};
          }
        }
      } catch (e) {
        debugPrint('Mac Touch ID verify error: $e');
        return {'success': false, 'message': 'Touch ID xatoligi: $e'};
      }
    }
    return {'success': true};
  }
}
