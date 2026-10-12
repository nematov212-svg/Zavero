import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

enum RealtimeEventType {
  tables,
  tableOrders,
  customerOrders,
  receipts,
  products,
  categories,
  halls,
  customers,
  employees,
  reports,
}

/// Supabase Realtime xizmati:
/// PostgreSQL jadvallaridagi (INSERT, UPDATE, DELETE) o'zgarishlarini
/// Supabase Realtime WebSocket kanallari orqali ushlab, ilovadagi barcha
/// ochiq qurilmalarni (Computer A, Computer B, telefon, planshet)
/// bir zumda, sahifani yangilamasdan sinxronizatsiya qiladi.
class SupabaseRealtimeService {
  static final SupabaseRealtimeService _instance =
      SupabaseRealtimeService._internal();
  factory SupabaseRealtimeService() => _instance;
  SupabaseRealtimeService._internal();

  SupabaseClient? _client;
  RealtimeChannel? _currentChannel;
  String? _subscribedCafeId;

  final Map<RealtimeEventType, StreamController<Map<String, dynamic>>>
      _controllers = {
    for (var type in RealtimeEventType.values)
      type: StreamController<Map<String, dynamic>>.broadcast()
  };

  Stream<Map<String, dynamic>> on(RealtimeEventType type) {
    return _controllers[type]!.stream;
  }

  bool get isConnected => _client != null && _currentChannel != null;

  /// Supabase clientni ishga tushirish (agar URL va AnonKey mavjud bo'lsa)
  Future<void> init() async {
    await SupabaseConfig.loadSavedConfig();
    if (!SupabaseConfig.isConfigured) {
      debugPrint(
          'ℹ️ [SupabaseRealtime] SupabaseConfig hali kiritilmagan. Realtime kutilmoqda.');
      return;
    }

    try {
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.anonKey,
          realtimeClientOptions: const RealtimeClientOptions(
            eventsPerSecond: 10,
          ),
        );
        _client = Supabase.instance.client;
      }
      debugPrint('⚡ [SupabaseRealtime] Supabase Realtime faollashtirildi: ${SupabaseConfig.url}');
    } catch (e) {
      debugPrint('⚠️ [SupabaseRealtime] Init xatosi: $e');
    }
  }

  /// Cafe uchun barcha PostgreSQL o'zgarishlariga subscribe bo'lish
  void subscribeToCafe(String cafeId) {
    if (!SupabaseConfig.isConfigured) return;

    if (_client == null) {
      try {
        _client = Supabase.instance.client;
      } catch (_) {
        return;
      }
    }

    if (_subscribedCafeId == cafeId && _currentChannel != null) {
      return;
    }

    unsubscribe();
    _subscribedCafeId = cafeId;

    final channelName = 'zavero_cafe_$cafeId';
    final channel = _client!.channel(channelName);

    void registerListener(String table, RealtimeEventType eventType) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'cafe_id',
          value: cafeId,
        ),
        callback: (payload) {
          debugPrint(
              '⚡ [Supabase Realtime] $table o\'zgardi (${payload.eventType})');
          final data = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;
          _emit(eventType, data);
        },
      );
    }

    // 1. Stollar (restaurant_tables)
    registerListener('restaurant_tables', RealtimeEventType.tables);

    // 2. Jonli stol savati (table_orders)
    registerListener('table_orders', RealtimeEventType.tableOrders);

    // 3. Mijoz buyurtmalari (customer_orders)
    registerListener('customer_orders', RealtimeEventType.customerOrders);

    // 4. Cheklar va to'lovlar (receipts)
    registerListener('receipts', RealtimeEventType.receipts);

    // 5. Mahsulotlar (products)
    registerListener('products', RealtimeEventType.products);

    // 6. Kategoriyalar (categories)
    registerListener('categories', RealtimeEventType.categories);

    // 7. Zallar (halls)
    registerListener('halls', RealtimeEventType.halls);

    // 8. Mijozlar (customers)
    registerListener('customers', RealtimeEventType.customers);

    // 9. Xodimlar (employees)
    registerListener('employees', RealtimeEventType.employees);

    // 10. Hisobotlar (reports)
    registerListener('reports', RealtimeEventType.reports);

    channel.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint(
            '✅ [SupabaseRealtime] $channelName ga muvaffaqiyatli ulandi (Real-time Jonli Faol)');
      } else if (error != null) {
        debugPrint('⚠️ [SupabaseRealtime] Kanal obuna xatosi: $error');
      }
    });

    _currentChannel = channel;
  }

  void _emit(RealtimeEventType type, Map<String, dynamic> data) {
    if (_controllers[type]?.isClosed == false) {
      _controllers[type]!.add(data);
    }
  }

  void unsubscribe() {
    if (_currentChannel != null) {
      _client?.removeChannel(_currentChannel!);
      _currentChannel = null;
      _subscribedCafeId = null;
      debugPrint('🔌 [SupabaseRealtime] Obuna to\'xtatildi');
    }
  }

  void dispose() {
    unsubscribe();
    for (final c in _controllers.values) {
      c.close();
    }
  }
}
