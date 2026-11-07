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
  return Number(amount || 0).toLocaleString('uz-UZ').replace(/,/g, ' ');
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

const getRequiredChannels = () => {
  const ch1 = (process.env.CHANNEL_1 || process.env.REQUIRED_CHANNEL_1 || '@zavero_uz').trim();
  const ch2 = (process.env.CHANNEL_2 || process.env.REQUIRED_CHANNEL_2 || '@mirzobekdev').trim();
  return { ch1, ch2 };
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
// MANDATORY SUBSCRIPTION VERIFICATION (getChatMember)
// ============================================================

const checkUserSubscriptions = async (userId) => {
  if (!bot || !bot.telegram) return { sub1: true, sub2: true, allSubscribed: true };
  const { ch1, ch2 } = getRequiredChannels();
  const isMember = (status) => ['creator', 'administrator', 'member', 'restricted'].includes(status);

  let sub1 = false;
  let sub2 = false;

  try {
    const m1 = await bot.telegram.getChatMember(ch1, userId);
    sub1 = isMember(m1.status);
  } catch (e) {
    console.warn(`[Bot Subscription] getChatMember for ${ch1} (${userId}):`, e.message);
  }

  try {
    const m2 = await bot.telegram.getChatMember(ch2, userId);
    sub2 = isMember(m2.status);
  } catch (e) {
    console.warn(`[Bot Subscription] getChatMember for ${ch2} (${userId}):`, e.message);
  }

  return { sub1, sub2, allSubscribed: sub1 && sub2, ch1, ch2 };
};

const getSubscriptionKeyboard = (ch1, ch2) => {
  const url1 = `https://t.me/${ch1.replace('@', '')}`;
  const url2 = `https://t.me/${ch2.replace('@', '')}`;
  return Markup.inlineKeyboard([
    [Markup.button.url('1-kanal', url1), Markup.button.url('2-kanal', url2)],
    [Markup.button.callback('✅ Tekshirish', 'check_subscription')],
  ]);
};

// ============================================================
// ROLE-BASED KEYBOARDS
// ============================================================

const getCafeKeyboard = (cafeId) => {
  const url = getWebAppUrl('cafe', cafeId);
  return Markup.keyboard([
    ['📊 Bugungi hisobot', '🧾 Cheklar'],
    [Markup.button.webApp('📱 Ilovani ochish', url)],
    ['🚪 Chiqish'],
  ]).resize();
};

const getDirectorKeyboard = () => {
  const url = getWebAppUrl('director');
  return Markup.keyboard([
    ['🏢 Cafelar'],
    [Markup.button.webApp('📱 Ilovani ochish', url)],
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
// DAILY REPORT CRON JOB (00:00 Asia/Tashkent)
// ============================================================

let lastDailyReportDay = '';

const checkAndSendDailyReports = async () => {
  try {
    const now = new Date();
    const tashkentTimeStr = now.toLocaleDateString('uz-UZ', { timeZone: 'Asia/Tashkent' });
    const tashkentHour = parseInt(now.toLocaleTimeString('en-US', { timeZone: 'Asia/Tashkent', hour: '2-digit', hour12: false }), 10);
    const tashkentMin = parseInt(now.toLocaleTimeString('en-US', { timeZone: 'Asia/Tashkent', minute: '2-digit', hour12: false }), 10);

    // Run at 00:00 (within first 3 minutes of the day)
    if (tashkentHour === 0 && tashkentMin < 3 && lastDailyReportDay !== tashkentTimeStr) {
      lastDailyReportDay = tashkentTimeStr;
      console.log(`⏰ [Telegram Bot] Kunlik 00:00 hisoboti boshlandi (${tashkentTimeStr})`);

      // Find all cafes that have active cafe telegram sessions
      const res = await db.query(
        `SELECT DISTINCT ts.cafe_id, c.cafe_name, c.receipt_name 
         FROM telegram_sessions ts
         JOIN cafes c ON ts.cafe_id = c.cafe_id
         WHERE ts.role = 'cafe'`
      );

      for (const row of res.rows) {
        await sendDailyReportForCafe(row.cafe_id, row.receipt_name || row.cafe_name);
      }
    }
  } catch (err) {
    console.error('checkAndSendDailyReports error:', err.message);
  }
};

const sendDailyReportForCafe = async (cafeId, cafeName) => {
  try {
    const sessions = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
      [cafeId]
    );
    if (sessions.rows.length === 0) return;

    // Yesterday's date in Tashkent timezone
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const dateStr = yesterday.toISOString().split('T')[0];

    const statsRes = await db.query(
      `SELECT 
         COUNT(*) AS total_count,
         COALESCE(SUM(total), 0) AS total_revenue,
         COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE 0 END), 0) AS cash_revenue,
         COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE 0 END), 0) AS card_revenue
       FROM receipts 
       WHERE cafe_id = $1 AND DATE(date AT TIME ZONE 'Asia/Tashkent') = $2`,
      [cafeId, dateStr]
    );

    const stats = statsRes.rows[0];
    const totalRev = formatSum(stats.total_revenue);
    const cashRev = formatSum(stats.cash_revenue);
    const cardRev = formatSum(stats.card_revenue);

    const msg = `📊 <b>KUNLIK YAKUNIY HISOBOT</b>\n` +
      `🏪 <b>${cafeName || 'Cafe'}</b>\n` +
      `📅 Sana: <b>${dateStr}</b>\n` +
      `━━━━━━━━━━━━━━━━━━━━\n` +
      `💰 Jami savdo: <b>${totalRev} so'm</b>\n` +
      `🧾 Cheklar soni: <b>${stats.total_count} ta</b>\n` +
      `💵 Naqd savdo: <b>${cashRev} so'm</b>\n` +
      `💳 Karta savdo: <b>${cardRev} so'm</b>\n` +
      `━━━━━━━━━━━━━━━━━━━━\n` +
      `<i>ZAVERO POS tizimi</i>`;

    for (const s of sessions.rows) {
      try {
        await bot.telegram.sendMessage(s.chat_id, msg, { parse_mode: 'HTML' });
      } catch (_) {}
    }
  } catch (err) {
    console.error(`sendDailyReportForCafe (${cafeId}) error:`, err.message);
  }
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

    // 3. /start komandasi
    bot.command('start', async (ctx) => {
      const chatId = String(ctx.chat.id);
      clearLiveRefresh(chatId);

      // Reset transient conversation state
      userStates.set(chatId, { state: 'IDLE', failedAttempts: 0, lockedUntil: null });

      const { sub1, sub2, allSubscribed, ch1, ch2 } = await checkUserSubscriptions(ctx.from.id);

      if (!allSubscribed) {
        userStates.set(chatId, { state: 'SUBSCRIBING' });
        return ctx.reply(
          `👋 Assalomu alaykum, <b>${ctx.from.first_name || 'foydalanuvchi'}</b>!\n\n` +
          `ZAVERO POS hisobot botiga xush kelibsiz.\n\n` +
          `Botdan to‘liq foydalanish uchun quyidagi kanallarga a'zo bo‘ling:`,
          {
            parse_mode: 'HTML',
            ...getSubscriptionKeyboard(ch1, ch2),
          }
        );
      }

      // Check existing session in DB
      const session = await getSession(chatId);
      if (session) {
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

      // Start login flow
      userStates.set(chatId, { state: 'AWAITING_LOGIN', failedAttempts: 0, lockedUntil: null });
      return ctx.reply(
        `✅ Kanallarga obuna tasdiqlandi!\n\nIltimos, Zavero POS ilovangizdagi <b>loginni</b> kiriting:`,
        { parse_mode: 'HTML', ...Markup.removeKeyboard() }
      );
    });

    // 4. "Tekshirish" callback (Majburiy obuna)
    bot.action('check_subscription', async (ctx) => {
      try {
        if (ctx.answerCbQuery) await ctx.answerCbQuery();
        const chatId = String(ctx.chat.id);
        const { sub1, sub2, allSubscribed, ch1, ch2 } = await checkUserSubscriptions(ctx.from.id);

        if (!allSubscribed) {
          let errorText = '⚠️ <b>Avval ikkala kanalga obuna bo‘ling:</b>\n\n';
          errorText += sub1 ? '✅ 1-kanalga a‘zo bo‘lgansiz\n' : `❌ 1-kanalga (${ch1}) obuna bo‘linmagan\n`;
          errorText += sub2 ? '✅ 2-kanalga a‘zo bo‘lgansiz\n' : `❌ 2-kanalga (${ch2}) obuna bo‘linmagan\n`;

          return ctx.editMessageText(errorText, {
            parse_mode: 'HTML',
            ...getSubscriptionKeyboard(ch1, ch2),
          });
        }

        // Check if session exists
        const session = await getSession(chatId);
        if (session) {
          if (session.role === 'director') {
            await ctx.reply(
              `👑 <b>ZAVERO DIRECTOR PANELI</b>\n\nXush kelibsiz!`,
              { parse_mode: 'HTML', ...getDirectorKeyboard() }
            );
          } else {
            await ctx.reply(
              `🏪 <b>${session.cafe_name || 'Cafe'} Hisobot Paneli</b>\n\nXush kelibsiz!`,
              { parse_mode: 'HTML', ...getCafeKeyboard(session.cafe_id) }
            );
          }
          return;
        }

        userStates.set(chatId, { state: 'AWAITING_LOGIN', failedAttempts: 0, lockedUntil: null });
        await ctx.reply(
          `✅ Kanallarga obuna tasdiqlandi!\n\nIltimos, Zavero POS ilovangizdagi <b>loginni</b> kiriting:`,
          { parse_mode: 'HTML', ...Markup.removeKeyboard() }
        );
      } catch (err) {
        console.error('check_subscription action error:', err.message);
      }
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
              OR LOWER(u.email) = $3
              OR ($2 = 'director' AND u.role = 'director')
              OR ($2 = 'admin' AND u.cafe_id = 'cafe1' AND u.role = 'admin'))
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
        userStates.set(chatId, { state: 'AUTHENTICATED' });

        await createSession(chatId, pending.id, pending.role, pending.cafe_id);

        if (pending.role === 'director') {
          return ctx.reply(
            `✅ Muvaffaqiyatli kirdingiz!\n\n👑 <b>ZAVERO DIRECTOR PANELI</b>`,
            { parse_mode: 'HTML', ...getDirectorKeyboard() }
          );
        } else {
          return ctx.reply(
            `✅ Muvaffaqiyatli kirdingiz!\n\n🏪 <b>${pending.cafe_name} Hisobot Paneli</b>`,
            { parse_mode: 'HTML', ...getCafeKeyboard(pending.cafe_id) }
          );
        }
      }

      // --- MENU TUGMALARI ISHLOVCHILARI ---

      if (text === '📊 Bugungi hisobot') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'cafe') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const todayStr = new Date().toISOString().split('T')[0];
        const statsRes = await db.query(
          `SELECT 
             COUNT(*) AS total_count,
             COALESCE(SUM(total), 0) AS total_revenue,
             COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE 0 END), 0) AS cash_revenue,
             COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE 0 END), 0) AS card_revenue
           FROM receipts 
           WHERE cafe_id = $1 AND DATE(date AT TIME ZONE 'Asia/Tashkent') = $2`,
          [session.cafe_id, todayStr]
        );
        const stats = statsRes.rows[0];

        const reportMsg = `📊 <b>BUGUNGI HISOBOT</b>\n` +
          `🏪 <b>${session.cafe_name || 'Cafe'}</b>\n` +
          `📅 Sana: <b>${todayStr}</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━\n` +
          `💰 Jami savdo: <b>${formatSum(stats.total_revenue)} so'm</b>\n` +
          `🧾 Cheklar soni: <b>${stats.total_count} ta</b>\n` +
          `💵 Naqd savdo: <b>${formatSum(stats.cash_revenue)} so'm</b>\n` +
          `💳 Karta savdo: <b>${formatSum(stats.card_revenue)} so'm</b>\n` +
          `━━━━━━━━━━━━━━━━━━━━\n` +
          `<i>ZAVERO POS tizimi</i>`;

        return ctx.reply(reportMsg, { parse_mode: 'HTML' });
      }

      if (text === '🧾 Cheklar') {
        const session = await getSession(chatId);
        if (!session || session.role !== 'cafe') {
          await ctx.deleteMessage().catch(() => {});
          return ctx.reply('⚠️ Avval panelga kiring: /start');
        }

        const todayStr = new Date().toISOString().split('T')[0];
        const recRes = await db.query(
          `SELECT id, total, method, table_number, hall_name, date, cashier_name 
           FROM receipts 
           WHERE cafe_id = $1 AND DATE(date AT TIME ZONE 'Asia/Tashkent') = $2
           ORDER BY date DESC LIMIT 10`,
          [session.cafe_id, todayStr]
        );

        if (recRes.rows.length === 0) {
          return ctx.reply(`🧾 Bugun hali yopilgan cheklar mavjud emas.`);
        }

        let msg = `🧾 <b>BUGUNGI OXIRGI CHEKLAR (${session.cafe_name || 'Cafe'})</b>\n━━━━━━━━━━━━━━━━━━━━\n`;
        for (const r of recRes.rows) {
          const time = new Date(r.date).toLocaleTimeString('uz-UZ', { timeZone: 'Asia/Tashkent', hour: '2-digit', minute: '2-digit' });
          const table = r.table_number ? (r.hall_name ? `${r.hall_name}, ${r.table_number}-stol` : `${r.table_number}-stol`) : (r.hall_name || 'Stol');
          const method = r.method === 'card' ? 'Karta' : 'Naqd';
          msg += `• Chek #${r.id} | ${time} | ${table}\n  💰 Summa: <b>${formatSum(r.total)} so'm</b> (${method})\n`;
        }
        msg += `━━━━━━━━━━━━━━━━━━━━`;

        return ctx.reply(msg, { parse_mode: 'HTML' });
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

      if (text === '🚪 Chiqish') {
        clearLiveRefresh(chatId);
        await deleteSession(chatId);
        userStates.set(chatId, { state: 'IDLE' });
        return ctx.reply(
          `👋 Siz tizimdan chiqdingiz. Bot orqali xabarlar kelishi to‘xtatildi.\n\nQayta kirish uchun: /start`,
          { ...Markup.removeKeyboard() }
        );
      }

      // --- BOSHQA HAR QANDAY ERKIN MATN ---
      // Bot erkin matnga javob bermaydi: xabar o'chiriladi va tugmadan foydalanish so'raladi
      await ctx.deleteMessage().catch(() => {});
      return ctx.reply('⚠️ Iltimos, pastdagi tugmalardan foydalaning.');
    });

    // 9. Periodic 00:00 Tashkent cron checker
    setInterval(checkAndSendDailyReports, 60 * 1000);

    // 10. Launch bot (polling mode if no webhook configured)
    if (!process.env.TELEGRAM_WEBHOOK_URL) {
      bot.launch({ dropPendingUpdates: true }).then(() => {
        console.log('🤖 [Telegram Bot] ZAVERO POS hisobot boti muvaffaqiyatli ishga tushdi (Polling rejimida).');
      }).catch((launchErr) => {
        console.warn('⚠️  [Telegram Bot] Launch ogohlantirish:', launchErr.message);
      });
    } else {
      console.log('🤖 [Telegram Bot] Webhook rejimida sozlangan.');
    }

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
    if (!bot || !bot.telegram || !cafeId || !receipt) return;

    // Deduplication check
    const dedupKey = `rec_${cafeId}_${receipt.id}`;
    if (sentReceiptsCache.has(dedupKey)) {
      return; // Already sent, prevent duplicate
    }
    sentReceiptsCache.add(dedupKey);

    if (receipt.id) {
      const chk = await db.query(
        `SELECT telegram_status FROM receipts WHERE id = $1`,
        [receipt.id]
      ).catch(() => ({ rows: [] }));
      if (chk.rows.length > 0 && chk.rows[0].telegram_status === 'sent') {
        return;
      }
    }

    // Query active cafe sessions for this cafe_id
    const sessionsRes = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
      [cafeId]
    );

    if (sessionsRes.rows.length === 0) return;

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
    for (const row of sessionsRes.rows) {
      try {
        await bot.telegram.sendMessage(row.chat_id, text, { parse_mode: 'HTML' });
        anySent = true;
      } catch (sendErr) {
        console.warn(`[Telegram Bot] Failed to send receipt to chat ${row.chat_id}:`, sendErr.message);
      }
    }

    if (receipt.id && anySent) {
      await db.query(
        `UPDATE receipts SET telegram_status = 'sent', telegram_sent_at = CURRENT_TIMESTAMP WHERE id = $1`,
        [receipt.id]
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
  required_channel_1: process.env.CHANNEL_1 || process.env.REQUIRED_CHANNEL_1 || '@zavero_uz',
  required_channel_2: process.env.CHANNEL_2 || process.env.REQUIRED_CHANNEL_2 || '@mirzobekdev',
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
};
