import 'dart:async';
import 'dart:io' show HttpClient, HttpHeaders;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

enum ConnectivityState {
  online,
  offline,
  serverUnavailable,
  checking,
}

/// Tarmoq va Server aloqasini ishonchli kuzatuvchi servis.
/// Yangi qat'iy standart ko'rsatkich qoidalari:
/// - 0 - 150 ms: Yashil nuqta + ms (● 87 ms) (Juda yaxshi)
/// - 151 - 400 ms: Sariq nuqta + ms (O'rtacha)
/// - 400+ ms: Qizil nuqta + ms (Sekin)
/// - Aloqa yo'q: Qizil nuqta + "Offline"
/// Barcha so'zlar ("Zo'r", "Biroz sekin", "Aloqa yo'q", "O'rtacha") butunlay olib tashlangan.
class ConnectivityService with WidgetsBindingObserver {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final ValueNotifier<ConnectivityState> stateNotifier =
      ValueNotifier<ConnectivityState>(ConnectivityState.online);
  final ValueNotifier<int> latencyNotifier = ValueNotifier<int>(20);
  final ValueNotifier<String> qualityNotifier = ValueNotifier<String>("20 ms");

  Timer? _timer;
  bool _isChecking = false;
  int _consecutiveFailures = 0;
  final List<int> _recentLatencies = [];
  bool _isObserverRegistered = false;

  HttpClient? _nativeHttpClient;

  ConnectivityState get currentState => stateNotifier.value;
  bool get isOnline => stateNotifier.value == ConnectivityState.online;
  int get latencyMs => latencyNotifier.value;
  String get qualityText => isOnline ? '$latencyMs ms' : 'Offline';
  int get consecutiveFailures => _consecutiveFailures;

  static Color colorFor(int ms, bool online) {
    if (!online) return const Color(0xFFEF4444); // Qizil (Offline)
    if (ms <= 150) return const Color(0xFF10B981); // 0-150 ms Yashil (Juda yaxshi)
    if (ms <= 400) return const Color(0xFFF59E0B); // 151-400 ms Sariq (O'rtacha)
    return const Color(0xFFEF4444); // 400+ ms Qizil (Sekin)
  }

  Color get color => colorFor(latencyNotifier.value, isOnline);

  void init() {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }
    _loadCachedLatency();

    if (!kIsWeb) {
      _nativeHttpClient ??= HttpClient()
        ..idleTimeout = const Duration(seconds: 25)
        ..connectionTimeout = const Duration(seconds: 3);
    }
    unawaited(_check());

    // Har 5 soniyada yangilab turish
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 5), (_) => _check());
        unawaited(_check());
      }
    }
  }

  void dispose() {
    if (_isObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isObserverRegistered = false;
    }
    _timer?.cancel();
    _timer = null;
    _nativeHttpClient?.close(force: true);
    _nativeHttpClient = null;
  }

  Future<void> checkNow() async {
    await _check();
  }

  Future<void> _loadCachedLatency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedMs = prefs.getInt('last_known_ping_ms');
      if (cachedMs != null && cachedMs >= 0) {
        latencyNotifier.value = cachedMs;
        qualityNotifier.value = '$cachedMs ms';
        stateNotifier.value = ConnectivityState.online;
      }
    } catch (_) {}
  }

  /// Yengil ping so'rovi (backend /api/health)
  Future<int?> _singlePing(Uri targetUri) async {
    final sw = Stopwatch()..start();
    try {
      if (!kIsWeb && _nativeHttpClient != null) {
        final req = await _nativeHttpClient!.getUrl(targetUri).timeout(const Duration(seconds: 3));
        req.headers.set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, must-revalidate');
        req.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
        final res = await req.close().timeout(const Duration(seconds: 3));
        await res.drain<void>();
        sw.stop();
        if (res.statusCode >= 200 && res.statusCode < 400) {
          return sw.elapsedMilliseconds;
        }
      } else {
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
      final targetUri = Uri.parse('${ApiClient().baseUrl}/health');
      final ms = await _singlePing(targetUri);

      if (ms != null && ms >= 0) {
        _consecutiveFailures = 0;
        _recentLatencies.add(ms);
        if (_recentLatencies.length > 3) {
          _recentLatencies.removeAt(0);
        }

        // Oxirgi 3 ta o'lchovning o'rtachasi
        final avgMs = (_recentLatencies.reduce((a, b) => a + b) / _recentLatencies.length).round();
        latencyNotifier.value = avgMs;
        stateNotifier.value = ConnectivityState.online;
        qualityNotifier.value = '$avgMs ms';

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_known_ping_ms', avgMs);
        } catch (_) {}
      } else {
        _consecutiveFailures++;
        if (_consecutiveFailures >= 2) {
          stateNotifier.value = ConnectivityState.offline;
          qualityNotifier.value = 'Offline';
        }
      }
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= 2) {
        stateNotifier.value = ConnectivityState.offline;
        qualityNotifier.value = 'Offline';
      }
    } finally {
      _isChecking = false;
    }
  }
}
