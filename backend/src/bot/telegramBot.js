/**
 * ZAVERO POS — Telegram Hisobot va Boshqaruv Boti
 * 
 * Rolli arxitektura:
 * 1. CAFE: O'z kafesining cheklari va hisobotlarini ko'radi
 * 2. DIRECTOR: Barcha kafelarni nazorat qiladi (Online/Offline vaqtlari, jonli yangilanish)
 * 
 * Login-parol YAGONA MANBA: Ma'lumotlar to'g'ridan-to'g'ri 'users' va 'cafes' jadvallaridan tekshiriladi.
 */

const { Telegraf, Markup } = require('telegraf');
const bcrypt = require('bcryptjs');
const db = require('../config/db');

let bot = null;

// ============================================================
// IN-MEMORY TRACKERS (State, Brute Force, Live Refresh, Dedup)
// ============================================================

// User conversational states: chatId -> { state, pendingUser, failedAttempts, lockedUntil }
const userStates = new Map();

// Active live refresh timers for Director "Cafelar" section: chatId -> { messageId, timer, startedAt }
const activeLiveRefreshes = new Map();

// Sent receipts deduplication set: receiptId -> timestamp
const sentReceiptsCache = new Set();

// Clean up cache periodically
setInterval(() => {
  if (sentReceiptsCache.size > 2000) {
    sentReceiptsCache.clear();
  }
}, 60 * 60 * 1000);

// ============================================================
// HELPER FUNCTIONS
// ============================================================

const formatSum = (amount) => {
  return Number(amount || 0).toLocaleString('uz-UZ').replace(/\u00A0/g, ' ').replace(/,/g, ' ');
};

