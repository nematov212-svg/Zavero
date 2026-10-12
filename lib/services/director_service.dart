import '../models/models.dart';
import 'api_client.dart';

class DirectorService {
  static final DirectorService _instance = DirectorService._internal();
  factory DirectorService() => _instance;
  DirectorService._internal();

  final ApiClient _api = ApiClient();

  /// Tizim statistikasi va metrikalari
  Future<DirectorMetrics> getMetrics() async {
    final res = await _api.get('/director/metrics');
    if (res['metrics'] is Map) {
      return DirectorMetrics.fromJson(Map<String, dynamic>.from(res['metrics'] as Map));
    }
    return DirectorMetrics();
  }

  /// Barcha cafelar ro'yxati
  Future<List<CafeSaaSItem>> getCafes({String? q, String? status}) async {
    final query = <String, dynamic>{};
    if (q != null && q.trim().isNotEmpty) query['q'] = q.trim();
    if (status != null && status != 'all') query['status'] = status;

    final res = await _api.get('/director/cafes', query: query.isNotEmpty ? query : null);
    if (res['cafes'] is List) {
      return (res['cafes'] as List)
          .map((e) => CafeSaaSItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Cafe batafsil ma'lumotlari (ishchilar, qurilmalar, obuna)
  Future<Map<String, dynamic>> getCafeDetail(String cafeId) async {
    final res = await _api.get('/director/cafes/$cafeId');
    return res['cafe'] is Map ? Map<String, dynamic>.from(res['cafe'] as Map) : {};
  }

  /// Yangi cafe qo'shish
  Future<void> createCafe({
    String? cafeId,
    required String cafeName,
    String? receiptName,
    required String ownerName,
    String? ownerPhone,
    required String ownerEmail,
    required String ownerPassword,
    int durationDays = 30,
  }) async {
    await _api.post('/director/cafes', body: {
      if (cafeId != null && cafeId.isNotEmpty) 'cafeId': cafeId,
      'cafeName': cafeName.trim(),
      'receiptName': (receiptName != null && receiptName.trim().isNotEmpty)
          ? receiptName.trim()
          : cafeName.trim(),
      'ownerName': ownerName.trim(),
      'ownerPhone': ownerPhone?.trim() ?? '',
      'ownerEmail': ownerEmail.trim().toLowerCase(),
      'ownerPassword': ownerPassword.trim(),
      'durationDays': durationDays,
    });
  }

  /// Yangi foydalanuvchi yaratish (Cafe, Ishchi, Mijoz)
  Future<void> createUser({
    required String cafeId,
    required String name,
    String? surname,
    String? phone,
    required String role,
    required String email,
    required String password,
  }) async {
    await _api.post('/director/users', body: {
      'cafeId': cafeId,
      'name': name.trim(),
      'surname': surname?.trim() ?? '',
      'phone': phone?.trim() ?? '',
      'role': role,
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });
  }

  /// Cafeni bloklash
  Future<void> blockCafe(String cafeId, {String? reason}) async {
    await _api.post('/director/cafes/$cafeId/block', body: {
      'reason': reason ?? 'Director tomonidan bloklandi',
    });
  }

  /// Cafeni blokdan chiqarish
  Future<void> unblockCafe(String cafeId) async {
    await _api.post('/director/cafes/$cafeId/unblock');
  }

  /// Cafeni o'chirish (DELETE va POST fallback bilan)
  Future<void> deleteCafe(String cafeId) async {
    try {
      await _api.delete('/director/cafes/$cafeId');
    } catch (e) {
      try {
        await _api.post('/director/cafes/$cafeId/delete');
      } catch (_) {
        await _api.post('/director/cafes/delete', body: {'cafeId': cafeId});
      }
    }
  }

  /// Murojaatlar va muammolar ro'yxati (Support Tickets)
  Future<List<Map<String, dynamic>>> getSupportTickets() async {
    final res = await _api.get('/director/support-tickets');
    if (res['tickets'] is List) {
      return (res['tickets'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Muammoni tuzatishni boshlash (Kafeni vaqtincha to'xtatish)
  Future<void> startFixTicket(int ticketId) async {
    await _api.post('/director/support-tickets/$ticketId/start-fix');
  }

  /// Muammoni hal qilingan deb belgilash (Kafeni qayta ishga tushirish)
  Future<void> resolveTicket(int ticketId) async {
    await _api.post('/director/support-tickets/$ticketId/resolve');
  }

  /// Kafeda texnik ishlar rejimini yoqish/o'chirish
  Future<void> toggleMaintenance(String cafeId, bool isUnderMaintenance) async {
    await _api.post('/director/cafes/$cafeId/maintenance', body: {
      'isUnderMaintenance': isUnderMaintenance,
    });
  }

  /// Cafeni tahrirlash (nomi, egasi, tel, parol, muddat va status)
  Future<void> updateCafe({
    required String cafeId,
    String? cafeName,
    String? receiptName,
    String? ownerName,
    String? ownerPhone,
    String? ownerEmail,
    String? ownerPassword,
    String? address,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    await _api.put('/director/cafes/$cafeId', body: {
      if (cafeName != null) 'cafeName': cafeName.trim(),
      if (receiptName != null) 'receiptName': receiptName.trim(),
      if (ownerName != null) 'ownerName': ownerName.trim(),
      if (ownerPhone != null) 'ownerPhone': ownerPhone.trim(),
      if (ownerEmail != null) 'ownerEmail': ownerEmail.trim().toLowerCase(),
      if (ownerPassword != null && ownerPassword.trim().isNotEmpty)
        'ownerPassword': ownerPassword.trim(),
      if (address != null) 'address': address.trim(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
      if (status != null) 'status': status,
    });
  }

  /// Cafe to'liq operational xulosasi
  Future<Map<String, dynamic>> getCafeOverview(String cafeId) async {
    final res = await _api.get('/director/cafes/$cafeId/overview');
    return res;
  }

  /// Tanlangan cafe mahsulotlari ro'yxati
  Future<List<Product>> getProductsForCafe(String cafeId) async {
    final res = await _api.get('/products', query: {'cafeId': cafeId});
    if (res['products'] is List) {
      return (res['products'] as List)
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe uchun mahsulot saqlash/yangilash
  Future<Product?> saveProductForCafe(String cafeId, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);
    body['cafeId'] = cafeId;
    final res = await _api.post('/products', body: body);
    if (res['product'] is Map) {
      return Product.fromJson(Map<String, dynamic>.from(res['product'] as Map));
    }
    return null;
  }

  /// Tanlangan cafe mahsulotini o'chirish
  Future<void> deleteProductForCafe(String cafeId, int id) async {
    await _api.delete('/products/$id?cafeId=$cafeId');
  }

  /// Tanlangan cafe mahsulotlarini ommaviy o'chirish (Bulk delete)
  Future<void> deleteProductsBulkForCafe(String cafeId, List<int> productIds) async {
    await _api.post('/products/bulk-delete', body: {
      'cafeId': cafeId,
      'productIds': productIds,
    });
  }

  /// Tanlangan cafe kategoriyalari
  Future<List<Category>> getCategoriesForCafe(String cafeId) async {
    final res = await _api.get('/categories', query: {'cafeId': cafeId});
    if (res['categories'] is List) {
      return (res['categories'] as List)
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe uchun kategoriya saqlash
  Future<Category?> saveCategoryForCafe(String cafeId, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);
    body['cafeId'] = cafeId;
    final res = await _api.post('/categories', body: body);
    if (res['category'] is Map) {
      return Category.fromJson(Map<String, dynamic>.from(res['category'] as Map));
    }
    return null;
  }

  /// Tanlangan cafe kategoriyasini o'chirish
  Future<void> deleteCategoryForCafe(String cafeId, int id) async {
    await _api.delete('/categories/$id?cafeId=$cafeId');
  }

  /// Tanlangan cafe zallari
  Future<List<Hall>> getHallsForCafe(String cafeId) async {
    final res = await _api.get('/halls', query: {'cafeId': cafeId});
    if (res['halls'] is List) {
      return (res['halls'] as List)
          .map((e) => Hall.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe uchun zal qo'shish / tahrirlash
  Future<Hall?> saveHallForCafe(String cafeId, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);
    body['cafeId'] = cafeId;
    final res = await _api.post('/halls', body: body);
    if (res['hall'] is Map) {
      return Hall.fromJson(Map<String, dynamic>.from(res['hall'] as Map));
    }
    return null;
  }

  /// Tanlangan cafe zalini o'chirish
  Future<void> deleteHallForCafe(String cafeId, int id) async {
    await _api.delete('/halls/$id?cafeId=$cafeId');
  }

  /// Tanlangan cafe stollari
  Future<List<TableModel>> getTablesForCafe(String cafeId) async {
    final res = await _api.get('/tables', query: {'cafeId': cafeId});
    if (res['tables'] is List) {
      return (res['tables'] as List)
          .map((e) => TableModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe uchun stol qo'shish / yangilash
  Future<TableModel?> saveTableForCafe(String cafeId, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);
    body['cafeId'] = cafeId;
    final res = await _api.post('/tables', body: body);
    if (res['table'] is Map) {
      return TableModel.fromJson(Map<String, dynamic>.from(res['table'] as Map));
    }
    return null;
  }

  /// Tanlangan cafe stolini tahrirlash (nomi, o'rindiqlar, boshqa zalga ko'chirish)
  Future<TableModel?> updateTableForCafe(String cafeId, int tableId, Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data);
    body['cafeId'] = cafeId;
    final res = await _api.put('/tables/$tableId', body: body);
    if (res['table'] is Map) {
      return TableModel.fromJson(Map<String, dynamic>.from(res['table'] as Map));
    }
    return null;
  }

  /// Tanlangan cafe stolini o'chirish
  Future<void> deleteTableForCafe(String cafeId, int id) async {
    await _api.delete('/tables/$id?cafeId=$cafeId');
  }

  /// App Version ma'lumotlarini olish
  Future<Map<String, dynamic>> getAppVersion() async {
    final res = await _api.get('/app/version');
    return res;
  }

  /// App Version sozlamalarini yangilash (Director only)
  Future<void> updateAppVersion(Map<String, dynamic> data) async {
    await _api.put('/director/app-version', body: data);
  }

  /// Tanlangan cafe cheklari (To'lovlar)
  Future<List<Receipt>> getReceiptsForCafe(String cafeId) async {
    final res = await _api.get('/receipts', query: {'cafeId': cafeId});
    if (res['receipts'] is List) {
      return (res['receipts'] as List)
          .map((e) => Receipt.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe buyurtmalari (Orders)
  Future<List<CustomerOrder>> getOrdersForCafe(String cafeId) async {
    final res = await _api.get('/customer-orders', query: {'cafeId': cafeId});
    if (res['orders'] is List) {
      return (res['orders'] as List)
          .map((e) => CustomerOrder.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Tanlangan cafe sozlamalari
  Future<Map<String, dynamic>> getSettingsForCafe(String cafeId) async {
    final res = await _api.get('/cafe/settings', query: {'cafeId': cafeId});
    return res['settings'] is Map ? Map<String, dynamic>.from(res['settings'] as Map) : {};
  }

  /// Tanlangan cafe sozlamalarini yangilash
  Future<void> saveSettingsForCafe(String cafeId, Map<String, dynamic> settings) async {
    await _api.put('/cafe/settings', body: {'cafeId': cafeId, 'data': settings});
  }

  /// Ogohlantirishlar (Notifications) ro'yxati
  Future<List<Map<String, dynamic>>> getNotifications(String cafeId) async {
    final res = await _api.get('/notifications', query: {'cafeId': cafeId});
    if (res['notifications'] is List) {
      return (res['notifications'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  /// Director tomonidan yangi ogohlantirish yuborish
  Future<void> sendNotification({
    required String cafeId,
    required String title,
    required String message,
    String priority = 'normal',
    DateTime? scheduledAt,
  }) async {
    await _api.post('/notifications', body: {
      'cafeId': cafeId,
      'title': title.trim(),
      'message': message.trim(),
      'priority': priority,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
    });
  }

  /// Ogohlantirishni o'qilgan deb belgilash
  Future<void> markNotificationRead(int id, {String? cafeId}) async {
    await _api.put('/notifications/$id/read', body: {
      if (cafeId != null) 'cafeId': cafeId,
    });
  }

  /// Ogohlantirishni o'chirish
  Future<void> deleteNotification(int id, {String? cafeId}) async {
    final q = cafeId != null ? '?cafeId=$cafeId' : '';
    await _api.delete('/notifications/$id$q');
  }

  /// Obuna muddatini uzaytirish
  Future<String?> extendSubscription(String cafeId, {int? days, String? newEndDate}) async {
    final res = await _api.post('/director/cafes/$cafeId/extend', body: {
      if (days != null) 'days': days,
      if (newEndDate != null) 'newEndDate': newEndDate,
    });
    return res['newEndDate'] as String?;
  }

  /// Audit loglari
  Future<List<AuditLogItem>> getAuditLogs({int limit = 100}) async {
    final res = await _api.get('/director/audit-logs', query: {'limit': limit.toString()});
    if (res['logs'] is List) {
      return (res['logs'] as List)
          .map((e) => AuditLogItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Ulangan qurilmalar ro'yxati
  Future<List<DeviceInfo>> getDevices({String? cafeId}) async {
    final query = <String, dynamic>{};
    if (cafeId != null) query['cafeId'] = cafeId;
    final res = await _api.get('/devices', query: query.isNotEmpty ? query : null);
    if (res['devices'] is List) {
      return (res['devices'] as List)
          .map((e) => DeviceInfo.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  /// Qurilmani uzish
  Future<void> revokeDevice(int deviceId) async {
    await _api.delete('/devices/$deviceId');
  }

  /// Kafening chek sozlamalarini olish
  Future<Map<String, dynamic>?> getCafeReceiptSettings(String cafeId) async {
    try {
      final res = await _api.get('/director/cafes/$cafeId/receipt');
      if (res['receiptSettings'] is Map) {
        return Map<String, dynamic>.from(res['receiptSettings'] as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Kafening chek sozlamalarini saqlash
  Future<void> updateCafeReceiptSettings({
    required String cafeId,
    String? receiptName,
    String? restaurantAddress,
    String? restaurantPhone,
    String? receiptHeader,
    String? receiptFooter,
    String? receiptLogoUrl,
    bool? showLogoOnReceipt,
    double? servicePercent,
  }) async {
    await _api.post('/director/cafes/$cafeId/receipt', body: {
      if (receiptName != null) 'receiptName': receiptName.trim(),
      if (restaurantAddress != null) 'restaurantAddress': restaurantAddress.trim(),
      if (restaurantPhone != null) 'restaurantPhone': restaurantPhone.trim(),
      if (receiptHeader != null) 'receiptHeader': receiptHeader.trim(),
      if (receiptFooter != null) 'receiptFooter': receiptFooter.trim(),
      if (receiptLogoUrl != null) 'receiptLogoUrl': receiptLogoUrl.trim(),
      if (showLogoOnReceipt != null) 'showLogoOnReceipt': showLogoOnReceipt,
      if (servicePercent != null) 'servicePercent': servicePercent,
    });
  }

  /// 150,000 so'm to'lov qabul qilinganda: kafeni blokdan chiqarish va obunasini 30 kunga uzaytirish
  Future<String?> unblockAndExtendSubscription(String cafeId, {int days = 30}) async {
    await unblockCafe(cafeId);
    return await extendSubscription(cafeId, days: days);
  }
}
