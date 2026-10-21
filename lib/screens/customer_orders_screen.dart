import 'package:flutter/material.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/sound_service.dart';
import '../services/localization_service.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Design color palette matching Image 4
  static const Color _bgScreen = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _orangePrimary = Color(0xFFFF7A00);
  static const Color _orangeLight = Color(0xFFFFF4EC);
  static const Color _textDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$h:$m ($d.$mo)';
  }

  Color _getStatusColor(OrderStatus st) {
    switch (st) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800);
      case OrderStatus.preparing:
        return const Color(0xFF2563EB);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.delivered:
        return const Color(0xFF059669);
      case OrderStatus.completed:
        return const Color(0xFF64748B);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  IconData _getStatusIcon(OrderStatus st) {
    switch (st) {
      case OrderStatus.pending:
        return Icons.hourglass_top_rounded;
      case OrderStatus.preparing:
        return Icons.soup_kitchen_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivered:
      case OrderStatus.completed:
        return Icons.task_alt_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusLabel(OrderStatus st) {
    switch (st) {
      case OrderStatus.pending:
        return tr('status_pending');
      case OrderStatus.preparing:
        return tr('status_preparing');
      case OrderStatus.ready:
        return tr('status_ready');
      case OrderStatus.delivered:
        return tr('status_delivered');
      case OrderStatus.completed:
        return tr('status_completed');
      case OrderStatus.cancelled:
        return tr('status_cancelled');
    }
  }

  void _confirmDeleteOrder(CustomerOrder order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Text(
              '№${order.id} ${tr('btn_delete_order')}',
              style: const TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          tr('delete_order_confirm'),
          style: const TextStyle(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('btn_cancel'), style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deleteCustomerOrder(order);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('№${order.id} buyurtma o‘chirildi')),
                );
              }
            },
            child: Text(tr('btn_delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmClearCompletedOrders() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: _orangePrimary, size: 24),
            const SizedBox(width: 8),
            Text(
              tr('clear_old_orders'),
              style: const TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Barcha yakunlangan va bekor qilingan eski buyurtmalarni tozalashni tasdiqlaysizmi?',
          style: TextStyle(color: _textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('btn_cancel'), style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orangePrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.clearCompletedCustomerOrders();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Eski buyurtmalar tozalandi')),
                );
              }
            },
            child: const Text('Tozalash', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, LocalizationService()]),
      builder: (context, _) {
        final allOrders = appState.customerOrders.toList()
          ..sort((a, b) => b.date.compareTo(a.date));

        final pendingOrders = allOrders.where((o) => o.status == OrderStatus.pending).toList();
        final prepOrders = allOrders.where((o) => o.status == OrderStatus.preparing).toList();
        final readyOrders = allOrders.where((o) => o.status == OrderStatus.ready).toList();
        final completedOrders = allOrders.where((o) =>
            o.status == OrderStatus.completed ||
            o.status == OrderStatus.cancelled ||
            o.status == OrderStatus.delivered).toList();

        return Scaffold(
          backgroundColor: _bgScreen,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: _textDark),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _orangePrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Mijozlardan buyurtmalar',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _textDark,
                  ),
                ),
              ],
            ),
            actions: [
              if (completedOrders.isNotEmpty)
                IconButton(
                  tooltip: tr('clear_old_orders'),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                  onPressed: _confirmClearCompletedOrders,
                ),
              if (pendingOrders.isNotEmpty)
                IconButton(
                  tooltip: 'Ovozlarni o‘chirish',
                  icon: const Icon(Icons.volume_off_rounded, color: _orangePrimary),
                  onPressed: () {
                    SoundService().stopAllVoices();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ovozli xabarlar to‘xtatildi')),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _textMuted),
                tooltip: 'Yangilash',
                onPressed: () {
                  appState.forceRefreshCustomerOrders();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Buyurtmalar yangilandi'), duration: Duration(seconds: 1)),
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            // 4 Pill Tabs Bar - Image 4
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildPillTab(
                        title: 'Yangi',
                        count: pendingOrders.length,
                        index: 0,
                        isActive: _selectedTabIndex == 0,
                      ),
                      const SizedBox(width: 10),
                      _buildPillTab(
                        title: 'Tayyorlanmoqda',
                        count: prepOrders.length,
                        index: 1,
                        isActive: _selectedTabIndex == 1,
                      ),
                      const SizedBox(width: 10),
                      _buildPillTab(
                        title: 'Tayyor',
                        count: readyOrders.length,
                        index: 2,
                        isActive: _selectedTabIndex == 2,
                      ),
                      const SizedBox(width: 10),
                      _buildPillTab(
                        title: 'Yakunlangan',
                        count: completedOrders.length,
                        index: 3,
                        isActive: _selectedTabIndex == 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(pendingOrders),
              _buildOrdersList(prepOrders),
              _buildOrdersList(readyOrders),
              _buildOrdersList(completedOrders),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HORIZONTAL PILL TAB FILTER - Image 4
  // ============================================================
  Widget _buildPillTab({
    required String title,
    required int count,
    required int index,
    required bool isActive,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        setState(() => _selectedTabIndex = index);
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? _orangePrimary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive ? _orangePrimary : _borderColor,
            width: 1.2,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: _orangePrimary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$title ($count)',
              style: TextStyle(
                color: isActive ? Colors.white : _textDark,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ORDERS LIST / GRID
  // ============================================================
  Widget _buildOrdersList(List<CustomerOrder> orders) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _orangeLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: _orangePrimary.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.receipt_long_rounded, color: _orangePrimary, size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('no_orders_yet'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textDark, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                tr('qr_orders_auto_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textMuted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

        if (isWideDesktop || isTablet) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isWideDesktop ? 550 : 450,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              mainAxisExtent: 290,
            ),
            itemCount: orders.length,
            itemBuilder: (context, idx) => _buildOrderCard(orders[idx]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          itemCount: orders.length,
          itemBuilder: (context, idx) => _buildOrderCard(orders[idx]),
        );
      },
    );
  }

  // ============================================================
  // ORDER CARD - Image 4 White Rounded Card
  // ============================================================
  Widget _buildOrderCard(CustomerOrder o) {
    final statusColor = _getStatusColor(o.status);
    final statusIcon = _getStatusIcon(o.status);
    final statusLabel = _getStatusLabel(o.status);
    final isPending = o.status == OrderStatus.pending;
    final isPreparing = o.status == OrderStatus.preparing;
    final isReady = o.status == OrderStatus.ready;

    final tableLabel = o.type == OrderType.delivery
        ? 'Dastavka'
        : (o.tableNumber != null && o.tableNumber! > 0
            ? '${o.tableNumber}-stol'
            : (o.deliveryAddress ?? 'Stol'));

    final customerName = o.customerName.trim().isNotEmpty && o.customerName.trim().toLowerCase() != 'mehmon'
        ? o.customerName.trim()
        : 'Mijoz';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER: [🪑 1-stol]  № 70  [👨‍🍳 Tayyorlanmoqda]  [Trash] - Image 4
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                // Table pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_restaurant_rounded, size: 14, color: Color(0xFF92400E)),
                      const SizedBox(width: 5),
                      Text(
                        tableLabel,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Order Number № ...
                Text(
                  '№ ${o.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),

                // Status pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Trash icon
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8), size: 20),
                  tooltip: tr('btn_delete_order'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => _confirmDeleteOrder(o),
                ),
              ],
            ),
          ),

          // 2. MID: Customer Info [👤 Mijoz (1-stol (Zal))] + Time [08:40 (16.10)]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$customerName ($tableLabel)',
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatTime(o.date),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),

          // 3. FOOD ITEM ROW WITH IMAGE - Image 4
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: o.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = o.items[i];
                  return Row(
                    children: [
                      // Food Image Thumbnail
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: const Color(0xFFF1F5F9),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: item.product.imageUrl != null && item.product.imageUrl!.isNotEmpty
                            ? Image.network(
                                item.product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Image.asset(
                                  'assets/images/shaurma_dish.png',
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/images/shaurma_dish.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 12),

                      // Black pill quantity badge [1x]
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.qty}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Item name
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Item price
                      Text(
                        '${item.total.toStringAsFixed(0)} ${tr('currency')}',
                        style: const TextStyle(
                          color: _textDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Note if present
          if (o.notes != null && o.notes!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Color(0xFFB45309), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Izoh: ${o.notes!}',
                        style: const TextStyle(color: Color(0xFF92400E), fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),

          // 4. FOOTER: Total Sum & Orange Button [✓ Tayyor deb belgilash] - Image 4
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Total Sum
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Umumiy summa:',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${o.total.toStringAsFixed(0)} ${tr('currency')}',
                      style: const TextStyle(
                        color: _orangePrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),

                // Action Button
                if (isPreparing)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orangePrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      appState.updateOrderStatus(o, OrderStatus.ready);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Tayyor deb belgilash',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (isPending)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.cancelled);
                        },
                        child: Text(tr('btn_cancel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.preparing);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text(
                          'Zakasni olish',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                else if (isReady)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      appState.updateOrderStatus(o, OrderStatus.delivered);
                    },
                    icon: const Icon(Icons.task_alt_rounded, size: 16),
                    label: Text(
                      tr('btn_mark_served'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orangePrimary,
                      side: const BorderSide(color: _orangePrimary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Kassaga yuklash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      appState.loadOrderIntoCart(o);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HallSelectionScreen()));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
