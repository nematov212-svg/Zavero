import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'socket_service.dart';

/// Result returned from requesting a cloud/station print job.
class CloudPrintResult {
  final bool success;
  final bool routedToStation;
  final bool hasActiveStation;
  final bool duplicate;
  final String? stationName;
  final String message;

  const CloudPrintResult({
    required this.success,
    required this.routedToStation,
    this.hasActiveStation = false,
    this.duplicate = false,
    this.stationName,
    required this.message,
  });
}

/// Dispatches print jobs from mobile devices / Telegram bot to the Cafe's
/// dedicated Cashier Printer Station via backend WebSocket & REST routing.
class CloudPrintService {
  static final CloudPrintService _instance = CloudPrintService._internal();
  factory CloudPrintService() => _instance;
  CloudPrintService._internal() {
    _initSocketListeners();
  }

  final Map<String, int> _localDebounce = {};
  final Map<String, Completer<bool>> _pendingJobCompleters = {};

  void _initSocketListeners() {
    SocketService().on(CafeSocketEvent.printJobCompleted).listen((data) {
      final id = data['id']?.toString() ?? data['jobId']?.toString();
      if (id != null && _pendingJobCompleters.containsKey(id)) {
        _pendingJobCompleters[id]?.complete(true);
        _pendingJobCompleters.remove(id);
      }
    });

    SocketService().on(CafeSocketEvent.printJobFailed).listen((data) {
      final id = data['id']?.toString() ?? data['jobId']?.toString();
      if (id != null && _pendingJobCompleters.containsKey(id)) {
        _pendingJobCompleters[id]?.complete(false);
        _pendingJobCompleters.remove(id);
      }
    });
  }

  /// Kassa printer stansiyasining real holatini tekshirish
  Future<Map<String, dynamic>> getPrinterStationStatus(String cafeId) async {
    if (cafeId.isEmpty || cafeId == 'local_default' || !ApiClient().isAuthenticated) {
      return {'hasStation': false, 'isPrinterReady': false};
    }
    try {
      final res = await ApiClient().get('/receipts/printer-status?cafeId=$cafeId').timeout(const Duration(seconds: 3));
      return res;
    } catch (_) {
      return {'hasStation': false, 'isPrinterReady': false};
    }
  }

  /// Sends a print job to the cafe's active cashier printer station.
  /// Enforces 5-second deduplication per job ID.
  Future<CloudPrintResult> dispatchPrintJob({
    required String id,
    required String type, // 'receipt', 'bill_preview', 'kitchen_ticket'
    required String html,
    Map<String, dynamic>? data,
    String? tableNumber,
    String? hallName,
    bool isAutoCheckout = false,
    bool waitForConfirmation = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _localDebounce[id] ?? 0;
    if (now - lastTime < 4000) {
      debugPrint('ℹ️ [CloudPrint] Local debounce active for job $id (4s)');
      return const CloudPrintResult(
        success: true,
        routedToStation: true,
        hasActiveStation: true,
        duplicate: true,
        message: 'Chek kassa printeriga yuborildi',
      );
    }
    _localDebounce[id] = now;
    if (_localDebounce.length > 200) {
      _localDebounce.clear();
    }

    final payload = {
      'id': id,
      'type': type,
      'html': html,
      'data': data,
      'tableNumber': tableNumber,
      'hallName': hallName,
      'isAutoCheckout': isAutoCheckout,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      final completer = Completer<bool>();
      if (waitForConfirmation) {
        _pendingJobCompleters[id] = completer;
      }

      final res = await ApiClient().post(
        '/receipts/print-job',
        body: payload,
      ).timeout(const Duration(milliseconds: 4000));

      final hasActive = res['hasActiveStation'] == true;
      final routed = res['routedToStation'] == true && hasActive;
      final duplicate = res['duplicate'] == true;
      final stationName = res['stationName']?.toString();
      final msg = res['message']?.toString() ??
          (routed
              ? 'Chek kassa printeriga yuborildi'
              : 'Kassa printeri oflayn. Chek navbatga saqlandi');

      if (waitForConfirmation && routed) {
        // Wait up to 3.5 seconds for physical print completion acknowledgement
        final printed = await completer.future.timeout(
          const Duration(milliseconds: 3500),
          onTimeout: () => true, // default to optimistic if acknowledged by station
        );
        _pendingJobCompleters.remove(id);
        return CloudPrintResult(
          success: printed,
          routedToStation: true,
          hasActiveStation: true,
          duplicate: duplicate,
          stationName: stationName,
          message: printed ? 'Chek chiqarildi' : 'Chop etishda xatolik yuz berdi',
        );
      }

      return CloudPrintResult(
        success: routed,
        routedToStation: routed,
        hasActiveStation: hasActive,
        duplicate: duplicate,
        stationName: stationName,
        message: msg,
      );
    } catch (e) {
      _pendingJobCompleters.remove(id);
      debugPrint('⚠️ [CloudPrint] Dispatch xatosi: $e');
    }

    return const CloudPrintResult(
      success: false,
      routedToStation: false,
      hasActiveStation: false,
      message: 'Kassa printeri oflayn yoki ulanmagan',
    );
  }
}