const formatDate = (date) => {
  try {
    return new Date(date || Date.now()).toLocaleString('uz-UZ', {
      timeZone: 'Asia/Tashkent',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  } catch (e) {
    return String(date);
  }
};

/**
 * Format duration into Uzbek: "2 soat 14 daq 05 s" or "12 daq 40 s"
 */



const formatDuration = (diffMs) => {
  if (!diffMs || diffMs < 0) diffMs = 0;
  const totalSeconds = Math.floor(diffMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;

  const pad = (n) => String(n).padStart(2, '0');

  if (hours > 0) {
    return `${hours} soat ${pad(minutes)} daq ${pad(seconds)} s`;
  }
  return `${minutes} daq ${pad(seconds)} s`;
};

/**
 * Mask phone number for security in logs and UI: "+998901234567" -> "+***4567"
 */
const maskPhone = (phone) => {
  if (!phone) return 'mavjud emas';
  const str = String(phone).trim();
  if (str.length <= 4) return '****';
  return `+***${str.slice(-4)}`;
};

const getBaseWebAppUrl = () => {
  let url = process.env.ZAVERO_MINI_APP_URL || process.env.WEBAPP_URL || process.env.APP_URL;
  if (!url && process.env.RAILWAY_PUBLIC_DOMAIN) {
    url = `https://${process.env.RAILWAY_PUBLIC_DOMAIN}`;
  }
  url = url || 'https://zavero-backend-production-7dc9.up.railway.app';
  return url.endsWith('/') ? url.slice(0, -1) : url;
};

const getWebAppUrl = (role, cafeId) => {
  const base = getBaseWebAppUrl();
  const v = process.env.APP_VERSION || 'v=20261107';
  if (role === 'director') {
    return `${base}/?role=director&${v}`;
  }
  return `${base}/?role=cafe_report&cafeId=${encodeURIComponent(cafeId || '')}&${v}`;
};

// ============================================================
// DATABASE SESSION MANAGEMENT (Single Source of Truth)
// ============================================================

const getSession = async (chatId) => {
  try {
    const res = await db.query(
      `SELECT ts.*, u.username, u.role AS user_role, u.is_active, c.cafe_name, c.status AS cafe_status 
       FROM telegram_sessions ts
       JOIN users u ON ts.user_id = u.id
       LEFT JOIN cafes c ON ts.cafe_id = c.cafe_id
       WHERE ts.chat_id = $1`,
      [String(chatId)]
    );
    if (res.rows.length === 0) return null;
    const session = res.rows[0];
    if (session.is_active === false) {
      await deleteSession(chatId);
      return null;
    }
    if (session.role === 'cafe' && session.cafe_status === 'blocked') {
      await deleteSession(chatId);
      return null;
    }
    return session;
  } catch (err) {
    console.error('getSession error:', err.message);
    return null;
  }
};

const createSession = async (chatId, userId, role, cafeId) => {
  await db.query(
    `INSERT INTO telegram_sessions (chat_id, user_id, role, cafe_id, created_at, updated_at)
     VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
     ON CONFLICT (chat_id) DO UPDATE SET
       user_id = EXCLUDED.user_id,
       role = EXCLUDED.role,
       cafe_id = EXCLUDED.cafe_id,
       updated_at = CURRENT_TIMESTAMP`,
    [String(chatId), userId, role, cafeId]
  );
};

const deleteSession = async (chatId) => {
  try {
    await db.query(`DELETE FROM telegram_sessions WHERE chat_id = $1`, [String(chatId)]);
  } catch (err) {
    console.error('deleteSession error:', err.message);
  }
};

const updateSessionPhone = async (chatId, phone) => {
  try {
    await db.query(
      `UPDATE telegram_sessions SET phone = $1, updated_at = CURRENT_TIMESTAMP WHERE chat_id = $2`,
      [phone, String(chatId)]
    );
  } catch (err) {
    console.error('updateSessionPhone error:', err.message);
  }
};

const deleteSessionPhone = async (chatId) => {
  try {
    await db.query(
      `UPDATE telegram_sessions SET phone = NULL, updated_at = CURRENT_TIMESTAMP WHERE chat_id = $1`,
      [String(chatId)]
    );
  } catch (err) {
    console.error('deleteSessionPhone error:', err.message);
  }
};

const saveTelegramUserPhone = async (telegramId, phone, cafeId, username) => {
  try {
    await db.query(
      `INSERT INTO telegram_users (telegram_id, phone, cafe_id, username, updated_at)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
       ON CONFLICT (telegram_id) DO UPDATE SET
         phone = EXCLUDED.phone,
         cafe_id = EXCLUDED.cafe_id,
         username = COALESCE(EXCLUDED.username, telegram_users.username),
         updated_at = CURRENT_TIMESTAMP`,
      [telegramId, phone, cafeId, username || null]
    );
  } catch (_) {
    // telegram_users is optional, ignore if absent
  }
};

// ============================================================
// BRUTE-FORCE LOCKOUT PROTECTION
// ============================================================

const checkLockout = (chatId) => {
  const st = userStates.get(String(chatId));
  if (st && st.lockedUntil && st.lockedUntil > Date.now()) {
    const remSeconds = Math.ceil((st.lockedUntil - Date.now()) / 1000);
    const mins = Math.ceil(remSeconds / 60);
    return { locked: true, mins };
  }
  return { locked: false, mins: 0 };
};

const recordFailedPasswordAttempt = (chatId) => {
  const strId = String(chatId);
  const current = userStates.get(strId) || { state: 'AWAITING_PASSWORD', failedAttempts: 0 };
  const attempts = (current.failedAttempts || 0) + 1;
  const isLock = attempts >= 5;
  const lockedUntil = isLock ? Date.now() + 5 * 60 * 1000 : null;

  userStates.set(strId, {
    ...current,
    failedAttempts: attempts,
    lockedUntil,
  });

  return { attempts, isLock, remaining: Math.max(0, 5 - attempts) };
};

const resetLockout = (chatId) => {
  const strId = String(chatId);
  const current = userStates.get(strId);
  if (current) {
    current.failedAttempts = 0;
    current.lockedUntil = null;
    userStates.set(strId, current);
  }
};

// ============================================================
// ROLE-BASED KEYBOARDS
// ============================================================

const getCafeKeyboard = (cafeId) => {
  return Markup.keyboard([
    ['📊 Bugungi hisobot', '🧾 Bugungi cheklar'],
    ['💰 Jami daromad', '📅 Kecha / oxirgi kunlar'],
    ['🔄 Yangilash', '📱 Nomerim'],
    ['🚪 Chiqish'],
  ]).resize();
};

const getDirectorKeyboard = () => {
  return Markup.keyboard([
    ['🏢 Cafelar', '📊 Umumiy hisobot'],
    ['🔄 Yangilash', '📱 Nomerim'],
    ['🚪 Chiqish'],
  ]).resize();
};

// ============================================================
// LIVE DIRECTOR CAFELAR RENDERER
// ============================================================

const buildCafesListContent = async () => {
  const res = await db.query(
    `SELECT cafe_id, cafe_name, receipt_name, status, last_seen, online_since, created_at 
     FROM cafes 
     WHERE cafe_id != 'zavero'
     ORDER BY created_at ASC`
  );

  const cafes = res.rows;
  const now = Date.now();
  let onlineCount = 0;
  let offlineCount = 0;

  const cafeLines = [];
  const inlineButtons = [];

  for (let i = 0; i < cafes.length; i++) {
    const c = cafes[i];
    const name = c.receipt_name || c.cafe_name || `Cafe ${c.cafe_id}`;
    const lastSeenTime = c.last_seen ? new Date(c.last_seen).getTime() : 0;
    const isOnline = lastSeenTime > 0 && (now - lastSeenTime <= 60000); // 60 soniya

    let statusText = '';
    if (isOnline) {
      onlineCount++;
      const onlineSince = c.online_since ? new Date(c.online_since).getTime() : lastSeenTime;
      const durationStr = formatDuration(now - onlineSince);
      statusText = `🟢 Online: ${durationStr}`;
    } else {
      offlineCount++;
      if (lastSeenTime > 0) {
        const durationStr = formatDuration(now - lastSeenTime);
        statusText = `🔴 Offline: oxirgi faollik ${durationStr} oldin`;
      } else {
        statusText = '🔴 Offline: faollik qayd etilmagan';
      }
    }

    cafeLines.push(`${i + 1}. <b>${name}</b>, ${statusText}`);
    inlineButtons.push([Markup.button.callback(`📊 ${name}`, `view_cafe_${c.cafe_id}`)]);
  }

  inlineButtons.push([
    Markup.button.callback('🔄 Yangilash', 'director_refresh_cafes'),
    Markup.button.callback('🔙 Orqaga', 'director_back_cafes'),
  ]);

  const summaryHeader = `🏢 <b>CAFELAR MONITORINGI</b>\nJami: <b>${cafes.length} ta</b> | 🟢 Online: <b>${onlineCount} ta</b> | 🔴 Offline: <b>${offlineCount} ta</b>\n━━━━━━━━━━━━━━━━━━━━\n`;
  const body = cafeLines.length > 0 ? cafeLines.join('\n') : '<i>Hozirda ro‘yxatdan o‘tgan kafelar mavjud emas.</i>';
  const footer = `\n━━━━━━━━━━━━━━━━━━━━\n⏱ <i>Har 5 soniyada jonli yangilanadi</i>`;

  return {
    text: summaryHeader + body + footer,
    markup: Markup.inlineKeyboard(inlineButtons),
  };
};

const clearLiveRefresh = (chatId) => {
  const strId = String(chatId);
  const active = activeLiveRefreshes.get(strId);
  if (active && active.timer) {
    clearInterval(active.timer);
    activeLiveRefreshes.delete(strId);
  }
};

const startLiveRefresh = (chatId, messageId) => {
  const strId = String(chatId);
  clearLiveRefresh(strId);

  const startedAt = Date.now();
  const timer = setInterval(async () => {
    // Stop after 5 minutes (300 seconds)
    if (Date.now() - startedAt >= 5 * 60 * 1000) {
      clearLiveRefresh(strId);
      return;
    }

    try {
      if (!bot || !bot.telegram) {
        clearLiveRefresh(strId);
        return;
      }
      const { text, markup } = await buildCafesListContent();
      await bot.telegram.editMessageText(strId, messageId, null, text, {
        parse_mode: 'HTML',
        ...markup,
      });
    } catch (err) {
      const msg = err.message || '';
      if (msg.includes('message is not modified')) {
        // Normal Telegram behavior when text hasn't changed
        return;
      }
      // If message was deleted or chat blocked, stop timer
      clearLiveRefresh(strId);
    }
  }, 5000); // Har 5 soniyada Telegram limitiga mos yangilash

  activeLiveRefreshes.set(strId, { messageId, timer, startedAt });
};

// ============================================================
// DAILY REPORT CRON JOB (24:00 / 00:00:00 Asia/Tashkent)
// ============================================================

/**
 * Aniq Toshkent vaqti va sanasini xatosiz olish (Asia/Tashkent, UTC+5)
 */
const getTashkentNow = (date = new Date()) => {
  const formatter = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Tashkent',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  });
  const parts = formatter.formatToParts(date);
  const map = {};
  for (const p of parts) map[p.type] = p.value;
  return {
    year: map.year,
    month: map.month,
    day: map.day,
    hour: parseInt(map.hour, 10),
    minute: parseInt(map.minute, 10),
    second: parseInt(map.second, 10),
    dateStr: `${map.year}-${map.month}-${map.day}`,
    timeStr: `${map.hour}:${map.minute}:${map.second}`,
    fullStr: `${map.year}-${map.month}-${map.day} ${map.hour}:${map.minute}:${map.second}`,
  };
};

/**
 * Kunlik hisobot xabari shabloni (HTML formatda, chiroyli va o'qilishi oson)
 */
const buildDailyReportMessage = ({
  cafeName,
  closedDate,
  timestamp,
  dailyRevenue,
  dailyCount,
  dailyCash,
  dailyCard,
  allTimeRevenue,
  allTimeCount,
  isTest = false,
}) => {
  const header = isTest
    ? `🧪 <b>KUNLIK HISOBOT (TEST / SINOV)</b>`
    : `🌙 <b>KUNLIK YAKUNIY HISOBOT (KUN YOPILDI)</b>`;

  return `${header}\n` +
    `🏪 Cafe: <b>${cafeName || 'Cafe'}</b>\n` +
    `📅 Yopilgan kun: <b>${closedDate}</b>\n` +
    `⏱ Hisobot vaqti: <b>${timestamp}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `💰 <b>Bugungi daromad:</b> <b>${formatSum(dailyRevenue)} so'm</b>\n` +
    `🧾 <b>Bugungi cheklar soni:</b> <b>${dailyCount} ta</b>\n` +
    `   ├ 💵 Naqd savdo: <b>${formatSum(dailyCash)} so'm</b>\n` +
    `   └ 💳 Karta savdo: <b>${formatSum(dailyCard)} so'm</b>\n` +
    `────────────────────\n` +
    `🌐 <b>Jami daromad (umumiy):</b> <b>${formatSum(allTimeRevenue)} so'm</b>\n` +
    `📑 <b>Jami cheklar soni:</b> <b>${allTimeCount} ta</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `<i>ZAVERO POS tizimi • Avtomatik hisobot</i>`;
};

// Dublikat hisobot yuborilishining oldini olish (Memory + DB bot_settings)
const sentReportsMemoryCache = new Set();

const isReportAlreadySent = async (cafeId, dateStr) => {
  const key = `daily_report_${cafeId}_${dateStr}`;
  if (sentReportsMemoryCache.has(key)) return true;
  try {
    const res = await db.query('SELECT value FROM bot_settings WHERE key = $1', [key]);
    if (res.rows.length > 0) {
      sentReportsMemoryCache.add(key);
      return true;
    }
  } catch (err) {
    console.error('isReportAlreadySent check error:', err.message);
  }
  return false;
};

const markReportAsSent = async (cafeId, dateStr) => {
  const key = `daily_report_${cafeId}_${dateStr}`;
  sentReportsMemoryCache.add(key);
  try {
    await db.query(
      `INSERT INTO bot_settings (key, value, updated_at)
       VALUES ($1, $2, CURRENT_TIMESTAMP)
       ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP`,
      [key, new Date().toISOString()]
    );
  } catch (err) {
    console.error('markReportAsSent error:', err.message);
  }
};

/**
 * Sanani Asia/Tashkent bo'yicha YYYY-MM-DD ko'rinishida olish
 */
const toTashkentDateString = (date = new Date()) => {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Tashkent',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
};

/**
 * Bugungi hisobot ostidagi qulay inline tugmalar
 */
const getTodayReportInlineMarkup = () => {
  return Markup.inlineKeyboard([
    [
      Markup.button.callback('🔄 Yangilash', 'action_refresh_today'),
      Markup.button.callback('🧾 Bugungi cheklar', 'action_view_receipts'),
    ],
    [
      Markup.button.callback('💰 Jami daromad', 'action_view_all_time'),
      Markup.button.callback('📅 Kecha / oxirgi kunlar', 'action_view_recent_days'),
    ]
  ]);
};

/**
 * 1. Bugungi jonli hisobot matnini generatsiya qilish (real-vaqt, soniyagacha)
 */
const generateTodayReportMessage = async (cafeId, cafeName) => {
  const tk = getTashkentNow();
  const todayStr = tk.dateStr;

  const statsRes = await db.query(
    `SELECT 
       COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN total ELSE 0 END), 0) AS daily_revenue,
       COALESCE(COUNT(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN 1 ELSE NULL END), 0) AS daily_count,
       COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'cash' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN cash_paid ELSE 0 END) END), 0) AS daily_cash,
       COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'card' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN card_paid ELSE 0 END) END), 0) AS daily_card,
       COALESCE(SUM(total), 0) AS all_time_revenue,
       COUNT(*) AS all_time_count
     FROM receipts 
     WHERE cafe_id = $1`,
    [cafeId, todayStr]
  );
  const stats = statsRes.rows[0] || {};

  return `📊 <b>BUGUNGI HISOBOT (JONLI)</b>\n` +
    `🏪 Cafe: <b>${cafeName || 'Cafe'}</b>\n` +
    `📅 Sana: <b>${todayStr}</b>\n` +
    `⏱ Hozirgi vaqt: <b>${tk.fullStr}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `💰 <b>Bugungi daromad:</b> <b>${formatSum(stats.daily_revenue)} so'm</b>\n` +
    `🧾 <b>Bugungi cheklar soni:</b> <b>${stats.daily_count || 0} ta</b>\n` +
    `   ├ 💵 Naqd savdo: <b>${formatSum(stats.daily_cash)} so'm</b>\n` +
    `   └ 💳 Karta savdo: <b>${formatSum(stats.daily_card)} so'm</b>\n` +
    `────────────────────\n` +
    `🌐 <b>Jami daromad (umumiy):</b> <b>${formatSum(stats.all_time_revenue)} so'm</b>\n` +
    `📑 <b>Jami cheklar soni:</b> <b>${stats.all_time_count || 0} ta</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `<i>ZAVERO POS tizimi • Real-vaqt ko‘rsatkichi</i>`;
};

/**
 * 2. So'nggi yopilgan cheklar ro'yxati matnini generatsiya qilish
 */
const generateRecentReceiptsMessage = async (cafeId, cafeName) => {
  const tk = getTashkentNow();
  const todayStr = tk.dateStr;

  let recRes = await db.query(
    `SELECT id, total, method, table_number, hall_name, date, cashier_name 
     FROM receipts 
     WHERE cafe_id = $1 AND to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2
     ORDER BY date DESC LIMIT 15`,
    [cafeId, todayStr]
  );

  let isToday = true;
  if (recRes.rows.length === 0) {
    recRes = await db.query(
      `SELECT id, total, method, table_number, hall_name, date, cashier_name 
       FROM receipts 
       WHERE cafe_id = $1 
       ORDER BY date DESC LIMIT 10`,
      [cafeId]
    );
    isToday = false;
  }

  if (recRes.rows.length === 0) {
    return `🧾 <b>CHEKLAR RO‘YXATI (${cafeName || 'Cafe'})</b>\n\n` +
      `<i>Hozircha yopilgan cheklar mavjud emas.</i>`;
  }

  const titleHeader = isToday
    ? `🧾 <b>BUGUNGI SO‘NGGI CHEKLAR (${cafeName || 'Cafe'})</b>`
    : `🧾 <b>SO‘NGGI YOPILGAN CHEKLAR (${cafeName || 'Cafe'})</b>\n<i>(Bugun hali chek urilmagan, oxirgi kungi cheklar ko‘rsatilmoqda)</i>`;

  let msg = `${titleHeader}\n⏱ Vaqt: <b>${tk.fullStr}</b>\n━━━━━━━━━━━━━━━━━━━━\n`;
  for (const r of recRes.rows) {
    const time = new Date(r.date).toLocaleTimeString('uz-UZ', { timeZone: 'Asia/Tashkent', hour: '2-digit', minute: '2-digit' });
    const datePart = toTashkentDateString(new Date(r.date));
    const table = r.table_number ? (r.hall_name ? `${r.hall_name}, ${r.table_number}-stol` : `${r.table_number}-stol`) : (r.hall_name || 'Stol');
    const method = (r.method === 'card' || r.payment_method === 'card') ? '💳 Karta' : '💵 Naqd';
    const cashier = r.cashier_name ? ` | 👤 ${r.cashier_name}` : '';
    msg += `• Chek #${r.id} | ${datePart} ${time} | ${table}${cashier}\n  💰 Summa: <b>${formatSum(r.total)} so'm</b> (${method})\n`;
  }
  msg += `━━━━━━━━━━━━━━━━━━━━\n<i>ZAVERO POS tizimi</i>`;
  return msg;
};

