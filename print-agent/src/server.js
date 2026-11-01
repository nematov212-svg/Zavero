require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { PrintQueue, log } = require('./printer/queue');
const { testNetworkConnection, isValidIpv4 } = require('./printer/network');
const { discoverUsbPrinters, testUsbConnection } = require('./printer/usb');
const { discoverBluetoothPrinters, testBluetoothConnection } = require('./printer/bluetooth');

const app = express();
const PORT = process.env.PORT || 9101;
const queue = new PrintQueue();

// ── Private Network Access & CORS Headers ───────────────────────────
// Chrome and modern browsers require Access-Control-Allow-Private-Network
// when a public HTTPS origin (e.g. Railway) talks to a local agent (0.0.0.0 / localhost).
const isAllowedOrigin = (origin) => {
  if (!origin) return true;
  if (
    origin.startsWith('http://localhost:') ||
    origin.startsWith('http://127.0.0.1:') ||
    origin.startsWith('http://0.0.0.0:')
  ) return true;
  if (origin.includes('zavero.uz') || origin.includes('railway.app')) return true;
  return false;
};

app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (isAllowedOrigin(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin || '*');
  }
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, X-Print-Key');
  res.setHeader('Access-Control-Allow-Private-Network', 'true');

  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }
  next();
});

// Authentication middleware for print operations
const checkAuth = (req, res, next) => {
  const secretKey = process.env.PRINT_AGENT_KEY;
  if (!secretKey) return next();
  const provided = req.headers['x-print-key'] || (req.headers['authorization'] || '').replace(/^Bearer\s+/i, '');
  if (provided !== secretKey) {
    return res.status(401).json({ success: false, error: 'Avtorizatsiyadan o‘tilmagan (Invalid Print Key)' });
  }
  next();
};

app.use(express.json({ limit: '25mb' }));
app.use(express.urlencoded({ extended: true, limit: '25mb' }));

// ── 1. GET /health ─────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'zavero-print-agent',
    version: '1.0.0',
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

// ── 2. GET /printers/discover ──────────────────────────────────────
app.get('/printers/discover', checkAuth, async (req, res) => {
  try {
    const [usbPrinters, btPrinters] = await Promise.all([
      discoverUsbPrinters(),
      discoverBluetoothPrinters(),
    ]);

    log(`🔍 Printerlar qidirildi: ${usbPrinters.length} ta USB, ${btPrinters.length} ta Bluetooth topildi`);
    res.json({
      success: true,
      usb: usbPrinters,
      bluetooth: btPrinters,
      network: [
        { id: 'custom_ip', name: 'Wi-Fi / LAN IP manzil orqali', defaultPort: 9100 },
      ],
    });
  } catch (err) {
    log(`❌ Printerlarni qidirishda xato: ${err.message}`, 'ERROR');
    res.status(500).json({ success: false, error: err.message });
  }
});

// ── 3. POST /printer/test-connection ───────────────────────────────
app.post('/printer/test-connection', checkAuth, async (req, res) => {
  try {
    const { type, ip, port, deviceId } = req.body || {};
    const connType = (type || 'wifi').toLowerCase();

    log(`🔌 Ulanish tekshiruvi: tur=${connType}, ip=${ip}, port=${port}, deviceId=${deviceId}`);

    let result;
    if (connType === 'wifi' || connType === 'network' || connType === 'ip') {
      if (ip && ip.startsWith('192.18.')) {
        return res.json({
          ok: false,
          error: `IP manzil "192.18.x.x" kiritilgan. Standart kafe Wi-Fi routerlari "192.168.x.x" bo‘ladi. IP manzilini tekshiring!`,
        });
      }
      result = await testNetworkConnection(ip, parseInt(port || 9100, 10));
    } else if (connType === 'usb') {
      result = await testUsbConnection(deviceId);
    } else if (connType === 'bluetooth' || connType === 'bt') {
      result = await testBluetoothConnection(deviceId);
    } else {
      return res.status(400).json({
        ok: false,
        error: `Noma‘lum ulanish turi: "${connType}". "wifi", "usb", yoki "bluetooth" bo‘lishi kerak.`,
      });
    }

    log(`🔌 Tekshiruv natijasi: ok=${result.ok}, info=${result.statusText || result.error}`);
    return res.json(result);
  } catch (err) {
    log(`❌ Tekshirishda kutilmagan xatolik: ${err.message}`, 'ERROR');
    return res.status(500).json({ ok: false, error: err.message });
  }
});

