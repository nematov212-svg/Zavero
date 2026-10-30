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
  bool _online = true;
  int? _latencyMs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Tarmoqni tekshirish oraliq vaqti optimallashtirildi: 12 soniya (batareya va resursni tejash)
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final sw = Stopwatch()..start();
    try {
      final health = await ApiClient().health().timeout(const Duration(seconds: 4));
      sw.stop();
      if (!mounted) return;
      if (health != null && health['status'] == 'ok') {
        setState(() {
          _online = true;
          _latencyMs = sw.elapsedMilliseconds;
        });
        OfflineSyncService().statusNotifier.value = SyncStatus.online;
      } else {
        setState(() {
          _online = false;
        });
        OfflineSyncService().statusNotifier.value = SyncStatus.offline;
      }
    } catch (_) {
      sw.stop();
      if (!mounted) return;
      setState(() {
        _online = false;
      });
      OfflineSyncService().statusNotifier.value = SyncStatus.offline;
    }
  }

  Color _getPingColor(int ms, bool isOnline) {
    if (!isOnline) return const Color(0xFFEF4444);
    if (ms <= 22) return const Color(0xFF10B981); // ~20ms: juda yaxshi
    if (ms <= 28) return const Color(0xFF22C55E); // ~25ms: yaxshi
    if (ms <= 38) return const Color(0xFFF59E0B); // 30-35ms: o'rtacha
    return const Color(0xFFEF4444); // >35ms: sekinlashgan
  }

  @override
  Widget build(BuildContext context) {
    final ms = _latencyMs ?? 0;
    final color = _getPingColor(ms, _online);
    final text = !_online ? 'Offline' : (ms > 0 ? '${ms}ms' : 'Online');
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
