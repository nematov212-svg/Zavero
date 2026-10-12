import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Tarmoq tezligi (ms ping) ko'rsatkichi — ilovaga halaqit bermaydi.
/// Chap yoki yuqori burchakda 500ms kabi kichik badge bo'lib turadi.
class ConnectivityBadge extends StatefulWidget {
  final String cafeId;

  const ConnectivityBadge({super.key, required this.cafeId});

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
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result = await _measureConnectivity();
    if (!mounted) return;
    setState(() {
      _online = result.online;
      _latencyMs = result.latencyMs;
    });
  }

  Future<_ConnectivityResult> _measureConnectivity() async {
    final sw = Stopwatch()..start();
    try {
      final health = await ApiClient().health().timeout(const Duration(seconds: 4));
      sw.stop();
      if (health != null && health['status'] == 'ok') {
        return _ConnectivityResult(online: true, latencyMs: sw.elapsedMilliseconds);
      }
      return const _ConnectivityResult(online: false);
    } catch (_) {
      sw.stop();
      return const _ConnectivityResult(online: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ms = _latencyMs ?? 0;
    final isSlow = ms > 350 || !_online;
    final color = !_online
        ? Colors.red.shade700
        : (isSlow ? Colors.red.shade700 : Colors.green.shade800);

    final badgeBg = color.withValues(alpha: 0.14);
    final text = !_online ? 'Offline' : '${ms}ms';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
    );
  }
}

class _ConnectivityResult {
  final bool online;
  final int? latencyMs;

  const _ConnectivityResult({required this.online, this.latencyMs});
}
