const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { mapEmployee } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { getTenantCafeId } = require('../utils/tenantHelper');

const list = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const result = await db.query(
      'SELECT * FROM employees WHERE cafe_id = $1 ORDER BY id ASC',
      [cafeId]
    );
    res.json({ success: true, employees: result.rows.map(mapEmployee) });
  } catch (err) {
    console.error('employee list error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// Upsert employee & synchronize with users table so employees can log in
const save = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) {
      return res.status(403).json({ success: false, message: 'Kafega kirish huquqi yo‘q.' });
    }

    const { id, name, surname, username, email, phone, role, salary, password } = req.body;

    const cleanName = (name || '').trim();
    if (!cleanName) {
      return res.status(400).json({ success: false, message: 'Xodim ismini kiriting.' });
    }

    const cleanUsername = (username || '').trim().replace(/^@/, '');
    if (!cleanUsername) {
      return res.status(400).json({ success: false, message: 'Xodim loginini kiriting.' });
    }

    // Login faqat harf, raqam va pastki chiziqdan iborat (kamida 3 ta belgi)
    const usernameRegex = /^[a-zA-Z0-9_.-]{3,30}$/;
    if (!usernameRegex.test(cleanUsername)) {
      return res.status(400).json({
        success: false,
        message: "Login faqat harf, raqam va pastki chiziqdan iborat bo'lishi kerak (kamida 3 ta belgi).",
      });
    }

    const cleanEmail = (email || '').trim() || `${cleanUsername}@cafe.uz`;
    const empRole = role || 'waiter';
    const empSalary = parseFloat(salary) || 0;

    let existingEmp = null;
    let existingUser = null;

    if (id) {
      const empRes = await db.query(
        'SELECT * FROM employees WHERE id = $1 AND cafe_id = $2',
        [id, cafeId]
      );
      if (empRes.rows.length > 0) {
        existingEmp = empRes.rows[0];
        const uRes = await db.query(
          `SELECT * FROM users WHERE cafe_id = $1 AND (LOWER(username) = LOWER($2) OR LOWER(username) = LOWER($3)) LIMIT 1`,
          [cafeId, existingEmp.username, cleanUsername]
        );
        if (uRes.rows.length > 0) {
          existingUser = uRes.rows[0];
        }
      } else {
        return res.status(404).json({ success: false, message: 'Xodim topilmadi.' });
      }
    }

    // A1 & A2: Butun tizimda login unikal bo'lishi shart (barcha cafelar bo'ylab)
    const conflictRes = await db.query(
      'SELECT id, cafe_id FROM users WHERE LOWER(username) = LOWER($1)',
      [cleanUsername]
    );
    if (conflictRes.rows.length > 0) {
      const conflictId = conflictRes.rows[0].id;
      const isSelf = existingUser && existingUser.id === conflictId;
      if (!isSelf) {
        return res.status(400).json({
          success: false,
          message: 'Bu login band, boshqasini tanlang.',
        });
      }
    }

    // Parol tekshiruvi: yangi xodim uchun kamida 6 belgi shart; tahrirlashda yangi parol berilsa kamida 6 belgi
    const hasPassword = password && password.trim().length > 0;
    if (!existingEmp && (!hasPassword || password.trim().length < 6)) {
      return res.status(400).json({
        success: false,
        message: 'Parol kamida 6 belgidan iborat bo‘lishi kerak.',
      });
    }
    if (existingEmp && hasPassword && password.trim().length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Yangi parol kamida 6 belgidan iborat bo‘lishi kerak.',
      });
    }

    let savedEmployeeRow;
    if (existingEmp) {
      const upRes = await db.query(
        `UPDATE employees SET name=$1, surname=$2, username=$3, email=$4, phone=$5, role=$6, salary=$7
         WHERE id=$8 AND cafe_id=$9 RETURNING *`,
        [cleanName, surname || '', cleanUsername, cleanEmail, phone || '', empRole, empSalary, id, cafeId]
      );
      savedEmployeeRow = upRes.rows[0];
    } else {
      const insRes = await db.query(
        `INSERT INTO employees (cafe_id, name, surname, username, email, phone, role, salary)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
        [cafeId, cleanName, surname || '', cleanUsername, cleanEmail, phone || '', empRole, empSalary]
      );
      savedEmployeeRow = insRes.rows[0];
    }

    // Users jadvaliga xavfsiz sinxronizatsiya va sessiyalarni boshqarish
    let passwordHash = null;
    if (hasPassword) {
      const salt = await bcrypt.genSalt(10);
      passwordHash = await bcrypt.hash(password.trim(), salt);
    }

    if (existingUser) {
      const passChanged = hasPassword;
      const userChanged = existingUser.username.toLowerCase() !== cleanUsername.toLowerCase();
      const shouldInvalidateSessions = passChanged || userChanged;

      await db.query(
        `UPDATE users SET
           name = $1, surname = $2, username = $3, email = $4, phone = $5, role = $6, salary = $7,
           password_hash = COALESCE($8, password_hash),
           is_active = true,
           token_version = CASE WHEN $9 = true THEN COALESCE(token_version, 1) + 1 ELSE token_version END,
           updated_at = CURRENT_TIMESTAMP
         WHERE id = $10 AND cafe_id = $11`,
        [cleanName, surname || '', cleanUsername, cleanEmail, phone || '', empRole, empSalary, passwordHash, shouldInvalidateSessions, existingUser.id, cafeId]
      );

      await db.query(
        `UPDATE user_cafes SET role = $1 WHERE user_id = $2 AND cafe_id = $3`,
        [empRole, existingUser.id, cafeId]
      ).catch(() => {});

      if (shouldInvalidateSessions) {
        await db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [existingUser.id]).catch(() => {});
        notifyCafe(cafeId, 'USER_FORCE_LOGOUT', { userId: existingUser.id, username: cleanUsername });
      }
    } else {
      const passToUse = hasPassword ? password.trim() : '123456';
      const salt = await bcrypt.genSalt(10);
      const hash = await bcrypt.hash(passToUse, salt);

      const uRow = await db.query(
        `INSERT INTO users (cafe_id, username, password_hash, name, surname, phone, email, role, salary, is_active, token_version)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, 1) RETURNING id`,
        [cafeId, cleanUsername, hash, cleanName, surname || '', phone || '', cleanEmail, empRole, empSalary]
      );
      if (uRow.rows.length > 0) {
        await db.query(
          `INSERT INTO user_cafes (user_id, cafe_id, role)
           VALUES ($1, $2, $3)
           ON CONFLICT (user_id, cafe_id) DO UPDATE SET role = EXCLUDED.role`,
          [uRow.rows[0].id, cafeId, empRole]
        ).catch(() => {});
      }
    }

    notifyCafe(cafeId, 'EMPLOYEES_UPDATED', { employee: mapEmployee(savedEmployeeRow) });
    return res.json({ success: true, employee: mapEmployee(savedEmployeeRow) });
  } catch (error) {
    console.error('Error saving employee:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id } = req.params;

    const existing = await db.query(
      'SELECT id, username, email FROM employees WHERE id = $1 AND cafe_id = $2',
      [id, cafeId]
    );
    if (existing.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Xodim topilmadi' });
    }

    const { username, email } = existing.rows[0];

    // Find matching user record
    const uRes = await db.query(
      'SELECT id FROM users WHERE cafe_id = $1 AND (LOWER(username) = LOWER($2) OR (LOWER(email) = LOWER($3) AND $3 != \'\'))',
      [cafeId, username, email]
    );

    if (uRes.rows.length > 0) {
      const uId = uRes.rows[0].id;
      await db.query('DELETE FROM user_cafes WHERE user_id = $1', [uId]).catch(() => {});
      await db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [uId]).catch(() => {});

      // Soft-inactivate and append unique deleted suffix to free up the login for reuse,
      // while preserving historical references in reports/receipts
      const deletedSuffix = `_deleted_${uId}_${Math.floor(Date.now() / 1000)}`;
      await db.query(
        `UPDATE users SET 
           is_active = false, 
           token_version = COALESCE(token_version, 1) + 1,
           username = username || $1
         WHERE id = $2`,
        [deletedSuffix, uId]
      );

      notifyCafe(cafeId, 'USER_FORCE_LOGOUT', { userId: uId, username });
    }

    await db.query('DELETE FROM employees WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    notifyCafe(cafeId, 'EMPLOYEES_UPDATED', { deletedId: parseInt(id, 10) });

    return res.json({ success: true, message: 'Xodim muvaffaqiyatli o\'chirildi' });
  } catch (error) {
    console.error('Error removing employee:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
