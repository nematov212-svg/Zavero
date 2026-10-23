import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sinxronizatsiya amallarining holatlari
enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
  conflict,
}

/// Sinxronizatsiya navbatidagi yagona unikal amal
class SyncOperation {
  final String id;
  final String cafeId;
  final String entityType; // 'receipt', 'table_order', 'product', 'inventory', 'customer'
  final String entityId;
  final String actionType; // 'create', 'update', 'delete', 'checkout'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;
  SyncStatus status;
  String? lastError;
  final String idempotencyKey;
  final int serverRevision;

  SyncOperation({
    required this.id,
    required this.cafeId,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
    this.lastError,
    required this.idempotencyKey,
    this.serverRevision = 1,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cafeId': cafeId,
    'entityType': entityType,
    'entityId': entityId,
    'actionType': actionType,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'status': status.name,
    'lastError': lastError,
    'idempotencyKey': idempotencyKey,
    'serverRevision': serverRevision,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] as String,
    cafeId: (json['cafeId'] ?? '') as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId']?.toString() ?? '',
    actionType: json['actionType'] as String,
    payload: (json['payload'] as Map<String, dynamic>?) ?? {},
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    status: SyncStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => SyncStatus.pending,
    ),
    lastError: json['lastError'] as String?,
    idempotencyKey: json['idempotencyKey'] as String? ?? 'idemp_${json['id']}',
    serverRevision: (json['serverRevision'] as num?)?.toInt() ?? 1,
  );
}

/// Ombor harakati (Inventory movement ledger) — audit va ziddiyatlarning oldini olish
class InventoryMovement {
  final String id;
  final String cafeId;
  final int productId;
  final int delta;
  final String reason; // 'sale', 'adjustment', 'delivery', 'waste'
  final DateTime timestamp;
  final String referenceId; // Masalan: receiptId

  InventoryMovement({
    required this.id,
    required this.cafeId,
    required this.productId,
    required this.delta,
    required this.reason,
    required this.timestamp,
    required this.referenceId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'cafeId': cafeId,
    'productId': productId,
    'delta': delta,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
    'referenceId': referenceId,
  };

  factory InventoryMovement.fromJson(Map<String, dynamic> json) => InventoryMovement(
    id: json['id'] as String,
    cafeId: (json['cafeId'] ?? '') as String,
    productId: (json['productId'] as num).toInt(),
    delta: (json['delta'] as num).toInt(),
    reason: json['reason'] as String,
    timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    referenceId: (json['referenceId'] ?? '') as String,
  );
}

/// ZAVERO POS uchun to'liq Oflayn Ma'lumotlar Bazasi (Cross-platform Local Database)
/// Web, macOS, iOS, Android qurilmalarida bir xil barqarorlik va tranzaksion butunlikni ta'minlaydi.
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized && _prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  Future<SharedPreferences> get prefs async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  String _pfx(String cafeId, String collection) =>
      cafeId.isNotEmpty ? 'zpos_${cafeId}_$collection' : 'zpos_$collection';

  // ==========================================================
  // 1. SINXRONIZATSIYA NAVBATI (SYNC QUEUE)
  // ==========================================================

  Future<List<SyncOperation>> getPendingOperations(String cafeId) async {
    final p = await prefs;
    final raw = p.getString(_pfx(cafeId, 'sync_queue'));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => SyncOperation.fromJson(e as Map<String, dynamic>))
          .where((op) => op.status != SyncStatus.synced)
          .toList();
    } catch (e) {
      debugPrint('LocalDatabase getPendingOperations error: $e');
      return [];
    }
  }

  Future<void> enqueueOperation(SyncOperation op) async {
    final p = await prefs;
    final ops = await getPendingOperations(op.cafeId);

    // Idempotency: ayni idempotencyKey ga ega amal navbatda bo'lsa qayta qo'shilmaydi
    final idx = ops.indexWhere((existing) => existing.idempotencyKey == op.idempotencyKey);
    if (idx >= 0) {
      ops[idx] = op;
    } else {
      ops.add(op);
    }

    final key = _pfx(op.cafeId, 'sync_queue');
    await p.setString(key, jsonEncode(ops.map((e) => e.toJson()).toList()));
  }

  Future<void> updateOperationStatus(
    String cafeId,
    String opId,
    SyncStatus newStatus, {
    String? error,
  }) async {
    final p = await prefs;
    final ops = await getPendingOperations(cafeId);
    final idx = ops.indexWhere((e) => e.id == opId);
    if (idx >= 0) {
      ops[idx].status = newStatus;
      if (error != null) ops[idx].lastError = error;
      if (newStatus == SyncStatus.failed) ops[idx].retryCount += 1;

      // Agar muvaffaqiyatli sinxronlangan bo'lsa, navbatdan olib tashlaymiz
      if (newStatus == SyncStatus.synced) {
        ops.removeAt(idx);
      }
      final key = _pfx(cafeId, 'sync_queue');
      await p.setString(key, jsonEncode(ops.map((e) => e.toJson()).toList()));
    }
  }

  Future<void> removeOperation(String cafeId, String opId) async {
    final p = await prefs;
    final ops = await getPendingOperations(cafeId);
    ops.removeWhere((e) => e.id == opId);
    final key = _pfx(cafeId, 'sync_queue');
    await p.setString(key, jsonEncode(ops.map((e) => e.toJson()).toList()));
  }

  // ==========================================================
  // 2. OMBOR HARAKATLARI LEDGERI (INVENTORY MOVEMENTS)
  // ==========================================================

  Future<List<InventoryMovement>> getInventoryMovements(String cafeId) async {
    final p = await prefs;
    final raw = p.getString(_pfx(cafeId, 'inv_movements'));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> recordInventoryMovement(InventoryMovement mov) async {
    final p = await prefs;
    final movements = await getInventoryMovements(mov.cafeId);
    // Takroriy hisoblanishdan himoya
    if (movements.any((m) => m.id == mov.id)) return;

    movements.add(mov);
    // So'nggi 200 ta harakatni saqlaymiz
    if (movements.length > 200) {
      movements.removeRange(0, movements.length - 200);
    }
    await p.setString(_pfx(mov.cafeId, 'inv_movements'), jsonEncode(movements.map((e) => e.toJson()).toList()));
  }

  // ==========================================================
  // 3. TO'PLAM KESHLARI (COLLECTIONS CACHE)
  // ==========================================================

  Future<void> saveCollection<T>(
    String cafeId,
    String collection,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final p = await prefs;
    final raw = jsonEncode(items.map(toJson).toList());
    await p.setString(_pfx(cafeId, collection), raw);
  }

  Future<List<T>> loadCollection<T>(
    String cafeId,
    String collection,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final p = await prefs;
    final raw = p.getString(_pfx(cafeId, collection));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('LocalDatabase loadCollection error ($collection): $e');
      return [];
    }
  }

  Future<void> clearCafeData(String cafeId) async {
    final p = await prefs;
    final keys = p.getKeys().where((k) => k.startsWith('zpos_${cafeId}_'));
    for (final k in keys) {
      await p.remove(k);
    }
  }
}
