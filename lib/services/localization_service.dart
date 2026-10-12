import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { uz, ru, en }

extension AppLanguageExtension on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.uz:
        return 'uz';
      case AppLanguage.ru:
        return 'ru';
      case AppLanguage.en:
        return 'en';
    }
  }

  String get title {
    switch (this) {
      case AppLanguage.uz:
        return 'O‘zbekcha 🇺🇿';
      case AppLanguage.ru:
        return 'Русский 🇷🇺';
      case AppLanguage.en:
        return 'English 🇬🇧';
    }
  }

  String get shortName {
    switch (this) {
      case AppLanguage.uz:
        return 'UZ';
      case AppLanguage.ru:
        return 'RU';
      case AppLanguage.en:
        return 'EN';
    }
  }
}

class LocalizationService extends ChangeNotifier {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  AppLanguage _currentLanguage = AppLanguage.uz;
  AppLanguage get currentLanguage => _currentLanguage;

  static const String _prefKey = 'zavero_app_language';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code == 'ru') {
        _currentLanguage = AppLanguage.ru;
      } else if (code == 'en') {
        _currentLanguage = AppLanguage.en;
      } else {
        _currentLanguage = AppLanguage.uz;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang.code);
    } catch (_) {}
  }

  String tr(String key) {
    final langKey = _currentLanguage.code;
    return _translations[key]?[langKey] ?? _translations[key]?['uz'] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // App & Brand
    'app_title': {
      'uz': 'ZAVERO',
      'ru': 'ZAVERO',
      'en': 'ZAVERO',
    },
    'app_subtitle': {
      'uz': 'Restoran va Kafe Savdo Tizimi',
      'ru': 'Система автоматизации ресторанов и кафе',
      'en': 'Restaurant & Café POS System',
    },
    'tagline': {
      'uz': 'TEZLIK • ISHONCH • NATIJA',
      'ru': 'СКОРОСТЬ • НАДЕЖНОСТЬ • РЕЗУЛЬТАТ',
      'en': 'SPEED • TRUST • RESULTS',
    },

    // Navigation & Main Menu
    'menu_dashboard': {
      'uz': 'Boshqaruv paneli',
      'ru': 'Панель управления',
      'en': 'Dashboard',
    },
    'menu_pos': {
      'uz': 'Kassa / Savdo (POS)',
      'ru': 'Касса / Продажи (POS)',
      'en': 'POS / Sales',
    },
    'menu_new_order': {
      'uz': 'Yangi buyurtma',
      'ru': 'Новый заказ',
      'en': 'New Order',
    },
    'menu_tables': {
      'uz': 'Stollar va Zallar',
      'ru': 'Столы и Залы',
      'en': 'Tables & Halls',
    },
    'menu_customer_orders': {
      'uz': 'Mijozlardan buyurtmalar',
      'ru': 'Заказы от клиентов',
      'en': 'Customer Orders',
    },
    'menu_receipts': {
      'uz': 'Cheklar tarixi',
      'ru': 'История чеков',
      'en': 'Receipt History',
    },
    'menu_reports': {
      'uz': 'Hisobotlar va Tahlil',
      'ru': 'Отчеты и Аналитика',
      'en': 'Reports & Analytics',
    },
    'menu_warehouse': {
      'uz': 'Ombor & Mahsulotlar',
      'ru': 'Склад и Товары',
      'en': 'Warehouse & Products',
    },
    'menu_settings': {
      'uz': 'Sozlamalar',
      'ru': 'Настройки',
      'en': 'Settings',
    },
    'menu_language': {
      'uz': 'Til / Язык / Language',
      'ru': 'Язык / Til / Language',
      'en': 'Language / Til / Язык',
    },

    // Dashboard Tiles & Panels
    'admin_panel': {
      'uz': 'Administrator paneli',
      'ru': 'Панель администратора',
      'en': 'Admin Panel',
    },
    'waiter_panel': {
      'uz': 'Ofitsiant paneli',
      'ru': 'Панель официанта',
      'en': 'Waiter Panel',
    },
    'courier_panel': {
      'uz': 'Kuryer paneli',
      'ru': 'Панель курьера',
      'en': 'Courier Panel',
    },
    'customer_panel': {
      'uz': 'Mijoz paneli',
      'ru': 'Панель клиента',
      'en': 'Customer Panel',
    },
    'cashier_panel': {
      'uz': 'Kassir paneli',
      'ru': 'Панель кассира',
      'en': 'Cashier Panel',
    },
    'welcome_user': {
      'uz': 'Xush kelibsiz',
      'ru': 'Добро пожаловать',
      'en': 'Welcome',
    },
    'technical_support': {
      'uz': 'Texnik yordam',
      'ru': 'Техподдержка',
      'en': 'Support',
    },
    'tile_new_order': {
      'uz': 'Yangi buyurtma',
      'ru': 'Новый заказ',
      'en': 'New Order',
    },
    'tile_customer_orders': {
      'uz': 'Mijoz buyurtmalari',
      'ru': 'Заказы клиентов',
      'en': 'Customer Orders',
    },
    'tile_delivery_orders': {
      'uz': 'Dastavka buyurtmalari',
      'ru': 'Заказы на доставку',
      'en': 'Delivery Orders',
    },
    'tile_receipt_history': {
      'uz': 'Cheklar tarixi',
      'ru': 'История чеков',
      'en': 'Receipt History',
    },
    'tile_reports': {
      'uz': 'Hisobotlar',
      'ru': 'Отчеты',
      'en': 'Reports',
    },
    'tile_inventory': {
      'uz': 'Ombor',
      'ru': 'Склад',
      'en': 'Inventory',
    },
    'tile_products': {
      'uz': 'Mahsulotlar',
      'ru': 'Товары',
      'en': 'Products',
    },
    'tile_categories': {
      'uz': 'Kategoriyalar',
      'ru': 'Категории',
      'en': 'Categories',
    },
    'tile_employees': {
      'uz': 'Xodimlar',
      'ru': 'Сотрудники',
      'en': 'Employees',
    },
    'tile_customers': {
      'uz': 'Mijozlar',
      'ru': 'Клиенты',
      'en': 'Customers',
    },
    'tile_tables': {
      'uz': 'Stollar boshqaruvi',
      'ru': 'Управление столами',
      'en': 'Tables Management',
    },
    'tile_settings': {
      'uz': 'Sozlamalar',
      'ru': 'Настройки',
      'en': 'Settings',
    },
    'role_admin': {
      'uz': 'Admin',
      'ru': 'Админ',
      'en': 'Admin',
    },
    'role_waiter': {
      'uz': 'Ofitsiant',
      'ru': 'Официант',
      'en': 'Waiter',
    },
    'role_courier': {
      'uz': 'Kuryer',
      'ru': 'Курьер',
      'en': 'Courier',
    },
    'role_cashier': {
      'uz': 'Kassa',
      'ru': 'Касса',
      'en': 'Cashier',
    },

    // Order Statuses & Tabs
    'tab_all': {
      'uz': 'Barchasi',
      'ru': 'Все',
      'en': 'All',
    },
    'status_pending': {
      'uz': 'Yangi',
      'ru': 'Новый',
      'en': 'New / Pending',
    },
    'status_preparing': {
      'uz': 'Tayyorlanmoqda',
      'ru': 'Готовится',
      'en': 'Preparing',
    },
    'status_ready': {
      'uz': 'Tayyor',
      'ru': 'Готово',
      'en': 'Ready',
    },
    'status_delivered': {
      'uz': 'Yetkazildi / Berildi',
      'ru': 'Доставлен / Выдан',
      'en': 'Delivered / Served',
    },
    'status_completed': {
      'uz': 'Yakunlangan',
      'ru': 'Завершен',
      'en': 'Completed',
    },
    'status_cancelled': {
      'uz': 'Bekor qilingan',
      'ru': 'Отменен',
      'en': 'Cancelled',
    },

    // Action Buttons
    'btn_accept': {
      'uz': 'Zakasni olish',
      'ru': 'Взять заказ',
      'en': 'Take Order',
    },
    'btn_delete_order': {
      'uz': 'O‘chirish',
      'ru': 'Удалить',
      'en': 'Delete',
    },
    'clear_old_orders': {
      'uz': 'Eski buyurtmalarni tozalash',
      'ru': 'Очистить старые заказы',
      'en': 'Clear Old Orders',
    },
    'delete_order_confirm': {
      'uz': 'Ushbu buyurtmani o‘chirishni tasdiqlaysizmi?',
      'ru': 'Вы уверены, что хотите удалить заказ?',
      'en': 'Confirm delete order?',
    },
    'btn_start_prep': {
      'uz': 'Tayyorlashni boshlash',
      'ru': 'Начать готовку',
      'en': 'Start Cooking',
    },
    'btn_mark_ready': {
      'uz': 'Tayyor deb belgilash',
      'ru': 'Отметить готовым',
      'en': 'Mark as Ready',
    },
    'btn_mark_served': {
      'uz': 'Berildi / Yetkazildi',
      'ru': 'Выдан / Доставлен',
      'en': 'Served / Delivered',
    },
    'btn_cancel': {
      'uz': 'Bekor qilish',
      'ru': 'Отмена',
      'en': 'Cancel',
    },
    'btn_view': {
      'uz': 'Ko‘rish',
      'ru': 'Просмотр',
      'en': 'View',
    },
    'btn_save': {
      'uz': 'Saqlash',
      'ru': 'Сохранить',
      'en': 'Save',
    },
    'btn_edit': {
      'uz': 'Tahrirlash',
      'ru': 'Редактировать',
      'en': 'Edit',
    },
    'btn_delete': {
      'uz': 'O‘chirish',
      'ru': 'Удалить',
      'en': 'Delete',
    },
    'btn_print': {
      'uz': 'Chop etish',
      'ru': 'Печать',
      'en': 'Print',
    },
    'btn_pay': {
      'uz': 'To‘lov & Chek',
      'ru': 'Оплата и Чек',
      'en': 'Pay & Receipt',
    },
    'btn_close': {
      'uz': 'Yopish',
      'ru': 'Закрыть',
      'en': 'Close',
    },
    'btn_logout': {
      'uz': 'Chiqish',
      'ru': 'Выйти',
      'en': 'Log out',
    },
    'btn_test_voice': {
      'uz': 'Ovozni sinab ko‘rish (Test)',
      'ru': 'Проверить звук (Тест)',
      'en': 'Test Voice Announcement',
    },
    'btn_add_table': {
      'uz': 'Stol qo‘shish',
      'ru': 'Добавить стол',
      'en': 'Add Table',
    },
    'btn_add_hall': {
      'uz': 'Zal qo‘shish',
      'ru': 'Добавить зал',
      'en': 'Add Hall',
    },

    // Voice & Sound Notifications
    'voice_notification_title': {
      'uz': 'Ovozli bildirishnomalar',
      'ru': 'Голосовые уведомления',
      'en': 'Voice Notifications',
    },
    'voice_notification_desc': {
      'uz': 'QR buyurtmalar uchun professional ovozli xabar tizimi',
      'ru': 'Профессиональная система голосовых оповещений о QR заказах',
      'en': 'Professional voice announcement system for QR orders',
    },
    'voice_notification_toggle': {
      'uz': 'Ovozli bildirishnomalar (QR buyurtmalar)',
      'ru': 'Голосовые уведомления (QR заказы)',
      'en': 'Voice Notifications (QR Orders)',
    },
    'voice_notification_hint': {
      'uz': 'Mijoz QR kod orqali buyurtma berganda real vaqtda ovozli e\'lon qilinadi va qabul qilinguncha har 5-6 soniyada takrorlanadi.',
      'ru': 'При заказе через QR-код система объявляет заказ голосом и повторяет каждые 5-6 сек до принятия.',
      'en': 'When a customer places a QR order, it speaks natural audio and repeats every 5-6 seconds until accepted.',
    },

    // Tables & Halls
    'tables_management': {
      'uz': 'Stollar boshqaruvi',
      'ru': 'Управление столами',
      'en': 'Tables Management',
    },
    'no_tables_in_hall': {
      'uz': 'Ushbu zalda hali stollar yo‘q',
      'ru': 'В этом зале пока нет столов',
      'en': 'No tables in this hall yet',
    },
    'table_qr_menu': {
      'uz': 'QR Menyu',
      'ru': 'QR Меню',
      'en': 'QR Menu',
    },
    'table_occupied': {
      'uz': 'Band',
      'ru': 'Занят',
      'en': 'Occupied',
    },
    'table_free': {
      'uz': 'Bo‘sh',
      'ru': 'Свободен',
      'en': 'Free',
    },
    'add_table': {
      'uz': 'Yangi stol',
      'ru': 'Новый стол',
      'en': 'New Table',
    },
    'add_hall': {
      'uz': 'Yangi zal',
      'ru': 'Новый зал',
      'en': 'New Hall',
    },
    'hall_name_label': {
      'uz': 'Zal nomi',
      'ru': 'Название зала',
      'en': 'Hall Name',
    },
    'table_number_label': {
      'uz': 'Stol raqami',
      'ru': 'Номер стола',
      'en': 'Table Number',
    },
    'seats_count': {
      'uz': 'O‘rinlar soni',
      'ru': 'Количество мест',
      'en': 'Seats Count',
    },
    'print_qr': {
      'uz': 'QR kodni chop etish',
      'ru': 'Печать QR-кода',
      'en': 'Print QR Code',
    },
    'download_qr': {
      'uz': 'QR yuklab olish',
      'ru': 'Скачать QR',
      'en': 'Download QR',
    },

    // Cart & Summary
    'cart_title': {
      'uz': 'Buyurtma savati',
      'ru': 'Корзина заказа',
      'en': 'Order Cart',
    },
    'cart_empty': {
      'uz': 'Savat bo‘sh',
      'ru': 'Корзина пуста',
      'en': 'Cart is empty',
    },
    'total_sum': {
      'uz': 'Jami summa',
      'ru': 'Итоговая сумма',
      'en': 'Total Amount',
    },
    'currency': {
      'uz': 'so‘m',
      'ru': 'сум',
      'en': 'UZS',
    },
    'table_text': {
      'uz': 'stol',
      'ru': 'стол',
      'en': 'table',
    },
    'order_number': {
      'uz': 'Buyurtma raqami',
      'ru': 'Номер заказа',
      'en': 'Order number',
    },
    'no_orders_yet': {
      'uz': 'Hozircha mijozlardan buyurtma yo‘q',
      'ru': 'Пока нет заказов от клиентов',
      'en': 'No customer orders yet',
    },
    'qr_orders_auto_desc': {
      'uz': 'Mijozlar stol ustidagi QR kod orqali buyurtma berganda ushbu ekranda real vaqtda avtomatik paydo bo‘ladi.',
      'ru': 'Когда клиенты заказывают через QR-код на столе, заказы автоматически появляются здесь в реальном времени.',
      'en': 'When customers order via the table QR code, orders automatically appear here in real-time.',
    },

    // QR Menu Screen
    'qr_menu_title': {
      'uz': 'A TASTE OF HOME',
      'ru': 'ВКУС ДОМА',
      'en': 'A TASTE OF HOME',
    },
    'search_dish': {
      'uz': 'Taom yoki kategoriya qidirish...',
      'ru': 'Поиск блюд или категорий...',
      'en': 'Search dishes or categories...',
    },
    'order_now': {
      'uz': 'Buyurtma berish',
      'ru': 'Оформить заказ',
      'en': 'Order Now',
    },
    'view_cart': {
      'uz': 'Savatni ko‘rish',
      'ru': 'Посмотреть корзину',
      'en': 'View Cart',
    },
    'customer_name_input': {
      'uz': 'Ismingiz (ixtiyoriy)',
      'ru': 'Ваше имя (необязательно)',
      'en': 'Your name (optional)',
    },
    'phone_input': {
      'uz': 'Telefon raqamingiz',
      'ru': 'Номер телефона',
      'en': 'Phone number',
    },
    'order_note': {
      'uz': 'Izoh (masalan: kamroq tuz, issiq bo‘lsin)',
      'ru': 'Комментарий (например: погорячее)',
      'en': 'Notes (e.g. less salt, extra hot)',
    },
    'send_order': {
      'uz': 'BUYURTMA BERISH',
      'ru': 'ОФОРМИТЬ ЗАКАЗ',
      'en': 'PLACE ORDER',
    },
    'order_sent_success': {
      'uz': 'Buyurtma qabul qilindi!',
      'ru': 'Заказ принят!',
      'en': 'Order Received!',
    },
    'order_sent_kitchen_desc': {
      'uz': 'Sizning buyurtmangiz oshxona va kassa ekraniga yuborildi.\n\nHolat: Tayyorlanmoqda 🍳\n\nOvqatingiz tayyor bo‘lganda ushbu sahifada xabar beriladi!',
      'ru': 'Ваш заказ отправлен на кухню и в кассу.\n\nСтатус: Готовится 🍳\n\nКогда блюда будут готовы, статус обновится здесь!',
      'en': 'Your order has been sent to kitchen & POS.\n\nStatus: Preparing 🍳\n\nYou will see live updates here when ready!',
    },
    'understood': {
      'uz': 'TUSHUNDIM',
      'ru': 'ПОНЯТНО',
      'en': 'UNDERSTOOD',
    },
    'no_categories_found': {
      'uz': 'Menyu kategoriyalari topilmadi',
      'ru': 'Категории меню не найдены',
      'en': 'No menu categories found',
    },
    'empty_category_dishes': {
      'uz': 'Ushbu bo‘limda hozircha taomlar mavjud emas.',
      'ru': 'В этом разделе пока нет блюд.',
      'en': 'No items in this category yet.',
    },
    'main_dishes_sub': {
      'uz': 'Har bir didga mos issiq taomlar',
      'ru': 'Сытные блюда на любой вкус',
      'en': 'Hearty plates for every craving',
    },
    'breakfast_sub': {
      'uz': 'Kunni boshlash uchun mazali nonushta',
      'ru': 'Утренние блюда для бодрого начала',
      'en': 'Morning favorites to start fresh',
    },
    'pizza_sub': {
      'uz': 'Qarsildoq xamirli pitsalar',
      'ru': 'Хрустящая пицца с сочной начинкой',
      'en': 'Hand tossed pies with bold toppings',
    },
    'dessert_sub': {
      'uz': 'Shirin va nafis desertlar',
      'ru': 'Сладкие и нежные десерты',
      'en': 'Sweet bites to treat yourself',
    },
    'beverages_sub': {
      'uz': 'Muzdek va issiq ichimliklar',
      'ru': 'Освежающие напитки на весь день',
      'en': 'Cool drinks to refresh your day',
    },
  };
}

/// Global helper for easy translation
String tr(String key) => LocalizationService().tr(key);