// ── 4. POST /print ─────────────────────────────────────────────────
app.post('/print', checkAuth, async (req, res) => {
  try {
    const payload = req.body || {};
    const result = await queue.addJob(payload);
    return res.json(result);
  } catch (err) {
    log(`❌ Chop etish xatosi: ${err.message}`, 'ERROR');
    return res.status(500).json({ success: false, error: err.message });
  }
});

// ── 5. GET /jobs/:id ───────────────────────────────────────────────
app.get('/jobs/:id', (req, res) => {
  const job = queue.getJob(req.params.id);
  if (!job) {
    return res.status(404).json({ success: false, error: 'Ish topilmadi' });
  }
  return res.json({ success: true, job });
});

// ── Background Cloud Polling Bridge (Waiters -> Local Printer) ─────
let cloudPollingInterval = null;
let currentCafeId = process.env.CAFE_ID || '';
let currentBackendUrl = (process.env.BACKEND_URL || 'https://zavero-backend-production-7dc9.up.railway.app').replace(/\/+$/, '');
let currentCafePrinterConfig = null;

app.post('/config', (req, res) => {
  const { cafeId, backendUrl, printerConfig } = req.body || {};
  if (cafeId) currentCafeId = cafeId;
  if (backendUrl) currentBackendUrl = backendUrl.replace(/\/+$/, '');
  if (printerConfig) currentCafePrinterConfig = printerConfig;
  log(`⚙️ Agent konfiguratsiyasi yangilandi: cafeId=${currentCafeId}, backendUrl=${currentBackendUrl}`);
  startCloudPollingIfNeeded();
  res.json({ success: true, cafeId: currentCafeId, backendUrl: currentBackendUrl });
});

function startCloudPollingIfNeeded() {
  if (cloudPollingInterval) clearInterval(cloudPollingInterval);
  if (!currentCafeId) return;

  log(`☁️ Cloud Polling ishga tushdi: har 2 soniyada ofitsiant cheklari tekshiriladi (Kafe: ${currentCafeId})`);
  cloudPollingInterval = setInterval(async () => {
    try {
      const url = `${currentBackendUrl}/api/receipts/pending-jobs?cafeId=${encodeURIComponent(currentCafeId)}`;
      const resp = await fetch(url, { headers: { 'Accept': 'application/json' }, signal: AbortSignal.timeout(3000) });
      if (!resp.ok) return;
      const data = await resp.json();
      const jobs = data.jobs || [];

      for (const j of jobs) {
        log(`📥 Yangi masofaviy chek olindi: ${j.id} (${j.type || 'receipt'})`);
        const printResult = await queue.addJob({
          jobId: j.id,
          type: j.type,
          printerConfig: j.printerConfig || currentCafePrinterConfig,
          image: j.image || j.image_base64,
          rawBytes: j.rawBytes,
          openDrawer: j.type === 'receipt',
        });

        const statusEndpoint = `${currentBackendUrl}/api/receipts/print-jobs/${encodeURIComponent(j.id)}/${printResult.success ? 'complete' : 'fail'}`;
        await fetch(statusEndpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ error: printResult.error, cafeId: currentCafeId }),
          signal: AbortSignal.timeout(3000),
        }).catch(() => {});
      }
    } catch (_) {}
  }, 2000);
}

// Start HTTP Server
const server = app.listen(PORT, '0.0.0.0', () => {
  log(`=======================================================`);
  log(`🚀 ZAVERO PRINT AGENT ISHGA TUSHDI!`);
  log(`📡 Manzil: http://localhost:${PORT} (va http://0.0.0.0:${PORT})`);
  log(`🖨️ Wi-Fi, USB va Bluetooth printerlarni qo‘llab-quvvatlaydi`);
  log(`=======================================================`);
  startCloudPollingIfNeeded();
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    log(`⚠️ Port ${PORT} band, agent allaqachon ishlayapti bo‘lishi mumkin.`, 'WARN');
  } else {
    log(`❌ Server xatosi: ${err.message}`, 'ERROR');
  }
});

