const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { getJwtSecret, getJwtExpiresIn } = require('../config/jwt');
const { logActivity } = require('../utils/auditLogger');

const generateToken = (user) => {
  const secret = getJwtSecret();
  const expiresIn = getJwtExpiresIn();
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
      logActivity({
        cafeId: 'system',
        action: 'FAILED_LOGIN',
        details: `Login attempt failed for input: ${rawInput.substring(0, 50)}`,
        performedBy: req.ip,
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
        performedBy: req.ip,
      });
      return res.status(401).json({
        success: false,
        message: 'Login yoki parol xato. Iltimos, qaytadan tekshiring.',
      });
    }

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

    const token = generateToken(user);

    const isBlocked = user.role !== 'director' && user.cafe_status === 'blocked';
    const isExpired = user.role !== 'director' && user.cafe_end_date ? new Date(user.cafe_end_date) < new Date() : false;

    return res.json({
      success: true,
      message: 'Tizimga muvaffaqiyatli kirildi.',
      token,
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

module.exports = { register, login, getMe, updateProfile, changePassword, changeCredentials, toClientUser };
