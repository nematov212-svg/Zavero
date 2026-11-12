library;

/// ZAVERO POS — Xavfsiz raqamli tiplarni o'qish yordamchi funksiyalari (Bulletproof Parsing)
/// Serverdan keladigan har qanday ma'lumot (int, double, num, String "28", "60000.00", null)
/// tiplarini runtime TypeError keltirib chiqarmasdan xavfsiz o'qiydi.

int safeInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final cleaned = v.trim();
    if (cleaned.isEmpty) return fallback;
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt() ?? fallback;
  }
  return fallback;
}

int? safeNullableInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final cleaned = v.trim();
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt();
  }
  return null;
}

double safeDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) {
    final cleaned = v.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return fallback;
    return double.tryParse(cleaned) ?? fallback;
  }
  return fallback;
}

double? safeNullableDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) {
    final cleaned = v.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
  return null;
}

num safeNum(dynamic v, [num fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v;
  if (v is String) {
    final cleaned = v.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return fallback;
    return num.tryParse(cleaned) ?? fallback;
  }
  return fallback;
}

num? safeNullableNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) {
    final cleaned = v.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return num.tryParse(cleaned);
  }
  return null;
}

