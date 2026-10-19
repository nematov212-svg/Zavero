const crypto = require('crypto');
const db = require('../config/db');
const { activateSubscription, getUserSubscription, getBotSettings } = require('../bot/telegramBot');

// Click Error Codes
const CLICK_ERRORS = {
  SUCCESS: 0,
  SIGN_CHECK_FAILED: -1,
  INVALID_AMOUNT: -2,
  ACTION_NOT_FOUND: -3,
  ALREADY_PAID: -4,
  USER_NOT_FOUND: -5,
  TRANSACTION_NOT_FOUND: -6,
  FAILED_TO_UPDATE_USER: -7,
  ERROR_IN_REQUEST: -8,
  TRANSACTION_CANCELLED: -9,
};

// Payme Error Codes
const PAYME_ERRORS = {
  INSUFFICIENT_PRIVILEGES: -32504,
  INVALID_AMOUNT: -31001,
  TRANSACTION_NOT_FOUND: -31003,
  CANNOT_PERFORM_OPERATION: -31008,
  USER_NOT_FOUND: -31050,
  ALREADY_DONE: -31060,
};

/**
 * 1. CLICK INTEGRATION (Prepare & Complete)
 * Endpoint: POST /api/payments/click
 */
const handleClick = async (req, res) => {
  try {
    const {
      click_trans_id,
      service_id,
      click_paydoc_id,
      merchant_trans_id,
      amount,
      action,
      error,
      error_note,
      sign_time,
      sign_string,
      merchant_prepare_id,
    } = req.body;

    const secretKey = process.env.CLICK_SECRET_KEY;
    const actionNum = parseInt(action, 10);
    const parsedAmount = parseFloat(amount);
    const telegramId = parseInt(merchant_trans_id, 10);

    // Verify MD5 signature if secret key is configured
    if (secretKey) {
      let expectedSign = '';
      if (actionNum === 0) {
        // Prepare
        expectedSign = crypto
          .createHash('md5')
          .update(`${click_trans_id}${service_id}${secretKey}${merchant_trans_id}${amount}${action}${sign_time}`)
          .digest('hex');
      } else if (actionNum === 1) {
        // Complete
        expectedSign = crypto
          .createHash('md5')
          .update(`${click_trans_id}${service_id}${secretKey}${merchant_trans_id}${merchant_prepare_id}${amount}${action}${sign_time}`)
          .digest('hex');
      }

      if (expectedSign.toLowerCase() !== (sign_string || '').toLowerCase()) {
        return res.json({
          click_trans_id,
          merchant_trans_id,
          error: CLICK_ERRORS.SIGN_CHECK_FAILED,
          error_note: 'Sign check failed',
        });
      }
    }

    if (error && parseInt(error, 10) < 0) {
      return res.json({
        click_trans_id,
        merchant_trans_id,
        error: parseInt(error, 10),
        error_note: error_note || 'Click reported an error',
      });
    }

    // ACTION 0: PREPARE
    if (actionNum === 0) {
      // Validate telegram_id
      if (!telegramId || isNaN(telegramId)) {
        return res.json({
          click_trans_id,
          merchant_trans_id,
          error: CLICK_ERRORS.USER_NOT_FOUND,
          error_note: 'Foydalanuvchi topilmadi',
        });
      }

      // Check settings price
      const settings = await getBotSettings();
      if (parsedAmount < (settings.subscription_price || 250000)) {
        return res.json({
          click_trans_id,
          merchant_trans_id,
          error: CLICK_ERRORS.INVALID_AMOUNT,
          error_note: 'Noto‘g‘ri to‘lov summasi',
        });
      }

      // Record pending payment
      const prepareId = `prep_${Date.now()}_${telegramId}`;
      await db.query(
        `INSERT INTO payments (telegram_id, transaction_id, provider, amount, status, raw_data)
         VALUES ($1, $2, 'click', $3, 'pending', $4)
         ON CONFLICT (transaction_id) DO NOTHING`,
        [telegramId, String(click_trans_id), parsedAmount, JSON.stringify(req.body)]
      );

      return res.json({
        click_trans_id,
        merchant_trans_id,
        merchant_prepare_id: prepareId,
        error: CLICK_ERRORS.SUCCESS,
        error_note: 'Success',
      });
    }

    // ACTION 1: COMPLETE
    if (actionNum === 1) {
      // Check if already paid
      const checkRes = await db.query(
        'SELECT * FROM payments WHERE transaction_id = $1 AND provider = $2',
        [String(click_trans_id), 'click']
      );

      if (checkRes.rows.length > 0 && checkRes.rows[0].status === 'completed') {
        return res.json({
          click_trans_id,
          merchant_trans_id,
          merchant_confirm_id: checkRes.rows[0].id,
          error: CLICK_ERRORS.ALREADY_PAID,
          error_note: 'Already paid',
        });
      }

      const settings = await getBotSettings();
      const days = settings.subscription_days || 30;

      // Activate subscription & notify Telegram user
      const activation = await activateSubscription(telegramId, {
        days,
        amount: parsedAmount,
        provider: 'click',
        transactionId: String(click_trans_id),
        notifyUser: true,
      });

      return res.json({
        click_trans_id,
        merchant_trans_id,
        merchant_confirm_id: activation.subscription.id,
        error: CLICK_ERRORS.SUCCESS,
        error_note: 'Success',
      });
    }

    return res.json({
      click_trans_id,
      merchant_trans_id,
      error: CLICK_ERRORS.ACTION_NOT_FOUND,
      error_note: 'Action not supported',
    });
  } catch (err) {
    console.error('Click webhook error:', err);
    return res.json({
      error: CLICK_ERRORS.ERROR_IN_REQUEST,
      error_note: err.message,
    });
  }
};

