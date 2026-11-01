const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const db = require('../config/db');
const { getJwtSecret, getJwtAccessExpiresIn } = require('../config/jwt');
const { logActivity } = require('../utils/auditLogger');

const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

const createRefreshToken = async (userId, ip = '') => {
  const rawToken = crypto.randomBytes(40).toString('hex');
  const tokenHash = hashToken(rawToken);
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
  await db.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at, created_by_ip)
     VALUES ($1, $2, $3, $4)`,
    [userId, tokenHash, expiresAt, ip]
  );
  return rawToken;
};

const generateToken = (user) => {
  const secret = getJwtSecret();
  const expiresIn = getJwtAccessExpiresIn(); // 15 minutes
  return jwt.sign(
    { id: user.id, username: user.username, cafeId: user.cafe_id, role: user.role },
    secret,
    { expiresIn }
  );
};

const toClientUser = (u) => ({
  id: u.id,
  username: u.username,
  name: u.name,
  surname: u.surname,
  phone: u.phone,
  email: u.email,
  role: u.role,
  salary: u.salary !== undefined ? parseFloat(u.salary) : 0,
  cafeId: u.cafe_id,
  cafeName: u.cafe_name || '',
  receiptName: u.receipt_name || u.cafe_name || '',
  isActive: u.is_active !== false,
  mustChangePassword: !!u.must_change_password,
  isBlocked: u.cafe_status === 'blocked',
  isExpired: u.cafe_end_date ? new Date(u.cafe_end_date) < new Date() : false,
  createdAt: u.created_at,
});

// POST /api/auth/register — Public registration is closed for multi-tenant SaaS
const register = async (req, res) => {
  return res.status(403).json({
    success: false,
    message: "Ommaviy ro'yxatdan o'tish yopilgan. Yangi cafe ochish uchun ZAVERO Director bilan bog'laning.",
  });
};

// POST /api/auth/login
const login = async (req, res) => {
  try {
    const { username, password, deviceId, deviceName, deviceType } = req.body;
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        message: 'Login yoki parol xato. Iltimos, qaytadan tekshiring.',
      });
    }

    const rawInput = (username || '').trim().toLowerCase();
    const cleanInput = rawInput.replace(/^@/, '');
    const cleanEmail = cleanInput.includes('@') ? cleanInput : `${cleanInput}@cafe.uz`;
    const clientIp = req.ip || req.headers['x-forwarded-for'] || 'unknown';

    // 1. Brute Force Protection: Check if account or IP is temporarily locked
    const lockCheck = await db.query(
      `SELECT attempts, locked_until FROM failed_logins 
       WHERE identifier = $1 AND ip_address = $2`,
      [cleanInput, clientIp]
    );
    if (lockCheck.rows.length > 0) {
      const { locked_until } = lockCheck.rows[0];
      if (locked_until && new Date(locked_until) > new Date()) {
        const remainingMinutes = Math.max(1, Math.ceil((new Date(locked_until) - new Date()) / 60000));
        return res.status(429).json({
          success: false,
          message: `Ketma-ket noto'g'ri urinishlar tufayli kirish vaqtincha bloklandi. Iltimos, ${remainingMinutes} daqiqadan so'ng qayta urinib ko'ring.`,
        });
      }
    }

    const recordFailedAttempt = async () => {
      try {
        const cur = await db.query(
          `SELECT id, attempts FROM failed_logins WHERE identifier = $1 AND ip_address = $2`,
          [cleanInput, clientIp]
        );
        if (cur.rows.length === 0) {
          await db.query(
            `INSERT INTO failed_logins (identifier, ip_address, attempts, last_attempt)
             VALUES ($1, $2, 1, CURRENT_TIMESTAMP)`,
            [cleanInput, clientIp]
          );
        } else {
          const nextAttempts = cur.rows[0].attempts + 1;
          const isLock = nextAttempts >= 5;
          await db.query(
            `UPDATE failed_logins 
             SET attempts = $1, last_attempt = CURRENT_TIMESTAMP, 
                 locked_until = ${isLock ? "CURRENT_TIMESTAMP + INTERVAL '5 minutes'" : "NULL"}
             WHERE id = $2`,
            [nextAttempts, cur.rows[0].id]
          );
        }
      } catch (err) {
        console.warn('Failed login record error:', err.message);
      }
    };

    // Query user and join cafe status
    const result = await db.query(
      `SELECT u.*, 
              c.status AS cafe_status, 
              c.end_date AS cafe_end_date, 
              c.cafe_name, 
              c.receipt_name
       FROM users u
       LEFT JOIN cafes c ON u.cafe_id = c.cafe_id
       WHERE LOWER(u.username) = $1 
          OR LOWER(u.username) = $2
          OR LOWER(u.email) = $1
          OR LOWER(u.email) = $2
          OR LOWER(u.email) = $3
          OR ($2 = 'director' AND u.role = 'director')
          OR ($2 = 'admin' AND u.cafe_id = 'cafe1' AND u.role = 'admin')`,
      [rawInput, cleanInput, cleanEmail]
    );

    if (result.rows.length === 0) {
      await recordFailedAttempt();
      logActivity({
        cafeId: 'system',
        action: 'FAILED_LOGIN',
        details: `Login attempt failed for input: ${rawInput.substring(0, 50)}`,
        performedBy: clientIp,
      });
      return res.status(401).json({
        success: false,
        message: 'Login yoki parol xato. Iltimos, qaytadan tekshiring.',
      });
    }

    let user = null;
    let hasInactive = false;

    for (const candidate of result.rows) {
      const isMatch = await bcrypt.compare(password.trim(), candidate.password_hash);
      if (isMatch) {
        if (candidate.is_active === false) {
          hasInactive = true;
          continue;
        }
        user = candidate;
        break;
      }
    }

    if (!user) {
      await recordFailedAttempt();
      if (hasInactive) {
        return res.status(403).json({
          success: false,
          message: 'Ushbu akkaunt faolsizlantirilgan. Administrator bilan bog\'laning.',
        });
      }
      logActivity({
        cafeId: 'system',
        action: 'FAILED_LOGIN_PASSWORD',
        details: `Incorrect password attempt for user ${rawInput}`,
        performedBy: clientIp,
      });
      return res.status(401).json({
        success: false,
        message: 'Login yoki parol xato. Iltimos, qaytadan tekshiring.',
      });
    }

    // Reset failed login tracker on success
    await db.query(
      `DELETE FROM failed_logins WHERE identifier = $1 AND ip_address = $2`,
      [cleanInput, clientIp]
    ).catch(() => {});

    // Audit log successful login
    logActivity({
      cafeId: user.cafe_id || 'system',
      action: 'LOGIN_SUCCESS',
      details: `User ${user.username} (${user.role}) logged in successfully`,
      performedBy: user.username,
    });

    // Register or update device if provided
    const targetDeviceId = deviceId || req.headers['x-device-id'];
    if (targetDeviceId && user.cafe_id) {
      try {
        const dName = deviceName || req.headers['x-device-name'] || 'Noma\'lum qurilma';
        const dType = deviceType || req.headers['x-device-type'] || 'desktop';
        await db.query(
          `INSERT INTO devices (cafe_id, user_id, device_name, device_type, device_identifier, last_seen, is_active)
           VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, true)
           ON CONFLICT (cafe_id, device_identifier) DO UPDATE SET
             user_id = EXCLUDED.user_id,
             device_name = EXCLUDED.device_name,
             device_type = EXCLUDED.device_type,
             last_seen = CURRENT_TIMESTAMP,
             is_active = true`,
          [user.cafe_id, user.id, dName, dType, targetDeviceId]
        );
      } catch (devErr) {
        console.warn('Device tracking warning:', devErr.message);
      }
    }

    // Fetch all cafes this user is authorized to access (for multi-cafe directors & owners)
    let userCafes = [];
    try {
      if (user.role === 'director' || user.role === 'super_admin') {
        const cRes = await db.query(
          `SELECT cafe_id, cafe_name, receipt_name, status, end_date FROM cafes WHERE status != 'deleted' ORDER BY created_at ASC`
        );
        userCafes = cRes.rows.map(c => ({
          cafeId: c.cafe_id,
          role: user.role,
          cafeName: c.cafe_name,
          receiptName: c.receipt_name || c.cafe_name,
          status: c.status,
        }));
      } else {
        const ucRes = await db.query(
          `SELECT uc.cafe_id, uc.role, c.cafe_name, c.receipt_name, c.status, c.end_date
           FROM user_cafes uc
           JOIN cafes c ON uc.cafe_id = c.cafe_id
           WHERE uc.user_id = $1`,
          [user.id]
        );
        userCafes = ucRes.rows.map(c => ({
          cafeId: c.cafe_id,
          role: c.role,
          cafeName: c.cafe_name,
          receiptName: c.receipt_name || c.cafe_name,
          status: c.status,
        }));
      }
    } catch (_) {}

    const token = generateToken(user);
    const refreshToken = await createRefreshToken(user.id, clientIp);

    const isBlocked = user.role !== 'director' && user.cafe_status === 'blocked';
    const isExpired = user.role !== 'director' && user.cafe_end_date ? new Date(user.cafe_end_date) < new Date() : false;

    return res.json({
      success: true,
      message: 'Tizimga muvaffaqiyatli kirildi.',
      token,
      refreshToken,
      user: toClientUser(user),
      cafes: userCafes,
      isBlocked,
      isExpired,
      cafe: {
        id: user.cafe_id,
        name: user.cafe_name || '',
        receiptName: user.receipt_name || user.cafe_name || '',
        status: user.cafe_status || 'active',
        endDate: user.cafe_end_date,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

// GET /api/auth/me
const getMe = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT u.*, 
              c.status AS cafe_status, 
              c.end_date AS cafe_end_date, 
              c.cafe_name, 
              c.receipt_name
       FROM users u
       LEFT JOIN cafes c ON u.cafe_id = c.cafe_id
       WHERE u.id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi.' });
    }

    const user = result.rows[0];
    const isBlocked = user.role !== 'director' && user.cafe_status === 'blocked';
    const isExpired = user.role !== 'director' && user.cafe_end_date ? new Date(user.cafe_end_date) < new Date() : false;

    return res.json({
      success: true,
      user: toClientUser(user),
      isBlocked,
      isExpired,
      cafe: {
        id: user.cafe_id,
        name: user.cafe_name || '',
        receiptName: user.receipt_name || user.cafe_name || '',
        status: user.cafe_status || 'active',
        endDate: user.cafe_end_date,
      },
    });
  } catch (error) {
    console.error('GetMe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// PUT /api/auth/profile
const updateProfile = async (req, res) => {
  try {
    const { name, surname, phone } = req.body;
    const fields = [];
    const params = [];
    let i = 1;
    if (name !== undefined) { fields.push(`name = $${i++}`); params.push(name); }
    if (surname !== undefined) { fields.push(`surname = $${i++}`); params.push(surname); }
    if (phone !== undefined) { fields.push(`phone = $${i++}`); params.push(phone); }
    fields.push(`updated_at = CURRENT_TIMESTAMP`);

    if (fields.length === 1) {
      return res.json({ success: true, message: "O'zgarish yo'q." });
    }

    params.push(req.user.id);
    const result = await db.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $${i} RETURNING *`,
      params
    );

    return res.json({ success: true, message: 'Profil yangilandi.', user: toClientUser(result.rows[0]) });
  } catch (error) {
    console.error('updateProfile error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// PUT /api/auth/change-credentials
const changeCredentials = async (req, res) => {
  try {
    const { oldLogin, oldPassword, newLogin, newPassword } = req.body;

    if (!oldPassword) {
      return res.status(400).json({ success: false, message: 'Parol noto‘g‘ri' });
    }

    // Fetch user with password_hash
    const result = await db.query('SELECT * FROM users WHERE id = $1', [req.user.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Foydalanuvchi topilmadi.' });
    }

    const user = result.rows[0];

    // Verify old password
    const isMatch = await bcrypt.compare(oldPassword.trim(), user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Parol noto‘g‘ri' });
    }

    const updates = [];
    const params = [];
    let idx = 1;

    // Handle new login/username
    if (newLogin && newLogin.trim()) {
      const cleanNewLogin = newLogin.trim().toLowerCase();
      const checkRes = await db.query(
        'SELECT id FROM users WHERE (LOWER(username) = $1 OR LOWER(email) = $1) AND id != $2',
        [cleanNewLogin, req.user.id]
      );
      if (checkRes.rows.length > 0) {
        return res.status(400).json({ success: false, message: 'Ushbu login allaqachon band.' });
      }
      updates.push(`username = $${idx++}`);
      params.push(cleanNewLogin);

      if (user.role === 'director' || user.email) {
        const newEmail = cleanNewLogin.includes('@') ? cleanNewLogin : (user.role === 'director' ? `${cleanNewLogin}@zavero.uz` : `${cleanNewLogin}@cafe.uz`);
        updates.push(`email = $${idx++}`);
        params.push(newEmail);
      }
    }

    // Handle new password
    if (newPassword && newPassword.trim()) {
      if (newPassword.trim().length < 6) {
        return res.status(400).json({ success: false, message: 'Yangi parol kamida 6 ta belgidan iborat bo‘lishi kerak.' });
      }
      const salt = await bcrypt.genSalt(12);
      const hash = await bcrypt.hash(newPassword.trim(), salt);
      updates.push(`password_hash = $${idx++}`);
      params.push(hash);
      updates.push(`must_change_password = false`);
    }

    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'O‘zgartirish uchun yangi login yoki yangi parol kiritilmadi.' });
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    params.push(req.user.id);

    const updateRes = await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
      params
    );

    const updatedUser = updateRes.rows[0];
    const newToken = generateToken(updatedUser);

    logActivity({
      cafeId: updatedUser.cafe_id || 'system',
      action: 'CREDENTIALS_CHANGED',
      details: `User ${updatedUser.username} changed security credentials`,
      performedBy: updatedUser.username,
    });

    return res.json({
      success: true,
      message: 'Login va parol muvaffaqiyatli o‘zgartirildi.',
      token: newToken,
      user: toClientUser(updatedUser),
    });
  } catch (error) {
    console.error('changeCredentials error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

const changePassword = changeCredentials;

// POST /api/auth/telegram-verify — Secure Telegram WebApp initData verification
const telegramVerify = async (req, res) => {
  try {
    const { initData } = req.body;
    if (!initData) {
      return res.status(400).json({ success: false, message: 'initData yuborilmadi' });
    }

    const crypto = require('crypto');
    const params = new URLSearchParams(initData);
    const hash = params.get('hash');
    if (!hash) {
      return res.status(400).json({ success: false, message: 'Telegram hash topilmadi' });
    }

    const botToken = process.env.TELEGRAM_BOT_TOKEN;
    if (botToken) {
      params.delete('hash');
      const items = [];
      for (const [key, value] of params.entries()) {
        items.push(`${key}=${value}`);
      }
      items.sort();
      const dataCheckString = items.join('\n');

      const secretKey = crypto.createHmac('sha256', 'WebAppData').update(botToken).digest();
      const calculatedHash = crypto.createHmac('sha256', secretKey).update(dataCheckString).digest('hex');

      if (calculatedHash !== hash) {
        return res.status(401).json({ success: false, message: 'Telegram autentifikatsiyasi xato (hash mos kelmadi)' });
      }

      const authDate = parseInt(params.get('auth_date'), 10);
      const now = Math.floor(Date.now() / 1000);
      if (now - authDate > 86400 * 2) { // 48 hours
        return res.status(401).json({ success: false, message: 'Telegram sessiyasi muddati o‘tgan' });
      }
    }

    const userStr = params.get('user');
    const tgUser = userStr ? JSON.parse(userStr) : null;

    let hasActiveSubscription = false;
    let subscriptionInfo = null;

    let userRow = null;
    let cafeId = 'zavero';
    let isAdmin = false;

    if (tgUser && tgUser.id) {
      try {
        const subRes = await db.query(
          `SELECT * FROM subscriptions 
           WHERE telegram_id = $1 AND status = 'active' AND end_date > NOW() 
           ORDER BY end_date DESC LIMIT 1`,
          [tgUser.id]
        );

        if (subRes.rows.length > 0) {
          const sub = subRes.rows[0];
          const daysRemaining = Math.max(0, Math.ceil((new Date(sub.end_date) - new Date()) / (1000 * 60 * 60 * 24)));
          hasActiveSubscription = true;
          subscriptionInfo = {
            id: sub.id,
            plan_name: sub.plan_name,
            start_date: sub.start_date,
            end_date: sub.end_date,
            daysRemaining,
          };
          if (sub.cafe_id) cafeId = sub.cafe_id;
        }

        // Check if user is an Administrator (Admin always has full access)
        const username = (tgUser.username || '').toLowerCase().replace('@', '');
        const tgIdStr = String(tgUser.id);
        const adminUsernames = (process.env.ADMIN_USERNAMES || 'mirzobekn,nmirzobek').toLowerCase().split(',').map(s => s.trim());
        const adminIds = (process.env.ADMIN_TELEGRAM_IDS || '').split(',').map(s => s.trim());

        // Check DB admin IDs as well
        let isDbAdmin = false;
        try {
          const dbAdminRes = await db.query("SELECT value FROM bot_settings WHERE key = 'admin_telegram_ids'");
          if (dbAdminRes.rows.length > 0 && dbAdminRes.rows[0].value) {
            isDbAdmin = dbAdminRes.rows[0].value.split(',').map(s => s.trim()).includes(tgIdStr);
          }
        } catch (e) { }

        if (adminUsernames.includes(username) || adminIds.includes(tgIdStr) || isDbAdmin || tgIdStr === '8413914382' || tgIdStr === '8873925517' || tgIdStr === '8989763161') {
          hasActiveSubscription = true;
          isAdmin = true;
          subscriptionInfo = subscriptionInfo || {
            id: 0,
            plan_name: 'Administrator (Cheksiz)',
            daysRemaining: 9999,
          };
        }

        // Link with internal user table
        const uRes = await db.query(
          'SELECT * FROM users WHERE telegram_id = $1 LIMIT 1',
          [tgIdStr]
        );
        if (uRes.rows.length > 0) {
          userRow = uRes.rows[0];
          cafeId = userRow.cafe_id || cafeId;
          if (userRow.role === 'admin' || userRow.role === 'director') isAdmin = true;
        } else {
          const tgUserRes = await db.query(
            'SELECT cafe_id FROM telegram_users WHERE telegram_id = $1',
            [tgUser.id]
          );
          if (tgUserRes.rows.length > 0 && tgUserRes.rows[0].cafe_id) {
            cafeId = tgUserRes.rows[0].cafe_id;
          }
        }
      } catch (dbErr) {
        console.warn('⚠️ [telegramVerify] Subscriptions tekshirish xatosi:', dbErr.message);
      }
    }

    const sessionPayload = {
      id: userRow?.id || tgUser?.id || 1,
      username: userRow?.username || tgUser?.username || `tg_${tgUser?.id}`,
      role: userRow?.role || (isAdmin ? 'admin' : 'waiter'),
      cafeId: userRow?.cafe_id || cafeId,
      telegramId: tgUser?.id,
    };
    const token = jwt.sign(sessionPayload, getJwtSecret(), { expiresIn: '7d' });

    return res.json({
      success: true,
      verified: true,
      token,
      user: userRow ? toClientUser(userRow) : sessionPayload,
      cafeId,
      telegramUser: tgUser,
      hasActiveSubscription,
      subscription: subscriptionInfo,
      message: hasActiveSubscription
        ? 'Telegram WebApp ma`lumotlari va faol obuna tasdiqlandi'
        : 'Obuna faol emas yoki muddati tugagan. Iltimos, Telegram botimiz orqali to‘lovni amalga oshiring.',
    });
  } catch (error) {
    console.error('telegramVerify error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

// POST /api/auth/refresh — Rotate refresh token and get fresh 15-minute access token
const refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ success: false, message: 'Refresh token yuborilmadi.' });
    }
    const tokenHash = hashToken(refreshToken);
    const tokenRes = await db.query(
      `SELECT rt.*, u.*, c.status AS cafe_status, c.end_date AS cafe_end_date, c.cafe_name, c.receipt_name
       FROM refresh_tokens rt
       JOIN users u ON rt.user_id = u.id
       LEFT JOIN cafes c ON u.cafe_id = c.cafe_id
       WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL AND rt.expires_at > CURRENT_TIMESTAMP`,
      [tokenHash]
    );
    if (tokenRes.rows.length === 0) {
      return res.status(401).json({ success: false, message: 'Yaroqsiz yoki muddati o‘tgan refresh token.' });
    }

    const row = tokenRes.rows[0];
    // Invalidate old token (Rotation)
    await db.query('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE id = $1', [row.id]);

    const clientIp = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    const newRefreshToken = await createRefreshToken(row.user_id, clientIp);
    const newAccessToken = generateToken(row);

    return res.json({
      success: true,
      token: newAccessToken,
      refreshToken: newRefreshToken,
      user: toClientUser(row),
    });
  } catch (error) {
    console.error('refresh error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

// POST /api/auth/logout — Revoke session and refresh token
const logout = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      const tokenHash = hashToken(refreshToken);
      await db.query('UPDATE refresh_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE token_hash = $1', [tokenHash]);
    }
    if (req.user && req.user.id) {
      logActivity({
        cafeId: req.user.cafeId || 'system',
        action: 'LOGOUT',
        details: `User ${req.user.username} logged out`,
        performedBy: req.user.username,
      });
    }
    return res.json({ success: true, message: 'Tizimdan muvaffaqiyatli chiqildi.' });
  } catch (error) {
    console.error('logout error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

module.exports = {
  register,
  login,
  refresh,
  logout,
  getMe,
  updateProfile,
  changePassword,
  changeCredentials,
  telegramVerify,
  toClientUser,
};

