import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../widgets/connectivity_badge.dart';
import '../widgets/optimized_image.dart';

class CashierDashboard extends StatefulWidget {
  final AppUser user;
  const CashierDashboard({super.key, required this.user});

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  final _authService = AuthService();
  final _cloudService = CloudService();
  TableModel? _selectedTable;
  final List<CartItem> _cart = [];
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _cloudService.loadFullCafeData(widget.user.ownerId);
    if (mounted) {
      setState(() {
        _products = (data['products'] as List<Product>?) ?? [];
        _isLoading = false;
      });
    }
  }

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
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iltimos, stolni tanlang!')),
      );
      return;
    }
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Savat bo\'sh!')),
      );
      return;
    }

    final receipt = Receipt(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      date: DateTime.now(),
      items: List.from(_cart),
      total: _totalPrice,
      method: PaymentMethod.cash,
      cashierName: widget.user.name,
      tableNumber: _selectedTable?.number,
      cashPaid: _totalPrice,
    );

    final success = await _cloudService.completeCheckout(
      ownerId: widget.user.ownerId,
      receipt: receipt,
      tableId: _selectedTable?.id,
      items: _cart,
      allProducts: _products,
      cafeId: '',
    );

    if (success && mounted) {
      setState(() {
        _cart.clear();
        _selectedTable = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buyurtma saqlandi va chek berildi!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Kassa - ${widget.user.name}'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: ConnectivityBadge(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Stollar oqimi
                SizedBox(
                  height: 60,
                  child: StreamBuilder<List<TableModel>>(
                    stream: _cloudService.streamTables(widget.user.ownerId),
                    builder: (context, snapshot) {
                      final tables = snapshot.data ?? [];
                      if (tables.isEmpty) return const SizedBox();
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: tables.map((t) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4.0),
                            child: ChoiceChip(
                              label: Text('Stol №${t.number}'),
                              selected: _selectedTable?.id == t.id,
                              onSelected: (_) =>
                                  setState(() => _selectedTable = t),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                const Divider(),
                // Mahsulotlar to'plami
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: _cloudService.streamProducts(widget.user.ownerId),
                    builder: (context, snapshot) {
                      final products = snapshot.data ?? [];
                      if (products.isEmpty) {
                        return const Center(child: Text('Taomlar mavjud emas'));
                      }
                      return GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, idx) {
                          final p = products[idx];
                          final resolvedUrl = ApiClient().resolveImageUrl(p.imageUrl);
                          return Card(
                            child: InkWell(
                              onTap: () => _addToCart(p),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (resolvedUrl.isNotEmpty)
                                    OptimizedImage(
                                      imageUrl: resolvedUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      fallbackIcon: p.icon,
                                      iconSize: 24,
                                      iconColor: Colors.orange.shade800,
                                      borderRadius: BorderRadius.circular(8),
                                    )
                                  else
                                    Icon(p.icon, size: 24, color: Colors.orange.shade800),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${p.price.toStringAsFixed(0)} so\'m'),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Savat paneli
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'Savat (Stol №${_selectedTable?.number ?? "-"})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _cart.isEmpty
                        ? const Center(child: Text('Savat bo\'sh'))
                        : ListView.builder(
                            itemCount: _cart.length,
                            itemBuilder: (context, i) {
                              final item = _cart[i];
                              return ListTile(
                                title: Text(item.product.name),
                                subtitle: Text(
                                    '${item.qty} x ${item.product.price.toStringAsFixed(0)}'),
                                trailing: Text(
                                    '${item.total.toStringAsFixed(0)} so\'m'),
                              );
                            },
                          ),
                  ),
                  Text(
                    'Jami: ${_totalPrice.toStringAsFixed(0)} so\'m',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                      ),
                      onPressed: _cart.isEmpty ? null : _submitOrder,
                      child: const Text('To\'lov va Chek',
                          style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