/**
 * 2. PAYME INTEGRATION (JSON-RPC 2.0)
 * Endpoint: POST /api/payments/payme
 */
const handlePayme = async (req, res) => {
  const { method, params, id } = req.body || {};

  // Auth check with Basic Authorization
  const secretKey = process.env.PAYME_SECRET_KEY;
  if (secretKey) {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.replace(/^Basic\s+/, '');
    const decoded = Buffer.from(token, 'base64').toString('utf8');
    const [login, password] = decoded.split(':');

    if (password !== secretKey) {
      return res.json({
        jsonrpc: '2.0',
        id,
        error: {
          code: PAYME_ERRORS.INSUFFICIENT_PRIVILEGES,
          message: 'Noto‘g‘ri autentifikatsiya maʼlumotlari',
        },
      });
    }
  }

  try {
    switch (method) {
      case 'CheckPerformTransaction': {
        const { amount, account } = params;
        const telegramId = parseInt(account?.telegram_id, 10);

        if (!telegramId || isNaN(telegramId)) {
          return res.json({
            jsonrpc: '2.0',
            id,
            error: { code: PAYME_ERRORS.USER_NOT_FOUND, message: 'Foydalanuvchi hisobi topilmadi' },
          });
        }

        const settings = await getBotSettings();
        const expectedPriceTiyin = (settings.subscription_price || 250000) * 100;

        if (amount < expectedPriceTiyin) {
          return res.json({
            jsonrpc: '2.0',
            id,
            error: { code: PAYME_ERRORS.INVALID_AMOUNT, message: 'Noto‘g‘ri summa' },
          });
        }

        return res.json({
          jsonrpc: '2.0',
          id,
          result: { allow: true },
        });
      }

      case 'CreateTransaction': {
        const { id: paymeTxId, time, amount, account } = params;
        const telegramId = parseInt(account?.telegram_id, 10);

        const checkRes = await db.query(
          'SELECT * FROM payments WHERE transaction_id = $1 AND provider = $2',
          [String(paymeTxId), 'payme']
        );

        if (checkRes.rows.length > 0) {
          const tx = checkRes.rows[0];
          return res.json({
            jsonrpc: '2.0',
            id,
            result: {
              create_time: new Date(tx.created_at).getTime(),
              transaction: String(tx.id),
              state: tx.status === 'completed' ? 2 : 1,
            },
          });
        }

        const amountSum = amount / 100;
        const insertRes = await db.query(
          `INSERT INTO payments (telegram_id, transaction_id, provider, amount, status, raw_data)
           VALUES ($1, $2, 'payme', $3, 'pending', $4)
           RETURNING *`,
          [telegramId, String(paymeTxId), amountSum, JSON.stringify(params)]
        );

        return res.json({
          jsonrpc: '2.0',
          id,
          result: {
            create_time: new Date(insertRes.rows[0].created_at).getTime(),
            transaction: String(insertRes.rows[0].id),
            state: 1,
          },
        });
      }

      case 'PerformTransaction': {
        const { id: paymeTxId } = params;
        const txRes = await db.query(
          'SELECT * FROM payments WHERE transaction_id = $1 AND provider = $2',
          [String(paymeTxId), 'payme']
        );

        if (txRes.rows.length === 0) {
          return res.json({
            jsonrpc: '2.0',
            id,
            error: { code: PAYME_ERRORS.TRANSACTION_NOT_FOUND, message: 'Tranzaksiya topilmadi' },
          });
        }

        const tx = txRes.rows[0];
        if (tx.status === 'completed') {
          return res.json({
            jsonrpc: '2.0',
            id,
            result: {
              transaction: String(tx.id),
              perform_time: new Date(tx.updated_at).getTime(),
              state: 2,
            },
          });
        }

        const settings = await getBotSettings();
        const days = settings.subscription_days || 30;

        // Activate subscription
        await activateSubscription(tx.telegram_id, {
          days,
          amount: tx.amount,
          provider: 'payme',
          transactionId: String(paymeTxId),
          notifyUser: true,
        });

        const performTime = Date.now();
        return res.json({
          jsonrpc: '2.0',
          id,
          result: {
            transaction: String(tx.id),
            perform_time: performTime,
            state: 2,
          },
        });
      }

      case 'CheckTransaction': {
        const { id: paymeTxId } = params;
        const txRes = await db.query(
          'SELECT * FROM payments WHERE transaction_id = $1 AND provider = $2',
          [String(paymeTxId), 'payme']
        );

        if (txRes.rows.length === 0) {
          return res.json({
            jsonrpc: '2.0',
            id,
            error: { code: PAYME_ERRORS.TRANSACTION_NOT_FOUND, message: 'Tranzaksiya topilmadi' },
          });
        }

        const tx = txRes.rows[0];
        return res.json({
          jsonrpc: '2.0',
          id,
          result: {
            create_time: new Date(tx.created_at).getTime(),
            perform_time: tx.status === 'completed' ? new Date(tx.updated_at).getTime() : 0,
            cancel_time: tx.status === 'cancelled' ? new Date(tx.updated_at).getTime() : 0,
            transaction: String(tx.id),
            state: tx.status === 'completed' ? 2 : (tx.status === 'cancelled' ? -1 : 1),
            reason: null,
          },
        });
      }

      case 'CancelTransaction': {
        const { id: paymeTxId, reason } = params;
        const txRes = await db.query(
          'SELECT * FROM payments WHERE transaction_id = $1 AND provider = $2',
          [String(paymeTxId), 'payme']
        );

        if (txRes.rows.length === 0) {
          return res.json({
            jsonrpc: '2.0',
            id,
            error: { code: PAYME_ERRORS.TRANSACTION_NOT_FOUND, message: 'Tranzaksiya topilmadi' },
          });
        }

        await db.query(
          `UPDATE payments SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP WHERE transaction_id = $1`,
          [String(paymeTxId)]
        );

        return res.json({
          jsonrpc: '2.0',
          id,
          result: {
            transaction: String(txRes.rows[0].id),
            cancel_time: Date.now(),
            state: -1,
          },
        });
      }

      default:
        return res.json({
          jsonrpc: '2.0',
          id,
          error: { code: -32601, message: 'Method not found' },
        });
    }
  } catch (err) {
    console.error('Payme error:', err);
    return res.json({
      jsonrpc: '2.0',
      id,
      error: { code: -32400, message: 'Internal error: ' + err.message },
    });
  }
};

