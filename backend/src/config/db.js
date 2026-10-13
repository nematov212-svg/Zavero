const { Pool } = require('pg');
require('dotenv').config();

const createPool = () => {
  const connectionString = process.env.DATABASE_URL;

  if (connectionString) {
    const isSsl = !connectionString.includes('localhost') && !connectionString.includes('127.0.0.1');
    return new Pool({
      connectionString,
      ssl: isSsl ? { rejectUnauthorized: false } : false,
      max: process.env.NODE_ENV === 'production' ? 3 : 10,
      idleTimeoutMillis: 10000,
      connectionTimeoutMillis: 15000,
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
