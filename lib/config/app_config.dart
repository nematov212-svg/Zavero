/// Global ilova konfiguratsiyasi va konstantalar
class AppConfig {
  AppConfig._();

  /// Standart kafe Instagram sahifasi havolasi
  static const String defaultCafeInstagramUrl = 'https://www.instagram.com/family_cafe.1';

  /// Instagram profil havolasini olish
  static String getCafeInstagramUrl([String? customUrl]) {
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim();
    }
    return defaultCafeInstagramUrl;
  }
}