/**
 * 3. Umumiy (All-Time) daromad va statistika matnini generatsiya qilish
 */
const generateAllTimeRevenueMessage = async (cafeId, cafeName) => {
  const tk = getTashkentNow();

  const res = await db.query(
    `SELECT 
       COALESCE(SUM(total), 0) AS all_time_revenue,
       COUNT(*) AS all_time_count,
       COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE cash_paid END), 0) AS all_time_cash,
       COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE card_paid END), 0) AS all_time_card,
       COALESCE(ROUND(AVG(total)), 0) AS all_time_avg,
       MIN(date AT TIME ZONE 'Asia/Tashkent') AS first_date,
       MAX(date AT TIME ZONE 'Asia/Tashkent') AS last_date
     FROM receipts
     WHERE cafe_id = $1`,
    [cafeId]
  );

  const stats = res.rows[0] || {};
  const firstDateStr = stats.first_date ? toTashkentDateString(new Date(stats.first_date)) : 'Noma\'lum';
  const lastDateStr = stats.last_date ? toTashkentDateString(new Date(stats.last_date)) : 'Noma\'lum';

  return `💰 <b>UMUMIY JAMI DAROMAD (ALL-TIME)</b>\n` +
    `🏪 Cafe: <b>${cafeName || 'Cafe'}</b>\n` +
    `⏱ Hozirgi vaqt: <b>${tk.fullStr}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `🌐 <b>Jami daromad:</b> <b>${formatSum(stats.all_time_revenue)} so'm</b>\n` +
    `📑 <b>Jami cheklar soni:</b> <b>${stats.all_time_count || 0} ta</b>\n` +
    `📊 <b>O‘rtacha chek:</b> <b>${formatSum(stats.all_time_avg)} so'm</b>\n` +
    `────────────────────\n` +
    `💵 <b>Jami naqd savdo:</b> <b>${formatSum(stats.all_time_cash)} so'm</b>\n` +
    `💳 <b>Jami karta savdo:</b> <b>${formatSum(stats.all_time_card)} so'm</b>\n` +
    `────────────────────\n` +
    `🗓 Ilk chek sanasi: <b>${firstDateStr}</b>\n` +
    `🕒 So‘nggi chek sanasi: <b>${lastDateStr}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `<i>ZAVERO POS tizimi</i>`;
};

/**
 * 4. Kecha va oxirgi kunlar hisoboti matnini generatsiya qilish
 */
const generateRecentDaysReportMessage = async (cafeId, cafeName) => {
  const tk = getTashkentNow();

  const res = await db.query(
    `SELECT 
       to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') AS day_str,
       COUNT(*) AS day_count,
       COALESCE(SUM(total), 0) AS day_revenue,
       COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE cash_paid END), 0) AS day_cash,
       COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE card_paid END), 0) AS day_card
     FROM receipts
     WHERE cafe_id = $1
     GROUP BY day_str
     ORDER BY day_str DESC
     LIMIT 7`,
    [cafeId]
  );

  const days = res.rows;
  if (days.length === 0) {
    return `📅 <b>KUNLIK HISOBOTLAR TARIXI</b>\n\n` +
      `🏪 Cafe: <b>${cafeName || 'Cafe'}</b>\n\n` +
      `<i>Hozircha oldingi kunlar bo‘yicha cheklar mavjud emas.</i>`;
  }

  const yesterdayObj = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const yesterdayStr = getTashkentNow(yesterdayObj).dateStr;
  const yesterdayData = days.find(d => d.day_str === yesterdayStr) || (days[0].day_str !== tk.dateStr ? days[0] : days[1]);

  let msg = `📅 <b>KECHA VA OXIRGI KUNLAR HISOBOTI</b>\n` +
    `🏪 Cafe: <b>${cafeName || 'Cafe'}</b>\n` +
    `⏱ Hozirgi vaqt: <b>${tk.fullStr}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n`;

  if (yesterdayData) {
    msg += `🌙 <b>KECHAGI KUN (${yesterdayData.day_str}):</b>\n` +
      `💰 Daromad: <b>${formatSum(yesterdayData.day_revenue)} so'm</b>\n` +
      `🧾 Cheklar soni: <b>${yesterdayData.day_count} ta</b>\n` +
      `   ├ 💵 Naqd: ${formatSum(yesterdayData.day_cash)} so'm\n` +
      `   └ 💳 Karta: ${formatSum(yesterdayData.day_card)} so'm\n` +
      `────────────────────\n`;
  }

  msg += `📊 <b>OXIRGI 7 KUN KO‘RSATKICHLARI:</b>\n`;
  let total7Revenue = 0;
  let total7Count = 0;

  for (const d of days) {
    total7Revenue += Number(d.day_revenue);
    total7Count += Number(d.day_count);
    const dayLabel = d.day_str === tk.dateStr ? 'Bugun' : (d.day_str === yesterdayStr ? 'Kecha' : d.day_str);
    msg += `• <b>${dayLabel} (${d.day_str})</b>: <b>${formatSum(d.day_revenue)} so'm</b> (${d.day_count} ta chek)\n`;
  }

  msg += `────────────────────\n` +
    `📈 <b>Oxirgi kunlar jami:</b> <b>${formatSum(total7Revenue)} so'm</b> (${total7Count} ta chek)\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `<i>ZAVERO POS tizimi</i>`;

  return msg;
};

/**
 * 5. Director uchun barcha cafelar umumiy hisoboti
 */
const generateDirectorSummaryMessage = async () => {
  const tk = getTashkentNow();
  const todayStr = tk.dateStr;

  const summaryRes = await db.query(
    `SELECT 
       COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $1 THEN total ELSE 0 END), 0) AS today_revenue,
       COALESCE(COUNT(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $1 THEN 1 ELSE NULL END), 0) AS today_count,
       COALESCE(SUM(total), 0) AS all_time_revenue,
       COUNT(*) AS all_time_count
     FROM receipts`
    , [todayStr]
  );
  const s = summaryRes.rows[0] || {};

  const cafeStatsRes = await db.query(
    `SELECT 
       c.cafe_id, 
       COALESCE(c.receipt_name, c.cafe_name, 'Cafe') AS name,
       COALESCE(SUM(CASE WHEN to_char(r.date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $1 THEN r.total ELSE 0 END), 0) AS today_rev,
       COALESCE(COUNT(CASE WHEN to_char(r.date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $1 THEN 1 ELSE NULL END), 0) AS today_cnt,
       COALESCE(SUM(r.total), 0) AS all_time_rev
     FROM cafes c
     LEFT JOIN receipts r ON c.cafe_id = r.cafe_id
     WHERE c.status = 'active' AND c.cafe_id != 'zavero'
     GROUP BY c.cafe_id, c.receipt_name, c.cafe_name
     ORDER BY today_rev DESC`,
    [todayStr]
  );

  let msg = `👑 <b>ZAVERO DIRECTOR — UMUMIY TARMOQ HISOBOTI</b>\n` +
    `📅 Sana: <b>${todayStr}</b>\n` +
    `⏱ Hozirgi vaqt: <b>${tk.fullStr}</b>\n` +
    `━━━━━━━━━━━━━━━━━━━━\n` +
    `💰 <b>Bugungi umumiy savdo:</b> <b>${formatSum(s.today_revenue)} so'm</b>\n` +
    `🧾 <b>Bugungi jami cheklar:</b> <b>${s.today_count || 0} ta</b>\n` +
    `🌐 <b>Tarmoq jami aylanmasi:</b> <b>${formatSum(s.all_time_revenue)} so'm</b>\n` +
    `📑 <b>Jami cheklar soni:</b> <b>${s.all_time_count || 0} ta</b>\n` +
    `────────────────────\n` +
    `🏢 <b>CAFELAR BO‘YICHA BUGUN:</b>\n`;

  for (const c of cafeStatsRes.rows) {
    msg += `• <b>${c.name}</b>: <b>${formatSum(c.today_rev)} so'm</b> (${c.today_cnt} ta chek) | Jami: ${formatSum(c.all_time_rev)} so'm\n`;
  }
  msg += `━━━━━━━━━━━━━━━━━━━━\n<i>ZAVERO Central Director Paneli</i>`;
  return msg;
};

/**
 * Bitta cafe uchun kunlik yopilish hisobotini yuborish (Strict Multi-Tenant)
 */
const sendDailyReportForCafe = async ({
  cafeId,
  cafeName,
  closedDateStr,
  timestampStr,
  isTest = false,
  ignoreDedupe = false,
  specificChatId = null,
}) => {
  try {
    if (!bot || !bot.telegram) {
      console.warn('⚠️ [Telegram Bot] sendDailyReportForCafe: bot obyekti mavjud emas');
      return { success: false, error: 'bot_not_initialized' };
    }

    // 1. Dublikat tekshiruvi (Test bo'lmasa)
    if (!ignoreDedupe) {
      const alreadySent = await isReportAlreadySent(cafeId, closedDateStr);
      if (alreadySent) {
        console.log(`ℹ️ [Daily Report] ${cafeName || cafeId} (${closedDateStr}) allaqachon yuborilgan, o‘tkazib yuborildi.`);
        return { success: true, skipped: true };
      }
    }

    // 2. Qabul qiluvchi chatlarni aniqlash (Multi-tenant: faqat shu cafe_id ga tegishli chat_id lar)
    let chatIds = [];
    if (specificChatId) {
      chatIds = [String(specificChatId)];
    } else {
      const sessions = await db.query(
        `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
        [cafeId]
      );
      chatIds = sessions.rows.map(r => String(r.chat_id));
    }

    if (chatIds.length === 0) {
      console.log(`ℹ️ [Daily Report] ${cafeName || cafeId} uchun faol telegram sessiya topilmadi.`);
      return { success: true, noSessions: true };
    }

    // 3. PostgreSQL da yopilgan kun va umumiy ko'rsatkichlarni bir so'rovda hisoblash
    const statsRes = await db.query(
      `SELECT 
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN total ELSE 0 END), 0) AS daily_revenue,
         COALESCE(COUNT(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN 1 ELSE NULL END), 0) AS daily_count,
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'cash' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN cash_paid ELSE 0 END) END), 0) AS daily_cash,
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'card' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN card_paid ELSE 0 END) END), 0) AS daily_card,
         COALESCE(SUM(total), 0) AS all_time_revenue,
         COUNT(*) AS all_time_count
       FROM receipts
       WHERE cafe_id = $1`,
      [cafeId, closedDateStr]
    );

    const stats = statsRes.rows[0] || {};
    const reportMsg = buildDailyReportMessage({
      cafeName: cafeName || 'Cafe',
      closedDate: closedDateStr,
      timestamp: timestampStr || getTashkentNow().fullStr,
      dailyRevenue: stats.daily_revenue,
      dailyCount: stats.daily_count,
      dailyCash: stats.daily_cash,
      dailyCard: stats.daily_card,
      allTimeRevenue: stats.all_time_revenue,
      allTimeCount: stats.all_time_count,
      isTest,
    });

    let sentCount = 0;
    for (const chatId of chatIds) {
      try {
        await bot.telegram.sendMessage(chatId, reportMsg, { parse_mode: 'HTML' });
        sentCount++;
      } catch (sendErr) {
        console.error(`⚠️ [Telegram Bot] Hisobot yuborishda xatolik (chat: ${chatId}, cafe: ${cafeId}):`, sendErr.message);
      }
    }

    if (sentCount > 0 && !ignoreDedupe) {
      await markReportAsSent(cafeId, closedDateStr);
      console.log(`✅ [Daily Report] ${cafeName || cafeId} (${closedDateStr}) ${sentCount} ta chatga muvaffaqiyatli yuborildi.`);
    }

    return { success: true, sentCount };
  } catch (err) {
    console.error(`❌ sendDailyReportForCafe (${cafeId}) error:`, err.message);
    return { success: false, error: err.message };
  }
};

/**
 * Barcha faol cafelar uchun 24:00 yakuniy hisobotini yuborish
 */
const triggerDailyReportsForAllCafes = async ({
  closedDateStr,
  timestampStr,
  isTest = false,
  ignoreDedupe = false,
}) => {
  try {
    const res = await db.query(
      `SELECT DISTINCT ts.cafe_id, COALESCE(c.receipt_name, c.cafe_name, 'Cafe') AS cafe_name 
       FROM telegram_sessions ts
       LEFT JOIN cafes c ON ts.cafe_id = c.cafe_id
       WHERE ts.role = 'cafe' AND ts.cafe_id IS NOT NULL`
    );

    console.log(`⏰ [Telegram Bot] Kunlik hisobot yuborish boshlandi (${closedDateStr}, Cafelar soni: ${res.rows.length})`);

    for (const row of res.rows) {
      try {
        await sendDailyReportForCafe({
          cafeId: row.cafe_id,
          cafeName: row.cafe_name,
          closedDateStr,
          timestampStr,
          isTest,
          ignoreDedupe,
        });
      } catch (cafeErr) {
        // Bitta cafedagi xato boshqa cafelarni to'xtatmaydi
        console.error(`❌ [Telegram Bot] Cafe ${row.cafe_id} hisobotida xatolik:`, cafeErr.message);
      }
    }
  } catch (err) {
    console.error('❌ [Telegram Bot] triggerDailyReportsForAllCafes xatosi:', err.message);
  }
};

let dailyReportCronInterval = null;

/**
 * 24:00 (Asia/Tashkent vaqti bilan 23:59:59 dan keyin 00:00:00 da) hisobot tekshiruvi
 */
const checkAndSendDailyReports = async () => {
  try {
    const tk = getTashkentNow();

    // 24:00 bo'lganda (00:00 dan 00:30 gacha bo'lgan oraliqda har 30 soniyada tekshiradi)
    if (tk.hour === 0 && tk.minute < 30) {
      // Yopilgan kun sanasi: 5 daqiqa oldingi sana olinadi (kechagi kalendar kuni)
      const closedDateObj = new Date(Date.now() - 5 * 60 * 1000);
      const closedDateStr = getTashkentNow(closedDateObj).dateStr;

      await triggerDailyReportsForAllCafes({
        closedDateStr,
        timestampStr: tk.fullStr,
        isTest: false,
        ignoreDedupe: false,
      });
    }
  } catch (err) {
    console.error('❌ [Telegram Bot] checkAndSendDailyReports xatosi:', err.message);
  }
};

/**
 * Kunlik hisobot rejalashtiruvchisini ishga tushirish
 */
const startDailyReportScheduler = () => {
  if (dailyReportCronInterval) {
    clearInterval(dailyReportCronInterval);
  }
  // Har 30 soniyada bir marta tekshirish (aniq 00:00:00 ni ushlaydi)
  dailyReportCronInterval = setInterval(checkAndSendDailyReports, 30 * 1000);
  console.log('⏰ [Telegram Bot] 24:00 (Asia/Tashkent) kunlik hisobot rejalashtiruvchisi (scheduler) ishga tushdi.');

  // Bot qayta yuklanganda darhol tekshirish
  checkAndSendDailyReports().catch((e) => {
    console.error('❌ [Telegram Bot] Startup check error:', e.message);
  });
};

// ============================================================
// MAIN BOT INITIALIZATION
// ============================================================

const initTelegramBot = async () => {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (!token) {
    console.warn('⚠️  [Telegram Bot] TELEGRAM_BOT_TOKEN sozlanmagan, bot ishga tushmadi.');
    return null;
  }

  if (bot) return bot;

  try {
    bot = new Telegraf(token);

    // Global xatolarni ushlash (xatolik pollingni o'ldirib qo'ymasligi uchun)
    bot.catch((err, ctx) => {
      console.error(`💥 [Telegram Bot] Xatolik yuz berdi (${ctx?.updateType || 'nomaʼlum'}):`, err.message);
    });

    // 0. Webhook holatini tozalash (polling bilan to'qnashuvni bartaraf etish)
    try {
      await bot.telegram.deleteWebhook({ drop_pending_updates: false });
      console.log('✅ [Telegram Bot] Webhook tekshirildi va tozalandi.');
    } catch (whErr) {
      console.warn('⚠️ [Telegram Bot] deleteWebhook ogohlantirish:', whErr.message);
    }

    // 0. Reset global chat menu button to default (WebApp loginsiz ko'rinmasligi uchun)
    try {
      await bot.telegram.setChatMenuButton({ menu_button: { type: 'default' } });
      console.log('✅ [Telegram Bot] Default chat menu tugmasi standart holatga qaytarildi.');
    } catch (btnErr) {
      console.warn('⚠️ [Telegram Bot] Default setChatMenuButton ogohlantirish:', btnErr.message);
    }

    // 0. Ensure telegram_sessions table has phone column
    try {
      await db.query('ALTER TABLE telegram_sessions ADD COLUMN IF NOT EXISTS phone VARCHAR(40);');
    } catch (_) {}

    // 1. Set Bot About & Short Description
    try {
      await bot.telegram.setMyDescription(
        'ZAVERO POS hisobot boti\nCafengiz savdosi va cheklari doim yoningizda:\n- Har bir yopilgan chek zumda sizga keladi\n- Kunlik hisobotlar avtomatik yuboriladi\n- Cafe va director paneliga xavfsiz kirish\nBoshlash uchun /start ni bosing.'
      );
      await bot.telegram.setMyShortDescription(
        'Zavero POS: cafe cheklari va kunlik hisobotlari bir joyda.'
      );
    } catch (descErr) {
      console.warn('⚠️  [Telegram Bot] setMyDescription xatosi:', descErr.message);
    }

    // 2. Private chat filter (Guruh va kanallarda ishlamaydi)
    bot.use(async (ctx, next) => {
      if (ctx.chat?.type && ctx.chat.type !== 'private') {
        return; // Guruh va kanallarda jim turadi
      }
      return next();
    });

    // 3. /start komandasi (To'g'ridan-to'g'ri login so'rash, kanallarsiz)
    bot.command('start', async (ctx) => {
      const chatId = String(ctx.chat.id);
      clearLiveRefresh(chatId);

      // Check existing session in DB first
      const session = await getSession(chatId);
      if (session) {
        // Authenticated user: set Web App menu button specifically for this chat
        await bot.telegram.setChatMenuButton({
          chat_id: chatId,
          menu_button: {
            type: 'web_app',
            text: '📱 ILOVANI OCHISH',
            web_app: { url: getWebAppUrl(session.role, session.cafe_id) },
          },
        }).catch(() => {});

        if (!session.phone) {
          userStates.set(chatId, { state: 'AWAITING_CONTACT', user: session });
          const contactKeyboard = Markup.keyboard([
            [Markup.button.contactRequest('📱 Nomer ulash')],
          ]).resize().oneTime();
          return ctx.reply(
            `👋 Xush kelibsiz, <b>${ctx.from.first_name || 'foydalanuvchi'}</b>!\n\n` +
            `Cheklar va hisobotlarni avtomatik qabul qilish uchun pastdagi <b>«📱 Nomer ulash»</b> tugmasini bosing:`,
            { parse_mode: 'HTML', ...contactKeyboard }
          );
        }

        userStates.set(chatId, { state: 'AUTHENTICATED' });

        if (session.role === 'director') {
          return ctx.reply(
            `👑 <b>ZAVERO DIRECTOR PANELI</b>\n\nXush kelibsiz! Cafelarni monitoring qilish uchun quyidagi menyudan foydalaning:`,
            { parse_mode: 'HTML', ...getDirectorKeyboard() }
          );
        } else {
          return ctx.reply(
            `🏪 <b>${session.cafe_name || 'Cafe'} Hisobot Paneli</b>\n\nXush kelibsiz! Bugungi savdo va cheklarni ko‘rish uchun menyudan tanlang:`,
            { parse_mode: 'HTML', ...getCafeKeyboard(session.cafe_id) }
          );
        }
      }

      // Unauthenticated: Ensure menu button is default
      await bot.telegram.setChatMenuButton({
        chat_id: chatId,
        menu_button: { type: 'default' },
      }).catch(() => {});

      // Immediate login prompt (No channel checks!)
      userStates.set(chatId, { state: 'AWAITING_LOGIN', failedAttempts: 0, lockedUntil: null });
      return ctx.reply(
        `👋 Assalomu alaykum, <b>${ctx.from.first_name || 'foydalanuvchi'}</b>!\n\n` +
        `ZAVERO POS hisobot botiga xush kelibsiz.\n\n` +
        `Iltimos, <b>Cafe loginini</b> kiriting:`,
        { parse_mode: 'HTML', ...Markup.removeKeyboard() }
      );
    });

    // 3.1. /test_report va /hisobot_test komandasi (24:00 kunlik hisobotini darhol sinab ko'rish)
    bot.command(['test_report', 'hisobot_test', 'kunlik_hisobot'], async (ctx) => {
      const chatId = String(ctx.chat.id);
      const session = await getSession(chatId);
      if (!session) {
        return ctx.reply('⚠️ Avval hisobingiz bilan tizimga kiring: /start');
      }

      const tk = getTashkentNow();
      const args = (ctx.message?.text || '').trim().split(/\s+/);
      const requestedDate = (args[1] && /^\d{4}-\d{2}-\d{2}$/.test(args[1])) ? args[1] : tk.dateStr;

      if (session.role === 'cafe') {
        await ctx.reply(`⏳ <b>${session.cafe_name || 'Cafe'}</b> uchun test hisoboti tayyorlanmoqda (${requestedDate})...`, { parse_mode: 'HTML' });
        const res = await sendDailyReportForCafe({
          cafeId: session.cafe_id,
          cafeName: session.cafe_name || 'Cafe',
          closedDateStr: requestedDate,
          timestampStr: tk.fullStr,
          isTest: true,
          ignoreDedupe: true,
          specificChatId: chatId,
        });

        if (!res.success) {
          return ctx.reply(`❌ Hisobot yuborishda xatolik: ${res.error || 'Noma\'lum xatolik'}`);
        }
      } else if (session.role === 'director') {
        await ctx.reply(`⏳ Director nazorati: cafelar bo‘yicha sinov hisoboti yuborilmoqda (${requestedDate})...`);
        const cafesRes = await db.query(
          `SELECT DISTINCT cafe_id, COALESCE(receipt_name, cafe_name, 'Cafe') AS cafe_name 
           FROM cafes WHERE status = 'active'`
        );
        for (const row of cafesRes.rows) {
          await sendDailyReportForCafe({
            cafeId: row.cafe_id,
            cafeName: row.cafe_name,
            closedDateStr: requestedDate,
            timestampStr: tk.fullStr,
            isTest: true,
            ignoreDedupe: true,
            specificChatId: chatId,
          });
        }
      }
    });

    // 4. Contact handler (Nomer ulash)
    bot.on('contact', async (ctx) => {
      const contact = ctx.message.contact;
      const chatId = String(ctx.chat.id);
      const fromId = ctx.from.id;

      if (!contact || contact.user_id !== fromId) {
        return ctx.reply('⚠️ Faqat o‘zingizning kontaktingizni yuborishingiz mumkin. Iltimos, pastdagi «📱 Nomer ulash» tugmasini bosing:');
      }

      const session = await getSession(chatId);
      if (!session) {
        userStates.set(chatId, { state: 'AWAITING_LOGIN', failedAttempts: 0, lockedUntil: null });
        return ctx.reply('⚠️ Sessiya topilmadi. Iltimos, Cafe loginini kiriting:');
      }

      let phone = String(contact.phone_number || '').trim();
      if (!phone.startsWith('+')) phone = `+${phone}`;

      console.log(`📱 [Telegram Bot] Nomer ulandi: chat_id=${chatId}, cafe_id=${session.cafe_id}, phone=${maskPhone(phone)}`);

      await updateSessionPhone(chatId, phone);
      await saveTelegramUserPhone(fromId, phone, session.cafe_id, ctx.from.username);

      userStates.set(chatId, { state: 'AUTHENTICATED' });

      if (session.role === 'director') {
        return ctx.reply(
          `✅ Telefon raqamingiz muvaffaqiyatli ulandi (${maskPhone(phone)})!\n\n👑 <b>ZAVERO DIRECTOR PANELI</b>`,
          { parse_mode: 'HTML', ...getDirectorKeyboard() }
        );
      } else {
        return ctx.reply(
          `✅ Telefon raqamingiz muvaffaqiyatli ulandi (${maskPhone(phone)})!\n` +
          `Endi cheklar va kunlik hisobotlar ushbu botga avtomatik kelib turadi.\n\n` +
          `🏪 <b>${session.cafe_name || 'Cafe'} Hisobot Paneli</b>`,
          { parse_mode: 'HTML', ...getCafeKeyboard(session.cafe_id) }
        );
      }
    });

    // 5. Phone Relink & Unlink Actions
    bot.action('relink_phone', async (ctx) => {
      if (ctx.answerCbQuery) await ctx.answerCbQuery();
      const chatId = String(ctx.chat.id);
      userStates.set(chatId, { state: 'AWAITING_CONTACT' });
      const contactKeyboard = Markup.keyboard([
        [Markup.button.contactRequest('📱 Nomer ulash')],
      ]).resize().oneTime();
      return ctx.reply(
        'Iltimos, pastdagi <b>«📱 Nomer ulash»</b> tugmasini bosing:',
        { parse_mode: 'HTML', ...contactKeyboard }
      );
    });

    bot.action('unlink_phone', async (ctx) => {
      const chatId = String(ctx.chat.id);
      await deleteSessionPhone(chatId);
      if (ctx.answerCbQuery) await ctx.answerCbQuery('Raqam uzildi');
      return ctx.reply(
        '✅ Telefon raqami uzildi. Yangi raqam ulash uchun istalgan vaqtda «📱 Nomerim» tugmasidan foydalanishingiz mumkin.'
      );
    });

    // 5. Director "Cafelar" Live Refresh callback
    bot.action('director_refresh_cafes', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery('🔄 Ma‘lumotlar yangilandi');
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'director') {
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }
        const { text, markup } = await buildCafesListContent();
        await ctx.editMessageText(text, { parse_mode: 'HTML', ...markup });
      } catch (err) {
        if (!err.message?.includes('message is not modified')) {
          console.error('director_refresh_cafes error:', err.message);
        }
      }
    });

    // 6. Director "Orqaga" callback
    bot.action('director_back_cafes', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        clearLiveRefresh(ctx.chat.id);
        await ctx.reply('👑 <b>Director Paneli:</b>', {
          parse_mode: 'HTML',
          ...getDirectorKeyboard(),
        });
      } catch (err) {
        console.error('director_back_cafes error:', err.message);
      }
    });

    // 7. Director Cafe Report view callback
    bot.action(/^view_cafe_(.+)$/, async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        const targetCafeId = ctx.match[1];
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'director') {
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        clearLiveRefresh(ctx.chat.id);

        // Fetch cafe name
        const cRes = await db.query(
          'SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1',
          [targetCafeId]
        );
        const cafeName = cRes.rows[0]?.receipt_name || cRes.rows[0]?.cafe_name || targetCafeId;

        // Fetch today's stats
        const todayStr = new Date().toISOString().split('T')[0];
        const statsRes = await db.query(
          `SELECT 
             COUNT(*) AS total_count,
             COALESCE(SUM(total), 0) AS total_revenue,
             COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE 0 END), 0) AS cash_revenue,
             COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE 0 END), 0) AS card_revenue
           FROM receipts 
           WHERE cafe_id = $1 AND DATE(date AT TIME ZONE 'Asia/Tashkent') = $2`,
          [targetCafeId, todayStr]
        );
        const stats = statsRes.rows[0];

        // Fetch last 5 receipts
        const recRes = await db.query(
          `SELECT id, total, method, table_number, hall_name, date 
           FROM receipts 
           WHERE cafe_id = $1 
           ORDER BY date DESC LIMIT 5`,
          [targetCafeId]
        );

        let reportMsg = `📊 <b>${cafeName} — BUGUNGI HISOBOTI</b>\n`;
        reportMsg += `📅 Sana: <b>${todayStr}</b>\n`;
        reportMsg += `━━━━━━━━━━━━━━━━━━━━\n`;
        reportMsg += `💰 Jami savdo: <b>${formatSum(stats.total_revenue)} so'm</b>\n`;
        reportMsg += `🧾 Cheklar soni: <b>${stats.total_count} ta</b>\n`;
        reportMsg += `💵 Naqd savdo: <b>${formatSum(stats.cash_revenue)} so'm</b>\n`;
        reportMsg += `💳 Karta savdo: <b>${formatSum(stats.card_revenue)} so'm</b>\n`;
        reportMsg += `━━━━━━━━━━━━━━━━━━━━\n`;
        reportMsg += `🧾 <b>Oxirgi cheklar:</b>\n`;

        if (recRes.rows.length === 0) {
          reportMsg += `<i>Bugun hali chek yopilmagan.</i>\n`;
        } else {
          for (const r of recRes.rows) {
            const time = new Date(r.date).toLocaleTimeString('uz-UZ', { timeZone: 'Asia/Tashkent', hour: '2-digit', minute: '2-digit' });
            const table = r.table_number ? (r.hall_name ? `${r.hall_name}, ${r.table_number}-stol` : `${r.table_number}-stol`) : (r.hall_name || 'Stol');
            const method = r.method === 'card' ? 'Karta' : 'Naqd';
            reportMsg += `• #${r.id} | ${time} | ${table} | <b>${formatSum(r.total)} so'm</b> (${method})\n`;
          }
        }

        const backMarkup = Markup.inlineKeyboard([
          [Markup.button.callback('🔙 Cafelar ro‘yxatiga qaytish', 'director_refresh_cafes')],
        ]);

        return ctx.reply(reportMsg, { parse_mode: 'HTML', ...backMarkup });
      } catch (err) {
        console.error('view_cafe action error:', err.message);
      }
    });

    // 7.1. Cafe report inline callbacks
    bot.action('action_refresh_today', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery('🔄 Hisobot yangilandi');
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'cafe') return;
        const msg = await generateTodayReportMessage(session.cafe_id, session.cafe_name);
        await ctx.editMessageText(msg, { parse_mode: 'HTML', ...getTodayReportInlineMarkup() }).catch(() => {});
      } catch (err) {
        if (!err.message?.includes('message is not modified')) {
          console.error('action_refresh_today error:', err.message);
        }
      }
    });

    bot.action('action_view_receipts', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'cafe') return;
        const msg = await generateRecentReceiptsMessage(session.cafe_id, session.cafe_name);
        await ctx.reply(msg, { parse_mode: 'HTML' });
      } catch (err) {
        console.error('action_view_receipts error:', err.message);
      }
    });

    bot.action('action_view_all_time', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'cafe') return;
        const msg = await generateAllTimeRevenueMessage(session.cafe_id, session.cafe_name);
        await ctx.reply(msg, { parse_mode: 'HTML' });
      } catch (err) {
        console.error('action_view_all_time error:', err.message);
      }
    });

    bot.action('action_view_recent_days', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        const session = await getSession(ctx.chat.id);
        if (!session || session.role !== 'cafe') return;
        const msg = await generateRecentDaysReportMessage(session.cafe_id, session.cafe_name);
        await ctx.reply(msg, { parse_mode: 'HTML' });
      } catch (err) {
        console.error('action_view_recent_days error:', err.message);
      }
    });

    // 8. Text message handler (Strict button enforcement + Login/Password state machine)
    bot.on('text', async (ctx, next) => {
      const text = ctx.message.text.trim();
      const chatId = String(ctx.chat.id);

      if (text.startsWith('/')) {
        return next();
      }

      // Check lockout status
      const lockStatus = checkLockout(chatId);
      if (lockStatus.locked) {
        await ctx.deleteMessage().catch(() => {});
        return ctx.reply(
          `⛔ Ketma-ket 5 ta xato urinish tufayli kirish bloklangan. Iltimos, ${lockStatus.mins} daqiqadan so‘ng qayta urinib ko‘ring.`
        );
      }

      const st = userStates.get(chatId) || { state: 'IDLE' };

      // --- LOGIN BOSQICHI ---
      if (st.state === 'AWAITING_LOGIN') {
        const rawInput = text;
        const cleanInput = rawInput.toLowerCase().replace(/^@/, '');
        const cleanEmail = cleanInput.includes('@') ? cleanInput : `${cleanInput}@cafe.uz`;

        const userRes = await db.query(
          `SELECT u.id, u.username, u.password_hash, u.role, u.is_active, u.cafe_id, 
                  c.cafe_name, c.receipt_name, c.status AS cafe_status
           FROM users u
           LEFT JOIN cafes c ON u.cafe_id = c.cafe_id
           WHERE (LOWER(u.username) = $1 
              OR LOWER(u.username) = $2
              OR LOWER(u.email) = $1
              OR LOWER(u.email) = $2
              OR LOWER(u.email) = $3)
             AND u.is_active = true
           LIMIT 1`,
          [rawInput.toLowerCase(), cleanInput, cleanEmail]
        );

        if (userRes.rows.length === 0) {
          return ctx.reply('❌ Login noto‘g‘ri. Qaytadan kiriting:');
        }

        const candidate = userRes.rows[0];

        // Ofitsiant / xodimlar paneliga bot orqali kirib bo'lmaydi
        const role = (candidate.role || '').toLowerCase();
        if (role === 'waiter' || role === 'cashier' || role === 'worker' || role === 'courier') {
          return ctx.reply(
            '❌ Ofitsiant yoki xodimlar hisobi bilan botga kirish mumkin emas. Faqat Cafe ma‘muri yoki Director hisobi qabul qilinadi.\n\nLoginni qaytadan kiriting:'
          );
        }

        if (candidate.cafe_status === 'blocked' && role !== 'director') {
          return ctx.reply('❌ Ushbu cafe faoliyati to‘xtatilgan.');
        }

        // Valid candidate found -> Proceed to password
        const roleType = (role === 'director' || role === 'super_admin') ? 'director' : 'cafe';
        userStates.set(chatId, {
          state: 'AWAITING_PASSWORD',
          pendingUser: {
            id: candidate.id,
            username: candidate.username,
            role: roleType,
            cafe_id: candidate.cafe_id,
            cafe_name: candidate.receipt_name || candidate.cafe_name || 'Cafe',
          },
          failedAttempts: st.failedAttempts || 0,
          lockedUntil: null,
        });

        return ctx.reply('🔑 <b>Parolni kiriting:</b>', { parse_mode: 'HTML' });
      }

      // --- PAROL BOSQICHI ---
      if (st.state === 'AWAITING_PASSWORD') {
        // MUHIM: Parol xabari chatdan darhol o'chiriladi
        await ctx.deleteMessage().catch(() => {});

        const pending = st.pendingUser;
        if (!pending || !pending.id) {
          userStates.set(chatId, { state: 'AWAITING_LOGIN' });
          return ctx.reply('❌ Sessiya vaqti tugadi. Loginni qaytadan kiriting:');
        }

        // Single source of truth: fresh password hash from 'users' table
        const freshUserRes = await db.query(
          'SELECT password_hash, is_active FROM users WHERE id = $1',
          [pending.id]
        );

        if (freshUserRes.rows.length === 0 || freshUserRes.rows[0].is_active === false) {
          userStates.set(chatId, { state: 'AWAITING_LOGIN' });
          return ctx.reply('❌ Foydalanuvchi hisobi faol emas. Loginni qaytadan kiriting:');
        }

        const isMatch = await bcrypt.compare(text, freshUserRes.rows[0].password_hash);

        if (!isMatch) {
          const attemptData = recordFailedPasswordAttempt(chatId);
          if (attemptData.isLock) {
            userStates.set(chatId, { state: 'AWAITING_LOGIN', lockedUntil: Date.now() + 5 * 60 * 1000 });
            return ctx.reply(
              '⛔ Ketma-ket 5 ta noto‘g‘ri parol kiritildi. Xavfsizlik yuzasidan 5 daqiqaga bloklandingiz.'
            );
          }
          // Faqat parol qayta so'raladi (login qayta so'ralmaydi)
          return ctx.reply(`❌ Parol noto‘g‘ri. Qaytadan kiriting:`);
        }

        // Parol to'g'ri -> Reset lockout & save session
        resetLockout(chatId);

        await createSession(chatId, pending.id, pending.role, pending.cafe_id);

        // Faqat muvaffaqiyatli login qilgan chat uchun "ILOVANI OCHISH" menyu tugmasini o'rnatish
        await bot.telegram.setChatMenuButton({
          chat_id: chatId,
          menu_button: {
            type: 'web_app',
            text: '📱 ILOVANI OCHISH',
            web_app: { url: getWebAppUrl(pending.role, pending.cafe_id) },
          },
        }).catch((e) => console.warn('[Telegram Bot] setChatMenuButton error:', e.message));

        // 3-BOSQICH: NOMER ULASH (Contact request tugmasi)
        userStates.set(chatId, { state: 'AWAITING_CONTACT', user: pending });
        const contactKeyboard = Markup.keyboard([
          [Markup.button.contactRequest('📱 Nomer ulash')],
        ]).resize().oneTime();

        return ctx.reply(
          `✅ <b>Parol to‘g‘ri!</b>\n\n` +
          `Cheklar va hisobotlarni avtomatik qabul qilish uchun pastdagi <b>«📱 Nomer ulash»</b> tugmasini bosing:`,
          { parse_mode: 'HTML', ...contactKeyboard }
        );
      }

      // --- NOMER ULASH KUTILAYOTGAN HOLATDA MATN YOZILSA ---
      if (st.state === 'AWAITING_CONTACT') {
        await ctx.deleteMessage().catch(() => {});
        return ctx.reply('⚠️ Iltimos, pastdagi «📱 Nomer ulash» tugmasini bosing.');
      }

      // --- MENU TUGMALARI ISHLOVCHILARI ---

      if (text === '/test_report' || text === 'test_report' || text === '/hisobot_test' || text === 'hisobot_test' || text === 'kunlik_hisobot') {
        const session = await getSession(chatId);
        if (!session) {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const tk = getTashkentNow();
        if (session.role === 'cafe') {
          await ctx.reply(`⏳ <b>${session.cafe_name || 'Cafe'}</b> uchun test hisoboti tayyorlanmoqda...`, { parse_mode: 'HTML' });
          return sendDailyReportForCafe({
            cafeId: session.cafe_id,
            cafeName: session.cafe_name || 'Cafe',
            closedDateStr: tk.dateStr,
            timestampStr: tk.fullStr,
            isTest: true,
            ignoreDedupe: true,
            specificChatId: chatId,
          });
        } else if (session.role === 'director') {
          await ctx.reply(`⏳ Director nazorati: cafelar hisoboti tayyorlanmoqda...`);
          const cafesRes = await db.query(
            `SELECT DISTINCT cafe_id, COALESCE(receipt_name, cafe_name, 'Cafe') AS cafe_name 
             FROM cafes WHERE status = 'active'`
          );
          for (const row of cafesRes.rows) {
            await sendDailyReportForCafe({
              cafeId: row.cafe_id,
              cafeName: row.cafe_name,
              closedDateStr: tk.dateStr,
              timestampStr: tk.fullStr,
              isTest: true,
              ignoreDedupe: true,
              specificChatId: chatId,
            });
          }
          return;
        }
      }

      // 1. Bugungi hisobot & Yangilash
      if (text === '📊 Bugungi hisobot' || text === '🔄 Yangilash') {
        const session = await getSession(chatId);
        if (!session) {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        if (session.role === 'cafe') {
          const reportMsg = await generateTodayReportMessage(session.cafe_id, session.cafe_name);
          return ctx.reply(reportMsg, { parse_mode: 'HTML', ...getTodayReportInlineMarkup() });
        } else if (session.role === 'director') {
          const dirMsg = await generateDirectorSummaryMessage();
          return ctx.reply(dirMsg, { parse_mode: 'HTML' });
        }
      }

      // 2. Bugungi so'nggi cheklar ro'yxati
      if (text === '🧾 Bugungi cheklar' || text === '🧾 Cheklar') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'cafe') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const msg = await generateRecentReceiptsMessage(session.cafe_id, session.cafe_name);
        return ctx.reply(msg, { parse_mode: 'HTML' });
      }

      // 3. Umumiy jami daromad
      if (text === '💰 Jami daromad') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'cafe') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const msg = await generateAllTimeRevenueMessage(session.cafe_id, session.cafe_name);
        return ctx.reply(msg, { parse_mode: 'HTML' });
      }

      // 4. Kecha va oxirgi kunlar hisoboti
      if (text === '📅 Kecha / oxirgi kunlar' || text === '📅 Oxirgi kunlar' || text === '📅 Kechagi hisobot') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'cafe') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const msg = await generateRecentDaysReportMessage(session.cafe_id, session.cafe_name);
        return ctx.reply(msg, { parse_mode: 'HTML' });
      }

      // 5. Director umumiy hisoboti
      if (text === '📊 Umumiy hisobot') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'director') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const dirMsg = await generateDirectorSummaryMessage();
        return ctx.reply(dirMsg, { parse_mode: 'HTML' });
      }

      if (text === '🏢 Cafelar') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'director') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const { text: contentText, markup } = await buildCafesListContent();
        const sentMsg = await ctx.reply(contentText, {
          parse_mode: 'HTML',
          ...markup,
        });

        // Start live 5-second auto refresh
        startLiveRefresh(chatId, sentMsg.message_id);
        return;
      }

      if (text === '📱 Nomerim') {
        const session = await getSession(chatId);
        if (!session) {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const currentPhone = session.phone ? maskPhone(session.phone) : 'ulanmagan';
        const msg = `📱 <b>TELEFON RAQAMI SOZLAMALARI</b>\n\n` +
          `Holat: <b>${currentPhone}</b>\n\n` +
          (session.phone
            ? `Cheklar va kunlik hisobotlar ushbu hisobga avtomatik yetkazilmoqda.`
            : `Cheklar va hisobotlarni qabul qilish uchun pastdagi tugma orqali telefon raqamingizni ulang.`);

        return ctx.reply(msg, {
          parse_mode: 'HTML',
          ...Markup.inlineKeyboard([
            [Markup.button.callback('🔄 Nomerni almashtirish', 'relink_phone')],
            ...(session.phone ? [[Markup.button.callback('🗑 Nomerni uzish', 'unlink_phone')]] : []),
          ]),
        });
      }

      if (text === '🚪 Chiqish') {
        clearLiveRefresh(chatId);
        await deleteSession(chatId);
        userStates.set(chatId, { state: 'IDLE' });

        // Reset chat menu button to default
        await bot.telegram.setChatMenuButton({
          chat_id: chatId,
          menu_button: { type: 'default' },
        }).catch(() => {});

        return ctx.reply(
          `👋 Siz tizimdan chiqdingiz. Bot orqali xabarlar kelishi to‘xtatildi.\n\nQayta kirish uchun: /start`,
          { ...Markup.removeKeyboard() }
        );
      }

      // --- BOSHQA HAR QANDAY ERKIN MATN ---
      // Agar foydalanuvchi erkin matn yozsa, menyu klaviaturasini qayta ko'rsatish
      await ctx.deleteMessage().catch(() => {});
      const currentSession = await getSession(chatId);
      if (currentSession) {
        const kb = currentSession.role === 'director' ? getDirectorKeyboard() : getCafeKeyboard(currentSession.cafe_id);
        return ctx.reply('ℹ️ Iltimos, pastdagi menyu tugmalaridan foydalaning:', { ...kb });
      } else {
        return ctx.reply('⚠️ Iltimos, hisobingiz bilan tizimga kiring: /start');
      }
    });

    // 9. Periodic 24:00 (Asia/Tashkent) cron scheduler
    startDailyReportScheduler();

    // 10. Launch bot with auto-reconnecting polling
    const startPollingWithRetry = async (retryCount = 0) => {
      if (process.env.TELEGRAM_WEBHOOK_URL) {
        console.log('🤖 [Telegram Bot] Webhook rejimida sozlangan.');
        return;
      }

      try {
        console.log(`🤖 [Telegram Bot] Polling ishga tushirilmoqda (urinish: ${retryCount + 1})...`);
        await bot.telegram.deleteWebhook({ drop_pending_updates: false }).catch(() => {});

        bot.launch({ dropPendingUpdates: false }, () => {
          console.log('🤖 [Telegram Bot] ZAVERO POS hisobot boti muvaffaqiyatli ishga tushdi va xabarlarni tinglamoqda.');
        }).then(() => {
          console.log('ℹ️ [Telegram Bot] Polling tugadi. 5 soniyadan so‘ng qayta tiklanadi...');
          setTimeout(() => startPollingWithRetry(retryCount + 1), 5000);
        }).catch((launchErr) => {
          console.warn(`⚠️ [Telegram Bot] Polling xatosi: ${launchErr.message}. 5 soniyadan so‘ng qayta ishga tushiriladi...`);
          setTimeout(() => startPollingWithRetry(retryCount + 1), 5000);
        });
      } catch (err) {
        console.error(`❌ [Telegram Bot] Launch xatosi: ${err.message}. 5 soniyadan so‘ng qayta uriniladi...`);
        setTimeout(() => startPollingWithRetry(retryCount + 1), 5000);
      }
    };

    startPollingWithRetry();

    process.once('SIGINT', () => { if (bot) bot.stop('SIGINT'); });
    process.once('SIGTERM', () => { if (bot) bot.stop('SIGTERM'); });

    return bot;
  } catch (err) {
    console.error('❌ [Telegram Bot] Boshlashda xatolik:', err);
    return null;
  }
};

