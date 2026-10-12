import 'dart:io';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Backend `/api/upload` xizmati orqali rasm yuklash (Firebase Storage o'rniga).
/// Mahsulot / Taom rasmlari va boshqa media fayllar shu orqali saqlanadi.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final ApiClient _api = ApiClient();

  /// Mahsulot / Taom rasmini backendga yuklash (multipart, POST /api/upload).
  /// [ownerId] va [productId] eski Firebase yo'lida papka nomlash uchun
  /// ishlatilgan edi — backend endi bitta umumiy `/uploads` papkasida
  /// noyob fayl nomi bilan saqlaydi, shuning uchun bu yerda faqat log uchun
  /// ishlatiladi (parametrlar signaturada saqlanadi, chunki main.dart shu
  /// nomlarni chaqiradi).
  /// Qaytaradi: Doimiy HTTPS backend havolasi (URL)
  Future<String?> uploadProductImage({
    required String ownerId,
    required int productId,
    required File imageFile,
  }) async {
    try {
      if (!await imageFile.exists()) {
        debugPrint('StorageService: Rasm fayli topilmadi: ${imageFile.path}');
        return null;
      }

      final url = await _api.uploadImage(imageFile);
      if (url != null) {
        debugPrint('StorageService: Rasm muvaffaqiyatli yuklandi -> $url');
      }
      return url;
    } catch (e) {
      debugPrint('StorageService rasm yuklashda xatolik: $e');
      return null;
    }
  }

  /// Backendda hozircha statik fayllarni o'chirish endpointi yo'q
  /// (`/uploads` papkasi statik serve qilinadi). Eski rasm shunchaki
  /// diskda qoladi — bu funksional jihatdan zararsiz, shuning uchun
  /// no-op sifatida qoldiriladi (chaqiruvchi kod o'zgarishsiz ishlaydi).
  Future<void> deleteImageByUrl(String imageUrl) async {
    debugPrint('StorageService: eski rasmni o\'chirish backendda qo\'llab-quvvatlanmaydi ($imageUrl)');
  }
}
