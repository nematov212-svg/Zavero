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
const { generalApiLimiter } = require('./middleware/rateLimitMiddleware');

const app = express();

app.disable('x-powered-by');

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
app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// Apply General Rate Limiter to all /api endpoints
app.use('/api', generalApiLimiter);

// Serve uploaded product images
app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));

// Serve static Flutter POS Web Application (Telegram Mini App, Web, Desktop)
app.use(
  express.static(path.join(__dirname, 'public'), {
    maxAge: '1h',
    setHeaders: (res, filePath) => {
      if (filePath.endsWith('.html')) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
        res.setHeader('Pragma', 'no-cache');
        res.setHeader('Expires', '0');
      }
    },
  })
);

// Serve Full ZAVERO POS App (Root, Telegram WebApp button, Direct links)
const servePosApp = (req, res) => {
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
};

app.get('/', servePosApp);
app.get('/menu', servePosApp);
app.get('/pos', servePosApp);
app.get('/app', servePosApp);

app.get('/m/:cafeId/:tableNumber', (req, res) => {
  servePosApp(req, res);
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'zavero-backend', time: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/director', directorRoutes);
app.use('/api/devices', deviceRoutes);
app.use('/api/cafe', cafeRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/products', productRoutes);
app.use('/api/halls', hallRoutes);
app.use('/api/tables', tableRoutes);
app.use('/api/customers', customerRoutes);
app.use('/api/receipts', receiptRoutes);
app.use('/api/customer-orders', customerOrderRoutes);
app.use('/api/employees', employeeRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/activity', activityRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/app', appRoutes);

// 404 for unhandled API routes
app.use('/api', (req, res) => {
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
