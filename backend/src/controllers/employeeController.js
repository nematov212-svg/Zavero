const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { mapEmployee } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

const list = async (req, res) => {
  const result = await db.query('SELECT * FROM employees WHERE cafe_id = $1 ORDER BY id ASC', [req.user.cafeId]);
  res.json({ success: true, employees: result.rows.map(mapEmployee) });
};

// Upsert employee & synchronize with users table so employees can log in
const save = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id, name, surname, username, email, phone, role, salary, password } = req.body;

    const cleanUsername = (username || '').trim().replace(/^@/, '');
    const cleanEmail = (email || '').trim() || (cleanUsername ? `${cleanUsername}@cafe.uz` : '');
    const empRole = role || 'waiter';

    let row;
    if (id) {
      const existing = await db.query('SELECT id, username FROM employees WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          `UPDATE employees SET name=$1, surname=$2, username=$3, email=$4, phone=$5, role=$6, salary=$7
           WHERE id=$8 AND cafe_id=$9 RETURNING *`,
          [name || '', surname || '', cleanUsername, cleanEmail, phone || '', empRole, salary || 0, id, cafeId]
        );
        row = result.rows[0];
      }
    }
    if (!row) {
      const result = await db.query(
        `INSERT INTO employees (cafe_id, name, surname, username, email, phone, role, salary)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
        [cafeId, name || '', surname || '', cleanUsername, cleanEmail, phone || '', empRole, salary || 0]
      );
      row = result.rows[0];
    }

    // Synchronize into users table
    if (cleanUsername) {
      const existingUser = await db.query(
        'SELECT id, password_hash FROM users WHERE cafe_id = $1 AND (LOWER(username) = LOWER($2) OR (LOWER(email) = LOWER($3) AND $3 != \'\'))',
        [cafeId, cleanUsername, cleanEmail]
      );

      let passwordHash = null;
      if (password && password.trim().length > 0) {
        const salt = await bcrypt.genSalt(10);
        passwordHash = await bcrypt.hash(password.trim(), salt);
      }

      if (existingUser.rows.length > 0) {
        const uId = existingUser.rows[0].id;
        if (passwordHash) {
          await db.query(
            `UPDATE users SET name=$1, surname=$2, username=$3, email=$4, phone=$5, role=$6, salary=$7, password_hash=$8, is_active=true, updated_at=CURRENT_TIMESTAMP
             WHERE id=$9`,
            [name || '', surname || '', cleanUsername, cleanEmail, phone || '', empRole, salary || 0, passwordHash, uId]
          );
        } else {
          await db.query(
            `UPDATE users SET name=$1, surname=$2, username=$3, email=$4, phone=$5, role=$6, salary=$7, is_active=true, updated_at=CURRENT_TIMESTAMP
             WHERE id=$8`,
            [name || '', surname || '', cleanUsername, cleanEmail, phone || '', empRole, salary || 0, uId]
          );
        }
      } else {
        const defaultPass = (password && password.trim().length > 0) ? password.trim() : '1234';
        const salt = await bcrypt.genSalt(10);
        const hash = await bcrypt.hash(defaultPass, salt);
        await db.query(
          `INSERT INTO users (cafe_id, username, password_hash, name, surname, phone, email, role, salary, is_active)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)`,
          [cafeId, cleanUsername, hash, name || '', surname || '', phone || '', cleanEmail, empRole, salary || 0]
        );
      }
    }

    notifyCafe(cafeId, 'EMPLOYEES_UPDATED', { employee: mapEmployee(row) });
    res.json({ success: true, employee: mapEmployee(row) });
  } catch (error) {
    console.error('Error saving employee:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id } = req.params;
    const existing = await db.query('SELECT username, email FROM employees WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    if (existing.rows.length > 0) {
      const { username, email } = existing.rows[0];
      await db.query('DELETE FROM users WHERE cafe_id = $1 AND (username = $2 OR email = $3)', [cafeId, username, email]);
    }
    await db.query('DELETE FROM employees WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    notifyCafe(cafeId, 'EMPLOYEES_UPDATED', { deletedId: parseInt(id, 10) });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
