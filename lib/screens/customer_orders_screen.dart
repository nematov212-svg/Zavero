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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '$h:$m (hozirgina)';
    if (diff.inMinutes < 60) return '$h:$m (${diff.inMinutes} daq oldin)';
    if (diff.inHours < 24) return '$h:$m (${diff.inHours} soat oldin)';
    return '$h:$m (${dt.day}.${dt.month.toString().padLeft(2, '0')})';
  }

  Color _getStatusColor(OrderStatus st) {
    switch (st) {
      case OrderStatus.pending:
        return const Color(0xFFFF9800); // Amber/Orange
      case OrderStatus.preparing:
        return const Color(0xFF3B82F6); // Blue
      case OrderStatus.ready:
        return const Color(0xFF10B981); // Emerald Green
      case OrderStatus.delivered:
        return const Color(0xFF059669); // Darker Green
      case OrderStatus.completed:
        return const Color(0xFF64748B); // Slate
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData _getStatusIcon(OrderStatus st) {
    switch (st) {
      case OrderStatus.pending:
        return Icons.notifications_active_rounded;
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('№${order.id} ${tr('btn_delete_order')}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          tr('delete_order_confirm'),
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('btn_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Text(tr('clear_old_orders'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Barcha yakunlangan va bekor qilingan eski buyurtmalarni tozalashni tasdiqlaysizmi?',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('btn_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
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
        final completedOrders = allOrders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled || o.status == OrderStatus.delivered).toList();

        return Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFFB300), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  tr('menu_customer_orders'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
              ],
            ),
            actions: [
              if (completedOrders.isNotEmpty)
                IconButton(
                  tooltip: tr('clear_old_orders'),
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.orangeAccent),
                  onPressed: _confirmClearCompletedOrders,
                ),
              if (pendingOrders.isNotEmpty)
                IconButton(
                  tooltip: 'Ovozlarni o‘chirish',
                  icon: const Icon(Icons.volume_off_rounded, color: Color(0xFFFFB300)),
                  onPressed: () {
                    SoundService().stopAllVoices();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ovozli xabarlar to‘xtatildi')),
                    );
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
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
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tabAlignment: TabAlignment.start,
                  indicatorColor: const Color(0xFFFFB300),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFFFB300),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  tabs: [
                    Tab(
                      child: Row(
                        children: [
                          Text(tr('status_pending')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: pendingOrders.isNotEmpty ? const Color(0xFFFF3D00) : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${pendingOrders.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Text(tr('status_preparing')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${prepOrders.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Text(tr('status_ready')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${readyOrders.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        children: [
                          Text(tr('status_completed')),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${completedOrders.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155), width: 1.5),
                ),
                child: const Center(
                  child: Icon(Icons.coffee_rounded, color: Color(0xFFFFB300), size: 36),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('no_orders_yet'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                tr('qr_orders_auto_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 260,
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

  Widget _buildOrderCard(CustomerOrder o) {
    final statusColor = _getStatusColor(o.status);
    final statusIcon = _getStatusIcon(o.status);
    final statusLabel = _getStatusLabel(o.status);
    final isPending = o.status == OrderStatus.pending;
    final isPreparing = o.status == OrderStatus.preparing;
    final isReady = o.status == OrderStatus.ready;

    final tableLabel = o.type == OrderType.delivery
        ? 'Dastavka: ${o.deliveryAddress ?? "Manzil yo'q"}'
        : (o.tableNumber != null && o.tableNumber! > 0 ? '${o.tableNumber}-${tr('table_text')}' : (o.deliveryAddress ?? tr('table_text')));

    final customerName = o.customerName.trim().isNotEmpty && o.customerName.trim().toLowerCase() != 'mehmon'
        ? o.customerName.trim()
        : 'Mijoz';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? const Color(0xFFFFB300) : const Color(0xFF334155),
          width: isPending ? 1.8 : 1.0,
        ),
        boxShadow: [
          if (isPending)
            BoxShadow(
              color: const Color(0xFFFFB300).withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER: Stol & Raqam & Status & Delete Trash
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                // Table badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.table_restaurant_rounded, size: 14, color: Colors.black),
                      const SizedBox(width: 5),
                      Text(
                        tableLabel,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '№ ${o.id}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                const Spacer(),
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF64748B), size: 18),
                  tooltip: tr('btn_delete_order'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _confirmDeleteOrder(o),
                ),
              ],
            ),
          ),

          // 2. MID: Customer Name & Time & Phone
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: Color(0xFF94A3B8), size: 15),
                    const SizedBox(width: 6),
                    Text(
                      '$customerName${o.phone.trim().isNotEmpty ? " • ${o.phone}" : ""}',
                      style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Text(
                  _formatTime(o.date),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF334155), height: 1),

          // 3. ORDER ITEMS LIST
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemCount: o.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final item = o.items[i];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.qty}x',
                              style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.product.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        '${item.total.toStringAsFixed(0)} ${tr('currency')}',
                        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          if (o.notes != null && o.notes!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: Color(0xFFFFB300), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Izoh: ${o.notes!}',
                        style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(color: Color(0xFF334155), height: 1),

          // 4. BOTTOM BAR: Total Sum & Actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('total_sum'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Text(
                      '${o.total.toStringAsFixed(0)} ${tr('currency')}',
                      style: const TextStyle(
                        color: Color(0xFFFFB300),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending) ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.cancelled);
                        },
                        child: Text(tr('btn_cancel'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981), // Emerald
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.preparing);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(tr('btn_accept'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (isPreparing) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6), // Blue
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.ready);
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: Text(tr('btn_mark_ready'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ] else if (isReady) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          appState.updateOrderStatus(o, OrderStatus.delivered);
                        },
                        icon: const Icon(Icons.task_alt_rounded, size: 16),
                        label: Text(tr('btn_mark_served'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      IconButton(
                        icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFFFFB300), size: 20),
                        tooltip: 'Kassaga yuklash',
                        onPressed: () {
                          appState.loadOrderIntoCart(o);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const HallSelectionScreen()));
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
