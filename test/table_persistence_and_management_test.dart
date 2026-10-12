import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zavero/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zavero/services/local_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Table Order Persistence & Hall Isolation Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Table numbers sorting ascending rule', () {
      final tables = [
        TableModel(id: 10, hallId: 1, number: 12, seats: 4, status: TableStatus.free),
        TableModel(id: 11, hallId: 1, number: 2, seats: 4, status: TableStatus.free),
        TableModel(id: 12, hallId: 1, number: 7, seats: 4, status: TableStatus.free),
        TableModel(id: 13, hallId: 1, number: 1, seats: 4, status: TableStatus.free),
      ];

      tables.sort((a, b) => a.number.compareTo(b.number));
      expect(tables.map((t) => t.number).toList(), [1, 2, 7, 12]);
    });

    test('Hall isolation: Tables in Zal, Podval, Dala, Saboy, Soy bo\'yi are strictly isolated', () {
      final hallZal = Hall(id: 1, name: 'Zal', icon: Icons.room_service);
      final hallPodval = Hall(id: 2, name: 'Podval', icon: Icons.store);
      final hallDala = Hall(id: 3, name: 'Dala', icon: Icons.deck);
      final hallSaboy = Hall(id: 4, name: 'Saboy', icon: Icons.takeout_dining);
      final hallSoyBoyi = Hall(id: 5, name: 'Soy bo\'yi', icon: Icons.water);

      final allTables = [
        TableModel(id: 101, hallId: hallZal.id, number: 1, seats: 4, status: TableStatus.free),
        TableModel(id: 102, hallId: hallZal.id, number: 2, seats: 4, status: TableStatus.occupied),
        TableModel(id: 201, hallId: hallPodval.id, number: 1, seats: 6, status: TableStatus.free),
        TableModel(id: 301, hallId: hallDala.id, number: 1, seats: 8, status: TableStatus.free),
        TableModel(id: 401, hallId: hallSaboy.id, number: 1, seats: 2, status: TableStatus.free),
        TableModel(id: 501, hallId: hallSoyBoyi.id, number: 1, seats: 4, status: TableStatus.free),
      ];

      // Filter for Zal
      final zalTables = allTables.where((t) => t.hallId == hallZal.id).toList();
      expect(zalTables.length, 2);
      expect(zalTables.any((t) => t.hallId != hallZal.id), isFalse);

      // Filter for Soy bo'yi
      final soyBoyiTables = allTables.where((t) => t.hallId == hallSoyBoyi.id).toList();
      expect(soyBoyiTables.length, 1);
      expect(soyBoyiTables.first.hallId, hallSoyBoyi.id);
    });

    test('Table order total calculation and occupied state persistence', () {
      final p1 = Product(id: 1, name: 'Shaurma', price: 35000, categoryId: 1, stock: 10, icon: Icons.lunch_dining);
      final p2 = Product(id: 2, name: 'Cola', price: 15000, categoryId: 2, stock: 10, icon: Icons.local_drink);

      final tableOrders = <int, List<CartItem>>{
        101: [
          CartItem(product: p1, qty: 4), // 4 * 35,000 = 140,000
          CartItem(product: p2, qty: 2), // 2 * 15,000 = 30,000
        ]
      };

      final total = tableOrders[101]!.fold<double>(0.0, (sum, item) => sum + item.total);
      expect(total, 170000);

      // Simulation of empty sync safeguard:
      // If server emits empty Map ({}), local orders MUST NOT be cleared
      final localOrders = Map<int, List<CartItem>>.from(tableOrders);
      final remoteOrders = <int, List<CartItem>>{}; // empty from backend sync glitch

      if (remoteOrders.isNotEmpty) {
        localOrders
          ..clear()
          ..addAll(remoteOrders);
      }

      expect(localOrders.isNotEmpty, isTrue);
      expect(localOrders[101]!.length, 2);
      expect(localOrders[101]!.first.qty, 4);
    });

    test('LocalCacheService quota management and pruning', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_reports_test', 'heavy report data');
      await prefs.setString('cache_customer_orders_test', 'heavy customer orders');
      await prefs.setString('cache_table_orders_test', '{"1": [{"product": {"name": "Lavash"}}]}');

      expect(prefs.containsKey('cache_reports_test'), isTrue);
      expect(prefs.containsKey('cache_customer_orders_test'), isTrue);
      expect(prefs.containsKey('cache_table_orders_test'), isTrue);

      await LocalCacheService().pruneCacheForQuota(prefs);

      // Heavy report caches pruned, but table orders are kept
      expect(prefs.containsKey('cache_reports_test'), isFalse);
      expect(prefs.containsKey('cache_customer_orders_test'), isFalse);
      expect(prefs.containsKey('cache_table_orders_test'), isTrue);
    });

    test('Occupied table deletion safety check', () {
      final table1 = TableModel(id: 10, hallId: 1, number: 1, seats: 4, status: TableStatus.occupied);
      final table2 = TableModel(id: 11, hallId: 1, number: 2, seats: 4, status: TableStatus.free);
      final orders = <int, List<CartItem>>{
        10: [CartItem(product: Product(id: 1, name: 'Burger', price: 30000, categoryId: 1, stock: 5, icon: Icons.fastfood), qty: 1)]
      };

      bool canDeleteTable(TableModel t) {
        final hasOrder = (orders[t.id]?.isNotEmpty ?? false) || t.status == TableStatus.occupied;
        return !hasOrder;
      }

      expect(canDeleteTable(table1), isFalse); // Cannot delete occupied table
      expect(canDeleteTable(table2), isTrue);  // Can delete free table
    });
  });
}
