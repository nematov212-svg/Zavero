import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supabase Realtime konfiguratsiyasi.
/// - [url]: Supabase loyihangiz URL manzili (masalan: https://your-project.supabase.co)
/// - [anonKey]: Supabase Public Anon Key (faqat frontend va Realtime uchun mo'ljallangan, xavfsiz)
class SupabaseConfig {
  static const String _defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder.supabase.co',
  );

  static const String _defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder',
  );

  static String _url = _defaultUrl;
  static String _anonKey = _defaultAnonKey;

  static String get url => _url;
  static String get anonKey => _anonKey;

  static bool get isConfigured =>
      _url.isNotEmpty &&
      !_url.contains('placeholder') &&
      _anonKey.isNotEmpty &&
      !_anonKey.contains('placeholder');

  static Future<void> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('supabase_url');
      final savedKey = prefs.getString('supabase_anon_key');
      if (savedUrl != null && savedUrl.isNotEmpty) _url = savedUrl;
      if (savedKey != null && savedKey.isNotEmpty) _anonKey = savedKey;
    } catch (e) {
      debugPrint('SupabaseConfig load error: $e');
    }
  }

  static Future<void> setConfig(String newUrl, String newKey) async {
    _url = newUrl.trim();
    _anonKey = newKey.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', _url);
      await prefs.setString('supabase_anon_key', _anonKey);
    } catch (e) {
      debugPrint('SupabaseConfig save error: $e');
    }
  }
}