const getBotInstance = () => bot;

// ============================================================
// REAL-TIME NOTIFICATIONS (ISOLATED BY CAFE_ID)
// ============================================================

/**
 * Send closed receipt notification strictly to sessions belonging to the given cafeId
 */
const notifyCafeSessionsReceipt = async (cafeId, receipt, items) => {
  try {
    let currentBot = bot;
    if (!currentBot || !currentBot.telegram) {
      currentBot = getBotInstance();
    }
    if (!currentBot || !currentBot.telegram) {
      console.warn('⚠️ [Telegram Receipt] Telegram bot instansi hali faol emas, chek yuborilmadi.');
      return;
    }
    if (!cafeId || !receipt) {
      console.warn('⚠️ [Telegram Receipt] cafeId yoki receipt parametri kiritilmagan.');
      return;
    }

    // Deduplication check
    const dedupKey = `rec_${cafeId}_${receipt.id}`;
    if (sentReceiptsCache.has(dedupKey)) {
      console.log(`ℹ️ [Telegram Receipt] Chek #${receipt.id} allaqachon yuborilgan (cache dedup).`);
      return; // Already sent, prevent duplicate
    }
    sentReceiptsCache.add(dedupKey);

    if (receipt.id) {
      const chk = await db.query(
        `SELECT telegram_status FROM receipts WHERE id = $1`,
        [receipt.id]
      ).catch(() => ({ rows: [] }));
      if (chk.rows.length > 0 && chk.rows[0].telegram_status === 'sent') {
        console.log(`ℹ️ [Telegram Receipt] Chek #${receipt.id} bazada allaqachon 'sent' holatida.`);
        return;
      }
    }

    // 1. Query active sessions for this cafe_id
    const sessionsRes = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE cafe_id = $1`,
      [cafeId]
    );

    const targetChatIds = new Set();
    for (const r of sessionsRes.rows) {
      if (r.chat_id) targetChatIds.add(String(r.chat_id).trim());
    }

    // 2. Query settings for configured telegram receipt chat
    try {
      const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1 LIMIT 1', [cafeId]);
      const sData = sRes.rows[0]?.data || {};
      if (sData.telegramReceiptsEnabled !== false) {
        const cfgChat = sData.telegramReceiptChatId || sData.telegramReceiptsChatId || sData.telegramResolvedChatId;
        if (cfgChat) {
          String(cfgChat).split(',').forEach((c) => {
            const trimmed = c.trim();
            if (/^-?\d+$/.test(trimmed) || trimmed.startsWith('@')) {
              targetChatIds.add(trimmed);
            }
          });
        }
      }
    } catch (sErr) {
      console.warn('⚠️ [Telegram Receipt] Settings tekshirishda ogohlantirish:', sErr.message);
    }

    if (targetChatIds.size === 0) {
      console.warn(`⚠️ [Telegram Receipt] Cafe (${cafeId}) uchun hech qanday faol Telegram chat topilmadi. Chek #${receipt.id} yuborilmadi.`);
      if (receipt.id) {
        await db.query(`UPDATE receipts SET telegram_status = 'no_chat' WHERE id = $1`, [receipt.id]).catch(() => {});
      }
      return;
    }

    // Fetch cafe name
    let cafeName = 'ZAVERO Cafe';
    const cRes = await db.query(
      'SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1',
      [cafeId]
    );
    if (cRes.rows.length > 0) {
      cafeName = cRes.rows[0].receipt_name || cRes.rows[0].cafe_name || cafeName;
    }

    const dateStr = formatDate(receipt.date || Date.now());
    const methodStr = (receipt.method === 'card' || receipt.payment_method === 'card') ? 'Karta' : 'Naqd';
    const tableStr = receipt.table_number ? (receipt.hall_name ? `${receipt.hall_name}, ${receipt.table_number}-stol` : `${receipt.table_number}-stol`) : (receipt.hall_name || 'Stol');
    const hallStr = receipt.hall_name || 'Asosiy zal';
    const cashierStr = receipt.cashier_name || 'Kassir';
    const totalStr = formatSum(receipt.total || 0);

    let text = `🧾 <b>YANGI TO‘LANGAN CHEK #${receipt.id || ''}</b>\n`;
    text += `🏪 <b>${cafeName}</b>\n`;
    text += `📍 Stol: <b>${tableStr}</b>\n`;
    text += `🏛 Zal: <b>${hallStr}</b>\n`;
    text += `🕒 Vaqt: <code>${dateStr}</code>\n`;
    text += `👤 Kassir/Ofitsiant: <b>${cashierStr}</b>\n`;
    text += `💳 To‘lov turi: <b>${methodStr}</b>\n`;
    text += `──────────────────\n`;

    const parsedItems = Array.isArray(items)
      ? items
      : (typeof items === 'string' ? JSON.parse(items || '[]') : []);

    for (const it of parsedItems) {
      const pName = it.product?.name || it.name || 'Mahsulot';
      const qty = it.qty || it.quantity || 1;
      const price = it.product?.price || it.price || 0;
      const lineTotal = price * qty;
      text += `• ${pName} × ${qty} = <b>${formatSum(lineTotal)} so'm</b>\n`;
    }

    text += `──────────────────\n`;
    text += `💰 <b>JAMI: ${totalStr} so'm</b>`;

    let anySent = false;
    for (const chatId of targetChatIds) {
      try {
        await currentBot.telegram.sendMessage(chatId, text, { parse_mode: 'HTML', disable_web_page_preview: true });
        anySent = true;
        console.log(`✅ [Telegram Receipt] Chek #${receipt.id || ''} chat ${chatId} ga muvaffaqiyatli yetkazildi.`);
      } catch (sendErr) {
        console.error(`❌ [Telegram Receipt] Chat ${chatId} ga chek yuborishda xatolik:`, sendErr.message);
        if (sendErr.message && sendErr.message.includes('blocked')) {
          console.warn(`🚫 [Telegram Receipt] Foydalanuvchi (${chatId}) botni bloklagan (Forbidden).`);
        } else if (sendErr.message && sendErr.message.includes('chat not found')) {
          console.warn(`⚠️ [Telegram Receipt] Chat (${chatId}) topilmadi. Foydalanuvchi botga /start bosishi lozim.`);
        }
      }
    }

    if (receipt.id) {
      const status = anySent ? 'sent' : 'failed';
      await db.query(
        `UPDATE receipts SET telegram_status = $1, telegram_sent_at = CURRENT_TIMESTAMP WHERE id = $2`,
        [status, receipt.id]
      ).catch(() => {});
    }
  } catch (err) {
    console.error('notifyCafeSessionsReceipt error:', err.message);
  }
};

