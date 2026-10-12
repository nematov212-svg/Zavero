import '../models/models.dart';

/// O'zbek tilidagi sonlarni so'zga aylantirish va tabiiy nutq matnini tayyorlash yordamchisi
class UzbekNumberToWords {
  static final Map<int, String> _units = {
    0: 'nol',
    1: 'bir',
    2: 'ikki',
    3: 'uch',
    4: 'to‘rt',
    5: 'besh',
    6: 'olti',
    7: 'yetti',
    8: 'sakkiz',
    9: 'to‘qqiz',
  };

  static final Map<int, String> _tens = {
    10: 'o‘n',
    20: 'yigirma',
    30: 'o‘ttiz',
    40: 'qirq',
    50: 'ellik',
    60: 'oltmish',
    70: 'yetmish',
    80: 'sakson',
    90: 'to‘qson',
  };

  /// Sonni o'zbek tilidagi ravon so'zlarga aylantiradi (masalan: 85000 -> "sakson besh ming", 125 -> "bir yuz yigirma besh")
  static String convert(int number) {
    if (number == 0) return 'nol';
    if (number < 0) return 'minus ${convert(-number)}';

    List<String> parts = [];

    if (number >= 1000000000) {
      int billions = number ~/ 1000000000;
      parts.add('${convert(billions)} milliard');
      number %= 1000000000;
    }

    if (number >= 1000000) {
      int millions = number ~/ 1000000;
      parts.add('${convert(millions)} million');
      number %= 1000000;
    }

    if (number >= 1000) {
      int thousands = number ~/ 1000;
      if (thousands == 1) {
        parts.add('bir ming');
      } else {
        parts.add('${convert(thousands)} ming');
      }
      number %= 1000;
    }

    if (number >= 100) {
      int hundreds = number ~/ 100;
      if (hundreds == 1) {
        parts.add('bir yuz');
      } else {
        parts.add('${_units[hundreds]} yuz');
      }
      number %= 100;
    }

    if (number >= 10) {
      int t = (number ~/ 10) * 10;
      if (_tens.containsKey(t)) {
        parts.add(_tens[t]!);
      }
      number %= 10;
    }

    if (number > 0) {
      parts.add(_units[number] ?? '');
    }

    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  /// Taom sonini tabiiy aytish (1 -> bitta, 2 -> ikki dona, 3 -> uch dona)
  static String convertQuantity(int qty, {bool useBittaForOne = true}) {
    if (qty == 1 && useBittaForOne) {
      return 'bitta';
    }
    return '${convert(qty)} dona';
  }
}

/// Zavero Café QR buyurtmalari uchun professional ovozli xabarlar generatori
class UzbekSpeechHelper {
  /// Yangi buyurtma kelganda aniq va qisqa erkak ovozi matni
  static String buildOrderAnnouncement(CustomerOrder order) {
    return 'Mijozdan yangi buyurtma keldi.';
  }

  /// Qabul qilinmagan buyurtma uchun eslatma (agar kerak bo'lsa)
  static String buildReminderAnnouncement(CustomerOrder order) {
    return 'Mijozdan yangi buyurtma keldi.';
  }
}
