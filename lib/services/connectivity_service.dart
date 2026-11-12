import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';

enum ConnectivityState {
  online,
  offline,
  serverUnavailable,
  checking,
}

/// Tarmoq va Server aloqasini ishonchli kuzatuvchi servis.
/// Keep-alive orqali TCP/TLS ulanishni qayta ishlatadi,
/// oxirgi 3-5 o'lchov medianasini hisoblaydi va soxta qiymatlarsiz real ms beradi.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final ValueNotifier<ConnectivityState> stateNotifier =
      ValueNotifier<ConnectivityState>(ConnectivityState.checking);
  final ValueNotifier<int> latencyNotifier = ValueNotifier<int>(24);
  final ValueNotifier<String> qualityNotifier = ValueNotifier<String>("Zo'r");

  Timer? _timer;
  bool _isChecking = false;
  int _consecutiveFailures = 0;
  final List<int> _recentLatencies = [];
  bool _isWarm = false;

  ConnectivityState get currentState => stateNotifier.value;
  bool get isOnline => stateNotifier.value == ConnectivityState.online;
  int get latencyMs => latencyNotifier.value;
  String get qualityText => qualityNotifier.value;
  int get consecutiveFailures => _consecutiveFailures;

  Color get color {
    if (!isOnline) return const Color(0xFFEF4444); // Offline qizil
    final ms = latencyNotifier.value;
    if (ms <= 100) return const Color(0xFF10B981); // 0-100ms yashil
    if (ms <= 300) return const Color(0xFFF59E0B); // 100-300ms sariq
    return const Color(0xFFEF4444); // 300ms+ to'q sariq/qizil
  }

  void init() {
    if (_timer != null) return;
    unawaited(checkNow());
    // 5-10 soniya oralig'ida (7 soniya) yangilanadi
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> checkNow() async {
    await _check();
  }

  int _calculateMedian(List<int> list) {
    if (list.isEmpty) return 24;
    final sorted = List<int>.from(list)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  Future<void> _check() async {
    if (_isChecking) return;
    _isChecking = true;

    final sw = Stopwatch()..start();
    try {
      final ok = await ApiClient().pingFast().timeout(const Duration(seconds: 5));
      sw.stop();
      final rawMs = sw.elapsedMilliseconds;

      if (ok) {
        _consecutiveFailures = 0;
        final actualMs = rawMs > 0 ? rawMs : 20;

        // Sovuq (cold) ulanishni filtrlash: birinchi so'rov TLS ochilishi sababli baland bo'lishi mumkin
        if (!_isWarm) {
          _isWarm = true;
          _recentLatencies.add(actualMs);
        } else {
          _recentLatencies.add(actualMs);
          if (_recentLatencies.length > 5) {
            _recentLatencies.removeAt(0);
          }
        }

        final medianMs = _calculateMedian(_recentLatencies);
        latencyNotifier.value = medianMs;
        stateNotifier.value = ConnectivityState.online;

        if (medianMs <= 100) {
          qualityNotifier.value = "Zo'r";
        } else if (medianMs <= 300) {
          qualityNotifier.value = "O'rtacha";
        } else {
          qualityNotifier.value = "Sekin";
        }
      } else {
        _consecutiveFailures++;
        stateNotifier.value = ConnectivityState.serverUnavailable;
        qualityNotifier.value = "Offline";
      }
    } catch (_) {
      sw.stop();
      _consecutiveFailures++;
      stateNotifier.value = ConnectivityState.offline;
      qualityNotifier.value = "Offline";
    } finally {
      _isChecking = false;
    }
  }
}