/**
 * Parol sinxroni: Ilovadan parol yoki login o'zgarganda sessiyalarni yopish va ogohlantirish
 */
const notifySessionsPasswordChanged = async (userId) => {
  try {
    if (!userId) return;
    const res = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE user_id = $1`,
      [userId]
    );

    for (const row of res.rows) {
      try {
        if (bot && bot.telegram) {
          await bot.telegram.setChatMenuButton({
            chat_id: row.chat_id,
            menu_button: { type: 'default' },
          }).catch(() => {});
          await bot.telegram.sendMessage(
            row.chat_id,
            `⚠️ <b>Parol o‘zgartirildi!</b>\n\nIlovadan hisob ma‘lumotlaringiz yangilandi. Xavfsizlik maqsadida botdagi sessiyangiz yakunlandi.\n\nYangi ma‘lumotlar bilan qaytadan kiring: /start`,
            { parse_mode: 'HTML', ...Markup.removeKeyboard() }
          );
        }
      } catch (_) {}
    }

    await db.query('DELETE FROM telegram_sessions WHERE user_id = $1', [userId]);
  } catch (e) {
    console.error('notifySessionsPasswordChanged error:', e.message);
  }
};

/**
 * Cafe o'chirish sinxroni: Ilovadan cafe o'chirilganda sessiyalarni to'liq tozalash
 */
const notifySessionsCafeDeleted = async (cafeId, cafeName) => {
  try {
    if (!cafeId) return;
    const res = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE cafe_id = $1`,
      [cafeId]
    );

    for (const row of res.rows) {
      try {
        if (bot && bot.telegram) {
          await bot.telegram.setChatMenuButton({
            chat_id: row.chat_id,
            menu_button: { type: 'default' },
          }).catch(() => {});
          await bot.telegram.sendMessage(
            row.chat_id,
            `⚠️ <b>"${cafeName || 'Cafe'}" kafesi o‘chirildi!</b>\n\nUshbu cafe paneli va bot xizmatiga kirish to‘liq yopildi.`,
            { parse_mode: 'HTML', ...Markup.removeKeyboard() }
          );
        }
      } catch (_) {}
    }

    await db.query('DELETE FROM telegram_sessions WHERE cafe_id = $1', [cafeId]);
  } catch (e) {
    console.error('notifySessionsCafeDeleted error:', e.message);
  }
};

