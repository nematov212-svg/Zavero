import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

enum ConnectivityState {
  online,
  offline,
  serverUnavailable,
  checking,
}

/// Tarmoq va Server aloqasini ishonchli kuzatuvchi servis (Phase 5).
/// Faqat tarmoq interfeysini emas, balki haqiqiy backend (`/api/health`)
/// mavjudligini xavfsiz timeout va eksponensial kechikish bilan tekshiradi.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final ValueNotifier<ConnectivityState> stateNotifier =
      ValueNotifier<ConnectivityState>(ConnectivityState.checking);
  final ValueNotifier<int?> latencyNotifier = ValueNotifier<int?>(null);

  Timer? _timer;
  bool _isChecking = false;
  int _consecutiveFailures = 0;

  ConnectivityState get currentState => stateNotifier.value;
  bool get isOnline => stateNotifier.value == ConnectivityState.online;
  int get consecutiveFailures => _consecutiveFailures;

  void init() {
    if (_timer != null) return;
    checkNow();
    // Har 10 soniyada tekshirib turamiz
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    await _check();
  }

  Future<void> _check() async {
    if (_isChecking) return;
    _isChecking = true;

    final sw = Stopwatch()..start();
    try {
      final res = await ApiClient().health().timeout(const Duration(seconds: 4));
      sw.stop();
      final ms = sw.elapsedMilliseconds;

      if (res != null && res['status'] == 'ok') {
        _consecutiveFailures = 0;
        latencyNotifier.value = ms;
        stateNotifier.value = ConnectivityState.online;
      } else {
        _consecutiveFailures++;
        latencyNotifier.value = null;
        stateNotifier.value = ConnectivityState.serverUnavailable;
      }
    } catch (e) {
      sw.stop();
      _consecutiveFailures++;
      latencyNotifier.value = null;

      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection refused') ||
          errStr.contains('network is unreachable')) {
        stateNotifier.value = ConnectivityState.offline;
      } else {
        stateNotifier.value = ConnectivityState.serverUnavailable;
      }
    } finally {
      _isChecking = false;
    }
  }
}
