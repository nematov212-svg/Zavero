import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_client.dart';

enum SyncStatus {
  online,
  syncing,
  offline,
  synced,
}

/// Offline-first rejimida bajarilgan va serverga sinxronlanishi kutilayotgan harakat
class PendingOfflineAction {
  final String id;
  final String type; // 'checkout', 'table_order', 'status_update'
  final String cafeId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  PendingOfflineAction({
    required this.id,
    required this.type,
    required this.cafeId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'cafeId': cafeId,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory PendingOfflineAction.fromJson(Map<String, dynamic> j) {
    return PendingOfflineAction(
      id: j['id']?.toString() ?? 'action_${DateTime.now().millisecondsSinceEpoch}',
      type: j['type']?.toString() ?? 'checkout',
      cafeId: j['cafeId']?.toString() ?? '',
      data: j['data'] is Map ? Map<String, dynamic>.from(j['data']) : {},
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ZAVERO OFFLINE-FIRST SYNCHRONIZATION SERVICE
/// Internet uzilgan paytda kassa va buyurtmalar to'xtab qolmaydi:
/// 1. Amallar lokal xotirada xavfsiz navbatga (queue) olinadi.
/// 2. Internet tiklanganda navbatdagi amallar ketma-ket avtomatik serverga yuboriladi.
/// 3. Idempotency kalitlari orqali bir xil operatsiya qayta takrorlanmaydi.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'zavero_offline_actions_queue';

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.online);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  Timer? _healthCheckTimer;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    // Talab 2: Oflayn navbatni butunlay tozalaymiz (eski buyurtmalar va to'lovlar qayta yuborilmasligi uchun)
    try {
      await _prefs?.remove(_queueKey);
    } catch (_) {}
    pendingCountNotifier.value = 0;
    statusNotifier.value = SyncStatus.online;
    checkConnectivity();
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }

  Future<SharedPreferences> get _asyncPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Navbatdagi amallar sonini yangilash
  Future<void> _updatePendingCount() async {
    pendingCountNotifier.value = 0;
    statusNotifier.value = SyncStatus.online;
  }

  /// Tarmoq mavjudligini tekshirish
  Future<bool> checkConnectivity() async {
    try {
      final res = await ApiClient().health().timeout(const Duration(seconds: 4));
      final isHealthy = res != null && res['status'] == 'ok';
      statusNotifier.value = isHealthy ? SyncStatus.online : SyncStatus.offline;
      return isHealthy;
    } catch (_) {
      statusNotifier.value = SyncStatus.offline;
      return false;
    }
  }

  /// Barcha kutilayotgan navbatni olish (bo'sh ro'yxat qaytaradi)
  Future<List<PendingOfflineAction>> getQueue() async => [];

  /// Navbatga qo'shish o'chirildi (Talab 2)
  Future<void> enqueueAction(PendingOfflineAction action) async {
    pendingCountNotifier.value = 0;
  }

  /// Kassada to'lov qilingan chekni oflayn navbatga kiritish (o'chirildi)
  Future<void> queueCheckout({
    required String cafeId,
    required Receipt receipt,
    required int? tableId,
    required List<CartItem> items,
  }) async {}

  /// Stol buyurtmasini oflayn navbatga kiritish (o'chirildi)
  Future<void> queueTableOrder({
    required String cafeId,
    required int tableId,
    required List<CartItem> items,
    String? note,
  }) async {}

  /// Barcha navbatdagi amallarni serverga sinxronlash (o'chirildi, no-op)
  Future<void> syncAllPending({bool force = false}) async {
    pendingCountNotifier.value = 0;
    statusNotifier.value = SyncStatus.online;
  }

  /// Oflayn navbatni majburiy tozalash
  Future<void> clearQueue() async {
    final p = await _asyncPrefs;
    await p.remove(_queueKey);
    await _updatePendingCount();
  }
}
