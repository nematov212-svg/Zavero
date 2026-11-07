import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_client.dart';

/// Backend socketHandler.js qaytaradigan barcha real-time hodisalar.
enum CafeSocketEvent {
  tableOrderUpdated,
  tableReleased,
  tableStatusUpdated,
  productsUpdated,
  categoriesUpdated,
  customersUpdated,
  employeesUpdated,
  receiptAdded,
  reportUpdated,
  reportCleared,
  customerOrderUpdated,
  newCustomerOrder,
  settingsUpdated,
  maintenanceStatus,
  supportIssueReported,
  hallsUpdated,
  staffStatusUpdated,
  staffMovementUpdated,
  subscriptionExtended,
  bannersUpdated,
  executePrintJob,
  printerStationStatusChanged,
  printJobCompleted,
  printJobFailed,
  userForceLogout,
}

const Map<CafeSocketEvent, String> _eventNames = {
  CafeSocketEvent.tableOrderUpdated: 'TABLE_ORDER_UPDATED',
  CafeSocketEvent.tableReleased: 'TABLE_RELEASED',
  CafeSocketEvent.tableStatusUpdated: 'TABLE_STATUS_UPDATED',
  CafeSocketEvent.productsUpdated: 'PRODUCTS_UPDATED',
  CafeSocketEvent.categoriesUpdated: 'CATEGORIES_UPDATED',
  CafeSocketEvent.customersUpdated: 'CUSTOMERS_UPDATED',
  CafeSocketEvent.employeesUpdated: 'EMPLOYEES_UPDATED',
  CafeSocketEvent.receiptAdded: 'RECEIPT_ADDED',
  CafeSocketEvent.reportUpdated: 'REPORT_UPDATED',
  CafeSocketEvent.reportCleared: 'REPORT_CLEARED',
  CafeSocketEvent.customerOrderUpdated: 'CUSTOMER_ORDER_UPDATED',
  CafeSocketEvent.newCustomerOrder: 'NEW_CUSTOMER_ORDER',
  CafeSocketEvent.settingsUpdated: 'SETTINGS_UPDATED',
  CafeSocketEvent.maintenanceStatus: 'CAFE_MAINTENANCE_STATUS',
  CafeSocketEvent.supportIssueReported: 'SUPPORT_ISSUE_REPORTED',
  CafeSocketEvent.hallsUpdated: 'HALLS_UPDATED',
  CafeSocketEvent.staffStatusUpdated: 'STAFF_STATUS_UPDATED',
  CafeSocketEvent.staffMovementUpdated: 'STAFF_MOVEMENT_UPDATED',
  CafeSocketEvent.subscriptionExtended: 'SUBSCRIPTION_EXTENDED',
  CafeSocketEvent.bannersUpdated: 'BANNERS_UPDATED',
  CafeSocketEvent.executePrintJob: 'EXECUTE_PRINT_JOB',
  CafeSocketEvent.printerStationStatusChanged: 'PRINTER_STATION_STATUS_CHANGED',
  CafeSocketEvent.printJobCompleted: 'PRINT_JOB_COMPLETED',
  CafeSocketEvent.printJobFailed: 'PRINT_JOB_FAILED',
  CafeSocketEvent.userForceLogout: 'USER_FORCE_LOGOUT',
};

