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
    if (_socket != null && _connectedCafeId == cafeId && isConnected) return;

    disconnect();
    _connectedCafeId = cafeId;

    final url = ApiClient().socketUrl;
    final options = io.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .enableAutoConnect()
        .enableReconnection()
        .setReconnectionAttempts(999999)
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(5000)
        .setTimeout(12000)
        .enableForceNew();

    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      options.setAuth({'token': effectiveToken});
      options.setExtraHeaders({'Authorization': 'Bearer $effectiveToken'});
    }

    try {
      _socket = io.io(url, options.build());

      _socket!.onConnect((_) {
        debugPrint('🔌 SocketService: ulandi ($url)');
        _socket!.emit('JOIN_CAFE', {
          'cafeId': cafeId,
          if (effectiveToken != null) 'token': effectiveToken,
        });
        _notifyAllForResync();
        _startHeartbeat(cafeId, effectiveToken);
      });

      _socket!.onReconnect((_) {
        debugPrint('🔄 SocketService: qayta ulandi ($url)');
        _socket!.emit('JOIN_CAFE', {
          'cafeId': cafeId,
          if (effectiveToken != null) 'token': effectiveToken,
        });
        _notifyAllForResync();
      });

      _socket!.onDisconnect((_) {
        debugPrint('❌ SocketService: uzildi');
      });

      _socket!.onConnectError((e) {
        debugPrint('SocketService ulanish xatoligi: $e');
      });

      _socket!.onError((e) {
        debugPrint('SocketService xatoligi: $e');
      });

      for (final entry in _eventNames.entries) {
        _socket!.on(entry.value, (data) {
          if (data is Map) {
            _controllers[entry.key]!.add(Map<String, dynamic>.from(data));
          } else {
            _controllers[entry.key]!.add(<String, dynamic>{});
          }
        });
      }
    } catch (e) {
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
      } else if (_socket != null && !_socket!.connected) {
        try {
          _socket!.connect();
        } catch (_) {}
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

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
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
