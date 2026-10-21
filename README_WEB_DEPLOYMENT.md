# ZAVERO — Web & Mobil Integratsiya va Deploy Qo‘llanmasi

Ushbu hujjat **Zavero Restaurant OS** (Flutter Mobile/Web) hamda **Zavero.uz** (React Marketing & Director Platformasi) integratsiyasi, brauzer orqali ishga tushirish, hosting va domenni sozlash bo‘yicha to‘liq texnik qo‘llanmadir.

---

## 🏛 1. Tizim Arxitekturasi

Zavero ekotizimi 3 ta asosiy bo‘g‘indan iborat:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ZAVERO EKOTIZIMI                                │
├────────────────────────────────┬───────────────────────────────────────┤
│ 1. Asosiy Sayt & Director CRM  │ https://zavero.uz                     │
│    (React 19 + Vite + Tailwind)│ Marketing, Tariflar, Leadlar, Director│
├────────────────────────────────┼───────────────────────────────────────┤
│ 2. Zavero POS & Cafe Web App   │ https://app.zavero.uz                 │
│    (Flutter Web / Desktop / PWA│ Kassa, Ofitsiant, Oshxona, Ombor      │
├────────────────────────────────┼───────────────────────────────────────┤
│ 3. Markaziy Backend & API      │ https://api.zavero.uz (yoki /api)     │
│    (Node.js + Postgres + Socket│ Avtorizatsiya, Buyurtmalar, Telegram  │
└────────────────────────────────┴───────────────────────────────────────┘
```

1. **Saytdan Web Ilovaga O'tish**:
   - `zavero.uz` bosh sahifasida (Navbar, Hero va Footer) maxsus **"Zavero POS Web"** tugmalari o'rnatilgan.
   - Foydalanuvchi bitta bosish orqali to'g'ridan-to'g'ri `https://app.zavero.uz` manzilidagi to'liq huquqli Restaurant OS ilovasiga kiradi.
2. **Yagona Backend va Baza**:
   - Flutter ilova ham, Web versiya ham bir xil PostgreSQL bazasi va REST API bilan ishlaydi.
   - Ofitsiant mobil ilovada stolga buyurtma olsa, bu buyurtma darhol veb-brauzerdagi Kassa (POS) va Oshxona (KDS) ekranlarida real vaqtda paydo bo'ladi.

---

## 🚀 2. Lokal Muhitda Ishga Tushirish (Local Development)

### A. Backendni ishga tushirish:
```bash
cd backend
npm install
npm run dev
# Server http://localhost:3000 da ishga tushadi
```

### B. Flutter Webni brauzerda ishga tushirish:
```bash
# Asosiy zavero papkasida:
flutter pub get
flutter run -d chrome
```

### C. Zavero.uz Web-saytini ishga tushirish:
```bash
cd ../Zavero.uz/frontend
npm install
npm run dev
# Sayt http://localhost:5173 da ochiladi
```

---

## 📦 3. Flutter Web Versiyasini Yig'ish (Build)

Flutter Web ilovasini eng tez va optimallashgan (CanvasKit + HTML renderer) ko'rinishda yig'ish:

```bash
flutter build web --release
```

Yig'ilgan fayllar `build/web` papkasida hosil bo'ladi:
- `index.html` — Asosiy kirish nuqtasi, PWA va Telegram WebApp SDK ulanishi.
- `main.dart.js` — Minifikatsiya qilingan Flutter logikasi.
- `flutter.js` va `flutter_bootstrap.js` — Yuklovchi skriptlar.
- `assets/` — Shriftlar, taomlar rasmlari va ikonlar.
- `canvaskit/` — WebAssembly (Wasm) render dvigateli.
- `sound_effects.js` va audio fayllar — Qo'ng'iroq va ovozli bildirishnomalar.

### Backend bilan birga tarqatish (Co-hosting):
Backend `backend/src/public/` papkasidagi fayllarni avtomatik statik resurs sifatida tarqatadi:
```bash
cp -R build/web/* backend/src/public/
```

---

## 🌐 4. Domen va Subdomenlarni Sozlash (DNS)

Domen provayderingizda (masalan, Regos, Eskiz, Cloudflare) quyidagi DNS yozuvlarini kiriting:

| Turi | Host / Nom | Qiymat (Target) | Vazifasi |
|---|---|---|---|
| **A** | `@` (zavero.uz) | `SERVER_IP_MANZILI` | Asosiy marketing sayti |
| **A** | `www` | `SERVER_IP_MANZILI` | www yo'naltirish |
| **A** | `app` (app.zavero.uz) | `SERVER_IP_MANZILI` | **Zavero Flutter Web POS ilovasi** |
| **A** | `api` (api.zavero.uz) | `SERVER_IP_MANZILI` | Backend REST API va WebSocket |

---

## 🖥 5. VPS Serverga Deploy Qilish (Ubuntu / Debian)

### 1. Zarur paketlarni o'rnatish:
```bash
sudo apt update && sudo apt install -y nginx certbot python3-certbot-nginx nodejs npm
sudo npm install -g pm2
```

### 2. Fayllarni serverga joylash:
- React sayt: `/var/www/zavero-website/dist`
- Flutter Web POS: `/var/www/zavero-app/public`
- Backend: `/var/www/zavero/backend`

### 3. Nginx konfiguratsiyasini faollashtirish:
Loyiha ichidagi `deployment/nginx.conf` faylidan foydalaning:
```bash
sudo cp deployment/nginx.conf /etc/nginx/sites-available/zavero.conf
sudo ln -s /etc/nginx/sites-available/zavero.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Bepul SSL (HTTPS) sertifikatini olish:
```bash
sudo certbot --nginx -d zavero.uz -d www.zavero.uz -d app.zavero.uz -d api.zavero.uz
```

### 5. Backendni PM2 orqali doimiy fonda ishlatish:
```bash
cd /var/www/zavero
pm2 start deployment/ecosystem.config.js
pm2 save
pm2 startup
```

---

## ☁️ 6. Cloud / PaaS Serverlarga Deploy Qilish (Vercel / Render)

1. **Flutter Web POS**:
   - `build/web` papkasini Vercel yoki Netlify'ga static site sifatida yuklashingiz mumkin.
   - Domen qismida `app.zavero.uz` CNAME qilib ulanadi.
2. **Backend**:
   - Loyiha Render.com da muvaffaqiyatli ishlaydi (`https://zavero-jrna.onrender.com`).
   - Webhooks va Telegram bot integratsiyasi to'liq avtomatlashtirilgan.
3. **Sayt (React)**:
   - `../Zavero.uz/frontend` Vercel yoki Cloudflare Pages orqali `zavero.uz` domeniga ulanadi.

---

## ✅ 7. Sinovdan O'tgan Imkoniyatlar

- [x] **Flutter Web Kompilyatsiya**: 0 ta xato, 0 ta ogohlantirish (`flutter analyze` toza).
- [x] **Web Responsive Dizayn**: Kompyuter (Desktop), Planshet (Tablet) va Smartfon (Mobile) ekranlariga to'liq moslashuvchan.
- [x] **Sayt Integratsiyasi**: `Zavero.uz` saytining Navbar, Hero va Footer qismlariga `Zavero POS Web` tugmalari o'rnatildi.
- [x] **Avtomatik Base URL**: Web versiya o'zi ochilgan domen (`localhost:3000`, `zavero.uz`, `onrender.com`) bo'yicha API manzilini avtomatik tanlaydi.
- [x] **Xavfsiz Autentifikatsiya**: JWT token, parollar va maxfiy kalitlar xavfsiz saqlanadi.
- [x] **Ovozli Bildirishnomalar**: Har qanday yangi QR buyurtmada doimiy «Ting!» qo'ng'iroq ovozi yangraydi, ovozli gapirish esa Sozlamalar orqali yoqiladi/o'chiriladi.
- [x] **Kesh va SPA Marshrutlash**: Sahifa yangilanganda (F5) 404 xatosi chiqmasligi uchun Nginx va Express `app.get('*')` fallbacklari sozlangan.
