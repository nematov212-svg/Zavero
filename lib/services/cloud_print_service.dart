import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// Result returned from requesting a cloud/station print job.
class CloudPrintResult {
  final bool success;
  final bool routedToStation;
  final bool duplicate;
  final String message;

  const CloudPrintResult({
    required this.success,
    required this.routedToStation,
    this.duplicate = false,
    required this.message,
  });
}

/// Dispatches print jobs from mobile devices / Telegram bot to the Cafe's
/// dedicated Cashier Printer Station via backend WebSocket & REST routing.
class CloudPrintService {
  static final CloudPrintService _instance = CloudPrintService._internal();
  factory CloudPrintService() => _instance;
  CloudPrintService._internal();

  final Map<String, int> _localDebounce = {};

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
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = _localDebounce[id] ?? 0;
    if (now - lastTime < 5000) {
      debugPrint('ℹ️ [CloudPrint] Local debounce active for job $id (5s)');
      return const CloudPrintResult(
        success: true,
        routedToStation: true,
        duplicate: true,
        message: 'Chek kassa printeriga yuborildi va chop etilmoqda',
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
      final res = await ApiClient().post(
        '/receipts/print-job',
        body: payload,
      ).timeout(const Duration(milliseconds: 3500));

      final routed = res['routedToStation'] == true;
      final duplicate = res['duplicate'] == true;
      final msg = res['message']?.toString() ??
          (routed
              ? 'Chek kassa printeriga yuborildi va chop etilmoqda'
              : 'Printer qurilmasi ulanmagan, chek ekranda ko\'rsatildi');

      return CloudPrintResult(
        success: res['success'] == true || routed,
        routedToStation: routed,
        duplicate: duplicate,
        message: msg,
      );
    } catch (e) {
      debugPrint('⚠️ [CloudPrint] Dispatch xatosi: $e');
    }

    return const CloudPrintResult(
      success: false,
      routedToStation: false,
      message: 'Printer qurilmasi ulanmagan, chek ekranda ko\'rsatildi',
    );
  }
}
