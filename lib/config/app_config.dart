/// Global ilova konfiguratsiyasi va konstantalar
class AppConfig {
  AppConfig._();

  /// Standart kafe Instagram sahifasi havolasi (To'liq havola parametri bilan)
  static const String defaultCafeInstagramUrl =
      'https://www.instagram.com/family_cafe.1?exln=MWFtaHg2c2NqZW95Zg==';

  /// Instagram profil havolasini olish (custom bo'sh bo'lsa default qaytaradi)
  static String getCafeInstagramUrl([String? customUrl]) {
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      return customUrl.trim();
    }
    return defaultCafeInstagramUrl;
  }

  /// URL validatsiyasi (faqat http:// yoki https:// bilan boshlanishi kerak)
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final u = url.trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }
}
