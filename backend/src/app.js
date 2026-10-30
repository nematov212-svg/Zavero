const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const authRoutes = require('./routes/authRoutes');
const cafeRoutes = require('./routes/cafeRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const productRoutes = require('./routes/productRoutes');
const hallRoutes = require('./routes/hallRoutes');
const tableRoutes = require('./routes/tableRoutes');
const customerRoutes = require('./routes/customerRoutes');
const receiptRoutes = require('./routes/receiptRoutes');
const customerOrderRoutes = require('./routes/customerOrderRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const reportRoutes = require('./routes/reportRoutes');
const activityRoutes = require('./routes/activityRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const directorRoutes = require('./routes/directorRoutes');
const deviceRoutes = require('./routes/deviceRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const appRoutes = require('./routes/appRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const syncRoutes = require('./routes/syncRoutes');
const subscriptionRoutes = require('./routes/subscriptionRoutes');
const { getBotInstance } = require('./bot/telegramBot');
const { generalApiLimiter } = require('./middleware/rateLimitMiddleware');

const app = express();

app.disable('x-powered-by');

// 🛑 Render Decommission: If running on Render, redirect all traffic to Railway
if (process.env.RENDER) {
  app.use((req, res, next) => {
    if (req.path === '/health' || req.path === '/api/health') {
      return res.status(200).json({ status: 'decommissioned', message: 'Render service has been migrated to Railway' });
    }
    return res.redirect(301, `https://zavero-backend-production-7dc9.up.railway.app${req.originalUrl}`);
  });
}

app.use(
  helmet({
    crossOriginResourcePolicy: false,
    contentSecurityPolicy: false,
    dnsPrefetchControl: { allow: false },
    frameguard: false,
    hidePoweredBy: true,
    hsts: { maxAge: 31536000, includeSubDomains: true },
    ieNoOpen: true,
    noSniff: true,
    referrerPolicy: { policy: 'no-referrer' },
    xssFilter: true,
  })
);

app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));

// ⚡ ULTRA-FAST HEALTH / PING ENDPOINTS (Zero overhead, instant < 1ms response)
app.get(['/health', '/api/health'], (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  return res.status(200).json({ status: 'ok', service: 'zavero-backend', time: Date.now() });
});
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Telegram Bot Webhook endpoint (High-performance handler, bypasses rate limit for Telegram servers)
app.post(['/api/bot/webhook', '/api/v1/telegram/webhook'], (req, res) => {
  const secretHeader = req.headers['x-telegram-bot-api-secret-token'];
  const expectedSecret = process.env.WEBHOOK_SECRET;
  if (expectedSecret && secretHeader && secretHeader !== expectedSecret) {
    console.warn('⚠️ [Telegram Bot] Noto‘g‘ri webhook secret token rad etildi!');
    return res.status(403).json({ success: false, message: 'Forbidden: Invalid secret token' });
  }

  const bot = getBotInstance();
  if (bot && req.body) {
    bot.handleUpdate(req.body).catch((e) => {
      console.warn('⚠️ [Telegram Bot] Webhook update xatoligi:', e.message);
    });
  }
  return res.sendStatus(200);
});

// Apply General Rate Limiter to all other /api endpoints
app.use('/api', generalApiLimiter);

// Serve uploaded product images (cached for 30 days so browser keeps them offline)
app.use(
  '/uploads',
  express.static(path.join(__dirname, '..', 'uploads'), {
    maxAge: '30d',
    immutable: true,
  })
);

// Serve static Flutter POS Web Application (Telegram Mini App, Web, Desktop)
app.use(
  express.static(path.join(__dirname, 'public'), {
    maxAge: '7d',
    etag: true,
    lastModified: true,
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('index.html') || filePath.endsWith('menu.html') || filePath.endsWith('version.json')) {
        res.setHeader('Cache-Control', 'no-cache, must-revalidate');
      } else if (
        filePath.includes('canvaskit') ||
        filePath.includes('assets') ||
        filePath.endsWith('.png') ||
        filePath.endsWith('.jpg') ||
        filePath.endsWith('.woff') ||
        filePath.endsWith('.woff2') ||
        filePath.endsWith('.ttf')
      ) {
        // Og'ir resurslar (CanvasKit 7MB, shriftlar, rasmlar) 30 kunga keshlanadi — qayta yuklashda darhol (0ms) ochiladi
        res.setHeader('Cache-Control', 'public, max-age=2592000, immutable');
      } else {
        // Boshqa JS/CSS fayllar 7 kunga keshlanadi (?v= parametr bilan boshqariladi)
        res.setHeader('Cache-Control', 'public, max-age=604800');
      }
    },
  })
);

