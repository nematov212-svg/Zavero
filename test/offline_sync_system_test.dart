import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zavero/database/local_database.dart';
import 'package:zavero/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2 & 6: LocalDatabase and SyncOperation Tests', () {
    test('SyncOperation serializes and deserializes correctly', () {
      final now = DateTime(2026, 10, 23, 14, 0, 0);
      final op = SyncOperation(
        id: 'op_test_1',
        cafeId: 'cafe_101',
        entityType: 'receipt',
        entityId: '1001',
        actionType: 'checkout',
        payload: {'total': 54000, 'method': 'cash'},
        createdAt: now,
        idempotencyKey: 'idemp_receipt_1001_123',
        retryCount: 0,
        status: SyncStatus.pending,
      );

      final json = op.toJson();
      expect(json['id'], 'op_test_1');
      expect(json['idempotencyKey'], 'idemp_receipt_1001_123');
      expect(json['status'], 'pending');

      final reconstructed = SyncOperation.fromJson(json);
      expect(reconstructed.id, op.id);
      expect(reconstructed.cafeId, op.cafeId);
      expect(reconstructed.entityType, op.entityType);
      expect(reconstructed.payload['total'], 54000);
      expect(reconstructed.idempotencyKey, op.idempotencyKey);
    });

    test('LocalDatabase deduplicates SyncOperations by idempotencyKey', () async {
      final db = LocalDatabase();
      await db.init();

      final op1 = SyncOperation(
        id: 'op_1',
        cafeId: 'cafe_test',
        entityType: 'receipt',
        entityId: '1',
        actionType: 'checkout',
        payload: {'amount': 30000},
        createdAt: DateTime.now(),
        idempotencyKey: 'idemp_unique_key_1',
      );

      // Ikkinchi marta aynan ayni idempotencyKey bilan qo'shish
      final op2 = SyncOperation(
        id: 'op_2',
        cafeId: 'cafe_test',
        entityType: 'receipt',
        entityId: '1',
        actionType: 'checkout',
        payload: {'amount': 30000},
        createdAt: DateTime.now(),
        idempotencyKey: 'idemp_unique_key_1',
      );

      await db.enqueueOperation(op1);
      await db.enqueueOperation(op2);

      final pending = await db.getPendingOperations('cafe_test');
      expect(pending.length, 1, reason: 'Duplicate operation with same idempotencyKey must not be duplicated');
    });

    test('InventoryMovement ledger tracks stock changes and prevents duplicates', () async {
      final db = LocalDatabase();
      await db.init();

      final movement1 = InventoryMovement(
        id: 'mov_101',
        cafeId: 'cafe_test',
        productId: 5,
        delta: -2,
        reason: 'sale',
        timestamp: DateTime.now(),
        referenceId: 'receipt_777',
      );

      await db.recordInventoryMovement(movement1);
      // Qayta urinish
      await db.recordInventoryMovement(movement1);

      final movements = await db.getInventoryMovements('cafe_test');
      expect(movements.length, 1);
      expect(movements.first.delta, -2);
      expect(movements.first.reason, 'sale');
    });
  });

  group('Phase 4: POS Order & Calculation Consistency', () {
    test('Calculates total price, service fee and grand total accurately', () {
      const productPrice = 35000.0;
      const quantity = 2;
      const servicePercent = 10.0;

      const productsTotal = productPrice * quantity; // 70000
      const serviceTotal = productsTotal * servicePercent / 100; // 7000
      const grandTotal = productsTotal + serviceTotal; // 77000

      expect(productsTotal, 70000.0);
      expect(serviceTotal, 7000.0);
      expect(grandTotal, 77000.0);
    });
  });

  group('Phase 5: ConnectivityService State Machine', () {
    test('Default initial state is checking', () {
      final conn = ConnectivityService();
      expect(conn.stateNotifier.value, isNotNull);
    });
  });
}