/// socket_io_client ustidan qatlam: JWT bilan ulanish, JOIN_CAFE,
/// iOS, Android, macOS, Windows va Web platformalarida barqaror real-time ishlash.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _connectedCafeId;
  Timer? _heartbeatTimer;
  bool _isPrinterStationRegistered = false;
  String? _printerStationCafeId;
  bool _isConnecting = false;

  final Map<String, int> _lastEventTimestamps = {};

  final Map<CafeSocketEvent, StreamController<Map<String, dynamic>>>
      _controllers = {
    for (final e in CafeSocketEvent.values)
      e: StreamController<Map<String, dynamic>>.broadcast(),
  };

  bool get isConnected => _socket?.connected ?? false;

  /// Har bir backend hodisasi uchun alohida Stream (masalan PRODUCTS_UPDATED).
  Stream<Map<String, dynamic>> on(CafeSocketEvent event) =>
      _controllers[event]!.stream;

  /// JWT token bilan socket ulanishini o'rnatish va cafe xonasiga qo'shilish.
  void connect({String? token, required String cafeId}) {
    final effectiveToken = token ?? ApiClient().token;

    // Token yoki cafeId yo'q bo'lsa yoki local_default bo'lsa umuman ulanmasin
    if (cafeId.isEmpty || cafeId == 'local_default') {
      debugPrint('ℹ️ [SocketService] Ulanish bekor qilindi: yaroqsiz cafeId ("$cafeId")');
      return;
    }
    if (effectiveToken == null || effectiveToken.isEmpty) {
      debugPrint('ℹ️ [SocketService] Ulanish bekor qilindi: token topilmadi');
      return;
    }

    // Duplicate ulanishni oldini olish: allaqachon shu cafeId bilan ulangan yoki ulanayotgan bo'lsa
    if (_socket != null && _connectedCafeId == cafeId && (_isConnecting || isConnected)) {
      return;
    }

    // Oldingi ulanishni yopish
    disconnect();

    _isConnecting = true;
    _connectedCafeId = cafeId;

    final url = ApiClient().socketUrl;
    final options = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(10) // Cheksiz loopni to'xtatish
        .setReconnectionDelay(2000)
        .setReconnectionDelayMax(30000) // Eksponentsial backoff (2s -> 30s)
        .setTimeout(15000)
        .setAuth({'token': effectiveToken})
        .setExtraHeaders({'Authorization': 'Bearer $effectiveToken'});

    try {
      _socket = io.io(url, options.build());

      _socket!.onConnect((_) {
        _isConnecting = false;
        debugPrint('🔌 SocketService: ulandi ($url)');
        _socket!.emit('JOIN_CAFE', {
          'cafeId': cafeId,
          'token': effectiveToken,
        });
        if (_isPrinterStationRegistered && _printerStationCafeId != null) {
          _socket!.emit('REGISTER_PRINTER_STATION', {'cafeId': _printerStationCafeId});
          debugPrint('🖨️ SocketService: Kassa printer stansiyasi qayta ro‘yxatga olindi');
        }
        if (ApiClient().isAuthenticated) {
          _notifyAllForResync();
        }
        _startHeartbeat(cafeId, effectiveToken);
      });

      _socket!.onReconnect((_) {
        _isConnecting = false;
        debugPrint('🔄 SocketService: qayta ulandi ($url)');
        _socket!.emit('JOIN_CAFE', {
          'cafeId': cafeId,
          'token': effectiveToken,
        });
        if (_isPrinterStationRegistered && _printerStationCafeId != null) {
          _socket!.emit('REGISTER_PRINTER_STATION', {'cafeId': _printerStationCafeId});
          debugPrint('🖨️ SocketService: Kassa printer stansiyasi qayta ro‘yxatga olindi (reconnect)');
        }
        if (ApiClient().isAuthenticated) {
          _notifyAllForResync();
        }
      });

      _socket!.onDisconnect((reason) {
        _isConnecting = false;
        debugPrint('❌ SocketService: uzildi ($reason)');
      });

      _socket!.onConnectError((e) {
        _isConnecting = false;
        debugPrint('SocketService ulanish xatoligi: $e');
      });

      _socket!.onError((e) {
        _isConnecting = false;
        debugPrint('SocketService xatoligi: $e');
      });

      for (final entry in _eventNames.entries) {
        _socket!.on(entry.value, (data) {
          final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
          // Event deduplication within 120ms to prevent duplicate rapid trigger
          final eventSignature = '${entry.value}_${map['id'] ?? map['tableId'] ?? map['receipt']?['id'] ?? ''}_${map['status'] ?? ''}';
          final now = DateTime.now().millisecondsSinceEpoch;
          final lastTime = _lastEventTimestamps[eventSignature] ?? 0;
          if (now - lastTime < 120 && eventSignature != '${entry.value}__') {
            return;
          }
          _lastEventTimestamps[eventSignature] = now;
          if (_lastEventTimestamps.length > 500) {
            _lastEventTimestamps.clear();
          }
          _controllers[entry.key]!.add(map);
        });
      }

      // Also listen to lower-case 'reports_cleared' for maximum cross-compatibility
      _socket!.on('reports_cleared', (data) {
        final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
        _controllers[CafeSocketEvent.reportCleared]?.add(map);
      });
    } catch (e) {
      _isConnecting = false;
      debugPrint('SocketService init xatoligi: $e');
    }
  }

  void _startHeartbeat(String cafeId, String? token) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_socket != null && _socket!.connected) {
        _socket!.emit('JOIN_CAFE', {
          'cafeId': cafeId,
          if (token != null) 'token': token,
        });
      }
    });
  }

  void joinCafe(String cafeId) {
    joinAdditionalRoom(cafeId);
  }

  void joinAdditionalRoom(String cafeId) {
    if (_socket != null) {
      _socket!.emit('JOIN_CAFE', {'cafeId': cafeId});
    }
  }

  void leaveAdditionalRoom(String cafeId) {
    if (_socket != null) {
      _socket!.emit('LEAVE_CAFE', {'cafeId': cafeId});
    }
  }

  void emitStaffStatus(Map<String, dynamic> data) {
    if (_socket != null) {
      _socket!.emit('STAFF_STATUS_UPDATE', data);
    }
  }

  void emitStaffMovement(Map<String, dynamic> data) {
    if (_socket != null) {
      _socket!.emit('STAFF_MOVEMENT_UPDATE', data);
    }
  }

  /// Kassa qurilmasini printer stansiyasi sifatida ro'yxatga olish
  void registerPrinterStation(String cafeId, {String? stationName, bool isPrinterReady = true}) {
    _isPrinterStationRegistered = true;
    _printerStationCafeId = cafeId;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('REGISTER_PRINTER_STATION', {
        'cafeId': cafeId,
        'stationName': stationName,
        'isPrinterReady': isPrinterReady,
      });
      debugPrint('🖨️ SocketService: REGISTER_PRINTER_STATION yuborildi ($cafeId, $stationName, ready: $isPrinterReady)');
    }
  }

  /// Kassa stansiyasi har 4 soniyada heartbeat yuboradi
  void emitPrinterStationHeartbeat(String cafeId, {String? stationName, bool isPrinterReady = true}) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('PRINTER_STATION_HEARTBEAT', {
        'cafeId': cafeId,
        'stationName': stationName,
        'isPrinterReady': isPrinterReady,
      });
    }
  }

  /// Kassa qurilmasini printer stansiyasidan chiqarish
  void unregisterPrinterStation(String cafeId) {
    _isPrinterStationRegistered = false;
    _printerStationCafeId = null;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('UNREGISTER_PRINTER_STATION', {'cafeId': cafeId});
      debugPrint('🖨️ SocketService: UNREGISTER_PRINTER_STATION yuborildi ($cafeId)');
    }
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isConnecting = false;
    if (_socket != null) {
      try {
        _socket!.clearListeners();
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _connectedCafeId = null;
  }

  void _notifyAllForResync() {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.add(<String, dynamic>{'resync': true});
      }
    }
  }
}
