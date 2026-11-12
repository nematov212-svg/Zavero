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
      data: j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : {},
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      retryCount: safeInt(j['retryCount']),
    );
  }
}

/// ZAVERO OFFLINE-FIRST SYNCHRONIZATION SERVICE
/// Internet uzilgan yoki backend uxlagan paytda ham kassa to'xtamaydi:
/// 1. Amallar lokal xotirada xavfsiz navbatga (queue) olinadi va diskka saqlanadi.
/// 2. Internet tiklanganda/server uyg'onganda navbatdagi amallar ketma-ket avtomatik yuboriladi.
/// 3. Idempotency kalitlari orqali bir xil to'lov qayta takrorlanmaydi.
/// 4. Sahifa yopilib qayta ochilsa ham navbat saqlanib qoladi.
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'zavero_offline_actions_queue_v2';

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.online);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  final List<PendingOfflineAction> _queue = [];
  Timer? _syncTimer;
  SharedPreferences? _prefs;
  bool _isSyncing = false;
  VoidCallback? onQueueChanged;
  Function(String cafeId)? onCheckoutSynced;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadQueueFromStorage();
    _startPeriodicSync();
    unawaited(checkConnectivity());
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<SharedPreferences> get _asyncPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> _loadQueueFromStorage() async {
    try {
      final p = await _asyncPrefs;
      final raw = p.getString(_queueKey);
      _queue.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              _queue.add(PendingOfflineAction.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [OfflineSync] loadQueue error: $e');
    }
    pendingCountNotifier.value = _queue.length;
  }

  Future<void> _saveQueueToStorage() async {
    try {
      final p = await _asyncPrefs;
      final encoded = jsonEncode(_queue.map((a) => a.toJson()).toList());
      await p.setString(_queueKey, encoded);
    } catch (e) {
      debugPrint('⚠️ [OfflineSync] saveQueue error: $e');
    }
    pendingCountNotifier.value = _queue.length;
    onQueueChanged?.call();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_queue.isNotEmpty && !_isSyncing) {
        syncAllPending();
      } else if (_queue.isEmpty && statusNotifier.value != SyncStatus.online) {
        checkConnectivity();
      }
    });
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

  /// Barcha kutilayotgan navbatni olish
  Future<List<PendingOfflineAction>> getQueue() async {
    return List.unmodifiable(_queue);
  }

  /// Muayyan kafe uchun kutilayotgan barcha to'lovlar ro'yxatini olish
  List<Receipt> getPendingReceiptsForCafe(String cafeId) {
    final list = <Receipt>[];
    for (final act in _queue) {
      if (act.type == 'checkout' && (cafeId.isEmpty || act.cafeId == cafeId)) {
        final rRaw = act.data['receipt'];
        if (rRaw is Map) {
          try {
            list.add(Receipt.fromJson(Map<String, dynamic>.from(rRaw)));
          } catch (_) {}
        }
      }
    }
    return list;
  }

  /// Yangi amalni oflayn navbatga kiritish va darhol diskka yozish
  Future<void> enqueueAction(PendingOfflineAction action) async {
    // Deduplication by action.id or idempotencyKey
    final existingIdx = _queue.indexWhere((a) =>
        a.id == action.id ||
        (action.data['idempotencyKey'] != null &&
            a.data['idempotencyKey'] == action.data['idempotencyKey']));

    if (existingIdx != -1) {
      _queue[existingIdx] = action;
    } else {
      _queue.add(action);
    }
    await _saveQueueToStorage();
    debugPrint('📦 [OfflineSync] Amal navbatga qo\'shildi: ${action.type} (Jami kutilmoqda: ${_queue.length})');

    // Darhol sinxronlashga urinish
    unawaited(syncAllPending());
  }

  /// Kassada to'lov qilingan chekni oflayn navbatga kiritish
  Future<void> queueCheckout({
    required String cafeId,
    required Receipt receipt,
    required int? tableId,
    required List<CartItem> items,
    String? idempotencyKey,
  }) async {
    final effKey = idempotencyKey ?? 'rcpt_${receipt.id}_${receipt.date.millisecondsSinceEpoch}';
    final action = PendingOfflineAction(
      id: 'act_${receipt.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: 'checkout',
      cafeId: cafeId,
      data: {
        'receipt': receipt.toJson(),
        'tableId': tableId,
        'items': items.map((e) => e.toJson()).toList(),
        'idempotencyKey': effKey,
      },
      createdAt: DateTime.now(),
    );
    await enqueueAction(action);
  }

  /// Agar to'lov bevosita muvaffaqiyatli o'tgan bo'lsa, navbatdan olib tashlash
  Future<void> removeCheckoutByReceiptId(dynamic receiptId) async {
    final strId = receiptId?.toString();
    if (strId == null) return;
    _queue.removeWhere((a) {
      if (a.type != 'checkout') return false;
      final rRaw = a.data['receipt'];
      if (rRaw is Map && rRaw['id']?.toString() == strId) return true;
      if (a.data['idempotencyKey']?.toString().contains(strId) == true) return true;
      return false;
    });
    await _saveQueueToStorage();
  }

  /// Barcha navbatdagi amallarni serverga sinxronlash
  Future<void> syncAllPending({bool force = false}) async {
    if (_isSyncing) return;
    if (_queue.isEmpty) {
      statusNotifier.value = SyncStatus.online;
      return;
    }

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;
    debugPrint('🔄 [OfflineSync] Sinxronizatsiya boshlandi (${_queue.length} ta amal)...');

    final toProcess = List<PendingOfflineAction>.from(_queue);
    bool anyError = false;

    for (final action in toProcess) {
      try {
        if (action.type == 'checkout') {
          final res = await ApiClient().post(
            '/receipts/checkout',
            body: action.data,
          ).timeout(const Duration(seconds: 8));

          if (res['success'] == true) {
            _queue.removeWhere((a) => a.id == action.id);
            await _saveQueueToStorage();
            debugPrint('✅ [OfflineSync] To‘lov muvaffaqiyatli sinxronlandi: ${action.id}');
            onCheckoutSynced?.call(action.cafeId);
          } else {
            debugPrint('⚠️ [OfflineSync] Server rad etdi: ${res['message']}');
            action.retryCount++;
          }
        }
      } catch (e) {
        anyError = true;
        action.retryCount++;
        debugPrint('⚠️ [OfflineSync] Tarmoq xatoligi (server uyg‘onayotgan bo‘lishi mumkin): $e');
        break; // Server offline yoki uxlab qolgan, keyingi tick'da qayta urinadi
      }
    }

    _isSyncing = false;
    if (_queue.isEmpty) {
      statusNotifier.value = SyncStatus.online;
    } else if (anyError) {
      statusNotifier.value = SyncStatus.offline;
    } else {
      statusNotifier.value = SyncStatus.syncing;
    }
  }

  /// Oflayn navbatni majburiy tozalash
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueueToStorage();
  }
}
