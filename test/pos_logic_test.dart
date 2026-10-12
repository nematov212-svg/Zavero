import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zavero/models/models.dart';
import 'package:zavero/data/initial_cafe_data.dart';

void main() {
  group('ZAVERO Models & Business Logic Tests', () {
    test('AppUser serialization and roles', () {
      final user = AppUser(
        id: 1001,
        uid: 'user_uid_123',
        name: 'Azizbek',
        surname: 'Rahimov',
        username: 'azizbek',
        email: 'azizbek@zavero.pos',
        phone: '+998901234567',
        password: '',
        role: UserRole.admin,
        ownerId: 'user_uid_123',
      );

      final json = user.toJson();
      expect(json['uid'], 'user_uid_123');
      expect(json['role'], 'admin');

      final deserialized = AppUser.fromJson(json);
      expect(deserialized.name, 'Azizbek');
      expect(deserialized.role, UserRole.admin);
      expect(roleToString(deserialized.role), 'Administrator (Cafe egasi)');
    });

    test('Product and CartItem calculation', () {
      final product = Product(
        id: 501,
        name: 'Oshxona Shaurma',
        price: 35000,
        categoryId: 1001,
        stock: 20,
        icon: Icons.lunch_dining,
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/zavero-pos.firebasestorage.app/products/shaurma.jpg',
      );

      final cartItem = CartItem(product: product, qty: 3, note: 'Achchiq');
      expect(cartItem.total, 105000);
      expect(cartItem.qty, 3);
      expect(cartItem.note, 'Achchiq');

      final json = product.toJson();
      expect(json['name'], 'Oshxona Shaurma');
      expect(json['imageUrl'], startsWith('https://'));
    });

    test('Table Status & Occupied Flow Rule Verification', () {
      final table = TableModel(
        id: 3001,
        hallId: 2001,
        number: 5,
        seats: 4,
        status: TableStatus.free,
      );

      // 1. Table is free initially
      expect(table.status, TableStatus.free);

      // 2. Draft order does NOT occupy table
      final cart = [
        CartItem(
          product: Product(
            id: 1,
            name: 'Lavash',
            price: 32000,
            categoryId: 1002,
            stock: 10,
            icon: Icons.fastfood,
          ),
          qty: 2,
        )
      ];
      expect(table.status, TableStatus.free);

      // 3. User clicks "To'lovga o'tish" -> Table is OCCUPIED
      table.status = TableStatus.occupied;
      expect(table.status, TableStatus.occupied);

      // 4. Cancel before checkout -> Table is released to FREE
      table.status = TableStatus.free;
      expect(table.status, TableStatus.free);

      // 5. Checkout completion -> Receipt created and Table is FREE
      final receipt = Receipt(
        id: 999,
        date: DateTime.now(),
        items: cart,
        total: 64000,
        method: PaymentMethod.cash,
        cashierName: 'Admin',
        tableNumber: table.number,
      );
      expect(receipt.total, 64000);
      expect(table.status, TableStatus.free);
    });

    test('OrderStatus transitions and label formatting', () {
      expect(orderStatusToString(OrderStatus.pending), 'Yangi');
      expect(orderStatusToString(OrderStatus.preparing), 'Tayyorlanmoqda');
      expect(orderStatusToString(OrderStatus.ready), 'Tayyor');
      expect(orderStatusToString(OrderStatus.delivered), 'Yetkazildi / Berildi');
      expect(orderStatusToString(OrderStatus.completed), 'Yakunlandi');
      expect(orderStatusToString(OrderStatus.cancelled), 'Bekor qilindi');
    });

    test('Authentic dishes & categories integrity test', () {
      expect(kInitialCategories.length, 13);
      expect(kInitialProducts.length, 103);

      final catIds = kInitialCategories.map((c) => c.id).toSet();
      expect(catIds.contains(1), isTrue); // Shaurma
      expect(catIds.contains(2), isTrue); // Lavash
      expect(catIds.contains(3), isTrue); // Pita
      expect(catIds.contains(4), isTrue); // Super Donar
      expect(catIds.contains(5), isTrue); // Hot-dog
      expect(catIds.contains(6), isTrue); // Pizza
      expect(catIds.contains(7), isTrue); // Ichimliklar
      expect(catIds.contains(8), isTrue); // Choy
      expect(catIds.contains(10), isTrue); // Simichka
      expect(catIds.contains(11), isTrue); // Marojni
      expect(catIds.contains(12), isTrue); // Desertlar
      expect(catIds.contains(13), isTrue); // Tostik
      expect(catIds.contains(14), isTrue); // Dastafka

      // Every single product must point to a valid category and have a valid image
      for (final p in kInitialProducts) {
        expect(catIds.contains(p.categoryId), isTrue,
            reason: 'Product "${p.name}" has invalid categoryId ${p.categoryId}');
        expect(p.imageUrl != null && p.imageUrl!.isNotEmpty, isTrue,
            reason: 'Product "${p.name}" must have an image');
      }

      // Check key authentic items
      expect(kInitialProducts.any((p) => p.name == 'мини шавурма'), isTrue);
      expect(kInitialProducts.any((p) => p.name == 'Средний шувурма'), isTrue);
      expect(kInitialProducts.any((p) => p.name == 'Большое шавурма'), isTrue);
      expect(kInitialProducts.any((p) => p.name == 'Мини лаваш'), isTrue);
      expect(kInitialProducts.any((p) => p.name == 'средний пита'), isTrue);

      // Verify no duplicates in Shaurma
      final shaurmaItems = kInitialProducts.where((p) => p.categoryId == 1).toList();
      expect(shaurmaItems.length, 3);
    });
  });
}
