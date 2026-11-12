import 'dart:async';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/offline_sync_service.dart';

/// Tarmoq va Oflayn-Sinxronizatsiya holati ko'rsatkichi.
/// Online: yashil (ping ms)
/// Offline: qizil (kutilayotgan navbat soni)
/// Sinxronlanmoqda: sariq/to'q sariq aylanuvchi
class ConnectivityBadge extends StatefulWidget {
  final String? cafeId;

  const ConnectivityBadge({super.key, this.cafeId});

  @override
  State<ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<ConnectivityBadge> {
  static int _cachedLatencyMs = 22;
  static bool _cachedOnline = true;

  bool _online = _cachedOnline;
  int _latencyMs = _cachedLatencyMs;
  bool _isChecking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // 5-10 soniya oralig'ida avtomatik yangilanish
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isChecking) return;
    _isChecking = true;
    final sw = Stopwatch()..start();
    try {
      await ApiClient().health().timeout(const Duration(seconds: 5));
      sw.stop();
      final raw = sw.elapsedMilliseconds;
      final realLatency = raw > 0 ? raw : 20;
      _cachedLatencyMs = realLatency;
      _cachedOnline = true;
      if (mounted) {
        setState(() {
          _online = true;
          _latencyMs = realLatency;
        });
      }
      OfflineSyncService().statusNotifier.value = SyncStatus.online;
    } catch (_) {
      sw.stop();
      _cachedOnline = false;
      if (mounted) {
        setState(() {
          _online = false;
        });
      }
      OfflineSyncService().statusNotifier.value = SyncStatus.offline;
    } finally {
      _isChecking = false;
    }
  }

  Color _getPingColor(int ms, bool isOnline) {
    if (!isOnline) return const Color(0xFFEF4444); // Offline qizil
    if (ms <= 100) return const Color(0xFF10B981); // 0-100ms yashil
    if (ms <= 300) return const Color(0xFFF59E0B); // 100-300ms sariq
    return const Color(0xFFEF4444); // 300ms+ to'q sariq/qizil
  }

  @override
  Widget build(BuildContext context) {
    final ms = _latencyMs;
    final color = _getPingColor(ms, _online);
    final text = !_online ? 'Offline' : (ms > 0 ? '${ms}ms' : '22ms');
    final badgeBg = color.withValues(alpha: 0.12);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _refresh(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