/**
 * Customer QR Order notification for compatibility with customerOrderController
 */
const sendCustomerOrderNotification = async (cafeId, order) => {
  try {
    if (!bot || !bot.telegram || !cafeId || !order) return;
    const sessions = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
      [cafeId]
    );
    if (sessions.rows.length === 0) return;

    let cafeName = 'ZAVERO';
    const cRes = await db.query('SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cRes.rows.length > 0) {
      cafeName = cRes.rows[0].receipt_name || cRes.rows[0].cafe_name || cafeName;
    }

    const tableLabel = order.type === 'delivery'
      ? `Dastavka (${order.deliveryAddress || 'Manzil yo‘q'})`
      : (order.tableNumber ? `${order.tableNumber}-stol` : 'Stol');

    let text = `📱 <b>YANGI ONLINE BUYURTMA #${order.id || ''}</b>\n`;
    text += `🏪 <b>${cafeName}</b>\n`;
    text += `📍 Joy: <b>${tableLabel}</b>\n`;
    text += `👤 Mijoz: <b>${order.customerName || 'Mijoz'}</b> (${order.customerPhone || ''})\n`;
    text += `──────────────────\n`;

    const items = Array.isArray(order.items) ? order.items : [];
    for (const it of items) {
      const q = it.qty || it.quantity || 1;
      const p = it.product?.price || it.price || 0;
      text += `• ${it.name || it.product?.name || 'Mahsulot'} × ${q} = <b>${formatSum(p * q)} so'm</b>\n`;
    }
    text += `──────────────────\n`;
    text += `💰 <b>JAMI: ${formatSum(order.total || 0)} so'm</b>`;

    for (const s of sessions.rows) {
      try {
        await bot.telegram.sendMessage(s.chat_id, text, { parse_mode: 'HTML' });
      } catch (_) {}
    }
  } catch (err) {
    console.error('sendCustomerOrderNotification error:', err.message);
  }
};

