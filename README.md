# ZAVERO POS

ZAVERO — zamonaviy ko'p tarmoqli (multi-tenant) restoran va kafe boshqaruv tizimi (Flutter Web / Android APK + Node.js / PostgreSQL / Railway backend + Telegram bot).

## Telegram Bot sozlamalari va Majburiy obuna

Bot orqali hisobotlar va cheklarni qabul qilish uchun quyidagi talablar bajarilishi shart:

1. **Kanallar sozlamasi (.env):**
   * `CHANNEL_1=@zavero_uz`
   * `CHANNEL_2=@mirzobekdev`
2. **Bot kanallarda ADMIN bo'lishi SHART:**
   * Telegram Bot API (`getChatMember`) kanaldagi a'zolik holatini tekshirishi uchun bot har ikkala kanalda (`@zavero_uz` va `@mirzobekdev`) **administrator** huquqiga ega bo'lishi kerak.
   * Agar bot kanalda admin bo'lmasa, Telegram API `member list is inaccessible` yoki `chat not found` xatosini qaytaradi.
3. **Bot boshlanganda avtomatik tekshiruv:**
   * Server ishga tushganda botning ikkala kanalda administrator ekanligi avtomatik tekshiriladi va konsolga xabar beriladi.
4. **Login va Xavfsizlik:**
   * Ilovadagi cafe yoki director hisobi bilan kiriladi (parollar faqat bcrypt hashda saqlanadi).
   * Sessiya faollashguncha "Ilovani ochish" (Web App) menyu tugmasi ko'rinmaydi.
   * Chiqish yoki parol o'zgarishida Telegram sessiyasi darhol bekor qilinadi.
