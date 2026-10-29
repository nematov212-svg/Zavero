const { Telegraf, Markup } = require('telegraf');
const db = require('../config/db');
const { notifyCafe } = require('../socket/socketHandler');
const { getBotInstance } = require('./telegramBot');

const ORDER_BOT_TOKEN = process.env.ORDER_BOT_TOKEN || '';
const MAIN_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || '9127763453:AAH4zi7O52rbL-M6zbgWVHqggeGylhJAONo';

let subBot = null;
let lastPendingRequest = null;

// Get list of admin IDs (from bot_settings or env)
const getAdminIds = async () => {
  const ids = new Set(['8873925517']);
  if (process.env.ADMIN_TELEGRAM_IDS) {
    process.env.ADMIN_TELEGRAM_IDS.split(',').forEach((id) => id.trim() && ids.add(id.trim()));
  }
  try {
    const res = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_telegram_ids'");
    if (res.rows.length > 0 && res.rows[0].value) {
      res.rows[0].value.split(',').forEach((id) => id.trim() && ids.add(id.trim()));
    }
  } catch (_) {}
  return Array.from(ids);
};

const registerSubscriptionHandlers = (bot) => {
  if (!bot) return;

  // Handle "30kun" or "30 kun" text approval
  bot.hears(/^(30kun|30 kun|tasdiqlash|ok)$/i, async (ctx) => {
    if (!lastPendingRequest) {
      return ctx.reply("Hozirda tasdiqlash uchun kutayotgan faol 30 kunlik so'rov mavjud emas.");
    }
    const cafeId = lastPendingRequest.cafeId;
    await approveExtension(cafeId, ctx);
  });

  // Handle button callbacks: approve_30_CAFEID
  bot.action(/^approve_30_(.+)$/, async (ctx) => {
    const cafeId = ctx.match[1];
    await approveExtension(cafeId, ctx);
  });

  // Handle button callbacks: reject_30_CAFEID
  bot.action(/^reject_30_(.+)$/, async (ctx) => {
    try {
      if (ctx.answerCbQuery) await ctx.answerCbQuery("So'rov rad etildi");
      if (ctx.editMessageText) {
        await ctx.editMessageText("❌ Obuna so'rovi rad etildi.");
      }
    } catch (e) {
      console.error('reject action error:', e.message);
    }
  });
};

const initSubscriptionBot = () => {
  // If dedicated ORDER_BOT_TOKEN is set and differs from main bot, launch a separate instance
  if (ORDER_BOT_TOKEN && ORDER_BOT_TOKEN !== MAIN_BOT_TOKEN) {
    if (subBot) return subBot;
    try {
      subBot = new Telegraf(ORDER_BOT_TOKEN);

      subBot.command('start', async (ctx) => {
        const chatId = String(ctx.chat.id);
        await ctx.reply(
          `👋 Assalomu alaykum!\n\nBu ZAVERO Buyurtmalar va Obuna Tasdiqlash boti.\nSizning Telegram ID: \`${chatId}\`\n\nIlovadan 30 kunlik obuna so'rovi yuborilganda, bu yerga xabar keladi va siz tasdiqlashingiz mumkin.`,
          { parse_mode: 'Markdown' }
        );
      });

      registerSubscriptionHandlers(subBot);

      subBot.catch((err) => {
        console.warn('⚠️ [Subscription Bot] Xatolik:', err.message);
      });

      subBot.launch().then(() => {
        console.log('🤖 [Subscription Bot] Alohida bot muvaffaqiyatli ishga tushdi!');
      }).catch((err) => {
        console.warn('⚠️ [Subscription Bot] Launch xatosi:', err.message);
      });

      process.once('SIGINT', () => subBot && subBot.stop('SIGINT'));
      process.once('SIGTERM', () => subBot && subBot.stop('SIGTERM'));

      return subBot;
    } catch (err) {
      console.error('initSubscriptionBot error:', err);
      return null;
    }
  }

  // Otherwise, attach handlers to the main unified telegramBot instance
  const mainBot = getBotInstance();
  if (mainBot) {
    registerSubscriptionHandlers(mainBot);
    console.log('🤖 [Subscription Bot] Obuna tasdiqlash buyruqlari asosiy botga birlashtirildi.');
  }
  return mainBot;
};

