const { Telegraf, Markup } = require('telegraf');
const db = require('../config/db');

// Telegram Bot instance
let bot = null;

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
    console.warn('⚠️ [Telegram Bot] bot_settings o‘qishda xatolik, default ishlatilmoqda:', err.message);
    return defaultSettings;
  }
};

// Helper: Check if telegram user is admin
const isAdminUser = (telegramId) => {
  const adminIds = (process.env.ADMIN_TELEGRAM_IDS || '')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);
  return adminIds.includes(String(telegramId));
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
const activateSubscription = async (telegramId, { days = 30, amount = 250000, provider = 'click', transactionId = null, notifyUser = true }) => {
  try {
    const currentSub = await getUserSubscription(telegramId);
    let newStartDate = new Date();
    let newEndDate;

    if (currentSub && new Date(currentSub.end_date) > new Date()) {
      // Mavjud obunani uzaytirish
      newStartDate = new Date(currentSub.start_date);
      newEndDate = new Date(currentSub.end_date);
      newEndDate.setDate(newEndDate.getDate() + days);
    } else {
      // Yangi obuna boshlash
      newEndDate = new Date();
      newEndDate.setDate(newEndDate.getDate() + days);
    }

    const txId = transactionId || `${provider}_${Date.now()}_${telegramId}`;

    // 1. Saqlash: subscriptions jadvaliga yozish
    const subRes = await db.query(
      `INSERT INTO subscriptions (telegram_id, plan_name, amount, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, 'active')
       RETURNING *`,
      [telegramId, `${days} kunlik obuna`, amount, newStartDate, newEndDate]
    );

    // 2. Saqlash: payments jadvaliga yozish
    await db.query(
      `INSERT INTO payments (telegram_id, transaction_id, provider, amount, status, raw_data)
       VALUES ($1, $2, $3, $4, 'completed', $5)
       ON CONFLICT (transaction_id) 
       DO UPDATE SET status = 'completed', updated_at = CURRENT_TIMESTAMP`,
      [telegramId, txId, provider, amount, JSON.stringify({ days, activated_at: new Date().toISOString() })]
    );

    // 3. Agar foydalanuvchiga Telegram orqali xabar yuborish kerak bo'lsa
    if (notifyUser && bot) {
      try {
        const webAppUrl = getWebAppUrl();
        const messageText = 
          `🎉 <b>TABRIKLAYMIZ! TO‘LOV QABUL QILINDI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `✅ <b>ZAVERO POS</b> premium obunangiz muvaffaqiyatli faollashtirildi!\n\n` +
          `⏳ <b>Muddati:</b> ${days} kun\n` +
          `📅 <b>Amal qilish vaqti:</b> ${formatDate(newEndDate)}\n` +
          `💰 <b>To‘langan summa:</b> ${formatSum(amount)} so‘m\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          `Tizimga kirish uchun quyidagi tugmani bosing:`;

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
      console.warn(`⚠️ [Channel Check] ${channelUsername} tekshirishda xatolik:`, err.message);
      // Agar bot kanalda admin bo'lmasa yoki kanal topilmasa:
      const isBotPermissionIssue =
        err.message.includes('chat not found') ||
        err.message.includes('bot is not a member') ||
        err.message.includes('chat_admin_required') ||
        err.message.includes('member list is inaccessible');

      if (isBotPermissionIssue) {
        console.warn(`⚠️ [Telegram Bot] Bot ${channelUsername} kanaliga admin qilib qo‘shilmagan! Kanal tekshiruvi chetlab o‘tiladi.`);
        // Agar STRICT_CHANNEL_CHECK=true bo'lmasa, bot admin qilinmaguncha foydalanuvchi tiqilib qolmasligi uchun ruxsat beriladi
        const bypass = process.env.STRICT_CHANNEL_CHECK !== 'true';
        results.push({ channel: channelUsername, isMember: bypass, error: 'bot_not_admin', bypass });
      } else {
        results.push({ channel: channelUsername, isMember: false, error: err.message });
      }
    }
  }

  const allSubscribed = results.length > 0 && results.every((r) => r.isMember);
  return { allSubscribed, results };
};

// Build channel subscription keyboard
const buildChannelKeyboard = (settings) => {
  const ch1 = settings.required_channel_1.replace('@', '');
  const ch2 = settings.required_channel_2.replace('@', '');

  return Markup.inlineKeyboard([
    [Markup.button.url(`📢 1-Kanal: ${settings.required_channel_1}`, `https://t.me/${ch1}`)],
    [Markup.button.url(`📢 2-Kanal: ${settings.required_channel_2}`, `https://t.me/${ch2}`)],
    [Markup.button.callback('🔄 Obunani tekshirish', 'check_channels')],
  ]);
};

// Build subscription tariff message and keyboard
const sendTariffCard = async (ctx, settings, telegramId) => {
  const price = settings.subscription_price || 250000;
  const days = settings.subscription_days || 30;
  const formattedPrice = formatSum(price);

  const text =
    `✅ <b>Kanallarga obuna tasdiqlandi!</b>\n\n` +
    `🚀 <b>ZAVERO POS PREMIUM TARIFI</b>\n` +
    `━━━━━━━━━━━━━━━━━━━\n` +
    `📦 <b>Tarif:</b> 1 oylik obuna (${days} kun)\n` +
    `💰 <b>Narxi:</b> <b>${formattedPrice} so‘m</b>\n\n` +
    `⚡️ <b>Imkoniyatlar:</b>\n` +
    `• To‘liq restoran va kafe POS kassa tizimi\n` +
    `• QR Menyular va har bir stol uchun avtomatik QR kodlar\n` +
    `• Ofitsiant va oshxona buyurtmalari monitoringi\n` +
    `• Real-vaqtli kassa hisobotlari va tushumlar tahlili\n` +
    `• Cheksiz xodimlar va stollar boshqaruvi\n` +
    `━━━━━━━━━━━━━━━━━━━\n\n` +
    `<i>Ilovani faollashtirish uchun to‘lov turini tanlang:</i>`;

  const buttons = [
    [
      Markup.button.callback('💳 Click orqali to‘lash', 'pay_click'),
      Markup.button.callback('💳 Payme orqali to‘lash', 'pay_payme'),
    ],
    [Markup.button.callback('🔄 To‘lovni tekshirish', 'verify_payment')],
  ];

  // Agar admin bo'lsa yoki test to'lov ruxsat berilgan bo'lsa, tezkor sinov tugmasi
  if (isAdminUser(telegramId) || process.env.ALLOW_TEST_PAYMENTS === 'true' || process.env.NODE_ENV !== 'production') {
    buttons.push([Markup.button.callback('⚡️ Sinov uchun faollashtirish (Demo)', 'pay_test_instant')]);
  }

  await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
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

    // 1. /start command
    bot.start(async (ctx) => {
      try {
        const from = ctx.from;
        const telegramId = from.id;

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
          const welcomeBack =
            `Assalomu alaykum, <b>${from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
            `✅ <b>Sizning ZAVERO POS obunangiz faol!</b>\n` +
            `📅 Amal qilish muddati: <b>${formatDate(activeSub.end_date)}</b>\n` +
            `⏳ Qolgan vaqt: <b>${activeSub.daysRemaining} kun</b>\n\n` +
            `Tizimga kirish uchun quyidagi tugmani bosing:`;

          return await ctx.replyWithHTML(
            welcomeBack,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
              [Markup.button.callback('🔄 Obunani uzaytirish', 'show_tariff')],
            ])
          );
        }

        // New or expired user: check channel subscription
        const settings = await getBotSettings();
        const greeting =
          `Assalomu alaykum, <b>${from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
          `ZAVERO POS tizimiga xush kelibsiz. Ilovadan foydalanish uchun quyidagi kanallarga obuna bo‘ling va oylik tarifni faollashtiring.\n\n` +
          `Ikkala kanalga a‘zo bo‘lgach, <b>«🔄 Obunani tekshirish»</b> tugmasini bosing:`;

        return await ctx.replyWithHTML(greeting, buildChannelKeyboard(settings));
      } catch (err) {
        console.error('❌ [Telegram Bot] /start xatosi:', err);
        return ctx.reply('Tizimda xatolik yuz berdi. Iltimos, qayta urinib ko‘ring.');
      }
    });

    // 2. 'check_channels' action
    bot.action('check_channels', async (ctx) => {
      try {
        await ctx.answerCbQuery('Obunalar tekshirilmoqda...');
        const telegramId = ctx.from.id;
        const settings = await getBotSettings();
        const channels = [settings.required_channel_1, settings.required_channel_2].filter(Boolean);

        const { allSubscribed, results } = await verifyChannelMembership(ctx, telegramId, channels);

        if (!allSubscribed) {
          await db.query(
            'UPDATE telegram_users SET is_subscribed_channels = false WHERE telegram_id = $1',
            [telegramId]
          );

          let unSubbedText = '⚠️ <b>Iltimos, avval barcha kanallarga a‘zo bo‘ling!</b>\n\n';
          for (const res of results) {
            unSubbedText += `${res.isMember ? '✅' : '❌'} ${res.channel}\n`;
          }
          unSubbedText += '\nHar ikkala kanalga obuna bo‘lib, qayta «🔄 Obunani tekshirish» tugmasini bosing.';

          return await ctx.replyWithHTML(unSubbedText, buildChannelKeyboard(settings));
        }

        // Channels verified successfully!
        await db.query(
          'UPDATE telegram_users SET is_subscribed_channels = true WHERE telegram_id = $1',
          [telegramId]
        );

        // Check if user already has an active subscription
        const activeSub = await getUserSubscription(telegramId);
        if (activeSub) {
          const webAppUrl = getWebAppUrl();
          return await ctx.replyWithHTML(
            `✅ <b>Kanallarga obuna tasdiqlandi!</b>\n` +
            `Sizning obunangiz faol (${activeSub.daysRemaining} kun qoldi).\n\n` +
            `Ilovani ochish uchun quyidagi tugmani bosing:`,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
            ])
          );
        }

        // Show Tariff Card
        return await sendTariffCard(ctx, settings, telegramId);
      } catch (err) {
        console.error('❌ [Telegram Bot] check_channels xatosi:', err);
        return ctx.reply('Obunani tekshirishda xatolik yuz berdi. Iltimos, qaytadan urinib ko‘ring.');
      }
    });

    // 3. 'show_tariff' action
    bot.action('show_tariff', async (ctx) => {
      try {
        await ctx.answerCbQuery();
        const settings = await getBotSettings();
        await sendTariffCard(ctx, settings, ctx.from.id);
      } catch (err) {
        console.error('show_tariff xatosi:', err);
      }
    });

    // 4. Click Payment Action
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
        buttons.push([Markup.button.callback('🔄 To‘lovni tekshirish', 'verify_payment')]);
        buttons.push([Markup.button.callback('⬅️ Orqaga', 'show_tariff')]);

        const text =
          `💳 <b>CLICK TO‘LOV TIZIMI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `To‘lov summasi: <b>${formatSum(price)} so‘m</b>\n` +
          `Foydalanuvchi ID (Hisob): <code>${telegramId}</code>\n\n` +
          (clickUrl
            ? `Quyidagi tugma orqali Click ilovasi yoki veb-saytida to‘lovni amalga oshiring. To‘lov amalga oshirilgach, tizim avtomatik faollashadi.`
            : `Click to‘lov havolasi sozlanmoqda. To‘lovni amalga oshirib bo‘lgach «🔄 To‘lovni tekshirish» tugmasini bosing yoki adminga murojaat qiling.`);

        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (err) {
        console.error('pay_click xatosi:', err);
      }
    });

    // 5. Payme Payment Action
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
        buttons.push([Markup.button.callback('🔄 To‘lovni tekshirish', 'verify_payment')]);
        buttons.push([Markup.button.callback('⬅️ Orqaga', 'show_tariff')]);

        const text =
          `💳 <b>PAYME TO‘LOV TIZIMI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `To‘lov summasi: <b>${formatSum(price)} so‘m</b>\n` +
          `Foydalanuvchi ID (Hisob): <code>${telegramId}</code>\n\n` +
          (paymeUrl
            ? `Quyidagi tugma orqali Payme ilovasi yoki veb-saytida to‘lovni amalga oshiring. To‘lov o‘tgach, ilovaga kirish darhol ochiladi.`
            : `Payme to‘lov havolasi sozlanmoqda. To‘lov qilingach «🔄 To‘lovni tekshirish» tugmasini bosing.`);

        return await ctx.replyWithHTML(text, Markup.inlineKeyboard(buttons));
      } catch (err) {
        console.error('pay_payme xatosi:', err);
      }
    });

    // 6. Instant test activation (for admin or demo testing)
    bot.action('pay_test_instant', async (ctx) => {
      try {
        await ctx.answerCbQuery('Sinov obunasi faollashtirilmoqda...');
        const telegramId = ctx.from.id;
        const settings = await getBotSettings();

        await activateSubscription(telegramId, {
          days: settings.subscription_days || 30,
          amount: settings.subscription_price || 250000,
          provider: 'demo_test',
          transactionId: `test_${Date.now()}_${telegramId}`,
          notifyUser: false,
        });

        const activeSub = await getUserSubscription(telegramId);
        const webAppUrl = getWebAppUrl();

        return await ctx.replyWithHTML(
          `🎉 <b>SINOV OBUNASI FAOLLASHTIRILDI!</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `✅ Sizning ZAVERO POS obunangiz muvaffaqiyatli ishga tushdi.\n` +
          `📅 Amal qilish muddati: <b>${formatDate(activeSub.end_date)}</b> (${activeSub.daysRemaining} kun)\n\n` +
          `Ilovani ochish uchun quyidagi tugmani bosing:`,
          Markup.inlineKeyboard([
            [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
          ])
        );
      } catch (err) {
        console.error('pay_test_instant xatosi:', err);
        return ctx.reply('Sinov obunasini faollashtirishda xatolik yuz berdi: ' + err.message);
      }
    });

    // 7. Verify payment status button
    bot.action('verify_payment', async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        const activeSub = await getUserSubscription(telegramId);

        if (activeSub) {
          await ctx.answerCbQuery('✅ Obuna faol!');
          const webAppUrl = getWebAppUrl();
          return await ctx.replyWithHTML(
            `🎉 <b>OBUNANGIZ FAOL!</b>\n\n` +
            `📅 Amal qilish muddati: <b>${formatDate(activeSub.end_date)}</b>\n` +
            `⏳ Qolgan vaqt: <b>${activeSub.daysRemaining} kun</b>\n\n` +
            `ZAVERO POS tizimiga kirish:`,
            Markup.inlineKeyboard([
              [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
            ])
          );
        } else {
          await ctx.answerCbQuery('To‘lov hali aniqlanmadi');
          return await ctx.replyWithHTML(
            `⏳ <b>To‘lovingiz hali tasdiqlanmadi.</b>\n\n` +
            `Agar siz to‘lov qilgan bo‘lsangiz, bir necha daqiqadan so‘ng qayta tekshiring yoki to‘lov chekini administratorga yuboring.`
          );
        }
      } catch (err) {
        console.error('verify_payment xatosi:', err);
      }
    });

    // ==========================================
    // 8. ADMIN COMMANDS & MANAGEMENT
    // ==========================================

    // /admin - Dashboard
    bot.command('admin', async (ctx) => {
      try {
        const telegramId = ctx.from.id;
        if (!isAdminUser(telegramId)) {
          return ctx.reply('⛔️ Kechirasiz, siz ushbu buyruqdan foydalana olmaysiz.');
        }

        const settings = await getBotSettings();

        // Query Stats
        const usersCountRes = await db.query('SELECT COUNT(*) FROM telegram_users');
        const activeSubsRes = await db.query("SELECT COUNT(*) FROM subscriptions WHERE status = 'active' AND end_date > NOW()");
        const expiredSubsRes = await db.query("SELECT COUNT(*) FROM subscriptions WHERE end_date <= NOW() OR status != 'active'");
        const totalRevenueRes = await db.query("SELECT COALESCE(SUM(amount), 0) as total FROM payments WHERE status = 'completed'");

        const totalUsers = usersCountRes.rows[0].count;
        const activeSubs = activeSubsRes.rows[0].count;
        const expiredSubs = expiredSubsRes.rows[0].count;
        const totalRevenue = totalRevenueRes.rows[0].total;

        const text =
          `👑 <b>ZAVERO POS ADMIN BOSHQARUV PANELI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `👥 <b>Jami foydalanuvchilar:</b> ${totalUsers} ta\n` +
          `🟢 <b>Faol obunalar:</b> ${activeSubs} ta\n` +
          `🔴 <b>Muddati tugaganlar:</b> ${expiredSubs} ta\n` +
          `💰 <b>Jami tushum:</b> ${formatSum(totalRevenue)} so‘m\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `📢 <b>1-Kanal:</b> <code>${settings.required_channel_1}</code>\n` +
          `📢 <b>2-Kanal:</b> <code>${settings.required_channel_2}</code>\n` +
          `💵 <b>Tarif narxi:</b> ${formatSum(settings.subscription_price)} so‘m (${settings.subscription_days} kun)\n` +
          `━━━━━━━━━━━━━━━━━━━\n\n` +
          `<b>Mavjud buyruqlar:</b>\n` +
          `• <code>/grant_sub &lt;telegram_id&gt; [kunlar]</code> — Foydalanuvchiga obuna berish\n` +
          `• <code>/check_user &lt;telegram_id&gt;</code> — Foydalanuvchi ma‘lumotlari\n` +
          `• <code>/set_price &lt;summa&gt;</code> — Oylik tarif narxini o‘zgartirish\n` +
          `• <code>/set_channel1 &lt;@kanal&gt;</code> — 1-kanalni o‘zgartirish\n` +
          `• <code>/set_channel2 &lt;@kanal&gt;</code> — 2-kanalni o‘zgartirish`;

        return await ctx.replyWithHTML(text);
      } catch (err) {
        console.error('/admin xatosi:', err);
        return ctx.reply('Admin panelda xatolik yuz berdi: ' + err.message);
      }
    });

    // /grant_sub <telegram_id> [days]
    bot.command('grant_sub', async (ctx) => {
      try {
        if (!isAdminUser(ctx.from.id)) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) {
          return ctx.replyWithHTML('Foydalanish: <code>/grant_sub &lt;telegram_id&gt; [kunlar]</code>\nMasalan: <code>/grant_sub 123456789 30</code>');
        }

        const targetId = parseInt(parts[1], 10);
        const days = parts[2] ? parseInt(parts[2], 10) : 30;

        if (isNaN(targetId) || isNaN(days)) {
          return ctx.reply('Noto‘g‘ri parametrlar.');
        }

        const result = await activateSubscription(targetId, {
          days,
          amount: 0,
          provider: 'admin_manual',
          transactionId: `admin_${Date.now()}_${targetId}`,
          notifyUser: true,
        });

        return ctx.replyWithHTML(
          `✅ <b>Obuna muvaffaqiyatli berildi!</b>\n` +
          `👤 Telegram ID: <code>${targetId}</code>\n` +
          `📅 Amal qilish vaqti: <b>${formatDate(result.endDate)}</b> (${days} kun)`
        );
      } catch (err) {
        console.error('/grant_sub xatosi:', err);
        return ctx.reply('Obuna berishda xatolik: ' + err.message);
      }
    });

    // /check_user <telegram_id>
    bot.command('check_user', async (ctx) => {
      try {
        if (!isAdminUser(ctx.from.id)) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) {
          return ctx.replyWithHTML('Foydalanish: <code>/check_user &lt;telegram_id&gt;</code>');
        }

        const targetId = parseInt(parts[1], 10);
        const userRes = await db.query('SELECT * FROM telegram_users WHERE telegram_id = $1', [targetId]);

        if (userRes.rows.length === 0) {
          return ctx.reply(`Foydalanuvchi topilmadi (ID: ${targetId}).`);
        }

        const user = userRes.rows[0];
        const sub = await getUserSubscription(targetId);

        const info =
          `👤 <b>FOYDALANUVCHI MA‘LUMOTLARI</b>\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `ID: <code>${user.telegram_id}</code>\n` +
          `Ism: <b>${user.first_name || ''} ${user.last_name || ''}</b>\n` +
          `Username: @${user.username || 'mavjud emas'}\n` +
          `Kanal obunasi: ${user.is_subscribed_channels ? '✅ Tasdiqlangan' : '❌ Yo‘q'}\n` +
          `Ro‘yxatdan o‘tgan: ${formatDate(user.created_at)}\n` +
          `━━━━━━━━━━━━━━━━━━━\n` +
          `<b>Obuna holati:</b>\n` +
          (sub
            ? `🟢 Faol (${sub.daysRemaining} kun qoldi)\n📅 Tugash vaqti: ${formatDate(sub.end_date)}`
            : `🔴 Faol obunasi yo‘q`);

        return ctx.replyWithHTML(info);
      } catch (err) {
        console.error('/check_user xatosi:', err);
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // /set_price <summa>
    bot.command('set_price', async (ctx) => {
      try {
        if (!isAdminUser(ctx.from.id)) return;
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

        return ctx.reply(`✅ Oylik obuna narxi ${formatSum(newPrice)} so‘mga o‘zgartirildi.`);
      } catch (err) {
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // /set_channel1 <@username>
    bot.command('set_channel1', async (ctx) => {
      try {
        if (!isAdminUser(ctx.from.id)) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_channel1 @kanal_nomi');

        const ch = parts[1].trim();
        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('required_channel_1', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [ch]
        );

        return ctx.reply(`✅ 1-kanal ${ch} ga o‘zgartirildi.`);
      } catch (err) {
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // /set_channel2 <@username>
    bot.command('set_channel2', async (ctx) => {
      try {
        if (!isAdminUser(ctx.from.id)) return;
        const parts = ctx.message.text.split(' ').filter(Boolean);
        if (parts.length < 2) return ctx.reply('Foydalanish: /set_channel2 @kanal_nomi');

        const ch = parts[1].trim();
        await db.query(
          `INSERT INTO bot_settings (key, value, updated_at)
           VALUES ('required_channel_2', $1, CURRENT_TIMESTAMP)
           ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = CURRENT_TIMESTAMP`,
          [ch]
        );

        return ctx.reply(`✅ 2-kanal ${ch} ga o‘zgartirildi.`);
      } catch (err) {
        return ctx.reply('Xatolik: ' + err.message);
      }
    });

    // Global error handler for Telegraf (prevents unhandled exceptions from crashing process)
    bot.catch((err, ctx) => {
      console.error(`⚠️ [Telegram Bot Error] Update ${ctx.update.update_id}:`, err.message);
    });

    // Fallback handler for random messages
    bot.on('text', async (ctx) => {
      if (ctx.message.text.startsWith('/')) return; // ignore unknown commands
      const telegramId = ctx.from.id;
      const activeSub = await getUserSubscription(telegramId);
      const webAppUrl = getWebAppUrl();

      if (activeSub) {
        return ctx.replyWithHTML(
          `Assalomu alaykum, <b>${ctx.from.first_name || 'Foydalanuvchi'}</b>!\n\n` +
          `Sizning ZAVERO POS obunangiz faol (${activeSub.daysRemaining} kun qoldi).\n` +
          `Ilovaga kirish uchun quyidagi tugmani bosing:`,
          Markup.inlineKeyboard([
            [Markup.button.webApp('🚀 ZAVERO POS’NI OCHISH', webAppUrl)],
          ])
        );
      } else {
        return ctx.replyWithHTML(
          `Assalomu alaykum! ZAVERO POS xizmatidan foydalanish uchun <b>/start</b> buyrug‘ini yuboring.`
        );
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
