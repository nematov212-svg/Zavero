const db = require('../config/db');
const crypto = require('crypto');

async function migrate() {
  console.log('🔄 Starting multi-tenant security migration...');

  // 1. user_cafes table
  await db.query(`
    CREATE TABLE IF NOT EXISTS user_cafes (
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      cafe_id VARCHAR(64) NOT NULL REFERENCES cafes(cafe_id) ON DELETE CASCADE,
      role VARCHAR(30) NOT NULL DEFAULT 'cashier',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (user_id, cafe_id)
    );
    CREATE INDEX IF NOT EXISTS idx_user_cafes_user ON user_cafes(user_id);
    CREATE INDEX IF NOT EXISTS idx_user_cafes_cafe ON user_cafes(cafe_id);
  `);
  console.log('✅ user_cafes table ready');

  // Backfill user_cafes from users
  await db.query(`
    INSERT INTO user_cafes (user_id, cafe_id, role)
    SELECT id, cafe_id, role FROM users 
    WHERE cafe_id IS NOT NULL AND cafe_id != ''
    ON CONFLICT (user_id, cafe_id) DO UPDATE SET role = EXCLUDED.role;
  `);
  console.log('✅ user_cafes backfilled');

  // 2. cafes table additions
  await db.query(`
    ALTER TABLE cafes ADD COLUMN IF NOT EXISTS director_id INTEGER REFERENCES users(id);
    ALTER TABLE cafes ADD COLUMN IF NOT EXISTS print_agent_token VARCHAR(120);
    CREATE INDEX IF NOT EXISTS idx_cafes_director ON cafes(director_id);
    CREATE UNIQUE INDEX IF NOT EXISTS idx_cafes_print_agent_token ON cafes(print_agent_token) WHERE print_agent_token IS NOT NULL;
  `);
  console.log('✅ cafes table columns ready');

  // Generate tokens for cafes that do not have print_agent_token
  const cafesRes = await db.query("SELECT cafe_id FROM cafes WHERE print_agent_token IS NULL OR print_agent_token = ''");
  for (const c of cafesRes.rows) {
    const token = 'agy_print_' + crypto.randomBytes(24).toString('hex');
    await db.query('UPDATE cafes SET print_agent_token = $1 WHERE cafe_id = $2', [token, c.cafe_id]);
  }
  console.log(`✅ generated print_agent_token for ${cafesRes.rows.length} cafes`);

  // 3. refresh_tokens table
  await db.query(`
    CREATE TABLE IF NOT EXISTS refresh_tokens (
      id SERIAL PRIMARY KEY,
      user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token_hash VARCHAR(255) NOT NULL,
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      revoked_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      created_by_ip VARCHAR(50)
    );
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id);
    CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens(token_hash);
  `);
  console.log('✅ refresh_tokens table ready');

  // 4. Failed login tracker table for brute force prevention
  await db.query(`
    CREATE TABLE IF NOT EXISTS failed_logins (
      id SERIAL PRIMARY KEY,
      identifier VARCHAR(150) NOT NULL,
      ip_address VARCHAR(50) NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 1,
      last_attempt TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      locked_until TIMESTAMP WITH TIME ZONE
    );
    CREATE INDEX IF NOT EXISTS idx_failed_logins_ident ON failed_logins(identifier, ip_address);
  `);
  console.log('✅ failed_logins table ready');

  console.log('🎉 All database migrations executed successfully!');
  process.exit(0);
}

migrate().catch(e => {
  console.error('Migration failed:', e);
  process.exit(1);
});

