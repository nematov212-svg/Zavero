import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';

class WorkerDashboard extends StatefulWidget {
  final AppUser user;
  const WorkerDashboard({super.key, required this.user});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  final _authService = AuthService();
  final _cloudService = CloudService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Oshxona / Ishchi - ${widget.user.name}'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: StreamBuilder<List<CustomerOrder>>(
        stream: _cloudService.streamCustomerOrders(widget.user.ownerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('Hozircha buyurtmalar yo\'q'));
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final o = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('Buyurtma #${o.id} - ${o.customerName}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Holat: ${orderStatusToString(o.status)}'),
                      ...o.items.map((i) => Text('${i.qty}x ${i.product.name}')),
                    ],
                  ),
                  trailing: o.status == OrderStatus.pending
                      ? ElevatedButton(
                          onPressed: () => _cloudService.updateCustomerOrderStatus(
                            widget.user.ownerId,
                            o.id,
                            OrderStatus.preparing,
                          ),
                          child: const Text('Tayyorlash'),
                        )
                      : o.status == OrderStatus.preparing
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _cloudService.updateCustomerOrderStatus(
                                widget.user.ownerId,
                                o.id,
                                OrderStatus.ready,
                              ),
                              child: const Text('Tayyor', style: TextStyle(color: Colors.white)),
                            )
                          : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