/**
 * 3. Check Subscription Status API
 * GET /api/payments/status/:telegramId
 */
const checkSubscriptionStatus = async (req, res) => {
  try {
    const telegramId = parseInt(req.params.telegramId, 10);
    if (!telegramId || isNaN(telegramId)) {
      return res.status(400).json({ success: false, message: 'Telegram ID noto‘g‘ri' });
    }

    const sub = await getUserSubscription(telegramId);
    if (sub) {
      return res.json({
        success: true,
        hasActiveSubscription: true,
        subscription: {
          id: sub.id,
          plan_name: sub.plan_name,
          amount: sub.amount,
          start_date: sub.start_date,
          end_date: sub.end_date,
          daysRemaining: sub.daysRemaining,
          status: sub.status,
        },
      });
    }

    return res.json({
      success: true,
      hasActiveSubscription: false,
      message: 'Faol obuna topilmadi yoki muddati tugagan.',
    });
  } catch (err) {
    console.error('checkSubscriptionStatus error:', err);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + err.message });
  }
};

/**
 * 4. Test Payment Simulation (Demo testing)
 * POST /api/payments/test-pay
 */
const testPayment = async (req, res) => {
  try {
    const { telegram_id, days = 30, amount = 250000, secret } = req.body;
    const telegramId = parseInt(telegram_id, 10);

    if (!telegramId || isNaN(telegramId)) {
      return res.status(400).json({ success: false, message: 'telegram_id kiritilishi shart' });
    }

    // Only allow if in development, ALLOW_TEST_PAYMENTS is true, or secret matches JWT_SECRET
    const isAllowed =
      process.env.NODE_ENV !== 'production' ||
      process.env.ALLOW_TEST_PAYMENTS === 'true' ||
      secret === process.env.JWT_SECRET;

    if (!isAllowed) {
      return res.status(403).json({ success: false, message: 'Test to‘lovlari taqiqlangan' });
    }

    const result = await activateSubscription(telegramId, {
      days: parseInt(days, 10) || 30,
      amount: parseFloat(amount) || 250000,
      provider: 'test_api',
      transactionId: `test_api_${Date.now()}_${telegramId}`,
      notifyUser: true,
    });

    return res.json({
      success: true,
      message: `${days} kunlik obuna muvaffaqiyatli faollashtirildi`,
      subscription: result.subscription,
      endDate: result.endDate,
    });
  } catch (err) {
    console.error('testPayment error:', err);
    return res.status(500).json({ success: false, message: 'Xatolik: ' + err.message });
  }
};

module.exports = {
  handleClick,
  handlePayme,
  checkSubscriptionStatus,
  testPayment,
};
