import 'dart:async';
import 'dart:io' show HttpClient, HttpHeaders;
import 'package:flutter/foundation.dart';
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
/// isitish (warm-up) so'rovini hisobdan chiqarib, median o'lchovni aniqlaydi.
/// Real vaqtda soxtalashtirmasdan haqiqiy tarmoq kechikishini (~20-40 ms) ko'rsatadi.
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

  HttpClient? _nativeHttpClient;

  ConnectivityState get currentState => stateNotifier.value;
  bool get isOnline => stateNotifier.value == ConnectivityState.online;
  int get latencyMs => latencyNotifier.value;
  String get qualityText => qualityNotifier.value;
  int get consecutiveFailures => _consecutiveFailures;

  Color get color {
    if (!isOnline) return const Color(0xFFEF4444); // Offline qizil
    final ms = latencyNotifier.value;
    if (ms <= 60) return const Color(0xFF10B981); // 0-60ms yashil (Zo'r)
    if (ms <= 150) return const Color(0xFF22C55E); // 60-150ms och yashil (Yaxshi)
    if (ms <= 300) return const Color(0xFFF59E0B); // 150-300ms sariq (O'rtacha)
    return const Color(0xFFEF4444); // 300ms+ qizil (Sekin)
  }

  void init() {
    if (_timer != null) return;
    if (!kIsWeb) {
      _nativeHttpClient ??= HttpClient()
        ..idleTimeout = const Duration(seconds: 25)
        ..connectionTimeout = const Duration(seconds: 3);
    }
    unawaited(checkNow());
    // Har 8 soniyada muntazam yangilanadi
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _nativeHttpClient?.close(force: true);
    _nativeHttpClient = null;
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

  /// Yengil ping so'rovi (HEAD yoki bo'sh GET)
  Future<int?> _singlePing(Uri targetUri) async {
    final sw = Stopwatch()..start();
    try {
      if (!kIsWeb && _nativeHttpClient != null) {
        final req = await _nativeHttpClient!.openUrl('HEAD', targetUri).timeout(const Duration(seconds: 3));
        req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
        req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
        final res = await req.close().timeout(const Duration(seconds: 3));
        await res.drain<void>();
        sw.stop();
        if (res.statusCode >= 200 && res.statusCode < 400) {
          return sw.elapsedMilliseconds;
        }
      } else {
        // Web platforma uchun ApiClient orqali yengil ping
        final ok = await ApiClient().pingFast().timeout(const Duration(seconds: 3));
        sw.stop();
        if (ok) {
          return sw.elapsedMilliseconds;
        }
      }
      return null;
    } catch (_) {
      sw.stop();
      return null;
    }
  }

  Future<void> _check() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      // Eng tezkor mintaqaviy CDN / edge tekshiruv nuqtasi (Android & Web standart)
      final primaryUri = Uri.parse(
        kIsWeb
            ? 'https://www.gstatic.com/generate_204'
            : 'http://connectivitycheck.gstatic.com/generate_204',
      );
      final backendUri = Uri.parse('${ApiClient().socketUrl}/ping');

      // 1. Isitish (Warm-up) so'rovi: DNS va TLS ulanish ochilishini statistika ichiga qo'shmaslik
      if (!_isWarm) {
        await _singlePing(primaryUri);
        _isWarm = true;
      }

      // 2. Keep-alive ulanish orqali 3-5 ta namuna olish
      final samples = <int>[];
      for (var i = 0; i < 3; i++) {
        final ms = await _singlePing(primaryUri);
        if (ms != null && ms > 0) {
          samples.add(ms);
        }
        if (i < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      }

      // Agar CDN javob bermasa, bevosita backendga fallback qilamiz
      if (samples.isEmpty) {
        for (var i = 0; i < 2; i++) {
          final ms = await _singlePing(backendUri);
          if (ms != null && ms > 0) {
            samples.add(ms);
          }
        }
      }

      if (samples.isNotEmpty) {
        _consecutiveFailures = 0;
        samples.sort();
        final currentSampleMedian = _calculateMedian(samples);

        _recentLatencies.add(currentSampleMedian);
        if (_recentLatencies.length > 5) {
          _recentLatencies.removeAt(0);
        }

        final finalMedian = _calculateMedian(_recentLatencies);
        latencyNotifier.value = finalMedian;
        stateNotifier.value = ConnectivityState.online;

        if (finalMedian <= 60) {
          qualityNotifier.value = "Zo'r";
        } else if (finalMedian <= 150) {
          qualityNotifier.value = "Yaxshi";
        } else if (finalMedian <= 300) {
          qualityNotifier.value = "O'rtacha";
        } else {
          qualityNotifier.value = "Sekin";
        }
      } else {
        _consecutiveFailures++;
        _isWarm = false; // Ulanish uzilganda warm-up qayta tiklansin
        if (_consecutiveFailures >= 2) {
          stateNotifier.value = ConnectivityState.offline;
          qualityNotifier.value = "Offline";
        } else {
          stateNotifier.value = ConnectivityState.serverUnavailable;
          qualityNotifier.value = "Ulanmoqda";
        }
      }
    } catch (_) {
      _consecutiveFailures++;
      _isWarm = false;
      stateNotifier.value = ConnectivityState.offline;
      qualityNotifier.value = "Offline";
    } finally {
      _isChecking = false;
    }
  }
}
