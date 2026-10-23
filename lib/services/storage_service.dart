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
  /// Web (Uint8List baytlar) va Mobil/Desktop (File) platformalari uchun to'liq moslashtirilgan.
  /// Qaytaradi: Doimiy HTTPS backend havolasi (URL)
  Future<String?> uploadProductImage({
    required String ownerId,
    required int productId,
    dynamic imageFile,
    Uint8List? imageBytes,
    String? filename,
  }) async {
    try {
      if (kIsWeb) {
        if (imageBytes != null) {
          final url = await _api.uploadImage(imageBytes, filename: filename ?? 'product_$productId.jpg');
          return url;
        } else if (imageFile != null) {
          final url = await _api.uploadImage(imageFile, filename: filename);
          return url;
        }
        return null;
      }

      if (imageFile is File) {
        if (!await imageFile.exists()) {
          debugPrint('StorageService: Rasm fayli topilmadi: ${imageFile.path}');
          return null;
        }
        final url = await _api.uploadImage(imageFile);
        return url;
      } else if (imageBytes != null) {
        final url = await _api.uploadImage(imageBytes, filename: filename ?? 'product_$productId.jpg');
        return url;
      } else if (imageFile != null) {
        final url = await _api.uploadImage(imageFile, filename: filename);
        return url;
      }
      return null;
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
