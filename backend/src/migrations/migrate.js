const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const db = require('../config/db');
const { seedNewCafe } = require('../utils/seedCafe');

const runMigrations = async () => {
  console.log('🔄 [Migration] Starting database migration...');
  const schemaPath = path.join(__dirname, 'schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');

  try {
    await db.query(sql);
    console.log('✅ [Migration] Database tables and indexes verified successfully.');

    // Deduplicate restaurant_tables before applying unique index
    await db.query(`
      DELETE FROM restaurant_tables a
      USING restaurant_tables b
      WHERE a.id > b.id
        AND a.cafe_id = b.cafe_id
        AND a.hall_id = b.hall_id
        AND a.number = b.number;
    `);
    await db.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_tables_cafe_hall_number ON restaurant_tables(cafe_id, hall_id, number);
    `);

    // Ensure token_version column exists and initialized
    await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER DEFAULT 1;`);
    await db.query(`UPDATE users SET token_version = 1 WHERE token_version IS NULL;`);

    // Ensure cafe_id in employees is NOT NULL
    await db.query(`
      UPDATE employees SET cafe_id = '89f104ec-462e-466d-878c-a97615d9a372' 
      WHERE cafe_id IS NULL OR cafe_id = '';
    `);
    await db.query(`ALTER TABLE employees ALTER COLUMN cafe_id SET NOT NULL;`).catch(() => {});

    // Sync any staff users (waiter, cashier, courier) into employees table if missing
    const staffUsers = await db.query(
      `SELECT u.id, u.cafe_id, u.name, u.surname, u.username, u.email, u.phone, u.role, u.salary
       FROM users u
       WHERE u.role IN ('waiter', 'cashier', 'courier') AND u.cafe_id IS NOT NULL AND u.cafe_id != ''`
    );
    for (const u of staffUsers.rows) {
      const empExists = await db.query(
        'SELECT id FROM employees WHERE cafe_id = $1 AND LOWER(username) = LOWER($2)',
        [u.cafe_id, u.username]
      );
      if (empExists.rows.length === 0) {
        await db.query(
          `INSERT INTO employees (cafe_id, name, surname, username, email, phone, role, salary)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [u.cafe_id, u.name || '', u.surname || '', u.username, u.email || '', u.phone || '', u.role, u.salary || 0]
        );
      }
    }

    await seedDirectorAndDefaults();
  } catch (error) {
    console.error('❌ [Migration Error]', error.message);
  }
};

/** Seeds Director account and ensures system cafe exists */
const seedDirectorAndDefaults = async () => {
  try {
    // 1. Ensure central zavero system cafe exists
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, receipt_name, status, start_date, end_date)
       VALUES ('zavero', 'ZAVERO Central', 'ZAVERO', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '100 years')
       ON CONFLICT (cafe_id) DO UPDATE SET 
         status = 'active',
         end_date = CURRENT_TIMESTAMP + INTERVAL '100 years'`
    );

    // 2. Ensure Director account exists with numeric password
    const directorUsername = 'director@zavero.uz';
    const directorEmail = 'director@zavero.uz';
    const numericDefaultPass = '123456';

    const existingDirector = await db.query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [directorUsername, directorEmail]
    );

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(numericDefaultPass, salt);

    if (existingDirector.rows.length === 0) {
      await db.query(
        `INSERT INTO users (cafe_id, username, password_hash, name, email, role, is_active, must_change_password)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        ['zavero', directorUsername, passwordHash, 'ZAVERO Director', directorEmail, 'director', true, false]
      );
      console.log('🌱 [Seed] Director account created: director@zavero.uz (Password: 123456)');
    } else {
      // Ensure director role & active, but preserve user-changed password if already set
      await db.query(
        `UPDATE users SET password_hash = COALESCE(NULLIF(password_hash, ''), $1), role = 'director', is_active = true WHERE id = $2`,
        [passwordHash, existingDirector.rows[0].id]
      );
      console.log('ℹ️  [Seed] Director account verified.');
    }

    // 3. Ensure cafe1 exists and has admin and staff with numeric passwords
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, receipt_name, owner_name, owner_email, status, start_date, end_date)
       VALUES ('cafe1', 'ZAVERO Cafe', 'ZAVERO', 'Kafe Admin', 'cafe1@cafe.uz', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '100 years')
       ON CONFLICT (cafe_id) DO UPDATE SET 
         status = 'active',
         end_date = CURRENT_TIMESTAMP + INTERVAL '100 years',
         receipt_name = COALESCE(cafes.receipt_name, 'ZAVERO')`
    );

    // Sync / insert cafe1 admin user
    const existingCafe1Admin = await db.query(
      "SELECT id FROM users WHERE (cafe_id = 'cafe1' AND role = 'admin') OR username = 'cafe1' OR email = 'cafe1@cafe.uz'"
    );
    if (existingCafe1Admin.rows.length === 0) {
      await db.query(
        `INSERT INTO users (cafe_id, username, password_hash, name, email, role, is_active, must_change_password)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        ['cafe1', 'cafe1', passwordHash, 'Kafe Admin', 'cafe1@cafe.uz', 'admin', true, false]
      );
      console.log('🌱 [Seed] cafe1 admin created: cafe1 (Password: 123456)');
    } else {
      await db.query(
        `UPDATE users SET password_hash = COALESCE(NULLIF(password_hash, ''), $1), is_active = true, email = COALESCE(NULLIF(email, ''), 'cafe1@cafe.uz') WHERE id = $2`,
        [passwordHash, existingCafe1Admin.rows[0].id]
      );
      console.log('ℹ️  [Seed] cafe1 admin verified.');
    }

    // Sync standard staff accounts for cafe1 (kassir, offitsant, oshpaz, kuryer)
    const defaultStaff = [
      { username: 'kassir', name: 'Kassir Aziz', role: 'cashier', email: 'kassir@ishchi.uz' },
      { username: 'offitsant', name: 'Ofitsiant Ali', role: 'waiter', email: 'offitsant@ishchi.uz' },
      { username: 'oshpaz', name: 'Oshpaz Hasan', role: 'cashier', email: 'oshpaz@ishchi.uz' },
      { username: 'kuryer', name: 'Kuryer Sardor', role: 'courier', email: 'kuryer@ishchi.uz' },
    ];

    for (const staff of defaultStaff) {
      const existingStaff = await db.query(
        'SELECT id FROM users WHERE cafe_id = $1 AND (username = $2 OR email = $3)',
        ['cafe1', staff.username, staff.email]
      );
      if (existingStaff.rows.length === 0) {
        await db.query(
          `INSERT INTO users (cafe_id, username, password_hash, name, email, role, is_active, must_change_password)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          ['cafe1', staff.username, passwordHash, staff.name, staff.email, staff.role, true, false]
        );
      } else {
        await db.query(
          'UPDATE users SET password_hash = $1, is_active = true WHERE id = $2',
          [passwordHash, existingStaff.rows[0].id]
        );
      }
    }
    console.log('ℹ️  [Seed] cafe1 default staff verified (Passwords: 123456).');

    // 4. Ensure tovuq_cafe exists with admin account
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, receipt_name, owner_name, owner_email, status, start_date, end_date)
       VALUES ('tovuq_cafe', 'Tovuq Cafe', 'Tovuq Cafe', 'Tovuq Admin', 'tovuq@cafe.uz', 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '100 years')
       ON CONFLICT (cafe_id) DO UPDATE SET 
         status = 'active',
         end_date = CURRENT_TIMESTAMP + INTERVAL '100 years',
         receipt_name = COALESCE(cafes.receipt_name, 'Tovuq Cafe')`
    );

    const existingTovuqAdmin = await db.query(
      "SELECT id FROM users WHERE (cafe_id = 'tovuq_cafe' AND role = 'admin') OR username = 'tovuq@cafe.uz' OR email = 'tovuq@cafe.uz'"
    );
    if (existingTovuqAdmin.rows.length === 0) {
      await db.query(
        `INSERT INTO users (cafe_id, username, password_hash, name, email, role, is_active, must_change_password)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        ['tovuq_cafe', 'tovuq@cafe.uz', passwordHash, 'Tovuq Admin', 'tovuq@cafe.uz', 'admin', true, false]
      );
      console.log('🌱 [Seed] tovuq_cafe admin created: tovuq@cafe.uz (Password: 123456)');
    } else {
      await db.query(
        `UPDATE users SET password_hash = COALESCE(NULLIF(password_hash, ''), $1), is_active = true WHERE id = $2`,
        [passwordHash, existingTovuqAdmin.rows[0].id]
      );
    }
    await seedNewCafe('tovuq_cafe', 'Tovuq Cafe').catch(() => {});
  } catch (error) {
    console.warn('⚠️  [Seed Warning]', error.message);
  }
};

module.exports = { runMigrations, seedDirectorAndDefaults };

if (require.main === module) {
  (async () => {
    try {
      await db.initDb();
      await runMigrations();
    } catch (e) {
      console.error('Migration error:', e);
    }
    // Migratsiyadan so'ng darhol Zavero SaaS serverini ishga tushirish
    require('../server');
  })();
}
