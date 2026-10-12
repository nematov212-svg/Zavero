import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../services/localization_service.dart';
import '../widgets/optimized_image.dart';

class QRMenuScreen extends StatefulWidget {
  final String cafeId;
  final String? tableNumber;
  final String? tableName;
  final String? hallId;

  const QRMenuScreen({
    super.key,
    required this.cafeId,
    this.tableNumber,
    this.tableName,
    this.hallId,
  });

  @override
  State<QRMenuScreen> createState() => _QRMenuScreenState();
}

class _QRMenuScreenState extends State<QRMenuScreen> {
  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();
  final LocalizationService _locale = LocalizationService();

  StreamSubscription? _productSub;
  StreamSubscription? _categorySub;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _cafeData;
  List<Category> _categories = [];
  List<Product> _products = [];
  String _searchQuery = '';

  // Cart: productId -> quantity
  final Map<int, int> _cart = {};

  // Active Order Status
  Map<String, dynamic>? _activeOrder;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    _socket.connect(cafeId: widget.cafeId);
    _productSub = _socket.on(CafeSocketEvent.productsUpdated).listen((_) => _refreshMenuSilently());
    _categorySub = _socket.on(CafeSocketEvent.categoriesUpdated).listen((_) => _refreshMenuSilently());
    _loadMenu();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    _productSub?.cancel();
    _categorySub?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshMenuSilently() async {
    try {
      final res = await _api.get('/customer-orders/public/menu/${widget.cafeId}');
      if (mounted) {
        setState(() {
          if (res['categories'] is List) {
            _categories = (res['categories'] as List)
                .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
                .toList();
          }
          if (res['products'] is List) {
            _products = (res['products'] as List)
                .map((p) => Product.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMenu() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/customer-orders/public/menu/${widget.cafeId}');
      if (res['cafe'] is Map) {
        _cafeData = Map<String, dynamic>.from(res['cafe'] as Map);
      }
      if (res['categories'] is List) {
        _categories = (res['categories'] as List)
            .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      }
      if (res['products'] is List) {
        _products = (res['products'] as List)
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _addToCart(Product product) {
    setState(() {
      final current = _cart[product.id] ?? 0;
      _cart[product.id] = current + 1;
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      final current = _cart[product.id] ?? 0;
      if (current > 1) {
        _cart[product.id] = current - 1;
      } else {
        _cart.remove(product.id);
      }
    });
  }

  double get _totalAmount {
    double sum = 0;
    for (final entry in _cart.entries) {
      final prod = _products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(id: 0, name: '', price: 0, categoryId: 0, stock: 0, icon: Icons.fastfood),
      );
      sum += prod.price * entry.value;
    }
    return sum;
  }

  int get _totalItemsCount {
    return _cart.values.fold(0, (a, b) => a + b);
  }

  String _getCategorySubtitle(Category cat) {
    final name = cat.name.toLowerCase();
    final count = _products.where((p) => p.categoryId == cat.id).length;
    if (name.contains('issiq') || name.contains('main') || name.contains('taom') || name.contains('asosiy') || name.contains('горяч')) {
      return tr('main_dishes_sub');
    } else if (name.contains('nonushta') || name.contains('breakfast') || name.contains('завтрак')) {
      return tr('breakfast_sub');
    } else if (name.contains('pizza') || name.contains('pitsa') || name.contains('пицц')) {
      return tr('pizza_sub');
    } else if (name.contains('shirinlik') || name.contains('desert') || name.contains('dessert') || name.contains('десерт')) {
      return tr('dessert_sub');
    } else if (name.contains('ichimlik') || name.contains('drink') || name.contains('beverage') || name.contains('sharbat') || name.contains('напит')) {
      return tr('beverages_sub');
    } else if (name.contains('burger') || name.contains('lavash') || name.contains('fast') || name.contains('бургер')) {
      return 'Crisp & juicy quick delights';
    } else if (name.contains('salat') || name.contains('salad') || name.contains('салат')) {
      return 'Fresh greens & crisp vegetables';
    } else if (name.contains('shorva') || name.contains('soup') || name.contains('суп')) {
      return 'Warm nourishing savory bowls';
    } else if (name.contains('qahva') || name.contains('coffee') || name.contains('кофе')) {
      return 'Freshly brewed aromatic coffee';
    }
    return '$count xil mazali tanlovlar';
  }

  String _getCategoryFallbackImage(Category cat) {
    // 1. Try finding a product in this category with an image
    final prodWithImg = _products.firstWhere(
      (p) => p.categoryId == cat.id && p.imageUrl != null && p.imageUrl!.isNotEmpty,
      orElse: () => Product(id: -1, name: '', price: 0, categoryId: -1, stock: 0, icon: Icons.fastfood),
    );
    if (prodWithImg.id != -1 && prodWithImg.imageUrl != null) {
      return _api.resolveImageUrl(prodWithImg.imageUrl);
    }

    // 2. High quality thematic food image fallbacks
    final name = cat.name.toLowerCase();
    if (name.contains('issiq') || name.contains('main') || name.contains('taom') || name.contains('asosiy') || name.contains('горяч')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('nonushta') || name.contains('breakfast') || name.contains('завтрак')) {
      return 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('pizza') || name.contains('pitsa') || name.contains('пицц')) {
      return 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('shirinlik') || name.contains('desert') || name.contains('dessert') || name.contains('десерт')) {
      return 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('ichimlik') || name.contains('drink') || name.contains('beverage') || name.contains('sharbat') || name.contains('напит')) {
      return 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('burger') || name.contains('lavash') || name.contains('fast') || name.contains('бургер')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('salat') || name.contains('salad') || name.contains('салат')) {
      return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('shorva') || name.contains('soup') || name.contains('суп')) {
      return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80';
    } else if (name.contains('qahva') || name.contains('coffee') || name.contains('кофе')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&auto=format&fit=crop&q=80';
  }

  void _openCategoryProductsSheet(Category cat) {
    final catProducts = _products.where((p) => p.categoryId == cat.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF9F6F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4C8BC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header with Category Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2C221E),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getCategorySubtitle(cat),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8276),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF2C221E)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Products List
                if (catProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        tr('empty_category_dishes'),
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: catProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, idx) {
                        final p = catProducts[idx];
                        final qty = _cart[p.id] ?? 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Product Image
                              ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 84,
                                height: 84,
                                child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                    ? OptimizedImage(
                                        imageUrl: _api.resolveImageUrl(p.imageUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFFF3EFE9),
                                        child: const Icon(Icons.restaurant_rounded, color: Color(0xFFC7BDB1), size: 36),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2C221E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${p.price.toStringAsFixed(0)} ${tr('currency')}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Add / Quantity Buttons
                            if (qty == 0)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2C221E),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  _addToCart(p);
                                  setModalState(() {});
                                  setState(() {});
                                },
                                child: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      _removeFromCart(p);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3EFE9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.remove, size: 18, color: Color(0xFF2C221E)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    child: Text(
                                      '$qty',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: Color(0xFF2C221E),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      _addToCart(p);
                                      setModalState(() {});
                                      setState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C221E),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.add, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

  void _showCartSheet() {
    final customerNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool sending = false;
    String? orderError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF7F2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final itemsList = _cart.entries.map((entry) {
            final prod = _products.firstWhere((p) => p.id == entry.key);
            return {'product': prod, 'qty': entry.value};
          }).toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2C221E)),
                          const SizedBox(width: 8),
                          Text(
                            '${tr('cart_title')} ($_totalItemsCount)',
                            style: const TextStyle(color: Color(0xFF2C221E), fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE5DDD2), height: 20),

                  if (orderError != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(orderError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),

                  // Stol belgisi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EFE9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5DDD2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.table_restaurant, color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${tr('table_text')}: ${widget.tableName ?? '${widget.tableNumber ?? '1'}-stol'}',
                          style: const TextStyle(color: Color(0xFF2C221E), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // Items List
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: itemsList.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFFE5DDD2), height: 12),
                      itemBuilder: (context, i) {
                        final item = itemsList[i];
                        final prod = item['product'] as Product;
                        final qty = item['qty'] as int;

                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: const TextStyle(color: Color(0xFF2C221E), fontWeight: FontWeight.bold, fontSize: 14.5),
                                  ),
                                  Text(
                                    '${prod.price.toStringAsFixed(0)} ${tr('currency')}',
                                    style: const TextStyle(color: Color(0xFF8E8276), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 22),
                                  onPressed: () {
                                    _removeFromCart(prod);
                                    setSheetState(() {});
                                    setState(() {});
                                    if (_cart.isEmpty) Navigator.pop(ctx);
                                  },
                                ),
                                Text(
                                  '$qty',
                                  style: const TextStyle(color: Color(0xFF2C221E), fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFFB45309), size: 22),
                                  onPressed: () {
                                    _addToCart(prod);
                                    setSheetState(() {});
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(color: Color(0xFFE5DDD2), height: 24),

                  // Mijoz ma'lumotlari
                  TextField(
                    controller: customerNameCtrl,
                    style: const TextStyle(color: Color(0xFF2C221E), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: tr('customer_name_input'),
                      labelStyle: const TextStyle(color: Color(0xFF8E8276)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD2))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    style: const TextStyle(color: Color(0xFF2C221E), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      labelText: tr('order_note'),
                      labelStyle: const TextStyle(color: Color(0xFF8E8276)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DDD2))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Umumiy summa
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${tr('total_sum')}:', style: const TextStyle(color: Color(0xFF8E8276), fontSize: 15)),
                      Text(
                        '${_totalAmount.toStringAsFixed(0)} ${tr('currency')}',
                        style: const TextStyle(color: Color(0xFF2C221E), fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SUBMIT ORDER BUTTON
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C221E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: sending
                          ? null
                          : () async {
                              setSheetState(() {
                                sending = true;
                                orderError = null;
                              });

                              try {
                                final orderItems = _cart.entries.map((e) {
                                  final p = _products.firstWhere((prod) => prod.id == e.key);
                                  return {
                                    'productId': p.id,
                                    'name': p.name,
                                    'price': p.price,
                                    'qty': e.value,
                                    'product': p.toJson(),
                                  };
                                }).toList();

                                final res = await _api.post('/customer-orders/public/order', body: {
                                  'cafeId': widget.cafeId,
                                  'tableNumber': widget.tableNumber,
                                  'tableName': widget.tableName ?? '${widget.tableNumber ?? '1'}-stol',
                                  'hallId': widget.hallId,
                                  'items': orderItems,
                                  'customerName': customerNameCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'notes': notesCtrl.text.trim(),
                                });

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (mounted) {
                                  setState(() {
                                    _cart.clear();
                                    _activeOrder = res['order'] != null ? Map<String, dynamic>.from(res['order'] as Map) : null;
                                  });
                                  _startOrderStatusPolling();
                                  _showOrderSuccessDialog();
                                }
                              } catch (e) {
                                setSheetState(() {
                                  sending = false;
                                  orderError = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      child: sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text(tr('send_order'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _startOrderStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 4), (t) async {
      if (_activeOrder == null || _activeOrder!['id'] == null) {
        t.cancel();
        return;
      }
      try {
        final orderId = _activeOrder!['id'];
        final res = await _api.get('/customer-orders/public/order-status/$orderId?cafeId=${widget.cafeId}');
        if (res['order'] is Map) {
          final updated = Map<String, dynamic>.from(res['order'] as Map);
          setState(() => _activeOrder = updated);
        }
      } catch (_) {}
    });
  }

  void _showOrderSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 10),
            Text(tr('order_sent_success'), style: const TextStyle(color: Color(0xFF2C221E), fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          tr('order_sent_kitchen_desc'),
          style: const TextStyle(color: Color(0xFF786C5E), fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2C221E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('understood'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderStatusCard() {
    if (_activeOrder == null) return const SizedBox.shrink();

    final status = _activeOrder!['status']?.toString().toLowerCase() ?? 'pending';
    int currentStep = 0;
    if (status == 'preparing' || status == 'cooking' || status == 'in_progress') {
      currentStep = 1;
    } else if (status == 'delivering' || status == 'on_way' || status == 'ready' || status == 'ready_to_serve') {
      currentStep = 2;
    } else if (status == 'delivered' || status == 'completed' || status == 'served') {
      currentStep = 3;
    }

    final steps = [
      {'title': tr('status_pending'), 'icon': Icons.assignment_turned_in_outlined},
      {'title': tr('status_preparing'), 'icon': Icons.soup_kitchen_outlined},
      {'title': tr('status_ready'), 'icon': Icons.delivery_dining_outlined},
      {'title': tr('status_delivered'), 'icon': Icons.task_alt_rounded},
    ];

    final isDelivered = currentStep == 3;
    final isOnTheWay = currentStep == 2;
    final isPreparing = currentStep == 1;

    String statusTitle = tr('status_pending');
    String statusDesc = 'Buyurtmangiz tizimga tushdi va tez orada tayyorlash boshlanadi.';

    if (isDelivered) {
      statusTitle = 'Ovqat yetkazildi! Yoqimli ishtaha! 🎉';
      statusDesc = 'Barcha taomlar stolingizga yetkazildi. Yoqimli ishtaha tilaymiz!';
    } else if (isOnTheWay) {
      statusTitle = 'Buyurtmangiz yo‘lda! 🚀';
      statusDesc = 'Taomlar tayyor bo‘ldi! Xodim stolingizga olib kelmoqda.';
    } else if (isPreparing) {
      statusTitle = 'Taomlar tayyorlanmoqda... 🍳';
      statusDesc = 'Oshpazlarimiz buyurtmangizni mehr bilan tayyorlamoqda.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3EFE9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined, color: Color(0xFFB45309), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF2C221E)),
                    ),
                    Text(
                      statusDesc,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8276)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stepper bar
          Row(
            children: List.generate(steps.length, (idx) {
              final active = idx <= currentStep;
              final item = steps[idx];
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF2C221E) : const Color(0xFFEFE6DC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData, size: 16, color: active ? Colors.white : const Color(0xFFB0A294)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? const Color(0xFF2C221E) : const Color(0xFFB0A294),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5EFE6),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2C221E)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5EFE6),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF2C221E), fontSize: 16)),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C221E), foregroundColor: Colors.white),
                  onPressed: _loadMenu,
                  child: const Text('Qaytadan yuklash'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cafeName = _cafeData?['name']?.toString() ?? 'il Piatto';
    final tableTitle = widget.tableName ?? '${widget.tableNumber ?? '1'}-stol';

    final filteredCategories = _categories.where((cat) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final catMatches = cat.name.toLowerCase().contains(query);
      final hasMatchingProducts = _products.any((p) => p.categoryId == cat.id && p.name.toLowerCase().contains(query));
      return catMatches || hasMatchingProducts;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE6), // Warm luxury latte background (Image 3)
      bottomNavigationBar: _totalItemsCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EFE6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C221E),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _showCartSheet,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB45309),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_totalItemsCount',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(tr('view_cart'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                          ],
                        ),
                        Text(
                          '${_totalAmount.toStringAsFixed(0)} ${tr('currency')} →',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Top Header: Subtitle, Cafe Name, Table tag, Round Action buttons (Image 3 style)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Column(
                  children: [
                    // Top round action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF2C221E)),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: Color(0xFF2C221E)),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
                            ],
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF2C221E)),
                            onPressed: _loadMenu,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // "A TASTE OF HOME" subtitle
                    Text(
                      tr('qr_menu_title'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
                        color: Color(0xFF786C5E),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Cafe Brand Name & Language dropdown row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Cafe Brand Name (Cursive/Serif elegant aesthetic)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cafeName,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF2C221E),
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8DECF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '📍 $tableTitle',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF786C5E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Language Selector Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AppLanguage>(
                              value: _locale.currentLanguage,
                              isDense: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF2C221E)),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2C221E)),
                              items: const [
                                DropdownMenuItem(value: AppLanguage.uz, child: Text('O‘zbekcha')),
                                DropdownMenuItem(value: AppLanguage.en, child: Text('English')),
                                DropdownMenuItem(value: AppLanguage.ru, child: Text('Русский')),
                              ],
                              onChanged: (val) {
                                if (val != null) _locale.setLanguage(val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Active Order Status Card
            SliverToBoxAdapter(
              child: _buildActiveOrderStatusCard(),
            ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    style: const TextStyle(color: Color(0xFF2C221E), fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: tr('search_dish'),
                      hintStyle: const TextStyle(color: Color(0xFFA89F95), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E8276), size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),
              ),
            ),

            // Categories List — Exact luxury horizontal cards (Image 3 design!)
            if (filteredCategories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Text(
                      tr('no_categories_found'),
                      style: const TextStyle(color: Color(0xFF8E8276), fontSize: 15),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, idx) {
                      final cat = filteredCategories[idx];
                      final catImage = _getCategoryFallbackImage(cat);
                      final catSubtitle = _getCategorySubtitle(cat);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        height: 122,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _openCategoryProductsSheet(cat),
                            child: Row(
                              children: [
                                // Left half: Title and Subtitle
                                Expanded(
                                  flex: 6,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2C221E),
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          catSubtitle,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8E8276),
                                            height: 1.25,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Right half: Rich Food Photo with smooth blend
                                Expanded(
                                  flex: 5,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        OptimizedImage(
                                          imageUrl: catImage,
                                          fit: BoxFit.cover,
                                        ),
                                        // Subtle soft white gradient overlay from left to blend with card
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white,
                                                Colors.white.withValues(alpha: 0.0),
                                              ],
                                              stops: const [0.0, 0.4],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: filteredCategories.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 30),
            ),
          ],
        ),
      ),
    );
  }
}