// Serve Customer Table QR Menu (Fast, standalone, mobile-optimized HTML menu)
const serveMenuApp = (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, 'public', 'menu.html'));
};

// Serve Full ZAVERO POS App (Flutter Web Application for Staff / Admin / Telegram Mini App)
const servePosApp = (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
};

// 1. Root and POS entrypoints -> ALWAYS Full ZAVERO POS Application
app.get('/', servePosApp);
app.get('/pos', servePosApp);
app.get('/app', servePosApp);
app.get('/dashboard', servePosApp);
app.get('/login', servePosApp);

// 2. Short link for Table QR codes: /m/:cafeId/:tableNumber -> ALWAYS Table QR Menu
app.get('/m/:cafeId/:tableNumber', (req, res) => {
  const { cafeId, tableNumber } = req.params;
  res.redirect(`/menu?cafeId=${encodeURIComponent(cafeId)}&tableNumber=${encodeURIComponent(tableNumber)}`);
});

// 3. /menu route:
// - If tableNumber or table is present -> Customer scanned a table QR code! Open QR Menu!
// - If NO tableNumber or table is present -> User opened from Telegram Bot button! Open ZAVERO POS!
app.get('/menu', (req, res) => {
  const hasTable = req.query.tableNumber || req.query.table_number || req.query.table;
  if (hasTable) {
    return serveMenuApp(req, res);
  }
  return servePosApp(req, res);
});

// Explicit direct QR menu route
app.get('/qr', serveMenuApp);
app.get('/qr-menu', serveMenuApp);



['/api', '/api/v1'].forEach((prefix) => {
  app.use(`${prefix}/auth`, authRoutes);
  app.use(`${prefix}/director`, directorRoutes);
  app.use(`${prefix}/devices`, deviceRoutes);
  app.use(`${prefix}/cafe`, cafeRoutes);
  app.use(`${prefix}/categories`, categoryRoutes);
  app.use(`${prefix}/products`, productRoutes);
  app.use(`${prefix}/halls`, hallRoutes);
  app.use(`${prefix}/tables`, tableRoutes);
  app.use(`${prefix}/reservations`, tableRoutes);
  app.use(`${prefix}/customers`, customerRoutes);
  app.use(`${prefix}/receipts`, receiptRoutes);
  app.use(`${prefix}/customer-orders`, customerOrderRoutes);
  app.use(`${prefix}/employees`, employeeRoutes);
  app.use(`${prefix}/reports`, reportRoutes);
  app.use(`${prefix}/activity`, activityRoutes);
  app.use(`${prefix}/audit-logs`, activityRoutes);
  app.use(`${prefix}/upload`, uploadRoutes);
  app.use(`${prefix}/notifications`, notificationRoutes);
  app.use(`${prefix}/app`, appRoutes);
  app.use(`${prefix}/payments`, paymentRoutes);
  app.use(`${prefix}/sync`, syncRoutes);
  app.use(`${prefix}/subscription`, subscriptionRoutes);
});

// 404 for unhandled API routes
app.use(['/api', '/api/v1'], (req, res) => {
  res.status(404).json({ success: false, message: 'API yo\'nalish topilmadi.' });
});

// Fallback for Flutter Web SPA routes
app.get('*', (req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/uploads')) {
    return servePosApp(req, res);
  }
  res.status(404).json({ success: false, message: 'Yo\'nalish topilmadi.' });
});

// Central error handler - never leak internal stack traces to clients in production
app.use((err, req, res, next) => {
  console.error('[Unhandled Error]', err);
  const status = err.status || 500;
  const message = process.env.NODE_ENV === 'production' && status === 500
    ? 'Serverda xatolik yuz berdi.'
    : (err.message || 'Serverda xatolik.');
  res.status(status).json({ success: false, message });
});

module.exports = app;
