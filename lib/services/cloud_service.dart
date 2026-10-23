import 'dart:async';

import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'local_cache_service.dart';
import 'offline_sync_service.dart';
import 'socket_service.dart';
import 'supabase_realtime_service.dart';

/// Stol band bo'lganda chiqadigan xatolik (backend 409 TABLE_BUSY qaytarganda)
class TableBusyException implements Exception {
  final String message;
  TableBusyException([this.message = 'Bu stol hozir band']);
  @override
  String toString() => message;
}

/// Backend REST API + Supabase Realtime — ko'p account (cafeId) va ko'p qurilma
/// real-time sinxronizatsiya. Har bir metod tegishli `/api/...` endpointiga
/// murojaat qiladi, real-time oqimlar esa Supabase Realtime PostgreSQL o'zgarishlari
/// orqali barcha ochiq qurilmalarda darhol yangilanadi.
class CloudService {
  static final CloudService _instance = CloudService._internal();
  factory CloudService() => _instance;
  CloudService._internal();

  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();
  final SupabaseRealtimeService _supabase = SupabaseRealtimeService();

  Map<String, dynamic> _map(dynamic v) =>
      (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw is! List) return <T>[];
    return raw.map((e) => fromJson(_map(e))).toList();
  }

  Map<int, List<CartItem>> _tableOrdersFromJson(dynamic raw) {
    final result = <int, List<CartItem>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final tId = int.tryParse('$k');
        if (tId == null || v is! List) return;
        result[tId] = v.map((e) => CartItem.fromJson(_map(e))).toList();
      });
    }
    return result;
  }

  Map<int, String> _tableNotesFromJson(dynamic raw) {
    final result = <int, String>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final tId = int.tryParse('$k');
        if (tId == null) return;
        final note = v?.toString() ?? '';
        if (note.isNotEmpty) result[tId] = note;
      });
    }
    return result;
  }

  // ============================================================
  // YANGI CAFE / WORKSPACE INIZIALIZATSIYA
  // ============================================================
  /// Endi kerak emas — backend `/api/auth/register` paytida avtomatik
  /// seed qiladi (bo'sh cafe: default kategoriyalar, zallar, stollar).
  /// main.dart va auth_service.dart shu metodni chaqirishda davom etadi,
  /// shuning uchun no-op sifatida saqlanadi.
  Future<void> initializeNewCafe(String cafeId, {String? cafeName}) async {
    return;
  }

  // ============================================================
  // BULUTDAN BIR MARTALIK YUKLASH — GET /api/cafe/full
  // ============================================================
  Future<Map<String, dynamic>> loadFullCafeData(String cafeId) async {
    final cache = LocalCacheService();
    final cachedTableOrdersRaw = await cache.getCachedMap('cache_table_orders_$cafeId');
    final result = <String, dynamic>{
      'categories': await cache.getCachedList('cache_categories_$cafeId', Category.fromJson),
      'products': await cache.getCachedList('cache_products_$cafeId', Product.fromJson),
      'halls': await cache.getCachedList('cache_halls_$cafeId', Hall.fromJson),
      'tables': await cache.getCachedList('cache_tables_$cafeId', TableModel.fromJson),
      'customers': await cache.getCachedList('cache_customers_$cafeId', Customer.fromJson),
      'receipts': await cache.getCachedList('cache_receipts_$cafeId', Receipt.fromJson),
      'customerOrders': await cache.getCachedList('cache_customer_orders_$cafeId', CustomerOrder.fromJson),
      'tableOrders': cachedTableOrdersRaw != null ? _tableOrdersFromJson(cachedTableOrdersRaw) : <int, List<CartItem>>{},
      'tableNotes': <int, String>{},
    };

    if (_api.token == null || _api.token!.isEmpty) {
      return result;
    }

    try {
      final res = await _api.get('/cafe/full');
      final raw = (res['data'] is Map<String, dynamic>)
          ? (res['data'] as Map<String, dynamic>)
          : res;
      if (raw.isEmpty) return result;

      final categories = _list(raw['categories'], Category.fromJson);
      final products = _list(raw['products'], Product.fromJson);
      final halls = _list(raw['halls'], Hall.fromJson);
      final tables = _list(raw['tables'], TableModel.fromJson);
      final customers = _list(raw['customers'], Customer.fromJson);
      final receipts = _list(raw['receipts'], Receipt.fromJson);
      final customerOrders = _list(raw['customerOrders'], CustomerOrder.fromJson);
      final tableOrders = _tableOrdersFromJson(raw['tableOrders']);
      final tableNotes = _tableNotesFromJson(raw['tableNotes'] ?? raw['tableOrders']);

      result['categories'] = categories;
      await cache.setCachedList('cache_categories_$cafeId', categories, (c) => c.toJson(), allowEmpty: true);

      result['products'] = products;
      await cache.setCachedList('cache_products_$cafeId', products, (p) => p.toJson(), allowEmpty: true);

      result['halls'] = halls;
      await cache.setCachedList('cache_halls_$cafeId', halls, (h) => h.toJson(), allowEmpty: true);

      result['tables'] = tables;
      await cache.setCachedList('cache_tables_$cafeId', tables, (t) => t.toJson(), allowEmpty: true);

      result['customers'] = customers;
      await cache.setCachedList('cache_customers_$cafeId', customers, (c) => c.toJson(), allowEmpty: true);

      result['receipts'] = receipts;
      await cache.setCachedList('cache_receipts_$cafeId', receipts, (r) => r.toJson(), allowEmpty: true);

      result['customerOrders'] = customerOrders;
      await cache.setCachedList('cache_customer_orders_$cafeId', customerOrders, (co) => co.toJson(), allowEmpty: true);

      result['tableOrders'] = tableOrders;
      final jsonMap = tableOrders.map((k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()));
      await cache.setCachedMap('cache_table_orders_$cafeId', jsonMap);
      result['tableNotes'] = tableNotes;
    } catch (e) {
      debugPrint('loadFullCafeData server xatoligi: $e');
    }

    return result;
  }

  /// Ichki yordamchi: dastlabki REST fetch + Supabase Realtime / Socket hodisalari
  /// kelganda qayta yuklab, natijani broadcast Stream orqali uzatadi.
  Stream<T> _watch<T>({
    required Future<T> Function() fetch,
    List<CafeSocketEvent>? triggers,
    RealtimeEventType? realtimeType,
    Future<T?> Function()? cacheRestore,
    Future<void> Function(T data)? cacheSave,
  }) {
    late StreamController<T> controller;
    final subs = <StreamSubscription>[];

    void instantRefresh() async {
      dynamic cachedObj;
      // 1. Keshdagi ma'lumotni DARHOL emit qilamiz (0-ms)
      if (cacheRestore != null) {
        try {
          cachedObj = await cacheRestore();
          if (cachedObj != null && !controller.isClosed) {
            final isCachedEmpty = (cachedObj is List && cachedObj.isEmpty) ||
                (cachedObj is Map && cachedObj.isEmpty);
            if (!isCachedEmpty) {
              controller.add(cachedObj as T);
            }
          }
        } catch (_) {}
      }
      // 2. Internet bo'lsa serverdan fon rejimida yangilab kelamiz
      if (_api.token != null && _api.token!.isNotEmpty) {
        try {
          if (!controller.isClosed) {
            final fresh = await fetch();
            if (!controller.isClosed) {
              final isFreshEmpty = (fresh is List && fresh.isEmpty) ||
                  (fresh is Map && fresh.isEmpty);
              final isCachedNotEmpty = (cachedObj is List && cachedObj.isNotEmpty) ||
                  (cachedObj is Map && cachedObj.isNotEmpty);
              if (isFreshEmpty && isCachedNotEmpty) {
                // Serverdan bo'sh ma'lumot vaqtinchalik xato tufayli kelsa, keshdagi ma'lumotlarni o'chirmaymiz
              } else {
                controller.add(fresh);
                if (cacheSave != null) {
                  cacheSave(fresh);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('CloudService stream yangilash xatoligi: $e');
        }
      }
    }


    controller = StreamController<T>.broadcast(
      onListen: () {
        instantRefresh();
        if (triggers != null) {
          for (final t in triggers) {
            subs.add(_socket.on(t).listen((_) => instantRefresh()));
          }
        }
        if (realtimeType != null) {
          subs.add(_supabase.on(realtimeType).listen((_) => instantRefresh()));
        }
      },
      onCancel: () {
        for (final s in subs) {
          s.cancel();
        }
        subs.clear();
      },
    );
    return controller.stream;
  }

  // ============================================================
  // REAL-TIME OQIMLAR (SUPABASE REALTIME + MULTI-DEVICE SYNC)
  // ============================================================

  Stream<List<TableModel>> streamTables(String cafeId) =>
      _watch<List<TableModel>>(
        realtimeType: RealtimeEventType.tables,
        cacheRestore: () => LocalCacheService().getCachedList('cache_tables_$cafeId', TableModel.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_tables_$cafeId', data, (t) => t.toJson()),
        fetch: () async {
          final res = await _api.get('/tables');
          return _list(res['tables'], TableModel.fromJson);
        },
        triggers: [
          CafeSocketEvent.tableOrderUpdated,
          CafeSocketEvent.tableReleased,
          CafeSocketEvent.tableStatusUpdated,
        ],
      );

  Stream<List<Hall>> streamHalls(String cafeId) =>
      _watch<List<Hall>>(
        realtimeType: RealtimeEventType.halls,
        cacheRestore: () => LocalCacheService().getCachedList('cache_halls_$cafeId', Hall.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_halls_$cafeId', data, (h) => h.toJson()),
        fetch: () async {
          final res = await _api.get('/halls');
          return _list(res['halls'], Hall.fromJson);
        },
        triggers: [CafeSocketEvent.hallsUpdated],
      );

  Stream<List<Category>> streamCategories(String cafeId) =>
      _watch<List<Category>>(
        realtimeType: RealtimeEventType.categories,
        cacheRestore: () => LocalCacheService().getCachedList('cache_categories_$cafeId', Category.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_categories_$cafeId', data, (c) => c.toJson()),
        fetch: () async {
          final res = await _api.get('/categories');
          return _list(res['categories'], Category.fromJson);
        },
        triggers: [CafeSocketEvent.categoriesUpdated],
      );

  Stream<List<Product>> streamProducts(String cafeId) => _watch<List<Product>>(
        realtimeType: RealtimeEventType.products,
        cacheRestore: () => LocalCacheService().getCachedList('cache_products_$cafeId', Product.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_products_$cafeId', data, (p) => p.toJson()),
        fetch: () async {
          final res = await _api.get('/products');
          return _list(res['products'], Product.fromJson);
        },
        triggers: [CafeSocketEvent.productsUpdated],
      );

  Stream<List<Customer>> streamCustomers(String cafeId) =>
      _watch<List<Customer>>(
        realtimeType: RealtimeEventType.customers,
        cacheRestore: () => LocalCacheService().getCachedList('cache_customers_$cafeId', Customer.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_customers_$cafeId', data, (c) => c.toJson()),
        fetch: () async {
          final res = await _api.get('/customers');
          return _list(res['customers'], Customer.fromJson);
        },
        triggers: [CafeSocketEvent.customersUpdated],
      );

  Stream<List<AppUser>> streamEmployees(String cafeId) =>
      _watch<List<AppUser>>(
        realtimeType: RealtimeEventType.employees,
        cacheRestore: () => LocalCacheService().getCachedList('cache_employees_$cafeId', AppUser.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_employees_$cafeId', data, (e) => e.toJson()),
        fetch: () async {
          final res = await _api.get('/employees');
          return _list(res['employees'], AppUser.fromJson);
        },
        triggers: [CafeSocketEvent.employeesUpdated],
      );

  Stream<Map<int, List<CartItem>>> streamTableOrders(String cafeId) =>
      _watch<Map<int, List<CartItem>>>(
        realtimeType: RealtimeEventType.tableOrders,
        cacheRestore: () async {
          final cached = await LocalCacheService().getCachedMap('cache_table_orders_$cafeId');
          if (cached == null) return null;
          return _tableOrdersFromJson(cached);
        },
        cacheSave: (data) async {
          if (data.isNotEmpty) {
            final jsonMap = data.map((k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()));
            await LocalCacheService().setCachedMap('cache_table_orders_$cafeId', jsonMap);
          }
        },
        fetch: () async {
          final res = await _api.get('/tables');
          return _tableOrdersFromJson(res['tableOrders']);
        },
        triggers: [
          CafeSocketEvent.tableOrderUpdated,
          CafeSocketEvent.tableReleased,
        ],
      );

  Stream<Map<int, String>> streamTableNotes(String cafeId) =>
      _watch<Map<int, String>>(
        realtimeType: RealtimeEventType.tableOrders,
        fetch: () async {
          final res = await _api.get('/tables');
          return _tableNotesFromJson(res['tableOrders'] ?? res['tables']);
        },
        triggers: [
          CafeSocketEvent.tableOrderUpdated,
          CafeSocketEvent.tableReleased,
        ],
      );

  Stream<List<Receipt>> streamReceipts(String cafeId) => _watch<List<Receipt>>(
        realtimeType: RealtimeEventType.receipts,
        cacheRestore: () => LocalCacheService().getCachedList('cache_receipts_$cafeId', Receipt.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_receipts_$cafeId', data, (r) => r.toJson()),
        fetch: () async {
          final res = await _api.get('/receipts');
          return _list(res['receipts'], Receipt.fromJson);
        },
        triggers: [CafeSocketEvent.receiptAdded],
      );

  Stream<List<CustomerOrder>> streamCustomerOrders(String cafeId) =>
      _watch<List<CustomerOrder>>(
        realtimeType: RealtimeEventType.customerOrders,
        cacheRestore: () => LocalCacheService().getCachedList('cache_customer_orders_$cafeId', CustomerOrder.fromJson),
        cacheSave: (data) => LocalCacheService().setCachedList('cache_customer_orders_$cafeId', data, (co) => co.toJson()),
        fetch: () async {
          final res = await _api.get('/customer-orders');
          return _list(res['customerOrders'], CustomerOrder.fromJson);
        },
        triggers: [
          CafeSocketEvent.customerOrderUpdated,
          CafeSocketEvent.newCustomerOrder,
        ],
      );

  Stream<DailyReport?> streamDailyReport(String cafeId, String dateId) =>
      _watch<DailyReport?>(
        realtimeType: RealtimeEventType.reports,
        fetch: () async {
          final res = await _api.get('/reports/$dateId');
          final raw = res['report'];
          if (raw == null) return null;
          return DailyReport.fromJson(_map(raw));
        },
        triggers: [
          CafeSocketEvent.reportUpdated,
          CafeSocketEvent.reportCleared
        ],
      );

  Stream<List<DailyReport>> streamReports(String cafeId) =>
      _watch<List<DailyReport>>(
        realtimeType: RealtimeEventType.reports,
        fetch: () async {
          final res = await _api.get('/reports');
          return _list(res['reports'], DailyReport.fromJson);
        },
        triggers: [
          CafeSocketEvent.reportUpdated,
          CafeSocketEvent.reportCleared
        ],
      );

  // ============================================================
  // STOL VA BUYURTMA
  // ============================================================

  /// Savat o'zgarishlarini backendga sinxronlash (telefon <-> planshet).
  /// forceOccupy=false bo'lib, stol boshqa foydalanuvchi tomonidan band
  /// qilingan bo'lsa, backend 409 TABLE_BUSY qaytaradi -> TableBusyException.
  Future<void> saveTableOrder({
    required String cafeId,
    required int tableId,
    required List<CartItem> items,
    String note = '',
    bool forceOccupy = false,
  }) async {
    if (items.isEmpty) {
      await releaseTable(cafeId: cafeId, tableId: tableId);
      return;
    }
    try {
      await _api.post('/tables/$tableId/order', body: {
        'items': items.map((e) => e.toJson()).toList(),
        'note': note,
        'forceOccupy': forceOccupy,
      });
    } on ApiException catch (e) {
      if (e.code == 'TABLE_BUSY' || e.statusCode == 409) {
        throw TableBusyException(e.message);
      }
      rethrow;
    } catch (e) {
      debugPrint('saveTableOrder tarmoq xatosi, oflayn navbatga olinmoqda: $e');
      try {
        await OfflineSyncService().queueTableOrder(
          cafeId: cafeId,
          tableId: tableId,
          items: items,
          note: note,
        );
      } catch (_) {}
    }
  }

  Future<bool> lockTableForCheckout({
    required String cafeId,
    required int tableId,
    required List<CartItem> items,
    required String note,
  }) async {
    try {
      await saveTableOrder(
        cafeId: cafeId,
        tableId: tableId,
        items: items,
        note: note,
        forceOccupy: true,
      );
      return true;
    } on TableBusyException {
      rethrow;
    } catch (e) {
      debugPrint('lockTableForCheckout xatoligi: $e');
      return false;
    }
  }

  Future<void> releaseTable({
    required String cafeId,
    required int tableId,
  }) async {
    try {
      await _api.post('/tables/$tableId/release');
    } catch (e) {
      debugPrint('releaseTable xatoligi: $e');
    }
  }

  Future<void> updateTableStatus({
    required String cafeId,
    required int tableId,
    required TableStatus status,
  }) async {
    try {
      await _api.put('/tables/$tableId/status', body: {'status': status.name});
    } catch (e) {
      debugPrint('updateTableStatus xatoligi: $e');
    }
  }

  Future<TableModel?> createTable({
    required String cafeId,
    required int hallId,
    required int number,
    int seats = 4,
  }) async {
    try {
      final res = await _api.post('/tables', body: {
        'hallId': hallId,
        'number': number,
        'seats': seats,
      });
      if (res['table'] != null) {
        return TableModel.fromJson(_map(res['table']));
      }
    } catch (e) {
      debugPrint('createTable xatoligi: $e');
    }
    return null;
  }

  Future<TableModel?> updateTable({
    required String cafeId,
    required int tableId,
    int? number,
    int? seats,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (number != null) body['number'] = number;
      if (seats != null) body['seats'] = seats;
      final res = await _api.put('/tables/$tableId', body: body);
      if (res['table'] != null) {
        return TableModel.fromJson(_map(res['table']));
      }
    } catch (e) {
      debugPrint('updateTable xatoligi: $e');
    }
    return null;
  }

  Future<bool> deleteTable({
    required String cafeId,
    required int tableId,
    bool force = false,
  }) async {
    try {
      final res = await _api.delete('/tables/$tableId?force=$force');
      return res['success'] == true;
    } catch (e) {
      debugPrint('deleteTable xatoligi: $e');
      return false;
    }
  }

  Future<bool> clearAllTables(String cafeId) async {
    try {
      final res = await _api.post('/tables/clear-all');
      return res['success'] == true;
    } catch (e) {
      debugPrint('clearAllTables xatoligi: $e');
      return false;
    }
  }

  Future<bool> clearHallTables(String cafeId, int hallId) async {
    try {
      final res = await _api.post('/tables/clear-hall/$hallId');
      return res['success'] == true;
    } catch (e) {
      debugPrint('clearHallTables xatoligi: $e');
      return false;
    }
  }



  /// To'lovni yakunlash — POST /api/receipts/checkout (backend transaction
  /// hammasini bajaradi: chek, ombor, kunlik hisobot, stolni bo'shatish).
  Future<bool> completeCheckout({
    required String cafeId,
    required Receipt receipt,
    required int? tableId,
    required List<CartItem> items,
    required List<Product> allProducts,
    required String ownerId,
  }) async {
    try {
      await _api.post('/receipts/checkout', body: {
        'receipt': receipt.toJson(),
        'tableId': tableId,
        'items': items.map((e) => e.toJson()).toList(),
      });
      return true;
    } catch (e) {
      debugPrint('completeCheckout tarmoq xatoligi, oflayn navbatga saqlanmoqda: $e');
      try {
        await OfflineSyncService().queueCheckout(
          cafeId: cafeId,
          receipt: receipt,
          tableId: tableId,
          items: items,
        );
        return true;
      } catch (offlineErr) {
        debugPrint('Offline checkout queue error: $offlineErr');
        return false;
      }
    }
  }

  Future<void> clearReport(String cafeId, String dateId) async {
    await _api.delete('/reports/$dateId');
  }

  // ============================================================
  // CRUD
  // ============================================================

  Future<Product?> saveProduct(String cafeId, Product p, {String? originalName}) async {
    try {
      final body = p.toJson();
      if (originalName != null && originalName.trim().isNotEmpty) {
        body['originalName'] = originalName.trim();
      }
      final res = await _api.post('/products', body: body);
      if (res['success'] == true && res['product'] != null) {
        return Product.fromJson(Map<String, dynamic>.from(res['product']));
      }
    } catch (e) {
      debugPrint('saveProduct xatoligi: $e');
    }
    return null;
  }

  Future<void> deleteProduct(String cafeId, int productId, {String? productName}) async {
    final query = productName != null && productName.trim().isNotEmpty
        ? '?name=${Uri.encodeComponent(productName.trim())}'
        : '';
    await _api.delete('/products/$productId$query');
  }

  Future<void> deleteProductsBulk(String cafeId, List<int> productIds) async {
    await _api.post('/products/bulk-delete', body: {
      'cafeId': cafeId,
      'productIds': productIds,
    });
  }

  Future<void> saveCategory(String cafeId, Category c) async {
    await _api.post('/categories', body: c.toJson());
  }

  Future<void> deleteCategory(String cafeId, int categoryId) async {
    await _api.delete('/categories/$categoryId');
  }

  Future<void> saveEmployee(String cafeId, AppUser user) async {
    await _api.post('/employees', body: user.toJson());
  }

  Future<void> deleteEmployee(String cafeId, int userId) async {
    await _api.delete('/employees/$userId');
  }

  Future<Hall?> saveHall(String cafeId, {int? id, required String name, int? iconCodePoint, String? imageAsset}) async {
    try {
      final res = await _api.post('/halls', body: {
        if (id != null) 'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint ?? 0xe318,
        if (imageAsset != null) 'imageAsset': imageAsset,
      });
      if (res['success'] == true && res['hall'] != null) {
        return Hall.fromJson(Map<String, dynamic>.from(res['hall']));
      }
    } catch (e) {
      debugPrint('saveHall xatoligi: $e');
    }
    return null;
  }

  Future<void> deleteHall(String cafeId, int hallId) async {
    try {
      await _api.delete('/halls/$hallId');
    } catch (e) {
      debugPrint('deleteHall xatoligi: $e');
    }
  }

  Future<void> saveCustomer(String cafeId, Customer c) async {
    await _api.post('/customers', body: c.toJson());
  }

  Future<void> deleteCustomer(String cafeId, int customerId) async {
    await _api.delete('/customers/$customerId');
  }

  Future<void> saveCustomerOrder(String cafeId, CustomerOrder order) async {
    await _api.post('/customer-orders', body: order.toJson());
  }

  Future<void> updateCustomerOrderStatus(
    String cafeId,
    int orderId,
    OrderStatus status,
  ) async {
    await _api
        .put('/customer-orders/$orderId/status', body: {'status': status.name});
  }

  Future<void> reportIssue({
    required String title,
    required String description,
    String? phone,
  }) async {
    await _api.post('/cafe/report-issue', body: {
      'title': title,
      'description': description,
      if (phone != null) 'phone': phone,
    });
  }

  Future<bool> getMaintenanceStatus() async {
    try {
      final res = await _api.get('/cafe/maintenance-status');
      return res['isUnderMaintenance'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSettings(
      String cafeId, Map<String, dynamic> settings) async {
    await _api.put('/cafe/settings', body: settings);
  }

  Future<bool> updateReceiptName(String cafeId, String receiptName) async {
    try {
      final res = await _api.put('/cafe/receipt-name', body: {
        'receiptName': receiptName,
      });
      return res['success'] == true;
    } catch (e) {
      debugPrint('updateReceiptName xatoligi: $e');
      try {
        await saveSettings(cafeId, {'receiptName': receiptName});
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<bool> restoreDefaultMenu() async {
    try {
      final res = await _api.post('/cafe/restore-menu');
      return res['success'] == true;
    } catch (e) {
      debugPrint('restoreDefaultMenu xatoligi: $e');
      return false;
    }
  }

  Future<void> logActivity(String cafeId, ActivityLog log) async {
    try {
      await _api.post('/activity', body: {
        'action': log.action,
        'details': log.details,
        'performedBy': log.performedBy,
      });
    } catch (e) {
      debugPrint('logActivity xatoligi: $e');
    }
  }
}