// Approval logic
const approveExtension = async (cafeId, ctx) => {
  try {
    const updated = await db.query(
      `UPDATE cafes 
       SET end_date = (CASE WHEN end_date IS NOT NULL AND end_date > NOW() THEN end_date ELSE NOW() END) + INTERVAL '30 days',
           is_blocked = false,
           is_expired = false,
           updated_at = CURRENT_TIMESTAMP
       WHERE cafe_id = $1
       RETURNING *`,
      [cafeId]
    );

    if (updated.rows.length === 0) {
      if (ctx.answerCbQuery) await ctx.answerCbQuery('Kafe topilmadi');
      return ctx.reply(`❌ Kafe (${cafeId}) ma'lumotlar bazasidan topilmadi.`);
    }

    const cafe = updated.rows[0];
    const newEndDate = cafe.end_date ? new Date(cafe.end_date).toISOString().split('T')[0] : '30 kun';

    await db.query(
      'UPDATE users SET is_blocked = false, is_expired = false WHERE cafe_id = $1',
      [cafeId]
    );

    notifyCafe(cafeId, 'SUBSCRIPTION_EXTENDED', {
      cafeId,
      endDate: cafe.end_date,
      days: 30,
    });

    if (ctx.answerCbQuery) {
      await ctx.answerCbQuery('30 kunlik obuna muvaffaqiyatli ochildi!');
    }

    const msg = `✅ TASDIQLANDI!\n\n🏪 Kafe: ${cafe.name || cafeId}\n📅 Yangi tugash sanasi: ${newEndDate}\n⏳ 30 kun muvaffaqiyatli qo'shildi va tizim ochildi!`;
    if (ctx.editMessageText) {
      await ctx.editMessageText(msg);
    } else {
      await ctx.reply(msg);
    }
    lastPendingRequest = null;
  } catch (err) {
    console.error('approveExtension error:', err);
    if (ctx.reply) await ctx.reply(`Xatolik yuz berdi: ${err.message}`);
  }
};

// Send extension request to bot admins
const sendExtensionRequest = async ({ cafeId, cafeName, userName, userPhone, currentEndDate }) => {
  lastPendingRequest = { cafeId, cafeName, userName, userPhone, time: Date.now() };

  const adminIds = await getAdminIds();
  const dateStr = currentEndDate ? String(currentEndDate).split('T')[0] : 'Mavjud emas';

  const text = `🔔 <b>YANGI OBUNA SO'ROVI (30 KUN):</b>\n\n🏪 <b>Kafe:</b> ${cafeName || 'ZAVERO'} (<code>${cafeId}</code>)\n👤 <b>Foydalanuvchi:</b> ${userName || 'Direktor'}\n📞 <b>Telefon:</b> ${userPhone || "Kiritilmagan"}\n⏳ <b>Hozirgi tugash sanasi:</b> ${dateStr}\n\n👉 <i>30 kun obuna ochishni tasdiqlaysizmi?</i>`;

  const keyboard = Markup.inlineKeyboard([
    [
      Markup.button.callback('✅ 30 kun tasdiqlash', `approve_30_${cafeId}`),
      Markup.button.callback('❌ Rad etish', `reject_30_${cafeId}`),
    ],
  ]);

  const targetBot = subBot || getBotInstance();
  let sentCount = 0;
  for (const adminId of adminIds) {
    try {
      if (targetBot) {
        await targetBot.telegram.sendMessage(adminId, text, {
          parse_mode: 'HTML',
          ...keyboard,
        });
        sentCount++;
      }
    } catch (e) {
      console.warn(`Admin ${adminId} ga xabar yuborishda xatolik:`, e.message);
    }
  }

  return { success: true, sentCount };
};

module.exports = {
  initSubscriptionBot,
  sendExtensionRequest,
};
