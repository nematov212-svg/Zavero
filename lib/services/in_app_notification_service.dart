import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'sound_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  OverlayEntry? _currentEntry;
  Timer? _dismissTimer;

  void showNewOrderNotification({
    required CustomerOrder order,
    required VoidCallback onViewOrder,
    VoidCallback? onAcceptOrder,
  }) {
    // 1. Start voice announcement loop with periodic repeat until accepted
    try {
      SoundService().announceNewOrder(order: order, repeatIntervalSec: 6);
    } catch (_) {}

    final overlayState = appNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final tableText = order.tableNumber != null && order.tableNumber! > 0
        ? '${order.tableNumber}-stol'
        : (order.deliveryAddress ?? 'Mijoz');
    final customerName = order.customerName.trim().isNotEmpty &&
            order.customerName.trim().toLowerCase() != 'mehmon'
        ? order.customerName.trim()
        : null;

    final titleRef = customerName != null ? '$tableText • $customerName' : tableText;
    final itemsSummary = order.items.map((e) => '${e.qty}x ${e.product.name}').take(3).join(', ');
    final remainingCount = order.items.length > 3 ? ' va yana ${order.items.length - 3} ta' : '';

    final entry = OverlayEntry(
      builder: (context) => _AnimatedNotificationBanner(
        title: '🔔 YANGI QR BUYURTMA (№${order.id})',
        subtitle: '$titleRef:\n$itemsSummary$remainingCount',
        totalSum: '${order.total.toStringAsFixed(0)} so‘m',
        onAccept: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          SoundService().stopOrderVoice(order.id);
          if (onAcceptOrder != null) {
            onAcceptOrder();
          }
        },
        onView: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          onViewOrder();
        },
        onDismiss: () {
          _dismissTimer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
          SoundService().stopOrderVoice(order.id);
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);

    // Auto-dismiss banner visually after 25s if untouched (voice loop will still honor order status)
    _dismissTimer = Timer(const Duration(seconds: 25), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _AnimatedNotificationBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final String totalSum;
  final VoidCallback onAccept;
  final VoidCallback onView;
  final VoidCallback onDismiss;

  const _AnimatedNotificationBanner({
    required this.title,
    required this.subtitle,
    required this.totalSum,
    required this.onAccept,
    required this.onView,
    required this.onDismiss,
  });

  @override
  State<_AnimatedNotificationBanner> createState() => _AnimatedNotificationBannerState();
}

class _AnimatedNotificationBannerState extends State<_AnimatedNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close(VoidCallback callback) async {
    await _ctrl.reverse();
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB300), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Pulsing Bell Icon Badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.black87, size: 28),
                  ),
                  const SizedBox(width: 14),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.totalSum,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action Buttons: Qabul qilish (Accept) + Ko'rish (View)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // Emerald Green
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => _close(widget.onAccept),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text(
                      'Zakasni olish',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB300),
                      side: const BorderSide(color: Color(0xFFFFB300), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () => _close(widget.onView),
                    child: const Text('Ko‘rish', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                    onPressed: () => _close(widget.onDismiss),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Yopish',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
