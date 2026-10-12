import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../widgets/optimized_image.dart';

class AdminDashboard extends StatefulWidget {
  final AppUser user;
  const AdminDashboard({super.key, required this.user});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final _authService = AuthService();
  final _cloudService = CloudService();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboardView(),
      _buildProductsView(),
      _buildOrdersView(),
      _buildReportsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel - ${widget.user.name}'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.logout(),
          )
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange.shade900,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fastfood), label: 'Mahsulotlar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.list_alt), label: 'Buyurtmalar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.analytics), label: 'Hisobotlar'),
        ],
      ),
    );
  }

  Widget _buildDashboardView() {
    return StreamBuilder<List<CustomerOrder>>(
      stream: _cloudService.streamCustomerOrders(widget.user.ownerId),
      builder: (context, snapshot) {
        int orderCount = snapshot.hasData ? snapshot.data!.length : 0;
        double totalRevenue = snapshot.hasData
            ? snapshot.data!.fold(0, (sum, item) => sum + item.total)
            : 0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                color: Colors.orange.shade100,
                child: ListTile(
                  title: const Text('Barcha Buyurtmalar'),
                  subtitle: Text('$orderCount ta'),
                  leading: const Icon(Icons.shopping_bag, size: 40),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.green.shade100,
                child: ListTile(
                  title: const Text('Umumiy Tushum'),
                  subtitle: Text('${totalRevenue.toStringAsFixed(0)} so\'m'),
                  leading: const Icon(Icons.monetization_on, size: 40),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.blue.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.restaurant_menu, color: Colors.blue, size: 36),
                  title: const Text(
                    'Menularni va Taomlarni Qayta Tiklash',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text('Barcha asliy 10 ta kategoriya va 29 ta ovqatni qayta tiklaydi'),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tiklash'),
                    onPressed: () => _confirmRestoreMenu(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmRestoreMenu(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Menularni qayta tiklash'),
        content: const Text(
          'Barcha 10 ta kategoriya va 29 ta asliy taomlar (Шаурма, Пита, Лаваш, Донер, Хот-дог, Напитки, Чай-кофе, Мороженое, Семечка...) baza va ilovaga qayta yuklanadi. Rosti bilan tiklamoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Menular tiklanmoqda...')),
              );
              final success = await _cloudService.restoreDefaultMenu();
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  backgroundColor: success ? Colors.green : Colors.red,
                  content: Text(
                    success
                        ? '✅ Barcha asliy menular va ovqatlar to\'liq tiklandi!'
                        : '⚠️ Menularni tiklashda xatolik yuz berdi',
                  ),
                ),
              );
              setState(() {});
            },
            child: const Text('Ha, Tiklash', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsView() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _cloudService.streamProducts(widget.user.ownerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const Center(child: Text('Mahsulotlar mavjud emas'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              final resolvedUrl = ApiClient().resolveImageUrl(p.imageUrl);
              return Card(
                elevation: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: resolvedUrl.isNotEmpty
                        ? OptimizedImage(
                            imageUrl: resolvedUrl,
                            fit: BoxFit.cover,
                            fallbackIcon: p.icon,
                            iconColor: Colors.orange.shade900,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : Icon(p.icon, color: Colors.orange.shade900),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${p.price.toStringAsFixed(0)} so\'m · Zaxira: Cheksiz (∞)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Bor (Mavjud)',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _cloudService.deleteProduct(widget.user.ownerId, p.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mahsulot qo\'shish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nomi')),
            const SizedBox(height: 8),
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Narxi')),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                final newProd = Product(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  name: nameCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 0,
                  categoryId: 1001,
                  stock: 50,
                  icon: Icons.fastfood,
                );
                await _cloudService.saveProduct(widget.user.ownerId, newProd);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  setState(() {});
                }
              }
            },
            child: const Text('Saqlash'),
          )
        ],
      ),
    );
  }

  Widget _buildOrdersView() {
    return StreamBuilder<List<CustomerOrder>>(
      stream: _cloudService.streamCustomerOrders(widget.user.ownerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const Center(child: Text('Buyurtmalar yo\'q'));
        }
        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final o = orders[index];
            return ListTile(
              title: Text('${o.customerName} - ${o.total.toStringAsFixed(0)} so\'m'),
              subtitle: Text('Status: ${orderStatusToString(o.status)} (${o.phone})'),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsView() {
    return const Center(
      child: Text(
        'Kunlik / Oylik Savdo Hisobotlari',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }
}
