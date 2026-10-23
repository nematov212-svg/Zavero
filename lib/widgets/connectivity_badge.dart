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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: OfflineSyncService().statusNotifier,
      builder: (context, syncStatus, _) {
        return ValueListenableBuilder<int>(
          valueListenable: OfflineSyncService().pendingCountNotifier,
          builder: (context, pendingCount, _) {
            final ms = _latencyMs ?? 0;
            Color color;
            String text;
            IconData? icon;

            switch (syncStatus) {
              case SyncStatus.syncing:
                color = Colors.amber.shade800;
                text = pendingCount > 0 ? 'Sinxron... ($pendingCount)' : 'Sinxron...';
                icon = Icons.sync_rounded;
                break;
              case SyncStatus.offline:
                color = Colors.red.shade700;
                text = pendingCount > 0 ? 'Offline ($pendingCount)' : 'Offline';
                icon = Icons.cloud_off_rounded;
                break;
              case SyncStatus.synced:
                color = Colors.green.shade700;
                text = 'Sinxronlandi';
                icon = Icons.check_circle_rounded;
                break;
              case SyncStatus.online:
                final isSlow = ms > 350 || !_online;
                color = !_online
                    ? Colors.red.shade700
                    : (isSlow ? Colors.amber.shade800 : Colors.green.shade800);
                text = !_online ? 'Offline' : (ms > 0 ? '${ms}ms' : 'Online');
                icon = null;
                break;
            }

            final badgeBg = color.withValues(alpha: 0.14);

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                if (pendingCount > 0 || syncStatus == SyncStatus.offline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Qayta sinxronlanmoqda ($pendingCount ta amal)...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  await OfflineSyncService().syncAllPending(force: true);
                } else {
                  await _refresh();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null)
                      Icon(icon, size: 12, color: color)
                    else
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
