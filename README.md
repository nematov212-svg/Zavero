# ZAVERO POS

ZAVERO — zamonaviy ko'p tarmoqli (multi-tenant) restoran va kafe boshqaruv tizimi (Flutter Web / Android APK + Node.js / PostgreSQL / Railway backend + Telegram bot).

## Telegram Bot: Kirish va Xavfsizlik Arxitekturasi

ZAVERO Telegram hisobot boti restoran va kafelarning real vaqtdagi savdolari, yopilgan cheklari va kunlik hisobotlarini avtomatik yetkazib beradi:

1. **To'g'ridan-to'g'ri kirish (Kanal obunasisiz):**
   - Botdan foydalanish uchun hech qanday kanallarga majburiy a'zolik talab qilinmaydi.
   - Bot kanallarda administrator bo'lishi shart emas.

2. **Kirish tartibi (Login -> Parol -> Nomer ulash):**
   - `/start` bosilganda bot darhol foydalanuvchini qutlaydi va Cafe loginini so'raydi.
   - Login topilgach, parol so'raladi. Parol xabari chatdan xavfsizlik uchun darhol o'chiriladi.
   - Ketma-ket 5 marta noto'g'ri parol kiritilsa, bot 5 daqiqaga bloklanadi (Brute-force himoyasi).
   - Login va parol to'g'ri kiritilgach, bot «📱 Nomer ulash» tugmasini chiqaradi.
   - Foydalanuvchi o'z kontaktini yuborganda (`contact.user_id == from.id`), telefon raqami sessiyaga biriktiriladi. Uchinchi shaxslar kontakti rad etiladi.

3. **Yagona Manba (Single Source of Truth):**
   - Botda alohida login-parol nusxasi saqlanmaydi — barcha tekshiruvlar ilovaning `users` jadvalidagi bcrypt xeshlar orqali amalga oshiriladi.
   - Ilovada login yoki parol o'zgarsa, botdagi barcha ochiq sessiyalar avtomatik yopiladi va menyu tugmasi standart holatga qaytariladi.
   - Ofitsiant, kassir va xodimlar loginlari botga kiritilmaydi (faqat Cafe ma'muri yoki Director).

4. **"ILOVANI OCHISH" (Web App):**
   - Login qilmagan chatlarda "Ilovani ochish" tugmasi ko'rinmaydi (global default holat).
   - Faqat tasdiqlangan va kirgan foydalanuvchilar chatiga `setChatMenuButton` orqali Web App tugmasi o'rnatiladi.
   - Chiqish (`🚪 Chiqish`) yoki kafe o'chirilganda tugma standart holatga qaytariladi.

5. **Multi-Tenant Izolyatsiya va Avtomatik Xabarlar:**
   - Har bir kafening cheklari va kunlik hisobotlari faqat o'sha kafening faol sessiyalariga boradi.
   - Telefon raqamlari maxfiy hisoblanadi va loglarda to'liq ko'rsatilmaydi (faqat `+***XXXX`).
