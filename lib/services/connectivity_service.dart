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
/// Ping chegaralari (qatiy talab):
/// 0–4 ms: Yashil, matn: "Zo'r"
/// 5–9 ms: Sariq, matn: "Biroz sekin"
/// 10+ ms yoki xatolik/aloqa yo'q: Qizil, matn: "Aloqa yo'q"
/// (DIQQAT: "Sekin" degan so'z umuman ishlatilmaydi!)
class ConnectivityService with WidgetsBindingObserver {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final ValueNotifier<ConnectivityState> stateNotifier =
      ValueNotifier<ConnectivityState>(ConnectivityState.online);
  final ValueNotifier<int> latencyNotifier = ValueNotifier<int>(3);
  final ValueNotifier<String> qualityNotifier = ValueNotifier<String>("Zo'r");

  Timer? _timer;
  bool _isChecking = false;
  int _consecutiveFailures = 0;
  final List<int> _recentLatencies = [];
  bool _isWarm = false;
  bool _isObserverRegistered = false;

  HttpClient? _nativeHttpClient;

  ConnectivityState get currentState => stateNotifier.value;
  bool get isOnline => stateNotifier.value == ConnectivityState.online;
  int get latencyMs => latencyNotifier.value;
  String get qualityText => qualityNotifier.value;
  int get consecutiveFailures => _consecutiveFailures;

  static String qualityFor(int ms, bool online) {
    if (!online) return "Aloqa yo'q";
    if (ms <= 4) return "Zo'r";
    if (ms <= 9) return "Biroz sekin";
    return "Aloqa yo'q";
  }

  static Color colorFor(int ms, bool online) {
    if (!online) return const Color(0xFFEF4444); // Qizil
    if (ms <= 4) return const Color(0xFF10B981); // 0-4 ms Yashil (Zo'r)
    if (ms <= 9) return const Color(0xFFF59E0B); // 5-9 ms Sariq (Biroz sekin)
    return const Color(0xFFEF4444); // 10+ ms Qizil (Aloqa yo'q)
  }

  Color get color => colorFor(latencyNotifier.value, isOnline);

  void init() {
    if (!_isObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isObserverRegistered = true;
    }
    // 1. Keshdan/xotiradan oxirgi ma'lumotni darhol ko'rsatish ("Ulanmoqda..." deb qotib qolmasligi uchun)
    _loadCachedLatency();

    if (!kIsWeb) {
      _nativeHttpClient ??= HttpClient()
        ..idleTimeout = const Duration(seconds: 25)
        ..connectionTimeout = const Duration(seconds: 3);
    }
    // 2. Orqa fonda tezda o'lchash (1-2 soniyada birinchi natija)
    unawaited(_check());

    // 3. Har 6 soniyada yangilab turish (5-10 soniya talabiga mos)
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Ilova fonda bo'lsa to'xtasin
      _timer?.cancel();
      _timer = null;
    } else if (state == AppLifecycleState.resumed) {
      // Ilova ochilganda qayta ishga tushsin
      if (_timer == null) {
        _timer = Timer.periodic(const Duration(seconds: 6), (_) => _check());
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
        final online = cachedMs < 10;
        qualityNotifier.value = qualityFor(cachedMs, online);
        stateNotifier.value = online ? ConnectivityState.online : ConnectivityState.serverUnavailable;
      }
    } catch (_) {}
  }

  int _calculateMedian(List<int> list) {
    if (list.isEmpty) return 3;
    final sorted = List<int>.from(list)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// Yengil ping so'rovi (3 soniya qat'iy timeout bilan)
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
      final primaryUri = Uri.parse(
        kIsWeb
            ? 'https://www.gstatic.com/generate_204'
            : 'http://connectivitycheck.gstatic.com/generate_204',
      );
      final backendUri = Uri.parse('${ApiClient().socketUrl}/ping');

      // 1. Isitish (Warm-up) so'rovi
      if (!_isWarm) {
        await _singlePing(primaryUri);
        _isWarm = true;
      }

      // 2. Keep-alive ulanish orqali tezkor namunalar olish
      final samples = <int>[];
      for (var i = 0; i < 3; i++) {
        final ms = await _singlePing(primaryUri);
        if (ms != null && ms >= 0) {
          samples.add(ms);
        }
        if (i < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }

      // Agar CDN javob bermasa, bevosita backendga fallback
      if (samples.isEmpty) {
        for (var i = 0; i < 2; i++) {
          final ms = await _singlePing(backendUri);
          if (ms != null && ms >= 0) {
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

        final isGood = finalMedian < 10;
        stateNotifier.value = isGood ? ConnectivityState.online : ConnectivityState.serverUnavailable;
        qualityNotifier.value = qualityFor(finalMedian, isGood);

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_known_ping_ms', finalMedian);
        } catch (_) {}
      } else {
        _consecutiveFailures++;
        _isWarm = false;
        stateNotifier.value = ConnectivityState.offline;
        qualityNotifier.value = "Aloqa yo'q";
      }
    } catch (_) {
      _consecutiveFailures++;
      _isWarm = false;
      stateNotifier.value = ConnectivityState.offline;
      qualityNotifier.value = "Aloqa yo'q";
    } finally {
      _isChecking = false;
    }
  }
}
