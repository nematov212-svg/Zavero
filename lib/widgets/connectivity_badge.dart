import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

/// Tarmoq va Oflayn-Sinxronizatsiya holati ko'rsatkichi.
class ConnectivityBadge extends StatefulWidget {
  final String? cafeId;

  const ConnectivityBadge({super.key, this.cafeId});

  @override
  State<ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<ConnectivityBadge> {
  final _service = ConnectivityService();

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _service.stateNotifier,
        _service.latencyNotifier,
        _service.qualityNotifier,
      ]),
      builder: (context, _) {
        final isOnline = _service.isOnline;
        final ms = _service.latencyMs;
        final quality = _service.qualityText;
        final color = _service.color;
        final text = !isOnline ? 'Offline' : '${ms}ms ($quality)';
        final badgeBg = color.withValues(alpha: 0.12);

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _service.checkNow(),
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
      },
    );
  }
}
