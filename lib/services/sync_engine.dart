import 'dart:async';
import 'package:flutter/foundation.dart';

import '../database/local_database.dart';
import 'api_client.dart';
import 'connectivity_service.dart';

/// Bardoshli Sinxronizatsiya Dvigateli (Durable Synchronization Engine - Phase 6).
/// Mahalliy navbatni (LocalDatabase) tranzaksion tartibda va idempotency kaliti
/// bilan serverga uzatadi, qayta urinishlar va tarmoq ulanishini boshqaradi.
class SyncEngine {
  static final SyncEngine _instance = SyncEngine._internal();
  factory SyncEngine() => _instance;
  SyncEngine._internal();

  final LocalDatabase _db = LocalDatabase();
  final ConnectivityService _conn = ConnectivityService();

  final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.synced);
  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  bool _isSyncing = false;
  String _activeCafeId = '';

  void init({required String cafeId}) {
    _activeCafeId = cafeId;
    _db.init().then((_) {
      _refreshPendingCount();
      // Tarmoq holati o'zgarganda (online bo'lganda) avtomatik sinxronlaymiz
      _conn.stateNotifier.addListener(() {
        if (_conn.isOnline) {
          triggerSync();
        }
      });
      // Har 15 soniyada kutilayotgan navbatni tekshiramiz
      Timer.periodic(const Duration(seconds: 15), (_) {
        if (_conn.isOnline && pendingCountNotifier.value > 0) {
          triggerSync();
        }
      });
    });
  }

  void updateCafeId(String cafeId) {
    _activeCafeId = cafeId;
    _refreshPendingCount();
  }

  Future<void> _refreshPendingCount() async {
    final ops = await _db.getPendingOperations(_activeCafeId);
    pendingCountNotifier.value = ops.length;
    if (ops.isEmpty && statusNotifier.value != SyncStatus.syncing) {
      statusNotifier.value = SyncStatus.synced;
    }
  }

  /// Yangi amalni navbatga qo'shish
  Future<void> queueOperation({
    required String entityType,
    required String entityId,
    required String actionType,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    final now = DateTime.now();
    final opId = 'op_${now.millisecondsSinceEpoch}_${now.microsecond}';
    final idemp = idempotencyKey ?? 'idemp_${entityType}_${entityId}_${now.millisecondsSinceEpoch}';

    final op = SyncOperation(
      id: opId,
      cafeId: _activeCafeId,
      entityType: entityType,
      entityId: entityId,
      actionType: actionType,
      payload: payload,
      createdAt: now,
      idempotencyKey: idemp,
    );

    await _db.enqueueOperation(op);
    await _refreshPendingCount();

    // Agar internet bo'lsa darhol jo'natishga harakat qilamiz
    if (_conn.isOnline) {
      triggerSync();
    }
  }

  /// Sinxronizatsiyani ishga tushirish (Durable Batch FIFO Execution)
  Future<void> triggerSync() async {
    if (_isSyncing) return;
    final ops = await _db.getPendingOperations(_activeCafeId);
    if (ops.isEmpty) {
      statusNotifier.value = SyncStatus.synced;
      pendingCountNotifier.value = 0;
      return;
    }

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    try {
      for (final op in ops) {
        if (op.retryCount > 10) {
          // 10 martadan ko'p muvaffaqiyatsiz bo'lsa, navbat to'xtab qolmasligi uchun belgilaymiz
          await _db.updateOperationStatus(_activeCafeId, op.id, SyncStatus.failed, error: 'Maksimal urinishlar sonidan oshdi');
          continue;
        }

        bool success = false;
        try {
          if (op.entityType == 'receipt' || op.actionType == 'checkout') {
            final res = await ApiClient().post('/receipts/checkout', body: {
              ...op.payload,
              'idempotencyKey': op.idempotencyKey,
            });
            if (res['success'] == true || res['receipt'] != null) {
              success = true;
            }
          } else if (op.entityType == 'table_order') {
            final tableId = op.payload['tableId'] ?? op.entityId;
            final res = await ApiClient().put('/tables/$tableId/order', body: {
              ...op.payload,
              'idempotencyKey': op.idempotencyKey,
            });
            if (res['success'] == true) {
              success = true;
            }
          } else if (op.entityType == 'product') {
            final res = await ApiClient().post('/products', body: op.payload);
            if (res['success'] == true) {
              success = true;
            }
          } else {
            // Noma'lum amal bo'lsa o'tkazib yuboramiz
            success = true;
          }
        } catch (e) {
          final errStr = e.toString();
          debugPrint('SyncEngine op xatosi (${op.id}): $errStr');

          // Agar server 409 (Conflict/Allaqachon mavjud) qaytarsa, idempotency bo'yicha muvaffaqiyatli deb hisoblaymiz
          if (errStr.contains('409') || errStr.contains('duplicate')) {
            success = true;
          } else {
            await _db.updateOperationStatus(_activeCafeId, op.id, SyncStatus.failed, error: errStr);
          }
        }

        if (success) {
          await _db.updateOperationStatus(_activeCafeId, op.id, SyncStatus.synced);
        }
      }
    } finally {
      _isSyncing = false;
      await _refreshPendingCount();
    }
  }
}
