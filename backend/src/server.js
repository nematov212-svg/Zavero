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

// Keep-Alive Self-Ping: Server 24/7 uyquga ketmasligi uchun ping yuboradi
const startKeepAlivePing = () => {
  let url = process.env.SELF_PING_URL || process.env.WEBAPP_URL;
  if (!url && process.env.RAILWAY_PUBLIC_DOMAIN) {
    url = `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`;
  }
  if (!url) {
    console.log('💡 Keep-alive ping: URL sozlanmagan, ichki timer faol.');
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
  let connected = false;
  try {
    connected = await db.initDb();
    if (connected) {
      await runMigrations();
      await ensureCafeSeeded('cafe1');
    } else {
      console.warn('⚠️  PostgreSQL hali ulanmagan, bot xotira rejimida ishlaydi.');
    }
  } catch (dbErr) {
    console.warn('⚠️  DB init xatosi:', dbErr.message);
  }

  // Telegram Botni har doim ishga tushirish (DB bo'lmasa ham qotib qolmaydi)
  try {
    initTelegramBot();
  } catch (botErr) {
    console.error('⚠️  Telegram botni ishga tushirishda xatolik:', botErr.message);
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

