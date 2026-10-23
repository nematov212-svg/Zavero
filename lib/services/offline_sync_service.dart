import 'dart:async';
import 'dart:convert';
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

  bool _isSyncing = false;
  Timer? _healthCheckTimer;
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _updatePendingCount();

    // Dastlabki tarmoq holatini tekshirish
    checkConnectivity();

    // Har 15 soniyada tarmoqni tekshirish va navbatdagi amallarni sinxronlash
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkConnectivity();
    });
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
    final actions = await getQueue();
    pendingCountNotifier.value = actions.length;
    if (actions.isEmpty && statusNotifier.value != SyncStatus.offline) {
      statusNotifier.value = SyncStatus.online;
    }
  }

  /// Tarmoq mavjudligini tekshirish
  Future<bool> checkConnectivity() async {
    try {
      final res = await ApiClient().health().timeout(const Duration(seconds: 4));
      final isHealthy = res != null && res['status'] == 'ok';

      if (isHealthy) {
        if (statusNotifier.value == SyncStatus.offline) {
          statusNotifier.value = SyncStatus.online;
        }
        // Agar navbatda amallar bo'lsa, zudlik bilan sinxronlashni boshlaymiz
        if (pendingCountNotifier.value > 0 && !_isSyncing) {
          syncAllPending();
        }
        return true;
      } else {
        statusNotifier.value = SyncStatus.offline;
        return false;
      }
    } catch (_) {
      statusNotifier.value = SyncStatus.offline;
      return false;
    }
  }

  /// Barcha kutilayotgan navbatni olish
  Future<List<PendingOfflineAction>> getQueue() async {
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(_queueKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => PendingOfflineAction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('OfflineSyncService getQueue error: $e');
      return [];
    }
  }

  /// Navbatga yangi amal qo'shish
  Future<void> enqueueAction(PendingOfflineAction action) async {
    try {
      final p = await _asyncPrefs;
      final queue = await getQueue();

      // Takroriy id bo'lsa qo'shmaymiz
      if (!queue.any((a) => a.id == action.id)) {
        queue.add(action);
        await p.setString(_queueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
      }

      await _updatePendingCount();

      // Agar tarmoq bo'lsa, darhol sinxronlashga harakat qilamiz
      if (statusNotifier.value != SyncStatus.offline) {
        syncAllPending();
      }
    } catch (e) {
      debugPrint('OfflineSyncService enqueueAction error: $e');
    }
  }

  /// Kassada to'lov qilingan chekni oflayn navbatga kiritish
  Future<void> queueCheckout({
    required String cafeId,
    required Receipt receipt,
    required int? tableId,
    required List<CartItem> items,
  }) async {
    final action = PendingOfflineAction(
      id: 'checkout_${receipt.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'checkout',
      cafeId: cafeId,
      data: {
        'receipt': receipt.toJson(),
        'tableId': tableId,
        'items': items.map((e) => e.toJson()).toList(),
        'idempotencyKey': 'receipt_${receipt.id}',
      },
      createdAt: DateTime.now(),
    );
    await enqueueAction(action);
  }

  /// Stol buyurtmasini oflayn navbatga kiritish
  Future<void> queueTableOrder({
    required String cafeId,
    required int tableId,
    required List<CartItem> items,
    String? note,
  }) async {
    final action = PendingOfflineAction(
      id: 'table_${tableId}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'table_order',
      cafeId: cafeId,
      data: {
        'tableId': tableId,
        'items': items.map((e) => e.toJson()).toList(),
        'note': note ?? '',
        'idempotencyKey': 'table_${tableId}_${DateTime.now().millisecondsSinceEpoch}',
      },
      createdAt: DateTime.now(),
    );
    await enqueueAction(action);
  }

  /// Barcha navbatdagi amallarni serverga sinxronlash (FIFO tartibida)
  Future<void> syncAllPending({bool force = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    try {
      final p = await _asyncPrefs;
      final queue = await getQueue();

      if (queue.isEmpty) {
        statusNotifier.value = SyncStatus.online;
        _isSyncing = false;
        return;
      }

      final List<PendingOfflineAction> remaining = [];

      for (final action in queue) {
        bool success = false;
        try {
          if (action.type == 'checkout') {
            final res = await ApiClient().post('/receipts/checkout', body: {
              ...action.data,
              'idempotencyKey': action.id,
            });
            if (res['success'] == true || res['receipt'] != null) {
              success = true;
            }
          } else if (action.type == 'table_order') {
            final tableId = action.data['tableId'];
            final res = await ApiClient().put('/tables/$tableId/order', body: action.data);
            if (res['success'] == true) {
              success = true;
            }
          } else {
            // Noma'lum amal bo'lsa o'tkazib yuboramiz
            success = true;
          }
        } catch (err) {
          debugPrint('Sinxronlash xatosi (Action: ${action.id}): $err');
          action.retryCount += 1;
          // Agar server 400 yoki 409 (allaqachon mavjud) qaytarsa, takrorlamaymiz
          if (err.toString().contains('409') || err.toString().contains('duplicate')) {
            success = true;
          } else if (action.retryCount > 10) {
            // 10 martadan oshsa, navbatni to'xtatib qo'ymasligi uchun o'chiramiz
            success = true;
          }
        }

        if (!success) {
          remaining.add(action);
          // Tarmoq uzilgan bo'lsa, keyingi safarga qoldiramiz
          break;
        }
      }

      // Qolgan elementlarni saqlash
      await p.setString(_queueKey, jsonEncode(remaining.map((e) => e.toJson()).toList()));
      await _updatePendingCount();

      if (remaining.isEmpty) {
        statusNotifier.value = SyncStatus.synced;
        // 2 soniyadan so'ng 'online' holatiga qaytadi
        Future.delayed(const Duration(seconds: 2), () {
          if (statusNotifier.value == SyncStatus.synced) {
            statusNotifier.value = SyncStatus.online;
          }
        });
      } else {
        statusNotifier.value = SyncStatus.offline;
      }
    } catch (e) {
      debugPrint('syncAllPending global xatoligi: $e');
      statusNotifier.value = SyncStatus.offline;
    } finally {
      _isSyncing = false;
    }
  }

  /// Oflayn navbatni majburiy tozalash (agar kerak bo'lsa)
  Future<void> clearQueue() async {
    final p = await _asyncPrefs;
    await p.remove(_queueKey);
    await _updatePendingCount();
  }
}
