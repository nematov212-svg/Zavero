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

// Helper: Check if user is authenticated admin (must have entered password)
const isAdminUser = async (from) => {
  if (!from) return false;
  const telegramId = String(from.id || from);
  return adminAuthenticatedSessions.has(telegramId);
};

// Helper: Save a new admin ID to database
const addAdminId = async (telegramId) => {
  try {
    const res = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_telegram_ids'");
    let ids = [];
    if (res.rows.length > 0 && res.rows[0].value) {
      ids = res.rows[0].value.split(',').map((s) => s.trim()).filter(Boolean);
    }
    if (!ids.includes(String(telegramId))) {
      ids.push(String(telegramId));
      await db.query(
        `INSERT INTO bot_settings (key, value, updated_at)
         VALUES ('admin_telegram_ids', $1, CURRENT_TIMESTAMP)
         ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
        [ids.join(',')]
      );
    }
    return true;
  } catch (e) {
    console.warn('addAdminId error:', e.message);
    return false;
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
  } catch (e) {}

  adminAuthenticatedSessions.forEach((id) => ids.add(id));
  return Array.from(ids);
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

    // 1. subscriptions jadvaliga yozish
    const subRes = await db.query(
      `INSERT INTO subscriptions (telegram_id, plan_name, amount, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, 'active')
       RETURNING *`,
      [telegramId, `${days} kunlik obuna`, amount, newStartDate, newEndDate]
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
      }).catch(() => {});
    }

    // 4. Foydalanuvchiga rasmiy tasdiqlash SMS / Xabari yuborish
    if (notifyUser && bot) {
      try {
        const webAppUrl = getWebAppUrl();
        const messageText = 
          `🎉 <b>TO‘LOVINGIZ TASDIQLANDI!</b>\n` +
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
      Markup.button.callback('🔍 ID orqali 30 kun berish', 'admin_grant_prompt'),
    ],
    [
      Markup.button.callback('⚙️ Sozlamalar', 'admin_settings_view'),
      Markup.button.callback('🚪 Chiqish (Logout)', 'admin_logout_action'),
    ],
  ];

  return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
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
          }).catch(() => {});

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
        ctx.setChatMenuButton({ type: 'default' }).catch(() => {});

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
      } catch (e) {}
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
            Markup.button.callback('✅ 30 kunlik ruxsat berish', `admin_approve_${telegramId}_30`),
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
      } catch (e) {}
    });

    // Action: Admin approves subscription from Cheque or User Card
    bot.action(/^admin_approve_(\d+)_(\d+)$/, async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.answerCbQuery('⛔️ Ruxsat yo‘q! Avval /admin orqali parol tering.');
        await ctx.answerCbQuery('Faollashtirilmoqda...');

        const targetId = parseInt(ctx.match[1], 10);
        const days = parseInt(ctx.match[2], 10) || 30;

        const result = await activateSubscription(targetId, {
          days,
          amount: 250000,
          provider: 'admin_panel',
          transactionId: `admin_${Date.now()}_${targetId}`,
          notifyUser: true,
        });

        const confirmText =
          `✅ <b>Mijozga muvaffaqiyatli ruxsat berildi!</b>\n\n` +
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
        } catch (e) {}

        return ctx.replyWithHTML(`❌ Mijoz <code>${targetId}</code> cheki rad etildi va unga xabar berildi.`);
      } catch (e) {}
    });

    // Action: Admin revoke subscription
    bot.action(/^admin_revoke_(\d+)$/, async (ctx) => {
      try {
        if (!(await isAdminUser(ctx.from))) return ctx.answerCbQuery('⛔️ Ruxsat yo‘q! Avval /admin orqali parol tering.');
        await ctx.answerCbQuery('Bekor qilinmoqda');

        const targetId = parseInt(ctx.match[1], 10);
        await db.query("UPDATE subscriptions SET status = 'cancelled', end_date = NOW() WHERE telegram_id = $1", [targetId]);

        // Reset chat menu button
        bot.telegram.setChatMenuButton({ chat_id: targetId, menu_button: { type: 'default' } }).catch(() => {});

        try {
          await bot.telegram.sendMessage(
            targetId,
            '⚠️ Sizning ZAVERO POS litsenziyangiz administrator tomonidan to‘xtatildi.',
            { parse_mode: 'HTML' }
          );
        } catch (e) {}

        return ctx.replyWithHTML(`🚫 Mijoz <code>${targetId}</code> litsenziyasi to‘xtatildi.`);
      } catch (e) {}
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
            Markup.button.callback('➕ 30 kun berish', `admin_approve_${targetId}_30`),
            Markup.button.callback('➕ 60 kun berish', `admin_approve_${targetId}_60`),
          ],
          [
            Markup.button.callback('➕ 365 kun (1 yil)', `admin_approve_${targetId}_365`),
            Markup.button.callback('🚫 Obunani to‘xtatish', `admin_revoke_${targetId}`),
          ],
          [Markup.button.callback('⬅️ Mijozlar ro‘yxatiga qaytish', 'admin_view_clients_1')],
        ];

        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (e) {
        console.error('admin_inspect xatosi:', e);
      }
    });

    // Action: Prompt admin for Telegram ID input
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
          `<code>/grant_sub 8413914382 30</code>`
        );
      } catch (e) {}
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
          return ctx.replyWithHTML(
            '✅ Hozirda kutilayotgan tasdiqlanmagan cheklar yo‘q.',
            Markup.inlineKeyboard([[Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]])
          );
        }

        let text = `⏳ <b>KUTILAYOTGAN CHEKLAR (${res.rows.length} ta)</b>\n━━━━━━━━━━━━━━━━━━━\n\n`;
        const buttons = [];

        for (const item of res.rows) {
          text += `👤 <b>${item.first_name || ''}</b> (@${item.username || 'yo‘q'})\n🆔 ID: <code>${item.telegram_id}</code> | Summa: ${formatSum(item.amount)} so‘m\n📅 Vaqt: ${formatDate(item.created_at)}\n\n`;
          buttons.push([
            Markup.button.callback(`✅ 30 kun berish (ID: ${item.telegram_id})`, `admin_approve_${item.telegram_id}_30`),
            Markup.button.callback(`❌ Rad etish`, `admin_reject_${item.telegram_id}`),
          ]);
        }

        buttons.push([Markup.button.callback('⬅️ Admin Panelga qaytish', 'open_admin_panel')]);
        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (e) {}
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

        return await ctx.replyWithHTML(
          text,
          Markup.inlineKeyboard([
            [Markup.button.callback('🔑 Parolni o‘zgartirish', 'admin_change_pass_prompt')],
            [Markup.button.callback('⬅️ Orqaga', 'open_admin_panel')],
          ])
        );
      } catch (e) {}
    });

    // Action: Change Admin Password Prompt
    bot.action('admin_change_pass_prompt', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        if (!(await isAdminUser(ctx.from))) return;
        adminState.set(ctx.from.id, { waitingFor: 'new_admin_password' });

        return await ctx.replyWithHTML(
          `🔑 <b>ADMIN PAROLINI O‘ZGARTIRISH</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Iltimos, yangi maxfiy admin parolini yozib yuboring:\n\n` +
          `<i>(Yangi parolni eslab qoling, keyingi kirishda ushbu paroldan foydalanasiz)</i>`
        );
      } catch (e) {}
    });

    // Action: Logout
    bot.action('admin_logout_action', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        adminAuthenticatedSessions.delete(String(ctx.from.id));
        return ctx.reply('🚪 Admin sessiyangiz yakunlandi. Qayta kirish uchun /admin bosing.');
      } catch (e) {}
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

        // Fetch current password from DB or env or default 'zavero2026'
        let currentPass = process.env.ADMIN_PASSWORD || 'zavero2026';
        try {
          const passRes = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_password'");
          if (passRes.rows.length > 0 && passRes.rows[0].value) {
            currentPass = passRes.rows[0].value;
          }
        } catch (e) {}

        // If password was passed directly in command: /admin <password>
        if (inputPass) {
          if (inputPass === currentPass) {
            adminAuthenticatedSessions.add(fromId);
            await addAdminId(fromId);
            await ctx.replyWithHTML('✅ <b>Parol to‘g‘ri! Xush kelibsiz, Administrator.</b>');
            return await sendAdminDashboard(ctx);
          } else {
            return ctx.replyWithHTML('❌ <b>Noto‘g‘ri parol!</b> Admin panelga kirish taqiqlandi.');
          }
        }

        // If already authenticated in current session
        if (adminAuthenticatedSessions.has(fromId)) {
          return await sendAdminDashboard(ctx);
        }

        // Otherwise prompt for password (NEVER leak password in prompt!)
        adminState.set(ctx.from.id, { waitingFor: 'admin_password' });
        return ctx.replyWithHTML(
          `🔐 <b>ADMINISTRATOR TIZIMIGA KIRISH</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `Admin panelga kirish uchun maxfiy parolni yozib yuboring:`
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

        const result = await activateSubscription(targetId, {
          days,
          amount: 250000,
          provider: 'admin_command',
          transactionId: `admin_${Date.now()}_${targetId}`,
          notifyUser: true,
        });

        return ctx.replyWithHTML(
          `✅ <b>Mijozga muvaffaqiyatli ruxsat berildi!</b>\n\n` +
          `👤 Mijoz ID: <code>${targetId}</code>\n` +
          `⏳ Muddat: <b>${days} kun</b>\n` +
          `📅 Tugash vaqti: <b>${formatDate(result.endDate)}</b>\n\n` +
          `<i>Mijozga avtomatik ravishda tasdiqlash xabari va «ZAVERO POS’NI OCHISH» tugmasi yuborildi.</i>`
        );
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

          let currentPass = process.env.ADMIN_PASSWORD || 'zavero2026';
          try {
            const passRes = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_password'");
            if (passRes.rows.length > 0 && passRes.rows[0].value) {
              currentPass = passRes.rows[0].value;
            }
          } catch (e) {}

          if (text === currentPass) {
            adminAuthenticatedSessions.add(String(telegramId));
            await addAdminId(telegramId);
            await ctx.replyWithHTML('✅ <b>Parol to‘g‘ri! Xush kelibsiz, Administrator.</b>');
            return await sendAdminDashboard(ctx);
          } else {
            return ctx.replyWithHTML('❌ <b>Noto‘g‘ri parol!</b> Admin panelga kirish taqiqlandi.');
          }
        }

        // 2. New Admin Password handler
        if (userState && userState.waitingFor === 'new_admin_password') {
          adminState.delete(telegramId);
          const newPass = text.trim();
          if (!newPass || newPass.length < 4) {
            return ctx.reply('Parol kamida 4 ta belgidan iborat bo‘lishi kerak.');
          }

          await db.query(
            `INSERT INTO bot_settings (key, value, updated_at)
             VALUES ('admin_password', $1, CURRENT_TIMESTAMP)
             ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
            [newPass]
          );

          return ctx.replyWithHTML(
            `✅ <b>Admin paroli muvaffaqiyatli o‘zgartirildi!</b>\n\n` +
            `Yangi maxfiy parol: <code>${newPass}</code>\n\n` +
            `Uni eslab qoling. Keyingi kirishda ushbu paroldan foydalanasiz.`
          );
        }

        // 3. Admin entering user ID to grant subscription
        const isAdmin = await isAdminUser(from);
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
              Markup.button.callback('➕ 30 kun berish', `admin_approve_${targetId}_30`),
              Markup.button.callback('➕ 60 kun berish', `admin_approve_${targetId}_60`),
            ],
            [
              Markup.button.callback('➕ 365 kun (1 yil)', `admin_approve_${targetId}_365`),
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

module.exports = {
  initTelegramBot,
  getBotInstance,
  getUserSubscription,
  activateSubscription,
  getBotSettings,
  isAdminUser,
};
