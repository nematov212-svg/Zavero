import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../widgets/optimized_image.dart';

class CustomerDashboard extends StatefulWidget {
  final AppUser user;
  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final _authService = AuthService();
  final _cloudService = CloudService();
  final List<CartItem> _cart = [];

  void _addToCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((item) => item.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].qty++;
      } else {
        _cart.add(CartItem(product: p, qty: 1));
      }
    });
  }

  double get _totalPrice => _cart.fold(0, (sum, i) => sum + i.total);

  void _submitOrder() async {
    if (_cart.isEmpty) return;

    final order = CustomerOrder(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      date: DateTime.now(),
      items: List.from(_cart),
      customerName: widget.user.name,
      phone: widget.user.phone,
      type: OrderType.dineIn,
      status: OrderStatus.pending,
    );

    await _cloudService.saveCustomerOrder(widget.user.ownerId, order);
    if (mounted) {
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyurtmangiz qabul qilindi!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mijoz Menyu - ${widget.user.name}'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _cloudService.streamProducts(widget.user.ownerId),
              builder: (context, snapshot) {
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(child: Text('Taomlar mavjud emas'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, idx) {
                    final p = products[idx];
                    final resolvedUrl = ApiClient().resolveImageUrl(p.imageUrl);
                    return Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _addToCart(p),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (resolvedUrl.isNotEmpty)
                                OptimizedImage(
                                  imageUrl: resolvedUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  fallbackIcon: p.icon,
                                  iconSize: 28,
                                  iconColor: Colors.orange.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                )
                              else
                                Icon(p.icon, size: 28, color: Colors.orange.shade800),
                              const SizedBox(height: 4),
                              Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${p.price.toStringAsFixed(0)} so\'m',
                                style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                onPressed: () => _addToCart(p),
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text('Qo\'shish'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jami: ${_totalPrice.toStringAsFixed(0)} so\'m',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Buyurtma berish'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