const sendGeneralTelegramNotification = async (title, message, cafeId = null) => {
  try {
    if (!bot || !bot.telegram) return;
    const query = cafeId
      ? `SELECT chat_id FROM telegram_sessions WHERE cafe_id = $1`
      : `SELECT chat_id FROM telegram_sessions`;
    const params = cafeId ? [cafeId] : [];
    const res = await db.query(query, params);

    const fullMsg = `<b>${title}</b>\n━━━━━━━━━━━━━━━━━━━━\n${message}\n\n<i>ZAVERO POS tizimi</i>`;
    for (const row of res.rows) {
      try {
        await bot.telegram.sendMessage(row.chat_id, fullMsg, { parse_mode: 'HTML' });
      } catch (_) {}
    }
  } catch (err) {
    console.error('sendGeneralTelegramNotification error:', err.message);
  }
};

// Compatibility stubs for paymentController & settings
const getUserSubscription = async (userId) => ({ status: 'active', daysRemaining: 365 });
const activateSubscription = async (userId, days) => ({ success: true });
const getBotSettings = async () => ({
  required_channel_1: null,
  required_channel_2: null,
});
const isAdminUser = () => false;

module.exports = {
  initTelegramBot,
  getBotInstance,
  notifyCafeSessionsReceipt,
  notifySessionsPasswordChanged,
  notifySessionsCafeDeleted,
  sendCustomerOrderNotification,
  sendGeneralTelegramNotification,
  getUserSubscription,
  activateSubscription,
  getBotSettings,
  isAdminUser,
  buildCafesListContent,
  maskPhone,
  getTashkentNow,
  buildDailyReportMessage,
  sendDailyReportForCafe,
  triggerDailyReportsForAllCafes,
  checkAndSendDailyReports,
  startDailyReportScheduler,
  isReportAlreadySent,
  markReportAsSent,
  toTashkentDateString,
  getTodayReportInlineMarkup,
  generateTodayReportMessage,
  generateRecentReceiptsMessage,
  generateAllTimeRevenueMessage,
  generateRecentDaysReportMessage,
  generateDirectorSummaryMessage,
};
