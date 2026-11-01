# 🖨️ ZAVERO PRINT AGENT

Zavero POS tizimi uchun lokal chek chiqarish xizmati (Print Bridge).
Brauzer, Telegram Mini App, planshet va ofitsiant telefonlaridan yuborilgan cheklarni kafe kompyuteridagi termal printerga (Wi-Fi, USB kabel, Bluetooth) 1:1 original dizaynda chiqarib beradi.

---

## 🚀 1. O'rnatish va Ishga Tushirish

### Talablar:
- Kompyuterda **Node.js (18+)** o'rnatilgan bo'lishi kerak ([nodejs.org](https://nodejs.org) dan bepul yuklab oling).

### Windows'da:
1. `print-agent/start.bat` faylini ikki marta bosing.
2. Birinchi marta ishga tushganda barcha kutubxonalar avtomatik o'rnatiladi.
3. Ekranda `🚀 ZAVERO PRINT AGENT ISHGA TUSHDI! (http://localhost:9101)` yozuvi chiqadi.

### macOS / Linux'da:
Terminalda:
```bash
cd print-agent
./start.sh
```

---

## ⚡ 2. Kompyuter Yoqilganda Avtomatik Ishga Tushirish (Autostart)

### Windows:
1. Klaviaturada `Win + R` bosing va `shell:startup` deb yozib Enter bosing.
2. Ochilgan "Avtozagruzka" papkasiga `print-agent/start.bat` faylining yorlig'ini (shortcut) nusxalang.
3. Endi kompyuter yonganda agent avtomatik fonda ishga tushadi.

### macOS:
`~/Library/LaunchAgents/com.zavero.printagent.plist` faylini yarating:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.zavero.printagent</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/Users/mirzobek/Desktop/zavero/print-agent/src/server.js</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/zavero-agent.log</string>
</dict>
</plist>
```
Keyin terminalda:
```bash
launchctl load ~/Library/LaunchAgents/com.zavero.printagent.plist
```

---

## ⚙️ 3. Printerni Ulash Turlari

Kafe boshqaruv panelida **Tizim Sozlamalari -> Printer** bo'limiga kiring:

### 1) Wi-Fi / IP (Tarmoq printeri):
- Printerning statik IP-manzilini kiriting (masalan: `192.168.1.50`).
- Port: `9100` (standart).
- "Ulanishni tekshirish" tugmasini bosing:
  - Yashil `Ulangan (xx ms)` chiqsa, printer tayyor.
- *Eslatma: Agar `192.18.x.x` kiritilsa, tizim ogohlantiradi (odatda `192.168.x.x` bo'lishi kerak).*

### 2) USB Kabel orqali:
- Printerni USB kabel bilan kompyuterga ulang va yoqing.
- Sozlamalarda "Qurilmalarni qidirish" tugmasini bosing.
- Chiqqan ro'yxatdan o'z printeringizni tanlang va "Ulanishni tekshirish" ni bosing.

### 3) Bluetooth orqali:
- Printerni yoqing. Kompyuterning Sozlamalar (Bluetooth) bo'limiga kirib printerni juftlang (pair qiling).
- Zavero Sozlamalarida "Qurilmalarni qidirish" ni bosing va printerni tanlang.

---

## 🛠️ 4. Muammolarni Bartaraf Etish (Troubleshooting)

| Muammo | Sababi | Yechimi |
|---|---|---|
| **"Print agent ishlamayapti"** | Agent yopiq yoki port band | `print-agent/start.bat` (yoki `./start.sh`) ni ishga tushiring. `http://localhost:9101/health` ochilishini tekshiring. |
| **"Ulanish rad etildi / Timeout"** | Printer o'chiq yoki IP xato | Printerni yoqing, tarmoq kabeli/Wi-Fi ulanganligini tekshiring. Printerni o'chirib-yoqib, chekdan haqiqiy IP-sini tekshiring. |
| **"USB printer topilmadi"** | Drayver yoki kabel uzilgan | USB kabelni boshqa portga ulab ko'ring, drayver o'rnatilganligini tekshiring. |
| **"Chek o'rtasida bo'sh joy ko'p"** | Rastr kesish ishlamagan | Zavero Print Agent rasmdagi bo'sh joyni avtomatik qirqadi (bottom trim). Agent yangilanganligiga ishonch hosil qiling. |
| **Loglar qayerda?** | Barcha yozuvlar faylga saqlanadi | `print-agent/logs/agent.log` faylida barcha xatolar va chop etish tarixlari ko'rinadi. |

