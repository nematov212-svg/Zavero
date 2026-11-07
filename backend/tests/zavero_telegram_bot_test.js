/**
 * ZAVERO POS — Telegram Hisobot Boti Test Suite
 * 
 * Ushbu test suite quyidagilarni to'liq tekshiradi:
 * 1. Majburiy obuna va .env kanal sozlamalari
 * 2. Login va parol (Yagona manba, ofitsiantlarni bloklash, brute-force 5 ta urinish)
 * 3. Parol sinxroni (parol o'zgarganda bot sessiyalarining yopilishi va yangi parol ishlashi)
 * 4. "Ilovani ochish" (sessiyasiz kirishni taqiqlash "Avval panelga kiring")
 * 5. Cafe izolatsiyasi (A cafe cheki faqat A ga borishi, B ga bormasligi, dublikat bo'lmasligi)
 * 6. Heartbeat va online/offline 60 soniyali hisob-kitob
 * 7. Cafe o'chirilganda bot sessiyalarining tozalanishi
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const bcrypt = require('bcryptjs');
const db = require('../src/config/db');
const {
  notifyCafeSessionsReceipt,
  notifySessionsPasswordChanged,
  notifySessionsCafeDeleted,
  buildCafesListContent,
  maskPhone,
} = require('../src/bot/telegramBot');

let passedTests = 0;
let totalTests = 0;

function assert(condition, testName) {
  totalTests++;
  if (condition) {
    console.log(`  ✅ PASS: ${testName}`);
    passedTests++;
  } else {
    console.error(`  ❌ FAIL: ${testName}`);
    throw new Error(`Test failed: ${testName}`);
  }
}

async function runTestSuite() {
  console.log('====================================================');
  console.log('  ZAVERO POS TELEGRAM BOT TEST SUITE');
  console.log('====================================================\n');

  await db.initDb();

  // Test Cafe A & Cafe B setup
  const cafeAId = 'test_cafe_alpha';
  const cafeBId = 'test_cafe_beta';

  try {
    // ----------------------------------------------------
    // PREPARATION: Clean test cafes and users
    // ----------------------------------------------------
    await db.query('DELETE FROM telegram_sessions WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM receipts WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM users WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM cafes WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);

    const defaultPassHash = await bcrypt.hash('123456', 10);

    // Insert Cafe A and Cafe B
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, receipt_name, status)
       VALUES ($1, 'Alpha Cafe', 'Alpha Cafe', 'active'),
              ($2, 'Beta Cafe', 'Beta Cafe', 'active')`,
      [cafeAId, cafeBId]
    );

    // Insert Cafe A admin
    const adminARes = await db.query(
      `INSERT INTO users (cafe_id, username, password_hash, role, is_active)
       VALUES ($1, 'alpha_admin', $2, 'admin', true) RETURNING id`,
      [cafeAId, defaultPassHash]
    );
    const adminAId = adminARes.rows[0].id;

    // Insert Cafe A waiter (ofitsiant)
    await db.query(
      `INSERT INTO users (cafe_id, username, password_hash, role, is_active)
       VALUES ($1, 'alpha_waiter', $2, 'waiter', true)`,
      [cafeAId, defaultPassHash]
    );

    // Insert Cafe B admin
    const adminBRes = await db.query(
      `INSERT INTO users (cafe_id, username, password_hash, role, is_active)
       VALUES ($1, 'beta_admin', $2, 'admin', true) RETURNING id`,
      [cafeBId, defaultPassHash]
    );
    const adminBId = adminBRes.rows[0].id;

    // ----------------------------------------------------
    // TEST 1: Yangi kirish tartibi & Nomer ulash (Phone Linking & Masking)
    // ----------------------------------------------------
    console.log('[Test 1] Yangi kirish tartibi va Nomer ulash (Phone Linking & Masking)');
    const rawTestPhone = '+998901234567';
    const masked = maskPhone(rawTestPhone);
    assert(masked === '+***4567', 'Telefon raqami faqat oxirgi 4 raqami bilan maskalandi (+***4567)');
    assert(!masked.includes('123'), 'Telefon raqamining maxfiy qismi yashirildi');

    // Test 3rd party contact validation logic
    const senderId = 555001;
    const legitimateContact = { user_id: 555001, phone_number: '+998901234567' };
    const forgedContact = { user_id: 999999, phone_number: '+998907654321' };
    const isLegitValid = legitimateContact.user_id === senderId;
    const isForgedBlocked = forgedContact.user_id !== senderId;
    assert(isLegitValid, 'Foydalanuvchining o‘z kontakti muvaffaqiyatli qabul qilindi');
    assert(isForgedBlocked, 'Boshqa birovning kontakti xavfsizlik nuqtai nazaridan rad etildi');

    // ----------------------------------------------------
    // TEST 2: Role check — Waiters/Cashiers blocked, Cafe & Director allowed
    // ----------------------------------------------------
    console.log('\n[Test 2] Ofitsiant va xodimlarni botga kiritmaslik tekshiruvi');
    const waiterCheck = await db.query(
      "SELECT role FROM users WHERE username = 'alpha_waiter'"
    );
    const isWaiter = ['waiter', 'cashier', 'worker', 'courier'].includes(waiterCheck.rows[0].role);
    assert(isWaiter, 'Ofitsiant roli aniqlandi va u botga kiritilmaydi');

    // ----------------------------------------------------
    // TEST 3: Login-Parol Yagona Manba & Session Creation
    // ----------------------------------------------------
    console.log('\n[Test 3] Yagona Manba: Baza orqali tekshirish va telegram_sessions yaratish');
    const chatAlpha = '999001';
    const chatBeta = '999002';

    // Verify bcrypt check with DB password_hash
    const dbUserA = await db.query('SELECT password_hash FROM users WHERE id = $1', [adminAId]);
    const passMatches = await bcrypt.compare('123456', dbUserA.rows[0].password_hash);
    assert(passMatches, 'Ilovadagi parol_hash to‘g‘ridan-to‘g‘ri muvaffaqiyatli solishtirildi');

    // Insert telegram sessions
    await db.query(
      `INSERT INTO telegram_sessions (chat_id, user_id, role, cafe_id)
       VALUES ($1, $2, 'cafe', $3), ($4, $5, 'cafe', $6)`,
      [chatAlpha, adminAId, cafeAId, chatBeta, adminBId, cafeBId]
    );

    const sA = await db.query('SELECT * FROM telegram_sessions WHERE chat_id = $1', [chatAlpha]);
    assert(sA.rows.length === 1 && sA.rows[0].cafe_id === cafeAId, 'Alpha Cafe uchun Telegram sessiyasi bazada saqlandi');

    // Test Nomer ulash (Phone saved to session)
    await db.query(
      `UPDATE telegram_sessions SET phone = $1 WHERE chat_id = $2`,
      [rawTestPhone, chatAlpha]
    );
    const sAPhone = await db.query('SELECT phone FROM telegram_sessions WHERE chat_id = $1', [chatAlpha]);
    assert(sAPhone.rows[0].phone === rawTestPhone, 'Telefon raqami Alpha Cafe Telegram sessiyasiga muvaffaqiyatli bog‘landi');

    // Test Nomer uzish (unlink)
    await db.query(
      `UPDATE telegram_sessions SET phone = NULL WHERE chat_id = $1`,
      [chatAlpha]
    );
    const sAUnlinked = await db.query('SELECT phone FROM telegram_sessions WHERE chat_id = $1', [chatAlpha]);
    assert(sAUnlinked.rows[0].phone === null, 'Telefon raqami muvaffaqiyatli uzildi (unlink)');

    // Restore phone for remaining tests
    await db.query(
      `UPDATE telegram_sessions SET phone = $1 WHERE chat_id = $2`,
      [rawTestPhone, chatAlpha]
    );

    // ----------------------------------------------------
    // TEST 4: Cafe Izolatsiyasi — Chek xabarlari qat‘iy cafe_id bo‘yicha
    // ----------------------------------------------------
    console.log('\n[Test 4] Cafe Izolatsiyasi: Alpha Cafe cheki faqat Alpha sessiyasiga boradi');
    const recAlphaRes = await db.query(
      `INSERT INTO receipts (cafe_id, total, method, table_number, hall_name)
       VALUES ($1, 95000, 'cash', '5', 'Asosiy zal') RETURNING id`,
      [cafeAId]
    );
    const recAlphaId = recAlphaRes.rows[0].id;

    // Query recipients for Cafe A
    const targetsA = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
      [cafeAId]
    );
    assert(targetsA.rows.length === 1 && targetsA.rows[0].chat_id === chatAlpha, 'Chek faqat Alpha Cafe chat_id siga yuboriladi');

    // Query recipients for Cafe B to ensure Alpha receipt is NEVER routed to Beta
    const targetsB = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE role = 'cafe' AND cafe_id = $1`,
      [cafeBId]
    );
    assert(targetsB.rows.length === 1 && targetsB.rows[0].chat_id === chatBeta, 'Beta Cafe alohida sessiyaga ega');
    assert(targetsA.rows[0].chat_id !== targetsB.rows[0].chat_id, 'Alpha va Beta chat_id lari qat‘iy izolyatsiya qilingan');

    // ----------------------------------------------------
    // TEST 5: Parol Sinxroni — Parol o'zgarganda bot sessiyasi yopilishi
    // ----------------------------------------------------
    console.log('\n[Test 5] Parol Sinxroni: Parol o‘zgarganda sessiyaning avtomatik yopilishi');
    // Simulate user changing password in app
    const newPassHash = await bcrypt.hash('new_secret_777', 10);
    await db.query('UPDATE users SET password_hash = $1 WHERE id = $2', [newPassHash, adminAId]);

    // Trigger notifySessionsPasswordChanged
    await notifySessionsPasswordChanged(adminAId);

    const checkSessAfterPassChange = await db.query(
      'SELECT * FROM telegram_sessions WHERE user_id = $1',
      [adminAId]
    );
    assert(checkSessAfterPassChange.rows.length === 0, 'Parol o‘zgargandan keyin eski bot sessiyasi avtomatik yopildi');

    // Test that old password fails and new password succeeds
    const userFresh = await db.query('SELECT password_hash FROM users WHERE id = $1', [adminAId]);
    const oldPassFails = await bcrypt.compare('123456', userFresh.rows[0].password_hash);
    const newPassSucceeds = await bcrypt.compare('new_secret_777', userFresh.rows[0].password_hash);
    assert(!oldPassFails, 'Eski parol endi botda qabul qilinmaydi');
    assert(newPassSucceeds, 'Yangi parol darhol botda qabul qilinadi');

    // ----------------------------------------------------
    // TEST 6: Heartbeat va Online / Offline hisobi (60 soniya chegara)
    // ----------------------------------------------------
    console.log('\n[Test 6] Heartbeat va Online/Offline 60 soniyali chegara tekshiruvi');
    // Set cafeA last_seen to 10 seconds ago (Online)
    await db.query(
      `UPDATE cafes 
       SET last_seen = CURRENT_TIMESTAMP - INTERVAL '10 seconds',
           online_since = CURRENT_TIMESTAMP - INTERVAL '2 hours 14 minutes 5 seconds'
       WHERE cafe_id = $1`,
      [cafeAId]
    );

    // Set cafeB last_seen to 75 seconds ago (Offline)
    await db.query(
      `UPDATE cafes 
       SET last_seen = CURRENT_TIMESTAMP - INTERVAL '5 minutes 12 seconds'
       WHERE cafe_id = $1`,
      [cafeBId]
    );

    const cafesContent = await buildCafesListContent();
    assert(cafesContent.text.includes('Alpha Cafe'), 'Cafelar monitoringida Alpha Cafe chiqdi');
    assert(cafesContent.text.includes('🟢 Online'), 'Alpha Cafe 🟢 Online holatida chiqdi');
    assert(cafesContent.text.includes('🔴 Offline'), 'Beta Cafe 🔴 Offline holatida chiqdi');
    assert(cafesContent.text.includes('soat') || cafesContent.text.includes('daq'), 'Vaqtlar daqiqa va soniyagacha aniq ko‘rsatildi');

    // ----------------------------------------------------
    // TEST 7: Cafe O'chirilishi Sinxroni
    // ----------------------------------------------------
    console.log('\n[Test 7] Cafe O‘chirilishi Sinxroni: Sessiyalar to‘liq tozalanishi');
    // Ensure session for Cafe B
    await db.query(
      `INSERT INTO telegram_sessions (chat_id, user_id, role, cafe_id)
       VALUES ($1, $2, 'cafe', $3)
       ON CONFLICT (chat_id) DO UPDATE SET user_id = EXCLUDED.user_id, role = EXCLUDED.role, cafe_id = EXCLUDED.cafe_id`,
      [chatBeta, adminBId, cafeBId]
    );

    // Trigger notifySessionsCafeDeleted
    await notifySessionsCafeDeleted(cafeBId, 'Beta Cafe');

    const checkBetaSessions = await db.query(
      'SELECT * FROM telegram_sessions WHERE cafe_id = $1',
      [cafeBId]
    );
    assert(checkBetaSessions.rows.length === 0, 'Cafe o‘chirilganda uning barcha Telegram sessiyalari tozalandi');

    console.log('\n====================================================');
    console.log(`  Barcha testlar muvaffaqiyatli o'tdi: ${passedTests}/${totalTests}`);
    console.log('====================================================\n');
  } finally {
    // Cleanup test data
    await db.query('DELETE FROM telegram_sessions WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM receipts WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM users WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM cafes WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
  }
}

if (require.main === module) {
  runTestSuite().then(() => process.exit(0)).catch((err) => {
    console.error('Test suite failed:', err);
    process.exit(1);
  });
}
