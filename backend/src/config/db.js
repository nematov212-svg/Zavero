const { Pool } = require('pg');
require('dotenv').config();

const createPool = () => {
  const connectionString = process.env.DATABASE_URL;

  if (connectionString) {
    const isSsl = !connectionString.includes('localhost') && !connectionString.includes('127.0.0.1');
    return new Pool({
      connectionString,
      ssl: isSsl ? { rejectUnauthorized: false } : false,
      max: 10,
      idleTimeoutMillis: 10000,
      connectionTimeoutMillis: 10000,
    });
  }

  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      "❌ [PostgreSQL] DATABASE_URL muhit o'zgaruvchisi topilmadi! Production rejimida DATABASE_URL kiritilishi shart (Neon/Supabase/PostgreSQL)."
    );
  }

  // Development localhost fallback
  const useSsl = process.env.PGSSL === 'true';
  return new Pool({
    host: process.env.PGHOST || 'localhost',
    port: parseInt(process.env.PGPORT || '5432', 10),
    user: process.env.PGUSER || 'postgres',
    password: process.env.PGPASSWORD || 'postgres',
    database: process.env.PGDATABASE || 'zavero_db',
    ssl: useSsl ? { rejectUnauthorized: false } : false,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 10000,
  });
};

const pool = createPool();

pool.on('error', (err) => {
  console.error('⚠️  [PostgreSQL Pool Error]', err.message);
});

const initDb = async () => {
  try {
    const client = await pool.connect();
    console.log('✅ [PostgreSQL] Connected successfully to database');
    try {
      await client.query('ALTER TABLE telegram_sessions ADD COLUMN IF NOT EXISTS phone VARCHAR(40);');
      await client.query(`
        ALTER TABLE table_orders ADD COLUMN IF NOT EXISTS hall_id INTEGER;
        UPDATE table_orders o
        SET hall_id = t.hall_id
        FROM restaurant_tables t
        WHERE o.table_id = t.id AND o.hall_id IS NULL;

        UPDATE receipts r
        SET hall_id = t.hall_id,
            hall_name = COALESCE(r.hall_name, h.name)
        FROM restaurant_tables t
        LEFT JOIN halls h ON h.id = t.hall_id
        WHERE r.table_id = t.id AND (r.hall_id IS NULL OR r.hall_name IS NULL);

        UPDATE receipts r
        SET hall_id = (SELECT id FROM halls WHERE cafe_id = r.cafe_id ORDER BY id ASC LIMIT 1),
            hall_name = COALESCE(r.hall_name, 'Zal')
        WHERE r.hall_id IS NULL OR r.hall_name IS NULL;

        UPDATE customer_orders o
        SET hall_id = (SELECT id FROM halls WHERE cafe_id = o.cafe_id ORDER BY id ASC LIMIT 1)
        WHERE o.hall_id IS NULL;

        CREATE TABLE IF NOT EXISTS announcements (
          id SERIAL PRIMARY KEY,
          title VARCHAR(255) NOT NULL,
          message TEXT NOT NULL,
          priority VARCHAR(20) NOT NULL DEFAULT 'normal',
          target_type VARCHAR(20) NOT NULL DEFAULT 'all',
          target_cafes JSONB DEFAULT '[]',
          send_telegram BOOLEAN DEFAULT false,
          created_by VARCHAR(120) DEFAULT 'Director',
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS announcement_reads (
          id SERIAL PRIMARY KEY,
          announcement_id INTEGER NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
          cafe_id VARCHAR(64) NOT NULL,
          user_id INTEGER,
          read_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          read_by VARCHAR(120)
        );
        ALTER TABLE announcement_reads ADD COLUMN IF NOT EXISTS user_id INTEGER;
        CREATE UNIQUE INDEX IF NOT EXISTS idx_announcement_reads_user ON announcement_reads(announcement_id, user_id) WHERE user_id IS NOT NULL;
        CREATE INDEX IF NOT EXISTS idx_announcements_created ON announcements(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_announcement_reads_cafe ON announcement_reads(cafe_id);
      `);
    } catch (migErr) {
      console.warn('⚠️ [Migration Notice]:', migErr.message);
    }
    client.release();
    return true;
  } catch (err) {
    console.error('❌ [PostgreSQL] Could not connect:', err.message);
    console.error('ℹ️  Set DATABASE_URL (or PGHOST/PGUSER/PGPASSWORD/PGDATABASE) in backend/.env');
    return false;
  }
};

const query = async (text, params = []) => {
  try {
    return await pool.query(text, params);
  } catch (error) {
    console.error('[SQL Error]', error.message, '| Query:', text.replace(/\s+/g, ' ').trim());
    throw error;
  }
};

/** Run several statements inside one transaction. `fn` receives a client with `.query`. */
const withTransaction = async (fn) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

module.exports = { pool, query, initDb, withTransaction };
