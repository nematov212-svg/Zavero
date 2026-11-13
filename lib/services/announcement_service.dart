import '../models/models.dart';
import 'api_client.dart';

class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  final ApiClient _api = ApiClient();

  /// Kafe uchun e'lonlar ro'yxatini olish
  Future<List<AnnouncementItem>> getAnnouncements() async {
    try {
      final res = await _api.get('/announcements');
      if (res['announcements'] is List) {
        return (res['announcements'] as List)
            .map((e) => AnnouncementItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Bitta e'lonni o'qilgan deb belgilash
  Future<bool> markAsRead(int announcementId) async {
    try {
      final res = await _api.post('/announcements/$announcementId/read');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Barcha e'lonlarni o'qilgan deb belgilash
  Future<bool> markAllAsRead() async {
    try {
      final res = await _api.post('/announcements/read-all');
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }
}

