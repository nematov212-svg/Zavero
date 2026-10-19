const http = require('http');
const https = require('https');
const { Server } = require('socket.io');
require('dotenv').config();

const app = require('./app');
const db = require('./config/db');
const { initSocket } = require('./socket/socketHandler');
const { runMigrations } = require('./migrations/migrate');
const { ensureCafeSeeded } = require('./utils/seedCafe');
const { initTelegramBot } = require('./bot/telegramBot');

const PORT = process.env.PORT || 3000;

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: process.env.CORS_ORIGIN || '*' },
});
initSocket(io);

// Keep-Alive Self-Ping: Render kabi bepul serverlar 15 daqiqada uyquga ketmasligi uchun har 10 minutda ping yuboradi
const startKeepAlivePing = () => {
  const url = process.env.RENDER_EXTERNAL_URL || process.env.SELF_PING_URL;
  if (!url) {
    console.log('💡 Keep-alive ping: RENDER_EXTERNAL_URL sozlanmagan, ichki timer faol.');
    return;
  }

  const pingUrl = url.endsWith('/') ? `${url}health` : `${url}/health`;
  const httpModule = pingUrl.startsWith('https') ? https : http;

  setInterval(() => {
    httpModule.get(pingUrl, (res) => {
      console.log(`⏱️ Keep-alive ping muvaffaqiyatli yuborildi (${pingUrl}) - Status: ${res.statusCode}`);
    }).on('error', (err) => {
      console.warn('⚠️ Keep-alive ping xatosi:', err.message);
    });
  }, 10 * 60 * 1000);
};

const start = async () => {
  const connected = await db.initDb();
  if (connected) {
    await runMigrations();
    await ensureCafeSeeded('cafe1');
    initTelegramBot();
  } else {
    console.warn('⚠️  Server ishga tushmoqda, lekin PostgreSQL ulanmagan. .env faylini tekshiring.');
  }

  server.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 ZAVERO SaaS backend ${PORT}-portda ishga tushdi (0.0.0.0:${PORT})`);
    console.log(`🔌 Socket.IO real-time sinxronizatsiya faol.`);
    startKeepAlivePing();
  });
};

process.on('uncaughtException', (err) => {
  console.error('💥 [Uncaught Exception]', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('💥 [Unhandled Rejection]', reason);
});

start();

