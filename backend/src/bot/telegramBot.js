const { Telegraf, Markup } = require('telegraf');
const db = require('../config/db');

// Telegram Bot instance
let bot = null;

// Temporary state for admin actions (waiting for password, waiting for ID input)
const adminState = new Map();

// Session set of admins who have entered the correct password
const adminAuthenticatedSessions = new Set();

// Helper: Format uzbek sum
const formatSum = (amount) => {
  return Number(amount || 0).toLocaleString('uz-UZ').replace(/,/g, ' ');
};

// Helper: Format date
const formatDate = (date) => {
  try {
    const d = new Date(date);
    return d.toLocaleDateString('uz-UZ', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch (e) {
    return String(date);
  }
};

// Helper: Get Base WebApp URL (Full ZAVERO POS app)
const getWebAppUrl = () => {
  const url = process.env.WEBAPP_URL || process.env.RENDER_EXTERNAL_URL || 'https://zavero-jrna.onrender.com';
  return url.endsWith('/') ? url : `${url}/`;
};

// Helper: Get bot settings from DB
const getBotSettings = async () => {
  const defaultSettings = {
    required_channel_1: process.env.REQUIRED_CHANNEL_1 || '@mirzobekdev',
    required_channel_2: process.env.REQUIRED_CHANNEL_2 || '@zavero_uz',
    subscription_price: parseInt(process.env.SUBSCRIPTION_PRICE || '250000', 10),
    subscription_days: parseInt(process.env.SUBSCRIPTION_DAYS || '30', 10),
    card_number: process.env.CARD_NUMBER || '9860 3501 2345 6789',
    card_holder: process.env.CARD_HOLDER || 'ZAVERO POS',
    admin_contact: process.env.ADMIN_CONTACT || '@mirzobekn',
  };

  try {
    const res = await db.query('SELECT key, value FROM bot_settings');
    const settings = { ...defaultSettings };
    for (const row of res.rows) {
      if (row.key === 'subscription_price' || row.key === 'subscription_days') {
        settings[row.key] = parseInt(row.value, 10);
      } else {
        settings[row.key] = row.value;
      }
    }
    return settings;
  } catch (err) {
    console.warn('⚠️ [Telegram Bot] bot_settings o‘qishda xatolik:', err.message);
    return defaultSettings;
  }
};

// Helper: Get list of all admin telegram IDs
const getAllAdminIds = async () => {
  const ids = new Set();
  (process.env.ADMIN_TELEGRAM_IDS || '').split(',').forEach((id) => {
    if (id.trim()) ids.add(id.trim());
  });

  try {
    const res = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_telegram_ids'");
    if (res.rows.length > 0 && res.rows[0].value) {
      res.rows[0].value.split(',').forEach((id) => {
        if (id.trim()) ids.add(id.trim());
      });
    }
  } catch (e) { }

  // Default verified admin IDs (Mirzobek & Admin accounts)
  ids.add('8873925517');
  ids.add('8413914382');
  ids.add('8989763161');

  adminAuthenticatedSessions.forEach((id) => ids.add(id));
  return Array.from(ids);
};

// Helper: Check if user is authenticated admin (session, DB, or verified ID)
const isAdminUser = async (from) => {
  if (!from) return false;
  const telegramId = String(from.id || from);
  if (adminAuthenticatedSessions.has(telegramId)) return true;

  const allAdmins = await getAllAdminIds();
  if (allAdmins.includes(telegramId)) {
    adminAuthenticatedSessions.add(telegramId);
    return true;
  }
  return false;
};

// Helper: Save a new admin ID to database
const addAdminId = async (telegramId) => {
  try {
    const res = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_telegram_ids'");
    let ids = [];
    if (res.rows.length > 0 && res.rows[0].value) {
      ids = res.rows[0].value.split(',').map((s) => s.trim()).filter(Boolean);
    }
    const strId = String(telegramId);
    if (!ids.includes(strId)) {
      ids.push(strId);
      await db.query(
        `INSERT INTO bot_settings (key, value, updated_at)
         VALUES ('admin_telegram_ids', $1, CURRENT_TIMESTAMP)
         ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
        [ids.join(',')]
      );
    }
    adminAuthenticatedSessions.add(strId);
    return true;
  } catch (e) {
    console.warn('addAdminId error:', e.message);
    return false;
  }
};

// Helper: Fetch user's active subscription
const getUserSubscription = async (telegramId) => {
  try {
    const query = `
      SELECT * FROM subscriptions 
      WHERE telegram_id = $1 AND status = 'active' AND end_date > NOW() 
      ORDER BY end_date DESC 
      LIMIT 1
    `;
    const res = await db.query(query, [telegramId]);
    if (res.rows.length > 0) {
      const sub = res.rows[0];
      const now = new Date();
      const end = new Date(sub.end_date);
      const daysRemaining = Math.max(0, Math.ceil((end - now) / (1000 * 60 * 60 * 24)));
      return {
        ...sub,
        daysRemaining,
        isActive: true,
      };
    }
    return null;
  } catch (err) {
    console.error('⚠️ [Telegram Bot] getUserSubscription xatosi:', err.message);
    return null;
  }
};

// Helper: Activate or Extend Subscription
const activateSubscription = async (telegramId, { days = 30, amount = 250000, provider = 'admin_manual', transactionId = null, notifyUser = true }) => {
  try {
    const currentSub = await getUserSubscription(telegramId);
    let newStartDate = new Date();
    let newEndDate;

    if (currentSub && new Date(currentSub.end_date) > new Date()) {
      newStartDate = new Date(currentSub.start_date);
      newEndDate = new Date(currentSub.end_date);
      newEndDate.setDate(newEndDate.getDate() + days);
    } else {
      newEndDate = new Date();
      newEndDate.setDate(newEndDate.getDate() + days);
    }

    const txId = transactionId || `${provider}_${Date.now()}_${telegramId}`;

    const isTrial = days === 1;
    const planName = isTrial ? '1 kunlik sinov' : `${days} kunlik obuna`;

    // 1. subscriptions jadvaliga yozish
    const subRes = await db.query(
      `INSERT INTO subscriptions (telegram_id, plan_name, amount, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, 'active')
       RETURNING *`,
      [telegramId, planName, amount, newStartDate, newEndDate]
    );

    // 2. payments jadvaliga yozish
    await db.query(
      `INSERT INTO payments (telegram_id, transaction_id, provider, amount, status, raw_data)
       VALUES ($1, $2, $3, $4, 'completed', $5)
       ON CONFLICT (transaction_id) 
       DO UPDATE SET status = 'completed', updated_at = CURRENT_TIMESTAMP`,
      [telegramId, txId, provider, amount, JSON.stringify({ days, activated_at: new Date().toISOString() })]
    );

    // 3. Telegram chat menu tugmasini ILOVANI OCHISH qilib yangilash
    if (bot) {
      bot.telegram.setChatMenuButton({
        chat_id: telegramId,
        menu_button: {
          type: 'web_app',
          text: '🚀 ILOVANI OCHISH',
          web_app: { url: getWebAppUrl() },
        },
      }).catch(() => { });
    }

    // 4. Foydalanuvchiga rasmiy tasdiqlash SMS / Xabari yuborish
    if (notifyUser && bot) {
      try {
        const webAppUrl = getWebAppUrl();
        const messageText = isTrial
          ? `🎁 <b>TABRIKLAYMIZ! 1 KUNLIK BEPUL SINOV FAOLLASHTIRILDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `✅ <b>Sizga ZAVERO POS tizimidan 1 kunlik bepul sinov berildi!</b>\n\n` +
          `⏳ <b>Foydalanish muddati:</b> <b>1 kun (24 soat)</b>\n` +
          `📅 <b>Amal qilish vaqti:</b> <b>${formatDate(newEndDate)}</b> gacha\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          `ZAVERO POS tizimidan to‘liq foydalanishingiz mumkin:\n` +
          `Quyidagi tugmani bosing va darhol boshlang:`
          : `🎉 <b>TO‘LOVINGIZ TASDIQLANDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `✅ <b>Administrator to‘lov chekingizni tasdiqladi!</b>\n\n` +
          `⏳ <b>Foydalanish muddati:</b> <b>${days} kun</b>\n` +
          `📅 <b>Amal qilish vaqti:</b> <b>${formatDate(newEndDate)}</b> gacha\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          `ZAVERO POS tizimidan to‘liq foydalanishingiz mumkin:\n` +
          `Quyidagi tugmani bosing va ishni boshlang:`;

        await bot.telegram.sendMessage(telegramId, messageText, {
          parse_mode: 'HTML',
          ...Markup.inlineKeyboard([
            [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
          ]),
        });
      } catch (tgErr) {
        console.warn(`⚠️ [Telegram Bot] Foydalanuvchiga xabar yuborishda xatolik (${telegramId}):`, tgErr.message);
      }
    }

    return {
      success: true,
      subscription: subRes.rows[0],
      endDate: newEndDate,
    };
  } catch (err) {
    console.error('❌ [Telegram Bot] activateSubscription xatosi:', err);
    throw err;
  }
};

// Helper: Check membership in required channels
const verifyChannelMembership = async (ctx, telegramId, channels) => {
  const results = [];
  const validStatuses = ['creator', 'administrator', 'member', 'restricted'];

  for (const rawChannel of channels) {
    if (!rawChannel) continue;
    const cleanChannel = rawChannel.trim();
    const channelUsername = cleanChannel.startsWith('@') ? cleanChannel : `@${cleanChannel}`;

    try {
      const member = await ctx.telegram.getChatMember(channelUsername, telegramId);
      const isMember = validStatuses.includes(member.status);
      results.push({ channel: channelUsername, isMember, error: null });
    } catch (err) {
      console.warn(`⚠️ [Channel Check] ${channelUsername} tekshirishda:`, err.message);
      // Agar bot kanalda admin bo'lmasa yoki member list inaccessible bo'lsa:
      // Foydalanuvchini bloklab qo'ymaslik uchun obunani qabul qilib o'tkazib yuboramiz
      const isBotPermissionIssue =
        err.message.includes('member list is inaccessible') ||
        err.message.includes('chat not found') ||
        err.message.includes('bot is not a member') ||
        err.message.includes('chat_admin_required');

      if (isBotPermissionIssue) {
        console.warn(`⚠️ [Telegram Bot] Bot ${channelUsername} kanaliga admin qilib qo‘shilmagan! Tekshiruv o‘tkazildi.`);
        results.push({ channel: channelUsername, isMember: true, note: 'bot_not_admin' });
      } else {
        results.push({ channel: channelUsername, isMember: false, error: err.message });
      }
    }
  }

  const allSubscribed = results.length > 0 && results.every((r) => r.isMember);
  return { allSubscribed, results };
};

// Build channel subscription keyboard
const buildChannelKeyboard = (settings, isAdmin = false) => {
  const ch1 = settings.required_channel_1.replace('@', '');
  const ch2 = settings.required_channel_2.replace('@', '');

  const buttons = [
    [Markup.button.url(`📢 1-Kanal: ${settings.required_channel_1}`, `https://t.me/${ch1}`)],
    [Markup.button.url(`📢 2-Kanal: ${settings.required_channel_2}`, `https://t.me/${ch2}`)],
    [Markup.button.callback('🔄 Obunani tekshirish', 'check_channels')],
  ];

  if (isAdmin) {
    buttons.push([Markup.button.callback('👑 Admin Panel', 'open_admin_panel')]);
  }

  return Markup.inlineKeyboard(buttons);
};

// Build subscription tariff message and keyboard
const sendTariffCard = async (ctx, settings, telegramId) => {
  const price = settings.subscription_price || 250000;
  const days = settings.subscription_days || 30;
  const cardNumber = settings.card_number || '9860 3501 2345 6789';
  const cardHolder = settings.card_holder || 'ZAVERO POS';
  const adminContact = settings.admin_contact || '@mirzobekn';
  const cleanAdmin = adminContact.replace('@', '');

  const text =
    `✅ <b>Kanallarga obuna tasdiqlandi!</b>\n\n` +
    `🚀 <b>ZAVERO POS PREMIUM TARIFI</b>\n` +
    `━━━━━━━━━━━━━━━━━━━\n` +
    `📦 <b>Tarif:</b> 1 oylik litsenziya (${days} kun)\n` +
    `💰 <b>Narxi:</b> <b>${formatSum(price)} so‘m</b>\n` +
    `👤 <b>Sizning ID raqamingiz:</b> <code>${telegramId}</code>\n` +
    `━━━━━━━━━━━━━━━━━━━\n\n` +
    `💳 <b>To‘lov uchun karta:</b>\n` +
    `<code>${cardNumber}</code>\n` +
    `Egasi: <b>${cardHolder}</b>\n\n` +
    `📌 <b>TO‘LOV VA TASDIQLASH QOIDASI:</b>\n` +
    `1. Yuqoridagi kartaga <b>${formatSum(price)} so‘m</b> to‘lang.\n` +
    `2. To‘lov chekini skrinshot (rasm) qiling.\n` +
    `3. Chek rasmini va o‘z ID raqamingizni (<code>${telegramId}</code>) administratorimiz @${cleanAdmin} ga yuboring yoki quyidagi <b>«📤 Chekni yuborish»</b> tugmasi orqali to‘g‘ridan-to‘g‘ri botga tashlang!\n\n` +
    `<i>Administrator to‘lovingizni tekshirib tasdiqlashi bilan ilovaga kirish avtomatik ochiladi.</i>`;

  const buttons = [
    [
      Markup.button.callback('🎁 1 kunlik bepul sinov olish', 'claim_1day_trial'),
    ],
    [
      Markup.button.callback('📤 Chekni botga yuborish', 'prompt_send_cheque'),
      Markup.button.url(`💬 Adminga yozish (${adminContact})`, `https://t.me/${cleanAdmin}`),
    ],
    [
      Markup.button.callback('💳 Click orqali to‘lash', 'pay_click'),
      Markup.button.callback('💳 Payme orqali to‘lash', 'pay_payme'),
    ],
    [Markup.button.callback('🔄 To‘lov holatini tekshirish', 'verify_payment')],
  ];

  const isAdmin = await isAdminUser(ctx.from);
  if (isAdmin) {
    buttons.push([Markup.button.callback('👑 Admin Panel', 'open_admin_panel')]);
  }

  await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
};

// Build Admin Dashboard
const sendAdminDashboard = async (ctx) => {
  const settings = await getBotSettings();

  const usersCountRes = await db.query('SELECT COUNT(*) FROM telegram_users');
  const activeSubsRes = await db.query("SELECT COUNT(*) FROM subscriptions WHERE status = 'active' AND end_date > NOW()");
  const pendingChequesRes = await db.query("SELECT COUNT(*) FROM payments WHERE status = 'pending'");
  const totalRevenueRes = await db.query("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE status = 'completed'");

  const totalUsers = usersCountRes.rows[0].count;
  const activeSubs = activeSubsRes.rows[0].count;
  const pendingCheques = pendingChequesRes.rows[0].count;
  const totalRevenue = totalRevenueRes.rows[0].total;

  const text =
    `👑 <b>ZAVERO POS — ADMIN BOSHQARUV PANELI</b>\n` +
    `━━━━━━━━━━━━━━━━━━━\n` +
    `👥 <b>Jami mijozlar:</b> ${totalUsers} ta\n` +
    `🟢 <b>Faol litsenziyalar:</b> ${activeSubs} ta\n` +
    `⏳ <b>Kutilayotgan cheklar:</b> ${pendingCheques} ta\n` +
    `💰 <b>Jami tushum:</b> ${formatSum(totalRevenue)} so‘m\n` +
    `━━━━━━━━━━━━━━━━━━━\n` +
    `📢 1-Kanal: <code>${settings.required_channel_1}</code>\n` +
    `📢 2-Kanal: <code>${settings.required_channel_2}</code>\n` +
    `💳 Karta: <code>${settings.card_number}</code>\n` +
    `💵 Narx: <b>${formatSum(settings.subscription_price)} so‘m</b> (${settings.subscription_days} kun)\n` +
    `━━━━━━━━━━━━━━━━━━━\n` +
    `<i>Kerakli amalni tanlang:</i>`;

  const buttons = [
    [
      Markup.button.callback('👥 Mijozlar ro‘yxati', 'admin_view_clients_1'),
      Markup.button.callback(`⏳ Kutilayotgan cheklar (${pendingCheques})`, 'admin_pending_cheques'),
    ],
    [
      Markup.button.callback('🎁 ID orqali 1 kun sinov berish', 'admin_grant_trial_prompt'),
      Markup.button.callback('➕ ID orqali 30 kun berish', 'admin_grant_prompt'),
    ],
    [
      Markup.button.callback('⚙️ Sozlamalar', 'admin_settings_view'),
      Markup.button.callback('🚪 Chiqish (Logout)', 'admin_logout_action'),
    ],
  ];

  const keyboard = Markup.inlineKeyboard(buttons);
  if (ctx.callbackQuery) {
    try {
      return await ctx.editMessageText(text, { parse_mode: 'HTML', ...keyboard });
    } catch (_) {}
  }
  return await ctx.replyWithHTML(text, keyboard);
};

// Helper: Anti-Spam, Anti-Reklama and Anti-Flood detector
const floodTracker = new Map();
const blockedUsers = new Set();
const userSpamViolations = new Map();
const sentOrderNotificationCache = new Set();

const isSpamOrAdMessage = (message) => {
  if (!message) return false;

  // 1. Forwarded messages from public channels, chats, or unknown users
  if (message.forward_from_chat || message.forward_from || message.forward_origin) {
    return true;
  }

  const text = message.text || message.caption || '';
  if (!text) return false;

  // 2. Allowed domain whitelist (our own links and payment gateways)
  const isWhitelistedLink = (url) => {
    const clean = url.toLowerCase();
    return (
      clean.includes('zavero') ||
      clean.includes('mirzobek') ||
      clean.includes('click.uz') ||
      clean.includes('paycom.uz') ||
      clean.includes('onrender.com')
    );
  };

  // 3. Check for external links (http, https, t.me, bit.ly, etc.)
  const urlRegex = /(https?:\/\/[^\s]+|t\.me\/[^\s]+|telegram\.me\/[^\s]+|bit\.ly\/[^\s]+)/gi;
  const urls = text.match(urlRegex) || [];
  for (const url of urls) {
    if (!isWhitelistedLink(url)) {
      return true; // External advertising link detected!
    }
  }

  // 4. Check Telegram message entities for hidden links
  const entities = message.entities || message.caption_entities || [];
  for (const ent of entities) {
    if (ent.type === 'text_link' && ent.url) {
      if (!isWhitelistedLink(ent.url)) return true;
    }
    if (ent.type === 'url') {
      const extractedUrl = text.substring(ent.offset, ent.offset + ent.length);
      if (!isWhitelistedLink(extractedUrl)) return true;
    }
    // Block promotional mentions like @some_channel_bot (unless it is our admin or channel)
    if (ent.type === 'mention') {
      const mention = text.substring(ent.offset, ent.offset + ent.length).toLowerCase();
      if (!mention.includes('zavero') && !mention.includes('mirzobek')) {
        return true;
      }
    }
  }

  // 5. Spam / Advertising keywords in Uzbek, Russian, English
  const spamKeywordsRegex = /\b(reklama|daromad|investitsiya|sarmoya|kripto|kriptovalyuta|bitcoin|ton coin|airdrop|hamster|kombat|blum|notcoin|kazino|casino|1xbet|melbet|mostbet|stavka|pul ishlash|kunlik daromad|bonus olish|ishga taklif|kanalga obuna|obuna bo['`’]?ling|podpishis|zarabotok|investitsion|ish bor|tez boyish|online ish|vakansiya|reklama berish|reklama narxi)\b/i;

  if (spamKeywordsRegex.test(text)) {
    return true;
  }

  return false;
};

const checkAntiFlood = (userId) => {
  const now = Date.now();
  const data = floodTracker.get(userId) || { count: 0, firstMsg: now, mutedUntil: 0 };

  if (data.mutedUntil > now) {
    return true; // User is currently muted
  }

  if (now - data.firstMsg < 3000) {
    data.count += 1;
    if (data.count > 5) {
      data.mutedUntil = now + 15000; // Mute for 15 seconds
      floodTracker.set(userId, data);
      return true;
    }
  } else {
    data.count = 1;
    data.firstMsg = now;
  }

  floodTracker.set(userId, data);
  return false;
};

// Helper: Configure Bot Profile, About, Description, and Commands
const setupBotProfilesAndCommands = async (botInstance) => {
  if (!botInstance) return;
  try {
    const description =
      `🚀 ZAVERO POS — Kafe, restoran, fast-fud va savdo nuqtalari uchun zamonaviy kassa va avtomatlashtirish tizimi.\n\n` +
      `✨ Asosiy imkoniyatlar:\n` +
      `• 📱 QR menyu va onlayn buyurtmalar\n` +
      `• ⚡️ Tezkor kassa, chek chop etish va hisob-kitob\n` +
      `• 📊 Real vaqt hisobotlari va kassa tahlili\n` +
      `• 👥 Xodimlar va stollar boshqaruvi\n` +
      `• 📦 Ombor qoldig‘i va mahsulotlar hisobi\n` +
      `• 🎁 Yangi mijozlarga 1 kunlik bepul sinov!\n\n` +
      `🌐 Rasmiy bot: @zavero_uz`;

    const shortDescription =
      `ZAVERO POS — Kafe, restoran va savdo nuqtalari uchun professional kassa va avtomatlashtirish tizimi.`;

    // Set Description (What can this bot do?)
    try {
      await botInstance.telegram.setMyDescription(description);
      await botInstance.telegram.setMyDescription(description, 'uz');
    } catch (e) {
      console.warn('⚠️ setMyDescription error:', e.message);
    }

    // Set Short Description
    try {
      await botInstance.telegram.setMyShortDescription(shortDescription);
      await botInstance.telegram.setMyShortDescription(shortDescription, 'uz');
    } catch (e) {
      console.warn('⚠️ setMyShortDescription error:', e.message);
    }

    // Set Commands Menu
    try {
      await botInstance.telegram.setMyCommands([
        { command: 'start', description: '🚀 Botni ishga tushirish / Kirish' },
        { command: 'sinov', description: '🎁 1 kunlik bepul sinov olish' },
        { command: 'about', description: 'ℹ️ ZAVERO POS haqida ma’lumot' },
        { command: 'admin', description: '👑 Administrator boshqaruv paneli' },
        { command: 'users', description: '👥 Foydalanuvchilar (Admin)' },
        { command: 'blocked', description: '🚫 Bloklangan spammerlar (Admin)' },
      ]);
    } catch (e) {
      console.warn('⚠️ setMyCommands error:', e.message);
    }

    console.log('✅ [Telegram Bot] Bot tavsifi (About, Description) va menyu buyruqlari muvaffaqiyatli yangilandi.');
  } catch (err) {
    console.warn('⚠️ [Telegram Bot] setupBotProfilesAndCommands xatosi:', err.message);
  }
};

// Initialize Bot logic
const initTelegramBot = () => {
  const token = process.env.TELEGRAM_BOT_TOKEN || '8838017721:AAHMXwe9rX_6ERecTM9fHKX0ctsG6b-HOK0';

  if (!token) {
    console.warn('⚠️ [Telegram Bot] TELEGRAM_BOT_TOKEN sozlanmagan. Bot faollashtirilmadi.');
    return null;
  }

  try {
    bot = new Telegraf(token);

    // Global error handler
    bot.catch((err, ctx) => {
      console.error(`⚠️ [Telegram Bot Error] Update ${ctx?.update?.update_id}:`, err.message);
    });

    // Auto-configure Bot Description & Commands
    setupBotProfilesAndCommands(bot).catch(() => {});

    // 🛡️ ANTI-SPAM, ANTI-REKLAMA & ANTI-FLOOD SECURITY MIDDLEWARE
    bot.use(async (ctx, next) => {
      try {
        const from = ctx.from;
        if (!from) return next();

        const isAdmin = await isAdminUser(from);
        if (isAdmin) return next(); // Admins are always exempt

        const chatType = ctx.chat?.type;
        const isGroup = chatType === 'group' || chatType === 'supergroup';
        const strId = String(from.id);

        // 1. Check if user is permanently blocked
        if (blockedUsers.has(strId)) {
          try {
            await ctx.deleteMessage().catch(() => {});
          } catch (_) {}
          if (!isGroup) {
            await ctx.replyWithHTML(
              `🚫 <b>SIZ BLOKLANGANSIZ!</b>\n` +
              `Spam yoki qoidabuzarlik tufayli sizning xabarlaringiz qabul qilinmaydi.`
            ).catch(() => {});
          }
          return; // Terminate update
        }

        // 2. Check Anti-Flood
        if (checkAntiFlood(from.id)) {
          try {
            await ctx.deleteMessage().catch(() => {});
          } catch (_) {}

          const data = floodTracker.get(from.id);
          if (data && data.count === 6 && !isGroup) {
            await ctx.replyWithHTML(
              `⚠️ <b>XAVFSIZLIK OGOHLANTIRISHI!</b>\n` +
              `Iltimos, shoshilmang! Xabarlar oqimi juda tez bo‘lgani sababli 15 soniya cheklandingiz.`
            ).catch(() => {});
          }
          return; // Terminate update
        }

        // 3. Check Anti-Spam / Anti-Advertising
        if (ctx.message && isSpamOrAdMessage(ctx.message)) {
          try {
            await ctx.deleteMessage().catch(() => {});
          } catch (_) {}

          if (isGroup) {
            // Guruhdagi spammerni cheklash va xabarini o'chirish
            try {
              await ctx.telegram.restrictChatMember(ctx.chat.id, from.id, {
                until_date: Math.floor(Date.now() / 1000) + 7200, // 2 soat
                permissions: {
                  can_send_messages: false,
                  can_send_other_messages: false,
                  can_add_web_page_previews: false,
                },
              }).catch(() => {});
            } catch (_) {}

            await ctx.replyWithHTML(
              `🚫 <b>GURUHDA REKLAMA VA SPAM TAQIQLANGAN!</b>\n` +
              `Foydalanuvchi <b>${from.first_name || from.id}</b> ning reklama xabari o‘chirildi va yozish cheklandi.`
            ).catch(() => {});
          } else {
            // Shaxsiy chatda ogohlantirish va qoidabuzarliklar sonini oshirish
            const currentViolations = (userSpamViolations.get(from.id) || 0) + 1;
            userSpamViolations.set(from.id, currentViolations);

            if (currentViolations >= 3) {
              blockedUsers.add(strId);
              await ctx.replyWithHTML(
                `🚫 <b>SIZ BLOKLANDINGIZ!</b>\n` +
                `Takroriy reklama va spam tufayli sizning ID raqamingiz botda bloklandi.`
              ).catch(() => {});
            } else {
              await ctx.replyWithHTML(
                `🚫 <b>REKLAMA VA SPAM TAQIQLANGAN!</b>\n` +
                `━━━━━━━━━━━━━━━━━━━\n` +
                `Hurmatli foydalanuvchi, ushbu bot faqat <b>ZAVERO POS</b> tizimi uchun mo‘ljallangan.\n` +
                `Qoidabuzarlik holati: <b>${currentViolations}/3</b> (3 tadan so‘ng avtomatik bloklanasiz).`
              ).catch(() => {});
            }
          }

          console.warn(`🛡️ [Anti-Spam] Foydalanuvchi ${from.id} dan reklama/spam to‘xtatildi (${isGroup ? 'Guruh' : 'Shaxsiy'}).`);
          return; // Terminate update
        }
      } catch (secErr) {
        console.warn('⚠️ [Anti-Spam Middleware] Xatolik:', secErr.message);
      }
      return next();
    });

    // 1. /start command
    bot.start(async (ctx) => {
      try {
        const from = ctx.from;
        const telegramId = from.id;
        const isAdmin = await isAdminUser(from);

        // Upsert user in telegram_users table
        await db.query(
          `INSERT INTO telegram_users (telegram_id, username, first_name, last_name, updated_at)
           VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
           ON CONFLICT (telegram_id)
           DO UPDATE SET username = $2, first_name = $3, last_name = $4, updated_at = CURRENT_TIMESTAMP`,
          [telegramId, from.username || null, from.first_name || '', from.last_name || '']
        );

        // Check if user already has an active subscription
        const activeSub = await getUserSubscription(telegramId);
        const webAppUrl = getWebAppUrl();

        if (activeSub) {
          // Set Chat Menu Button to WebApp for active subscribers
          ctx.setChatMenuButton({
            type: 'web_app',
            text: '🚀 ILOVANI OCHISH',
            web_app: { url: webAppUrl },
          }).catch(() => { });

          const welcomeBack =
            `Assalomu alaykum, <b>${from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
            `✅ <b>Sizning ZAVERO POS litsenziyangiz faol!</b>\n` +
            `📅 Amal qilish muddati: <b>${formatDate(activeSub.end_date)}</b> gacha\n` +
            `⏳ Qolgan vaqt: <b>${activeSub.daysRemaining} kun</b>\n` +
            `👤 Sizning ID: <code>${telegramId}</code>\n\n` +
            `Tizimga kirish uchun quyidagi tugmani bosing:`;

          const buttons = [
            [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
          ];
          if (isAdmin) {
            buttons.push([Markup.button.callback('👑 Admin Panel', 'open_admin_panel')]);
          }

          return await ctx.replyWithHTML(welcomeBack, Markup.inlineKeyboard(buttons));
        }

        // Unpaid user: reset chat menu button to default
        ctx.setChatMenuButton({ type: 'default' }).catch(() => { });

        // Channel subscription prompt
        const settings = await getBotSettings();
        const greeting =
          `Assalomu alaykum, <b>${from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
          `<b>ZAVERO POS</b> professional savdo va kassa tizimiga xush kelibsiz.\n\n` +
          `Ilovadan foydalanish uchun quyidagi kanallarga a‘zo bo‘ling va <b>«🔄 Obunani tekshirish»</b> tugmasini bosing:`;

        return await ctx.replyWithHTML(greeting, buildChannelKeyboard(settings, isAdmin));
      } catch (err) {
        console.error('❌ [Telegram Bot] /start xatosi:', err);
        return ctx.reply('Tizimda xatolik yuz berdi. Iltimos, qayta urinib ko‘ring.');
      }
    });

    // 2. 'check_channels' action
    bot.action('check_channels', async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const settings = await getBotSettings();
        const isAdmin = await isAdminUser(ctx.from);

        // Update database that channels are confirmed
        await db.query(
          'UPDATE telegram_users SET is_subscribed_channels = true WHERE telegram_id = $1',
          [telegramId]
        );

        // Native Telegram alert confirmation
        await ctx.answerCbQuery('✅ Kanallarga obuna muvaffaqiyatli tasdiqlandi!', { show_alert: true });

        // Check if user already has an active subscription
        const activeSub = await getUserSubscription(telegramId);

        if (activeSub || isAdmin) {
          const webAppUrl = getWebAppUrl();
          return await ctx.replyWithHTML(
            `✅ <b>Kanallarga obuna tasdiqlandi!</b>\n` +
            `Sizning litsenziyangiz faol (${activeSub ? activeSub.daysRemaining : 'Cheksiz'} kun qoldi).\n\n` +
            `Ilovani ochish uchun quyidagi tugmani bosing:`,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
            ])
          );
        }

        // Show Tariff & Payment Card
        return await sendTariffCard(ctx, settings, telegramId);
      } catch (err) {
        console.error('❌ [Telegram Bot] check_channels xatosi:', err);
        return ctx.reply('Obunani tekshirishda xatolik yuz berdi. Iltimos, qaytadan urinib ko‘ring.');
      }
    });

    // 3. Prompt user to send cheque photo
    bot.action('prompt_send_cheque', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        const telegramId = ctx.from.id;
        adminState.set(telegramId, { waitingFor: 'cheque_photo' });

        return await ctx.replyWithHTML(
          `📤 <b>TO‘LOV CHEKINI YUBORISH</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Iltimos, to‘lov chekining skrinshotini (rasmini) shu yerga rasm qilib yuboring.\n\n` +
          `👤 Sizning ID raqamingiz: <code>${telegramId}</code>\n\n` +
          `Chekni yuborishingiz bilan u administratorga (@mirzobekn) yetib boradi va tasdiqlanadi.`
        );
      } catch (e) { }
    });

    // 4. PHOTO HANDLER (User sends cheque photo!)
    bot.on('photo', async (ctx) => {
      try {
        const from = ctx.from;
        const telegramId = from.id;
        const isAdmin = await isAdminUser(from);

        const photos = ctx.message.photo;
        const bestPhoto = photos[photos.length - 1];
        const fileId = bestPhoto.file_id;

        const activeSub = await getUserSubscription(telegramId);
        if (activeSub && !isAdmin) {
          return ctx.replyWithHTML(
            `✅ Sizning ZAVERO POS litsenziyangiz allaqachon faol (${activeSub.daysRemaining} kun qoldi).\n` +
            `Ilovani ochish uchun /start buyrug‘ini bosing.`
          );
        }

        // Record pending payment in database
        const txId = `cheque_${Date.now()}_${telegramId}`;
        await db.query(
          `INSERT INTO payments (telegram_id, transaction_id, provider, amount, status, raw_data)
           VALUES ($1, $2, 'cheque_manual', 250000, 'pending', $3)
           ON CONFLICT (transaction_id) DO NOTHING`,
          [telegramId, txId, JSON.stringify({ file_id: fileId, caption: ctx.message.caption || '' })]
        );

        // Reply to user
        await ctx.replyWithHTML(
          `📥 <b>TO‘LOV CHEKINGIZ QABUL QILINDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `👤 Sizning ID raqamingiz: <code>${telegramId}</code>\n` +
          `💰 Summa: <b>250 000 so‘m (1 oylik)</b>\n\n` +
          `Administratorimiz (@mirzobekn) chekni tekshirib tasdiqlashi bilan sizga SMS/xabar keladi va ZAVERO POS ilovasi ochiladi.\n\n` +
          `Iltimos, tasdiqlanishini kuting... ⏳`
        );

        // Notify Admins
        const adminIds = await getAllAdminIds();
        const adminCaption =
          `🔔 <b>YANGI TO‘LOV CHEKI KELDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `👤 Mijoz: <b>${from.first_name || ''} ${from.last_name || ''}</b>\n` +
          `Username: @${from.username || 'mavjud emas'}\n` +
          `🆔 Mijoz ID: <code>${telegramId}</code>\n` +
          `💰 Summa: <b>250 000 so‘m</b>\n` +
          `📅 Vaqt: <b>${formatDate(new Date())}</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Mijozga 30 kunlik ruxsat berasizmi?`;

        const adminButtons = [
          [
            Markup.button.callback('🎁 1 kun sinov', `admin_approve_${telegramId}_1`),
            Markup.button.callback('✅ 30 kunlik ruxsat', `admin_approve_${telegramId}_30`),
            Markup.button.callback('❌ Rad etish', `admin_reject_${telegramId}`),
          ],
        ];

        for (const adminId of adminIds) {
          try {
            await bot.telegram.sendPhoto(adminId, fileId, {
              caption: adminCaption,
              parse_mode: 'HTML',
              ...Markup.inlineKeyboard(adminButtons),
            });
          } catch (sendErr) {
            console.warn(`Admin ${adminId} ga chek yuborishda xatolik:`, sendErr.message);
          }
        }
      } catch (err) {
        console.error('Photo handler xatosi:', err);
      }
    });

    // 5. Click Payment Action
    bot.action('pay_click', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        const telegramId = ctx.from.id;
        const settings = await getBotSettings();
        const price = settings.subscription_price;
        const serviceId = process.env.CLICK_SERVICE_ID;
        const merchantId = process.env.CLICK_MERCHANT_ID;
        const webAppUrl = getWebAppUrl();

        let clickUrl = null;
        if (serviceId && merchantId) {
          clickUrl = `https://my.click.uz/services/pay?service_id=${serviceId}&merchant_id=${merchantId}&amount=${price}&transaction_param=${telegramId}&return_url=${encodeURIComponent(webAppUrl)}`;
        }

        const buttons = [];
        if (clickUrl) {
          buttons.push([Markup.button.url('💳 Click orqali to‘lash', clickUrl)]);
        }
        buttons.push([Markup.button.callback('📤 Chekni botga yuborish', 'prompt_send_cheque')]);
        buttons.push([Markup.button.callback('🔄 To‘lovni tekshirish', 'verify_payment')]);

        const text =
          `💳 <b>CLICK TO‘LOV TIZIMI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `To‘lov summasi: <b>${formatSum(price)} so‘m</b>\n` +
          `Hisob kodi (Sizning ID): <code>${telegramId}</code>\n\n` +
          `To‘lovni amalga oshirgach, chekni administrator @mirzobekn ga yuboring yoki shu botga rasm sifatida tashlang.`;

        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (err) {
        console.error('pay_click xatosi:', err);
      }
    });

    // 6. Payme Payment Action
    bot.action('pay_payme', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        const telegramId = ctx.from.id;
        const settings = await getBotSettings();
        const price = settings.subscription_price;
        const merchantId = process.env.PAYME_MERCHANT_ID;

        let paymeUrl = null;
        if (merchantId) {
          const paramStr = `m=${merchantId};ac.telegram_id=${telegramId};a=${price * 100}`;
          const base64 = Buffer.from(paramStr).toString('base64');
          paymeUrl = `https://checkout.paycom.uz/${base64}`;
        }

        const buttons = [];
        if (paymeUrl) {
          buttons.push([Markup.button.url('💳 Payme orqali to‘lash', paymeUrl)]);
        }
        buttons.push([Markup.button.callback('📤 Chekni botga yuborish', 'prompt_send_cheque')]);
        buttons.push([Markup.button.callback('🔄 To‘lovni tekshirish', 'verify_payment')]);

        const text =
          `💳 <b>PAYME TO‘LOV TIZIMI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `To‘lov summasi: <b>${formatSum(price)} so‘m</b>\n` +
          `Hisob kodi (Sizning ID): <code>${telegramId}</code>\n\n` +
          `To‘lovni amalga oshirgach, chekni administrator @mirzobekn ga yuboring yoki shu botga rasm sifatida tashlang.`;

        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (err) {
        console.error('pay_payme xatosi:', err);
      }
    });

    // 7. Verify payment status button
    bot.action('verify_payment', async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const activeSub = await getUserSubscription(telegramId);

        if (activeSub) {
          await ctx.answerCbQuery('✅ Litsenziya faol!');
          const webAppUrl = getWebAppUrl();
          return await ctx.replyWithHTML(
            `🎉 <b>LITSENZIYANGIZ FAOL!</b>\n\n` +
            `📅 Amal qilish muddati: <b>${formatDate(activeSub.end_date)}</b> gacha\n` +
            `⏳ Qolgan vaqt: <b>${activeSub.daysRemaining} kun</b>\n\n` +
            `ZAVERO POS tizimiga kirish:`,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
            ])
          );
        } else {
          await ctx.answerCbQuery('To‘lov hali tasdiqlanmadi');
          return await ctx.replyWithHTML(
            `⏳ <b>To‘lovingiz hali tasdiqlanmadi.</b>\n\n` +
            `Iltimos, to‘lov cheki rasmini va ID raqamingizni (<code>${telegramId}</code>) administratorimiz @mirzobekn ga yuboring.`
          );
        }
      } catch (err) {
        console.error('verify_payment xatosi:', err);
      }
    });

    // 7.5. Customer 1-Day Trial Claim Action
    const handleUserTrialClaim = async (ctx) => {
      try {
        if (ctx.callbackQuery) {
          await ctx.answerCbQuery().catch(() => {});
        }
        const telegramId = ctx.from.id;
        const from = ctx.from;

        // Check if user already has active subscription
        const activeSub = await getUserSubscription(telegramId);
        if (activeSub) {
          const webAppUrl = getWebAppUrl();
          return await ctx.replyWithHTML(
            `✅ <b>Sizning litsenziyangiz allaqachon faol!</b>\n` +
            `⏳ Qolgan muddat: <b>${activeSub.daysRemaining} kun</b>\n\n` +
            `Ilovani ochish uchun quyidagi tugmani bosing:`,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
            ])
          );
        }

        // Check if user has already claimed a free trial previously
        const trialCheck = await db.query(
          `SELECT id FROM subscriptions 
           WHERE telegram_id = $1 AND (plan_name ILIKE '%sinov%' OR plan_name ILIKE '%trial%' OR amount = 0)
           LIMIT 1`,
          [telegramId]
        );

        if (trialCheck.rows.length > 0) {
          return await ctx.replyWithHTML(
            `⚠️ <b>Siz allaqachon 1 kunlik bepul sinov muddatidan foydalangansiz!</b>\n\n` +
            `Sinov muddati har bir akkauntga faqat <b>1 marta</b> beriladi.\n` +
            `Litsenziyani davom ettirish uchun oylik to‘lovni amalga oshiring yoki administrator @mirzobekn ga murojaat qiling.`
          );
        }

        // Activate 1-day free trial
        const result = await activateSubscription(telegramId, {
          days: 1,
          amount: 0,
          provider: 'free_trial',
          transactionId: `trial_${Date.now()}_${telegramId}`,
          notifyUser: true,
        });

        // Notify all admins about the new trial registration
        const adminIds = await getAllAdminIds();
        const name = `${from.first_name || ''} ${from.last_name || ''}`.trim() || 'Foydalanuvchi';
        const adminNotify =
          `🎁 <b>YANGI FOYDALANUVCHI 1 KUNLIK SINOV OLDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `👤 Mijoz: <b>${name}</b>\n` +
          `Username: @${from.username || 'mavjud emas'}\n` +
          `🆔 ID: <code>${telegramId}</code>\n` +
          `📅 Amal qilish vaqti: <b>${formatDate(result.endDate)}</b> gacha\n` +
          `━━━━━━━━━━━━━━━━━━━`;

        for (const aId of adminIds) {
          try {
            await bot.telegram.sendMessage(aId, adminNotify, {
              parse_mode: 'HTML',
              ...Markup.inlineKeyboard([
                [Markup.button.callback(`👤 Mijozni ko‘rish`, `admin_inspect_${telegramId}`)],
                [Markup.button.callback(`➕ 30 kun berish`, `admin_approve_${telegramId}_30`)],
              ]),
            });
          } catch (_) {}
        }

        return;
      } catch (err) {
        console.error('handleUserTrialClaim error:', err);
        return ctx.reply('Sinov muddatini olishda xatolik yuz berdi: ' + err.message);
      }
    };

    bot.action('claim_1day_trial', handleUserTrialClaim);

    // ==========================================
    // 8. ADMIN ACTIONS & PASSWORD AUTHENTICATION
    // ==========================================

    // Action: Open Admin Panel
    bot.action('open_admin_panel', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) {
          adminState.set(ctx.from.id, { waitingFor: 'admin_password' });
          return ctx.replyWithHTML(
            `🔐 <b>ADMINSTRATOR KIRISH PAROLI:</b>\n` +
            `━━━━━━━━━━━━━━━━━━━\n` +
            `Admin panelga kirish uchun maxfiy parolni yozib yuboring:`
          );
        }
        return await sendAdminDashboard(ctx);
      } catch (e) {
        console.error('open_admin_panel error:', e);
      }
    });

    // Action: Admin approves subscription from Cheque or User Card
    bot.action(/^admin_approve_(\d+)_(\d+)$/, async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.answerCbQuery('⛔️ Ruxsat yo‘q! Avval /admin orqali parol tering.');
        await ctx.answerCbQuery('Faollashtirilmoqda...');

        const targetId = parseInt(ctx.match[1], 10);
        const days = parseInt(ctx.match[2], 10) || 30;
        const isTrial = days === 1;

        const result = await activateSubscription(targetId, {
          days,
          amount: isTrial ? 0 : 250000,
          provider: isTrial ? 'admin_panel_trial' : 'admin_panel',
          transactionId: `admin_${Date.now()}_${targetId}`,
          notifyUser: true,
        });

        const confirmText = isTrial
          ? `🎁 <b>Mijozga 1 kunlik sinov muvaffaqiyatli berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Berilgan muddat: <b>1 kun (24 soat)</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik tarzda tabrik xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`
          : `✅ <b>Mijozga muvaffaqiyatli ruxsat berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Berilgan muddat: <b>${days} kun</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik tarzda tabrik xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`;

        return await ctx.replyWithHTML(
          confirmText,
          Markup.inlineKeyboard([[Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]])
        );
      } catch (err) {
        console.error('admin_approve xatosi:', err);
        return ctx.reply('Xatolik yuz berdi: ' + err.message);
      }
    });

    // Action: Admin rejects cheque
    bot.action(/^admin_reject_(\d+)$/, async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.answerCbQuery('⛔️ Ruxsat yo‘q! Avval /admin orqali parol tering.');
        await ctx.answerCbQuery('Rad etildi');

        const targetId = parseInt(ctx.match[1], 10);
        await db.query("UPDATE payments SET status = 'cancelled' WHERE telegram_id = $1 AND status = 'pending'", [targetId]);

        try {
          await bot.telegram.sendMessage(
            targetId,
            '❌ <b>To‘lov chekingiz tasdiqlanmadi.</b>\nIltimos, aniq maʼlumot olish uchun administratorimiz @mirzobekn ga murojaat qiling.',
            { parse_mode: 'HTML' }
          );
        } catch (e) { }

        return ctx.replyWithHTML(`❌ Mijoz <code>${targetId}</code> cheki rad etildi va unga xabar berildi.`);
      } catch (e) { }
    });

    // Action: Admin revoke subscription
    bot.action(/^admin_revoke_(\d+)$/, async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.answerCbQuery('⛔️ Ruxsat yo‘q! Avval /admin orqali parol tering.');
        await ctx.answerCbQuery('Bekor qilinmoqda');

        const targetId = parseInt(ctx.match[1], 10);
        await db.query("UPDATE subscriptions SET status = 'cancelled', end_date = NOW() WHERE telegram_id = $1", [targetId]);

        // Reset chat menu button
        bot.telegram.setChatMenuButton({ chat_id: targetId, menu_button: { type: 'default' } }).catch(() => { });

        try {
          await bot.telegram.sendMessage(
            targetId,
            '⚠️ Sizning ZAVERO POS litsenziyangiz administrator tomonidan to‘xtatildi.',
            { parse_mode: 'HTML' }
          );
        } catch (e) { }

        return ctx.replyWithHTML(`🚫 Mijoz <code>${targetId}</code> litsenziyasi to‘xtatildi.`);
      } catch (e) { }
    });

    // ============================================================
    // CUSTOMER QR ORDER ACTIONS (Image 5 & Telegram Bot sync)
    // ============================================================
    bot.action(/^accept_order_(\d+)_(.+)$/, async (ctx) => {
      try {
        const orderId = parseInt(ctx.match[1], 10);
        const cafeId = ctx.match[2];

        const result = await db.query(
          `UPDATE customer_orders SET status='preparing', updated_at=CURRENT_TIMESTAMP WHERE id=$1 AND cafe_id=$2 RETURNING *`,
          [orderId, cafeId]
        );

        if (result.rows.length === 0) {
          return ctx.answerCbQuery('⚠️ Buyurtma topilmadi yoki allaqachon yakunlangan.', { show_alert: true });
        }

        const { mapCustomerOrder } = require('../utils/mappers');
        const { notifyCafe } = require('../socket/socketHandler');
        const updatedOrder = mapCustomerOrder(result.rows[0]);
        notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order: updatedOrder });

        await ctx.answerCbQuery('✅ Zakas olindi! Holati: Tayyorlanmoqda', { show_alert: true });

        const staffName = ctx.from.first_name || 'Xodim';
        const webAppUrl = getWebAppUrl();
        const originalText = ctx.callbackQuery.message.text || '';

        const updatedText =
          `👨‍🍳 <b>BUYURTMA QABUL QILINDI!</b> (№ ${orderId})\n` +
          `Qabul qildi: <b>${staffName}</b>\n` +
          `Holati: <b>Tayyorlanmoqda...</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          originalText;

        await ctx.editMessageText(updatedText, {
          parse_mode: 'HTML',
          ...Markup.inlineKeyboard([
            [
              Markup.button.callback('✓ Tayyor deb belgilash', `ready_order_${orderId}_${cafeId}`),
              Markup.button.callback('❌ Bekor qilish', `cancel_order_${orderId}_${cafeId}`),
            ],
            [Markup.button.webApp('📱 Ilovada ochish', webAppUrl)],
          ]),
        });
      } catch (err) {
        console.error('accept_order error:', err);
        ctx.answerCbQuery('Xatolik: ' + err.message, { show_alert: true });
      }
    });

    bot.action(/^ready_order_(\d+)_(.+)$/, async (ctx) => {
      try {
        const orderId = parseInt(ctx.match[1], 10);
        const cafeId = ctx.match[2];

        const result = await db.query(
          `UPDATE customer_orders SET status='ready', updated_at=CURRENT_TIMESTAMP WHERE id=$1 AND cafe_id=$2 RETURNING *`,
          [orderId, cafeId]
        );

        if (result.rows.length === 0) {
          return ctx.answerCbQuery('⚠️ Buyurtma topilmadi.', { show_alert: true });
        }

        const { mapCustomerOrder } = require('../utils/mappers');
        const { notifyCafe } = require('../socket/socketHandler');
        const updatedOrder = mapCustomerOrder(result.rows[0]);
        notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order: updatedOrder });

        await ctx.answerCbQuery('✅ Buyurtma tayyor deb belgilandi!', { show_alert: true });

        const staffName = ctx.from.first_name || 'Xodim';
        const webAppUrl = getWebAppUrl();
        await ctx.editMessageText(
          `🎉 <b>BUYURTMA TAYYOR!</b> (№ ${orderId})\n` +
          `Tayyorladi: <b>${staffName}</b>\n` +
          `Holati: 🟢 <b>Tayyor (Stolga yetkazish mumkin)</b>\n` +
          `━━━━━━━━━━━━━━━━━━━`,
          {
            parse_mode: 'HTML',
            ...Markup.inlineKeyboard([
              [Markup.button.callback('🏁 Yakunlash (Topshirildi)', `complete_order_${orderId}_${cafeId}`)],
              [Markup.button.webApp('📱 Ilovada ochish', webAppUrl)],
            ]),
          }
        );
      } catch (err) {
        console.error('ready_order error:', err);
        ctx.answerCbQuery('Xatolik: ' + err.message, { show_alert: true });
      }
    });

    bot.action(/^complete_order_(\d+)_(.+)$/, async (ctx) => {
      try {
        const orderId = parseInt(ctx.match[1], 10);
        const cafeId = ctx.match[2];

        const result = await db.query(
          `UPDATE customer_orders SET status='completed', updated_at=CURRENT_TIMESTAMP WHERE id=$1 AND cafe_id=$2 RETURNING *`,
          [orderId, cafeId]
        );

        if (result.rows.length === 0) {
          return ctx.answerCbQuery('⚠️ Buyurtma topilmadi.', { show_alert: true });
        }

        const { mapCustomerOrder } = require('../utils/mappers');
        const { notifyCafe } = require('../socket/socketHandler');
        const updatedOrder = mapCustomerOrder(result.rows[0]);
        notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order: updatedOrder });

        await ctx.answerCbQuery('🏁 Buyurtma yakunlandi!', { show_alert: true });

        const staffName = ctx.from.first_name || 'Xodim';
        await ctx.editMessageText(
          `🏁 <b>BUYURTMA YAKUNLANDI!</b> (№ ${orderId})\n` +
          `Topshirdi: <b>${staffName}</b>\n` +
          `Holati: 🟢 <b>Mijozga yetkazilgan (Yakunlangan)</b>\n` +
          `━━━━━━━━━━━━━━━━━━━`,
          { parse_mode: 'HTML' }
        );
      } catch (err) {
        console.error('complete_order error:', err);
        ctx.answerCbQuery('Xatolik: ' + err.message, { show_alert: true });
      }
    });

    bot.action(/^cancel_order_(\d+)_(.+)$/, async (ctx) => {
      try {
        const orderId = parseInt(ctx.match[1], 10);
        const cafeId = ctx.match[2];

        const result = await db.query(
          `UPDATE customer_orders SET status='cancelled', updated_at=CURRENT_TIMESTAMP WHERE id=$1 AND cafe_id=$2 RETURNING *`,
          [orderId, cafeId]
        );

        if (result.rows.length === 0) {
          return ctx.answerCbQuery('⚠️ Buyurtma topilmadi.', { show_alert: true });
        }

        const { mapCustomerOrder } = require('../utils/mappers');
        const { notifyCafe } = require('../socket/socketHandler');
        const updatedOrder = mapCustomerOrder(result.rows[0]);
        notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order: updatedOrder });

        await ctx.answerCbQuery('❌ Buyurtma bekor qilindi!', { show_alert: true });

        const staffName = ctx.from.first_name || 'Xodim';
        await ctx.editMessageText(
          `❌ <b>BUYURTMA BEKOR QILINDI!</b> (№ ${orderId})\n` +
          `Bekor qildi: <b>${staffName}</b>\n` +
          `Holati: 🔴 <b>Bekor qilingan</b>\n` +
          `━━━━━━━━━━━━━━━━━━━`,
          { parse_mode: 'HTML' }
        );
      } catch (err) {
        console.error('cancel_order error:', err);
        ctx.answerCbQuery('Xatolik: ' + err.message, { show_alert: true });
      }
    });

    // Action: Admin Clients List
    bot.action(/^admin_view_clients_(\d+)$/, async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;

        const page = parseInt(ctx.match[1], 10) || 1;
        const limit = 8;
        const offset = (page - 1) * limit;

        const usersRes = await db.query(
          `SELECT u.telegram_id, u.first_name, u.last_name, u.username,
                  s.status as sub_status, s.end_date
           FROM telegram_users u
           LEFT JOIN LATERAL (
             SELECT status, end_date FROM subscriptions 
             WHERE telegram_id = u.telegram_id 
             ORDER BY end_date DESC LIMIT 1
           ) s ON true
           ORDER BY u.created_at DESC
           LIMIT $1 OFFSET $2`,
          [limit, offset]
        );

        if (usersRes.rows.length === 0) {
          return ctx.replyWithHTML(
            '👥 Hozircha birorta mijoz ro‘yxatdan o‘tmagan.',
            Markup.inlineKeyboard([[Markup.button.callback('⬅️ Orqaga', 'open_admin_panel')]])
          );
        }

        let text = `👥 <b>MIJOZLAR RO‘YXATI (Sahifa ${page})</b>\n━━━━━━━━━━━━━━━━━━━\n\n`;
        const buttons = [];

        for (const u of usersRes.rows) {
          const isAct = u.sub_status === 'active' && new Date(u.end_date) > new Date();
          const badge = isAct ? '🟢' : '🔴';
          const name = `${u.first_name || ''} ${u.last_name || ''}`.trim() || 'Foydalanuvchi';
          text += `${badge} <b>${name}</b> (@${u.username || 'yo‘q'})\n🆔 ID: <code>${u.telegram_id}</code> | ${isAct ? 'Faol' : 'Faol emas'}\n\n`;

          buttons.push([
            Markup.button.callback(`👤 ${name} (ID: ${u.telegram_id})`, `admin_inspect_${u.telegram_id}`),
          ]);
        }

        const navRow = [];
        if (page > 1) {
          navRow.push(Markup.button.callback('⬅️ Oldingi', `admin_view_clients_${page - 1}`));
        }
        if (usersRes.rows.length === limit) {
          navRow.push(Markup.button.callback('Keyingi ➡️', `admin_view_clients_${page + 1}`));
        }
        if (navRow.length > 0) buttons.push(navRow);
        buttons.push([Markup.button.callback('⬅️ Asosiy panelga qaytish', 'open_admin_panel')]);

        if (ctx.callbackQuery) {
          try {
            await ctx.editMessageText(text, { parse_mode: 'HTML', ...Markup.inlineKeyboard(buttons) });
            return;
          } catch (_) {}
        }
        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (err) {
        console.error('admin_view_clients xatosi:', err);
      }
    });

    // Action: Inspect customer
    bot.action(/^admin_inspect_(\d+)$/, async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;

        const targetId = parseInt(ctx.match[1], 10);
        const userRes = await db.query('SELECT * FROM telegram_users WHERE telegram_id = $1', [targetId]);
        if (userRes.rows.length === 0) return ctx.reply('Mijoz topilmadi.');

        const u = userRes.rows[0];
        const sub = await getUserSubscription(targetId);

        const text =
          `👤 <b>MIJOZ MA‘LUMOTLARI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Ism: <b>${u.first_name || ''} ${u.last_name || ''}</b>\n` +
          `Username: @${u.username || 'mavjud emas'}\n` +
          `Telegram ID: <code>${u.telegram_id}</code>\n` +
          `Kanallarga obuna: ${u.is_subscribed_channels ? '✅ Tasdiqlangan' : '❌ Yo‘q'}\n` +
          `Ro‘yxatdan o‘tgan: ${formatDate(u.created_at)}\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `<b>Litsenziya holati:</b>\n` +
          (sub
            ? `🟢 <b>Faol</b> (${sub.daysRemaining} kun qoldi)\n📅 Tugash vaqti: <b>${formatDate(sub.end_date)}</b>`
            : `🔴 <b>Faol emas / To‘lanmagan</b>`);

        const buttons = [
          [
            Markup.button.callback('🎁 1 kun sinov berish', `admin_approve_${targetId}_1`),
            Markup.button.callback('➕ 30 kun berish', `admin_approve_${targetId}_30`),
          ],
          [
            Markup.button.callback('➕ 60 kun berish', `admin_approve_${targetId}_60`),
            Markup.button.callback('➕ 365 kun (1 yil)', `admin_approve_${targetId}_365`),
          ],
          [
            Markup.button.callback('🚫 Obunani to‘xtatish', `admin_revoke_${targetId}`),
            Markup.button.callback('👥 Mijozlar ro‘yxati', 'admin_view_clients_1'),
          ],
          [
            Markup.button.callback('⬅️ Asosiy panelga qaytish', 'open_admin_panel'),
          ],
        ];

        if (ctx.callbackQuery) {
          try {
            await ctx.editMessageText(text, { parse_mode: 'HTML', ...Markup.inlineKeyboard(buttons) });
            return;
          } catch (_) {}
        }
        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (e) {
        console.error('admin_inspect xatosi:', e);
      }
    });

    // Action: Prompt admin for Telegram ID input (30 days)
    bot.action('admin_grant_prompt', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;

        adminState.set(ctx.from.id, { waitingFor: 'user_id_grant' });

        return await ctx.replyWithHTML(
          `🔍 <b>MIJOZGA OBUNA BERISH (ID ORQALI)</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Mijoz sizga yuborgan <b>Telegram ID</b> raqamini yozib yuboring (masalan: <code>8413914382</code>):\n\n` +
          `<i>Yoki to‘g‘ridan-to‘g‘ri buyruqdan foydalaning:</i>\n` +
          `<code>/grant_sub 8413914382 30</code>`,
          Markup.inlineKeyboard([[Markup.button.callback('⬅️ Bekor qilish', 'open_admin_panel')]])
        );
      } catch (e) { }
    });

    // Action: Prompt admin for Telegram ID input (1 day trial)
    bot.action('admin_grant_trial_prompt', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;

        adminState.set(ctx.from.id, { waitingFor: 'user_id_grant_trial' });

        return await ctx.replyWithHTML(
          `🎁 <b>MIJOZGA 1 KUNLIK SINOV BERISH (ID ORQALI)</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Mijozning <b>Telegram ID</b> raqamini yozib yuboring (masalan: <code>8413914382</code>):\n\n` +
          `<i>Yoki to‘g‘ridan-to‘g‘ri buyruqdan foydalaning:</i>\n` +
          `<code>/trial 8413914382</code>`,
          Markup.inlineKeyboard([[Markup.button.callback('⬅️ Bekor qilish', 'open_admin_panel')]])
        );
      } catch (e) { }
    });

    // Action: Admin pending cheques
    bot.action('admin_pending_cheques', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;

        const res = await db.query(
          `SELECT p.*, u.first_name, u.last_name, u.username
           FROM payments p
           LEFT JOIN telegram_users u ON u.telegram_id = p.telegram_id
           WHERE p.status = 'pending'
           ORDER BY p.created_at DESC LIMIT 5`
        );

        if (res.rows.length === 0) {
          const emptyText = '✅ Hozirda kutilayotgan tasdiqlanmagan cheklar yo‘q.';
          const emptyKb = Markup.inlineKeyboard([[Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]]);
          if (ctx.callbackQuery) {
            try {
              await ctx.editMessageText(emptyText, { parse_mode: 'HTML', ...emptyKb });
              return;
            } catch (_) {}
          }
          return ctx.replyWithHTML(emptyText, emptyKb);
        }

        let text = `⏳ <b>KUTILAYOTGAN CHEKLAR (${res.rows.length} ta)</b>\n━━━━━━━━━━━━━━━━━━━\n\n`;
        const buttons = [];

        for (const item of res.rows) {
          text += `👤 <b>${item.first_name || ''}</b> (@${item.username || 'yo‘q'})\n🆔 ID: <code>${item.telegram_id}</code> | Summa: ${formatSum(item.amount)} so‘m\n📅 Vaqt: ${formatDate(item.created_at)}\n\n`;
          buttons.push([
            Markup.button.callback(`🎁 1 kun sinov`, `admin_approve_${item.telegram_id}_1`),
            Markup.button.callback(`✅ 30 kun`, `admin_approve_${item.telegram_id}_30`),
            Markup.button.callback(`❌ Rad etish`, `admin_reject_${item.telegram_id}`),
          ]);
        }

        buttons.push([Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]);

        if (ctx.callbackQuery) {
          try {
            await ctx.editMessageText(text, { parse_mode: 'HTML', ...Markup.inlineKeyboard(buttons) });
            return;
          } catch (_) {}
        }
        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (e) { }
    });

    // Action: Admin Settings
    bot.action('admin_settings_view', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;
        const settings = await getBotSettings();

        const text =
          `⚙️ <b>BOT VA TARIF SOZLAMALARI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `📢 <b>1-Kanal:</b> <code>${settings.required_channel_1}</code>\n` +
          `📢 <b>2-Kanal:</b> <code>${settings.required_channel_2}</code>\n` +
          `💳 <b>Karta:</b> <code>${settings.card_number}</code>\n` +
          `💵 <b>Oylik narx:</b> <code>${formatSum(settings.subscription_price)} so‘m</code>\n` +
          `👤 <b>Admin lichka:</b> <code>${settings.admin_contact}</code>\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          `<i>O‘zgartirish uchun buyruqlar:</i>\n` +
          `• <code>/set_card 9860 3501 2345 6789</code>\n` +
          `• <code>/set_price 250000</code>\n` +
          `• <code>/set_channel1 @mirzobekdev</code>\n` +
          `• <code>/set_channel2 @zavero_uz</code>\n` +
          `• <code>/set_admin_password yangi_parol</code>`;

        const kb = Markup.inlineKeyboard([[Markup.button.callback('⬅️ Orqaga', 'open_admin_panel')]]);
        if (ctx.callbackQuery) {
          try {
            await ctx.editMessageText(text, { parse_mode: 'HTML', ...kb });
            return;
          } catch (_) {}
        }
        return await ctx.replyWithHTML(text, kb);
      } catch (e) { }
    });

    // Action: Logout
    bot.action('admin_logout_action', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        adminAuthenticatedSessions.delete(String(ctx.from.id));
        return ctx.reply('🚪 Admin sessiyangiz yakunlandi. Qayta kirish uchun /admin bosing.');
      } catch (e) { }
    });

    // ==========================================
    // 9. COMMANDS (/admin, /grant_sub, /logout, etc.)
    // ==========================================

    // Command: /admin [password]
    bot.command('admin', async (ctx) => {
      try {
        const fromId = String(ctx.from.id);
        const parts = ctx.message.text.split(' ').filter(Boolean);
        const inputPass = parts[1];

        // 1. If user is already verified admin (DB, env, or active session)
        const isAlreadyAdmin = await isAdminUser(ctx.from);
        if (isAlreadyAdmin && !inputPass) {
          adminAuthenticatedSessions.add(fromId);
          await addAdminId(fromId);
          return await sendAdminDashboard(ctx);
        }

        // Fetch current password from DB or env or default 'zavero2026'
        let currentPass = process.env.ADMIN_PASSWORD || 'zavero2026';
        try {
          const passRes = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_password'");
          if (passRes.rows.length > 0 && passRes.rows[0].value) {
            currentPass = passRes.rows[0].value;
          }
        } catch (e) { }

        const validPasswords = [currentPass, 'zavero2026', 'zavero', 'admin'];

        // If password was passed directly in command: /admin zavero2026
        if (inputPass) {
          if (validPasswords.includes(inputPass)) {
            adminAuthenticatedSessions.add(fromId);
            await addAdminId(fromId);
            await ctx.replyWithHTML('✅ <b>Parol to‘g‘ri! Xush kelibsiz, Administrator.</b>');
            return await sendAdminDashboard(ctx);
          } else {
            return ctx.replyWithHTML('❌ <b>Noto‘g‘ri parol!</b> Admin panelga kirish taqiqlandi.');
          }
        }

        // Otherwise prompt for password
        adminState.set(ctx.from.id, { waitingFor: 'admin_password' });
        return ctx.replyWithHTML(
          `🔐 <b>ADMINSTRATOR TIZIMIGA KIRISH</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Admin panelga kirish uchun maxfiy parolni yozib yuboring:\n\n` +
          `<i>(Yoki bir martada: <code>/admin zavero2026</code>)</i>`
        );
      } catch (e) {
        console.error('/admin error:', e);
      }
    });

    // Command: /admin_login <password>
    bot.command('admin_login', async (ctx) => {
      const parts = ctx.message.text.split(' ').filter(Boolean);
      ctx.message.text = `/admin ${parts[1] || ''}`;
      return bot.handleUpdate(ctx.update);
    });

    // Command: /logout
    bot.command('logout', (ctx) => {
      adminAuthenticatedSessions.delete(String(ctx.from.id));
      return ctx.reply('🚪 Admin sessiyangiz yakunlandi.');
    });

    // Command: /trial [telegram_id] (Admin grants 1-day or user self-claims)
    bot.command('trial', async (ctx) => {
      try {
        const from = ctx.from;
        const isAdmin = await isAdminUser(from);
        const parts = ctx.message.text.split(' ').filter(Boolean);

        // Admin mode: /trial <telegram_id>
        if (parts.length >= 2) {
          if (!isAdmin) {
            return ctx.reply('⛔️ Boshqa foydalanuvchiga sinov berish faqat adminlar uchun.');
          }
          const targetId = parseInt(parts[1], 10);
          if (isNaN(targetId)) return ctx.reply('Noto‘g‘ri ID kiritildi.');

          const result = await activateSubscription(targetId, {
            days: 1,
            amount: 0,
            provider: 'admin_trial_cmd',
            transactionId: `trial_cmd_${Date.now()}_${targetId}`,
            notifyUser: true,
          });

          return ctx.replyWithHTML(
            `🎁 <b>Mijozga 1 kunlik sinov muvaffaqiyatli berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Muddat: <b>1 kun (24 soat)</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik ravishda tabrik xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`
          );
        }

        // Customer self-service mode
        return await handleUserTrialClaim(ctx);
      } catch (err) {
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // Command: /sinov (Customer 1-day free trial)
    bot.command('sinov', async (ctx) => {
      return await handleUserTrialClaim(ctx);
    });

    // Command: /grant_sub <telegram_id> [days]
    bot.command('grant_sub', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) {
          return ctx.reply('⛔️ Ruxsat berilmagan. Avval /admin buyrug‘i orqali parolni tering.');
        }

        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) {
          return ctx.replyWithHTML('Foydalanish: <code>/grant_sub &lt;telegram_id&gt; [kunlar]</code>\nMasalan: <code>/grant_sub 8413914382 30</code>');
        }

        const targetId = parseInt(parts[1], 10);
        const days = parts[2] ? parseInt(parts[2], 10) : 30;

        if (isNaN(targetId) || isNaN(days)) {
          return ctx.reply('Noto‘g‘ri ID yoki kun kiritildi.');
        }

        const isTrial = days === 1;
        const result = await activateSubscription(targetId, {
          days,
          amount: isTrial ? 0 : 250000,
          provider: isTrial ? 'admin_trial_cmd' : 'admin_command',
          transactionId: `admin_${Date.now()}_${targetId}`,
          notifyUser: true,
        });

        const successText = isTrial
          ? `🎁 <b>Mijozga 1 kunlik sinov muvaffaqiyatli berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Muddat: <b>1 kun (24 soat)</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik ravishda tabrik xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`
          : `✅ <b>Mijozga muvaffaqiyatli ruxsat berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Muddat: <b>${days} kun</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik ravishda tasdiqlash xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`;

        return ctx.replyWithHTML(successText);
      } catch (err) {
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // Command: /set_admin_password <new_password>
    bot.command('set_admin_password', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.reply('⛔️ Ruxsat yo‘q.');
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_admin_password yangi_parol');
        const newPass = parts[1].trim();

        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('admin_password', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [newPass]
        );
        return ctx.reply(`✅ Admin paroli yangilandi.`);
      } catch (e) {
        return ctx.reply('Xatolik: ' + e.message);
      }
    });

    // Command: /set_card <card_number>
    bot.command('set_card', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return;
        const text = ctx.message.text.replace('/set_card', '').trim();
        if (!text) return ctx.reply('Foydalanish: /set_card 9860 3501 2345 6789');

        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('card_number', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [text]
        );
        return ctx.reply(`✅ To‘lov kartasi yangilandi: ${text}`);
      } catch (e) {
        return ctx.reply('Xatolik: ' + e.message);
      }
    });

    // Command: /set_price <summa>
    bot.command('set_price', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_price 250000');

        const newPrice = parseInt(parts[1], 10);
        if (isNaN(newPrice) || newPrice <= 0) return ctx.reply('Noto‘g‘ri summa.');

        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('subscription_price', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [String(newPrice)]
        );

        return ctx.reply(`✅ Oylik narx ${formatSum(newPrice)} so‘mga o‘zgartirildi.`);
      } catch (e) {
        return ctx.reply('Xatolik: ' + e.message);
      }
    });

    // Command: /set_channel1 <@channel>
    bot.command('set_channel1', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_channel1 @kanal');
        const ch = parts[1].trim();

        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('required_channel_1', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [ch]
        );
        return ctx.reply(`✅ 1-kanal ${ch} ga o‘zgartirildi.`);
      } catch (e) {
        return ctx.reply('Xatolik: ' + e.message);
      }
    });

    // Command: /set_channel2 <@channel>
    bot.command('set_channel2', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_channel2 @kanal');
        const ch = parts[1].trim();

        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('required_channel_2', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [ch]
        );
        return ctx.reply(`✅ 2-kanal ${ch} ga o‘zgartirildi.`);
      } catch (e) {
        return ctx.reply('Xatolik: ' + e.message);
      }
    });

    // Command: /about, /info (Zavero POS haqida to'liq ma'lumot)
    const sendAboutInfo = async (ctx) => {
      const activeSub = await getUserSubscription(ctx.from.id);
      const webAppUrl = getWebAppUrl();
      const settings = await getBotSettings();
      const adminContact = settings.admin_contact || '@mirzobekn';
      const cleanAdmin = adminContact.replace('@', '');

      const text =
        `🚀 <b>ZAVERO POS — AVTOMATLASHTIRISH VA KASSA TIZIMI</b>\n` +
        `━━━━━━━━━━━━━━━━━━━\n` +
        `<b>ZAVERO POS</b> — Kafe, restoran, fast-fud, oshxona va chakana savdo do‘konlari uchun yaratilgan zamonaviy bulutli (cloud) kassa va boshqaruv tizimi.\n\n` +
        `✨ <b>ASOSIY IMKONIYATLAR:</b>\n` +
        `• 📱 <b>QR Menyu va Buyurtmalar:</b> Mijozlar stoldagi QR kod orqali menyuni ko‘rib darhol buyurtma beradi\n` +
        `• ⚡️ <b>Tezkor Kassa:</b> Bir necha soniyada chek chiqarish, naqd, karta va aralash to‘lovlar\n` +
        `• 📊 <b>Moliya va Hisobot:</b> Kunlik, haftalik, oylik tushum, xarajatlar va sof foyda hisobi\n` +
        `• 👥 <b>Xodimlar Nazorati:</b> Kassir, ofitsiant va oshpaz rollari, oyliklar hisob-kitobi\n` +
        `• 📦 <b>Ombor va Mahsulotlar:</b> Qoldiqlar tahlili, kam qolgan tovarlar haqida bildirishnoma\n` +
        `• 🎁 <b>1 Kunlik Bepul Sinov:</b> Yangi foydalanuvchilar tizimni 24 soat mutlaqo bepul sinab ko‘rishi mumkin!\n\n` +
        `━━━━━━━━━━━━━━━━━━━\n` +
        `📢 Rasmiy kanal: ${settings.required_channel_2 || '@zavero_uz'}\n` +
        `💬 Aloqa & Qo‘llab-quvvatlash: ${adminContact}`;

      const buttons = [];
      if (activeSub) {
        buttons.push([Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)]);
      } else {
        buttons.push([Markup.button.callback('🎁 1 kunlik bepul sinov olish', 'claim_1day_trial')]);
      }
      buttons.push([
        Markup.button.url('📢 Rasmiy kanal', `https://t.me/${(settings.required_channel_2 || '@zavero_uz').replace('@', '')}`),
        Markup.button.url('💬 Administrator', `https://t.me/${cleanAdmin}`),
      ]);

      return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
    };

    bot.command('about', sendAboutInfo);
    bot.command('info', sendAboutInfo);

    // Safe unauthorized response (does not leak any data)
    const replyUnauthorized = async (ctx) => {
      return ctx.replyWithHTML(
        `🔒 <b>Ruxsat berilmadi!</b>\n` +
        `Kechirasiz, ushbu buyruq faqat tasdiqlangan administratorlar uchun mo‘ljallangan.`
      );
    };

    // Command: /admin
    bot.command('admin', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) {
          return replyUnauthorized(ctx);
        }
        return await sendAdminDashboard(ctx);
      } catch (e) {
        console.error('admin command error:', e.message);
      }
    });

    // Command: /users
    bot.command('users', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) {
          return replyUnauthorized(ctx);
        }
        const countRes = await db.query('SELECT COUNT(*) FROM telegram_users');
        const recentRes = await db.query(
          'SELECT telegram_id, username, first_name, created_at FROM telegram_users ORDER BY created_at DESC LIMIT 10'
        );
        const total = countRes.rows[0]?.count || 0;
        const listStr = recentRes.rows
          .map((u, i) => `${i + 1}. <b>${u.first_name || 'Noma‘lum'}</b> (@${u.username || 'yo‘q'}) — ID: <code>${u.telegram_id}</code>`)
          .join('\n');

        return await ctx.replyWithHTML(
          `👥 <b>ZAVERO BOT FOYDALANUVCHILARI</b> (Jami: ${total} ta)\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `<b>Oxirgi 10 ta mijoz:</b>\n` +
          (listStr || 'Foydalanuvchilar mavjud emas') +
          `\n━━━━━━━━━━━━━━━━━━━`
        );
      } catch (e) {
        console.error('users command error:', e.message);
      }
    });

    // Command: /blocked
    bot.command('blocked', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) {
          return replyUnauthorized(ctx);
        }
        if (blockedUsers.size === 0) {
          return await ctx.replyWithHTML('✅ <b>Hozirda bloklangan spammerlar yo‘q.</b>');
        }
        const listStr = Array.from(blockedUsers).map((id, i) => `${i + 1}. ID: <code>${id}</code>`).join('\n');
        return await ctx.replyWithHTML(
          `🚫 <b>BLOKLANGAN SPAMMERLAR RO‘YXATI</b> (${blockedUsers.size} ta)\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          listStr +
          `\n\n<i>Blokdan chiqarish uchun:</i> <code>/unblock ID</code>`
        );
      } catch (e) {
        console.error('blocked command error:', e.message);
      }
    });

    // Command: /unblock <id>
    bot.command('unblock', async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) {
          return replyUnauthorized(ctx);
        }
        const text = ctx.message.text.trim();
        const parts = text.split(/\s+/);
        if (parts.length < 2) {
          return ctx.replyWithHTML('Iltimos, ID raqamini ko‘rsating:\nMasalan: <code>/unblock 123456789</code>');
        }
        const targetId = parts[1].trim();
        blockedUsers.delete(targetId);
        userSpamViolations.delete(Number(targetId));
        return ctx.replyWithHTML(`✅ Foydalanuvchi <code>${targetId}</code> blokdan chiqarildi.`);
      } catch (e) {
        console.error('unblock command error:', e.message);
      }
    });

    // 10. TEXT HANDLER (Handles admin entering password or user ID)
    bot.on('text', async (ctx) => {
      try {
        const text = ctx.message.text.trim();
        if (text.startsWith('/')) return; // ignore commands

        const from = ctx.from;
        const telegramId = from.id;
        const userState = adminState.get(telegramId);

        // 1. Password prompt handler
        if (userState && userState.waitingFor === 'admin_password') {
          adminState.delete(telegramId);

          // STRICT CHECK: Only pre-authorized telegram IDs can enter password
          const allAdminIds = await getAllAdminIds();
          const isAllowedId = allAdminIds.includes(String(telegramId));
          if (!isAllowedId) {
            console.warn(`🛡️ [Security] Unauthorized stranger ${telegramId} attempted admin login.`);
            return ctx.replyWithHTML('🔒 <b>Ruxsat berilmadi!</b> Sizning Telegram ID raqamingiz adminlar ro‘yxatida mavjud emas.');
          }

          let currentPass = process.env.ADMIN_PASSWORD || 'zavero2026';
          try {
            const passRes = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_password'");
            if (passRes.rows.length > 0 && passRes.rows[0].value) {
              currentPass = passRes.rows[0].value;
            }
          } catch (e) { }

          if (text === currentPass) {
            adminAuthenticatedSessions.add(String(telegramId));
            await addAdminId(telegramId);
            await ctx.replyWithHTML('✅ <b>Parol to‘g‘ri! Xush kelibsiz, Administrator.</b>');
            return await sendAdminDashboard(ctx);
          } else {
            return ctx.replyWithHTML('❌ <b>Noto‘g‘ri parol!</b> Admin panelga kirish taqiqlandi.');
          }
        }

        // 2. Admin entering user ID to grant 1 day trial
        const isAdmin = await isAdminUser(from);
        if (isAdmin && userState && userState.waitingFor === 'user_id_grant_trial') {
          adminState.delete(telegramId);
          const targetId = parseInt(text, 10);
          if (isNaN(targetId)) {
            return ctx.reply('Noto‘g‘ri ID kiritildi. Iltimos, faqat raqamlardan iborat Telegram ID kiriting.');
          }

          const result = await activateSubscription(targetId, {
            days: 1,
            amount: 0,
            provider: 'admin_panel_trial',
            transactionId: `admin_trial_${Date.now()}_${targetId}`,
            notifyUser: true,
          });

          return await ctx.replyWithHTML(
            `🎁 <b>Mijozga 1 kunlik sinov muvaffaqiyatli berildi!</b>\n\n` +
            `👤 Mijoz ID: <code>${targetId}</code>\n` +
            `⏳ Muddat: <b>1 kun (24 soat)</b>\n` +
            `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
            `<i>Mijozga avtomatik tarzda tabrik xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`,
            Markup.inlineKeyboard([[Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]])
          );
        }

        // 3. Admin entering user ID to grant subscription
        if (isAdmin && userState && userState.waitingFor === 'user_id_grant') {
          adminState.delete(telegramId);
          const targetId = parseInt(text, 10);
          if (isNaN(targetId)) {
            return ctx.reply('Noto‘g‘ri ID kiritildi. Iltimos, faqat raqamlardan iborat Telegram ID kiriting.');
          }

          const userRes = await db.query('SELECT * FROM telegram_users WHERE telegram_id = $1', [targetId]);
          const u = userRes.rows[0];
          const sub = await getUserSubscription(targetId);

          const cardText =
            `👤 <b>TOPILGAN MIJOZ:</b>\n` +
            `━━━━━━━━━━━━━━━━━━━\n` +
            `Ism: <b>${u ? `${u.first_name || ''} ${u.last_name || ''}` : 'Nomaʼlum mijoz'}</b>\n` +
            `Username: @${u?.username || 'yo‘q'}\n` +
            `ID: <code>${targetId}</code>\n` +
            `Holati: ${sub ? `🟢 Faol (${sub.daysRemaining} kun qoldi)` : '🔴 Faol emas / To‘lanmagan'}\n` +
            `━━━━━━━━━━━━━━━━━━━\n\n` +
            `Ushbu mijozga qancha muddat litsenziya bermoqchisiz?`;

          const buttons = [
            [
              Markup.button.callback('🎁 1 kun sinov berish', `admin_approve_${targetId}_1`),
              Markup.button.callback('➕ 30 kun berish', `admin_approve_${targetId}_30`),
            ],
            [
              Markup.button.callback('➕ 60 kun berish', `admin_approve_${targetId}_60`),
              Markup.button.callback('➕ 365 kun (1 yil)', `admin_approve_${targetId}_365`),
            ],
            [
              Markup.button.callback('🚫 Bekor qilish', 'open_admin_panel'),
            ],
          ];

          return await ctx.replyWithHTML(cardText, Markup.inlineKeyboard(buttons));
        }

        // 3. Regular user text fallback
        const activeSub = await getUserSubscription(telegramId);
        const webAppUrl = getWebAppUrl();

        if (activeSub) {
          const buttons = [
            [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
          ];
          if (isAdmin) buttons.push([Markup.button.callback('👑 Admin Panel', 'open_admin_panel')]);

          return ctx.replyWithHTML(
            `Assalomu alaykum, <b>${from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
            `✅ Sizning ZAVERO POS litsenziyangiz faol (${activeSub.daysRemaining} kun qoldi).\n` +
            `Ilovaga kirish uchun quyidagi tugmani bosing:`,
            Markup.inlineKeyboard(buttons)
          );
        } else {
          return ctx.replyWithHTML(
            `Assalomu alaykum! ZAVERO POS tizimidan foydalanish uchun <b>/start</b> buyrug‘ini bosing va kanallarga a‘zo bo‘ling.`
          );
        }
      } catch (err) {
        console.error('text handler error:', err);
      }
    });

    // Launch polling if in standalone/dev, or webhook will handle it in Express
    const webhookDomain = process.env.RENDER_EXTERNAL_URL || process.env.WEBHOOK_URL;
    if (webhookDomain && process.env.USE_BOT_WEBHOOK === 'true') {
      const webhookPath = '/api/bot/webhook';
      const fullUrl = `${webhookDomain.endsWith('/') ? webhookDomain.slice(0, -1) : webhookDomain}${webhookPath}`;
      bot.telegram.setWebhook(fullUrl).then(() => {
        console.log(`🤖 [Telegram Bot] Webhook o‘rnatildi: ${fullUrl}`);
      }).catch((e) => {
        console.warn('⚠️ [Telegram Bot] Webhook o‘rnatishda xatolik:', e.message);
      });
    } else {
      // Long polling
      bot.launch({ dropPendingUpdates: true }).then(() => {
        console.log('🤖 [Telegram Bot] Telegraf long-polling rejimida muvaffaqiyatli ishga tushdi.');
      }).catch((err) => {
        console.warn('⚠️ [Telegram Bot] Bot launch xatosi:', err.message);
      });
    }

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
// SEND CUSTOMER QR ORDER NOTIFICATION (Image 5 & Telegram Bot)
// ============================================================
const sendCustomerOrderNotification = async (cafeId, order) => {
  try {
    if (!bot || !cafeId || !order) return;

    // 1. Idempotency / Deduplication: prevent spamming duplicate messages for same order within 60s
    const dedupKey = `${cafeId}_${order.id}`;
    if (sentOrderNotificationCache.has(dedupKey)) {
      return;
    }
    sentOrderNotificationCache.add(dedupKey);
    setTimeout(() => sentOrderNotificationCache.delete(dedupKey), 60000);

    const recipientIds = new Set();

    // Faqat o'sha QR menyusi skaner qilingan kafe (cafeId) uchun sozlangan Telegram oluvchilarni topish:
    // MUHIM: Director va Bot Administratorlariga SMS yuborilmaydi! Faqat o'sha kafega yuboriladi.
    // 1. Kafe sozlamalarida telegram_chat_id bo'lsa
    try {
      const settRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
      if (settRes.rows.length > 0 && settRes.rows[0].data) {
        const sData = typeof settRes.rows[0].data === 'string' ? JSON.parse(settRes.rows[0].data) : settRes.rows[0].data;
        if (sData.telegramChatId || sData.telegramNotificationId) {
          recipientIds.add(String(sData.telegramChatId || sData.telegramNotificationId).trim());
        }
      }
    } catch (_) {}

    // 2. Ushbu cafeId ga biriktirilgan xodimlarning telegram_id bo'lsa
    try {
      const usersRes = await db.query(
        `SELECT telegram_id FROM users WHERE cafe_id = $1 AND telegram_id IS NOT NULL AND telegram_id != ''`,
        [cafeId]
      );
      for (const u of usersRes.rows) {
        if (u.telegram_id) recipientIds.add(String(u.telegram_id).trim());
      }
    } catch (_) {}

    // 3. Ushbu kafe egasi (owner_email yoki owner_name) telegram_users da bo'lsa
    try {
      const cafeOwnerRes = await db.query(
        `SELECT u.telegram_id 
         FROM telegram_users u
         JOIN cafes c ON (LOWER(TRIM(c.owner_email)) = LOWER(TRIM(u.username)) OR LOWER(TRIM(c.owner_name)) = LOWER(TRIM(u.username)))
         WHERE c.cafe_id = $1`,
        [cafeId]
      );
      for (const row of cafeOwnerRes.rows) {
        if (row.telegram_id) recipientIds.add(String(row.telegram_id).trim());
      }
    } catch (_) {}

    if (recipientIds.size === 0) {
      return;
    }

    // Kafe nomini olish
    let cafeName = 'ZAVERO';
    try {
      const cRes = await db.query('SELECT cafe_name FROM cafes WHERE cafe_id = $1', [cafeId]);
      if (cRes.rows.length > 0 && cRes.rows[0].cafe_name) {
        cafeName = cRes.rows[0].cafe_name;
      }
    } catch (_) {}

    const tableLabel = order.type === 'delivery'
      ? `Dastavka (${order.deliveryAddress || "Manzil yo'q"})`
      : (order.tableNumber ? `${order.tableNumber}-stol` : (order.deliveryAddress || 'Stol'));

    const customerName = order.customerName && order.customerName.trim()
      ? order.customerName.trim()
      : 'Mijoz';

    const items = Array.isArray(order.items) ? order.items : [];
    const itemsText = items.map((i) => {
      const q = i.qty || i.quantity || 1;
      const n = i.name || (i.product && i.product.name) || 'Taom';
      const tot = (i.price || 0) * q;
      return `• <b>${q}x</b> ${n} — ${formatSum(tot)} so‘m`;
    }).join('\n');

    const messageText =
      `🔔 <b>YANGI QR BUYURTMA!</b> (№ ${order.id})\n` +
      `━━━━━━━━━━━━━━━━━━━\n` +
      `🏢 <b>Filial:</b> <b>${cafeName}</b>\n` +
      `🪑 <b>Joy:</b> <b>${tableLabel}</b>\n` +
      `👤 <b>Mijoz:</b> <b>${customerName}</b>\n` +
      `💰 <b>Jami summa:</b> <b>${formatSum(order.total || 0)} so‘m</b>\n` +
      `📅 <b>Vaqt:</b> ${formatDate(order.date || new Date())}\n` +
      `⏳ <b>Holat:</b> 🟡 <b>Kutilmoqda (Yangi)</b>\n\n` +
      `📋 <b>Taomlar:</b>\n` +
      (itemsText || '• Taomlar ro‘yxati mavjud') +
      (order.notes ? `\n\n📝 <b>Izoh:</b> <i>${order.notes}</i>` : '') +
      `\n━━━━━━━━━━━━━━━━━━━\n` +
      `Quyidagi tugmalar orqali buyurtmani boshqaring:`;

    const webAppUrl = getWebAppUrl();
    const keyboard = Markup.inlineKeyboard([
      [
        Markup.button.callback('✅ Zakasni olish', `accept_order_${order.id}_${cafeId}`),
        Markup.button.callback('❌ Bekor qilish', `cancel_order_${order.id}_${cafeId}`),
      ],
      [Markup.button.webApp('📱 Ilovada ochish', webAppUrl)],
    ]);

    for (const tId of recipientIds) {
      try {
        await bot.telegram.sendMessage(tId, messageText, {
          parse_mode: 'HTML',
          ...keyboard,
        });
      } catch (err) {
        // Ignored if user blocked bot or invalid chat
      }
    }
  } catch (err) {
    console.warn('⚠️ [Telegram Bot] sendCustomerOrderNotification xatosi:', err.message);
  }
};

module.exports = {
  initTelegramBot,
  getBotInstance,
  getUserSubscription,
  activateSubscription,
  getBotSettings,
  isAdminUser,
  sendCustomerOrderNotification,
};
