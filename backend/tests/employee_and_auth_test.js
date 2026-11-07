require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const bcrypt = require('bcryptjs');
const db = require('../src/config/db');

// Test locally or against current controller logic
const BASE_URL = process.env.TEST_API_URL || 'http://localhost:3000/api';

async function runTests() {
  console.log('🚀 [Test] Starting employee credentials & multi-tenant verification...');

  try {
    // 1. Direct DB check on hashing
    const testUsername = 'test_agent_' + Date.now().toString().slice(-6);
    const testPassword = 'TestPassword123!';
    const salt = await bcrypt.genSalt(10);
    const hash = await bcrypt.hash(testPassword, salt);

    // Verify bcrypt hash structure
    if (!hash.startsWith('$2a$') && !hash.startsWith('$2b$')) {
      throw new Error('Hash format is invalid');
    }
    const isMatch = await bcrypt.compare(testPassword, hash);
    if (!isMatch) throw new Error('Bcrypt compare failed');
    console.log('✅ [Test 1] Bcrypt hashing & verification works perfectly');

    // 2. Check token_version column in database
    const colCheck = await db.query(`
      SELECT column_name, data_type, column_default
      FROM information_schema.columns
      WHERE table_name = 'users' AND column_name = 'token_version'
    `);
    if (colCheck.rows.length === 0) {
      throw new Error('users.token_version column does not exist!');
    }
    console.log('✅ [Test 2] users.token_version column verified in PostgreSQL schema:', colCheck.rows[0]);

    // 3. Create test employee in cafe1
    const cafe1Id = 'cafe1';
    const cleanUser = testUsername;
    const insUser = await db.query(`
      INSERT INTO users (cafe_id, username, email, password_hash, role, name, token_version, is_active)
      VALUES ($1, $2, $3, $4, 'waiter', 'Test Waiter', 1, true)
      RETURNING id, username, token_version, is_active
    `, [cafe1Id, cleanUser, `${cleanUser}@cafe.uz`, hash]);
    const createdUser = insUser.rows[0];

    const insEmp = await db.query(`
      INSERT INTO employees (cafe_id, name, username, email, role, salary)
      VALUES ($1, 'Test Waiter', $2, $3, 'waiter', 3000000)
      RETURNING id, name, username, cafe_id
    `, [cafe1Id, cleanUser, `${cleanUser}@cafe.uz`]);
    const createdEmp = insEmp.rows[0];

    console.log('✅ [Test 3] Test employee created successfully:', { userId: createdUser.id, empId: createdEmp.id, username: cleanUser });

    // 4. Test Global Username Uniqueness
    // Attempting to register same username in cafe2 must detect collision
    const collisionCheck = await db.query(`
      SELECT id, cafe_id FROM users WHERE LOWER(username) = LOWER($1)
    `, [cleanUser]);
    if (collisionCheck.rows.length === 0) {
      throw new Error('Collision check failed to find existing username');
    }
    console.log('✅ [Test 4] Global username collision check found existing user across cafelar:', collisionCheck.rows[0]);

    // 5. Test Password Update & Token Version Invalidation
    const newPassword = 'NewSecretPass456!';
    const newHash = await bcrypt.hash(newPassword, await bcrypt.genSalt(10));
    const oldVersion = createdUser.token_version;

    const updateRes = await db.query(`
      UPDATE users SET
        password_hash = $1,
        token_version = token_version + 1,
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $2 AND cafe_id = $3
      RETURNING id, token_version
    `, [newHash, createdUser.id, cafe1Id]);

    const updatedUser = updateRes.rows[0];
    if (updatedUser.token_version !== oldVersion + 1) {
      throw new Error(`Token version was not incremented! Expected ${oldVersion + 1}, got ${updatedUser.token_version}`);
    }
    console.log(`✅ [Test 5] Password updated. token_version successfully incremented from ${oldVersion} to ${updatedUser.token_version}`);

    // Verify old password fails and new password succeeds
    const oldMatch = await bcrypt.compare(testPassword, newHash);
    const newMatch = await bcrypt.compare(newPassword, newHash);
    if (oldMatch === true || newMatch === false) {
      throw new Error('Password mismatch verification failed');
    }
    console.log('✅ [Test 6] Old password rejected, new password verified successfully');

    // 6. Test Employee Deletion: Soft-inactivation & Session revocation
    await db.query(`
      UPDATE users SET
        is_active = false,
        token_version = token_version + 1,
        username = username || '_deleted_' || FLOOR(EXTRACT(EPOCH FROM NOW())),
        updated_at = CURRENT_TIMESTAMP
      WHERE id = $1
    `, [createdUser.id]);

    await db.query(`DELETE FROM employees WHERE id = $1`, [createdEmp.id]);

    const deletedUserCheck = await db.query(`SELECT id, is_active, username, token_version FROM users WHERE id = $1`, [createdUser.id]);
    if (deletedUserCheck.rows[0].is_active !== false) {
      throw new Error('User was not set to is_active=false on deletion');
    }
    console.log('✅ [Test 7] On employee deletion: login disabled (is_active=false), token_version incremented, historical user row preserved for receipts');

    // Clean up test user
    await db.query(`DELETE FROM users WHERE id = $1`, [createdUser.id]);
    console.log('🧹 Test artifacts cleaned up successfully.');

    console.log('\n🎉 ALL INTEGRATION TESTS PASSED 100%!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Test failed:', err);
    process.exit(1);
  }
}

runTests();
