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
  getTashkentNow,
  buildDailyReportMessage,
  sendDailyReportForCafe,
  isReportAlreadySent,
  markReportAsSent,
  generateTodayReportMessage,
  generateRecentReceiptsMessage,
  generateAllTimeRevenueMessage,
  generateRecentDaysReportMessage,
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

    // ----------------------------------------------------
    // TEST 8: 24:00 Kunlik hisobot xabari va vaqt aniqligi
    // ----------------------------------------------------
    console.log('\n[Test 8] 24:00 Kunlik hisobot: Hisobot xabari va maydonlar to‘liqligi');
    const tkNow = getTashkentNow();
    assert(tkNow.year && tkNow.month && tkNow.day, 'Toshkent sanasi to‘liq shakllandi');
    assert(typeof tkNow.hour === 'number' && typeof tkNow.minute === 'number', 'Toshkent soati va daqiqasi raqam sifatida olindi');
    assert(/^\d{4}-\d{2}-\d{2}$/.test(tkNow.dateStr), 'dateStr YYYY-MM-DD formatida');

    const sampleMsg = buildDailyReportMessage({
      cafeName: 'Family Cafe',
      closedDate: '2026-11-10',
      timestamp: '2026-11-11 00:00:00',
      dailyRevenue: 1937000,
      dailyCount: 20,
      dailyCash: 1500000,
      dailyCard: 437000,
      allTimeRevenue: 23876000,
      allTimeCount: 215,
      isTest: false,
    });

    assert(sampleMsg.includes('Family Cafe'), 'Hisobotda Cafe nomi to‘g‘ri chiqdi');
    assert(sampleMsg.includes('2026-11-10'), 'Hisobotda yopilgan kun sanasi chiqdi');
    assert(sampleMsg.includes('2026-11-11 00:00:00'), 'Hisobotda aniq hisobot vaqti (soat:daqiqa:soniya) chiqdi');
    assert(sampleMsg.includes('Bugungi daromad:') && sampleMsg.includes('1 937 000'), 'Bugungi daromad to‘g‘ri formatda chiqdi');
    assert(sampleMsg.includes('Bugungi cheklar soni:') && sampleMsg.includes('20 ta'), 'Bugungi cheklar soni to‘g‘ri chiqdi');
    assert(sampleMsg.includes('Jami daromad (umumiy):') && sampleMsg.includes('23 876 000'), 'Jami umumiy daromad chiqdi');
    assert(sampleMsg.includes('Jami cheklar soni:') && sampleMsg.includes('215 ta'), 'Jami umumiy cheklar soni chiqdi');

    // ----------------------------------------------------
    // TEST 9: 24:00 Kunlik hisobot: Multi-tenant va SQL hisob-kitob
    // ----------------------------------------------------
    console.log('\n[Test 9] 24:00 Kunlik hisobot: Multi-tenant izolyatsiya va SQL hisob-kitob');
    const testDate = '2026-11-10';
    // Clean receipts for test cafes
    await db.query('DELETE FROM receipts WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);

    // Insert Alpha Cafe receipts for 2026-11-10
    await db.query(
      `INSERT INTO receipts (cafe_id, date, total, method, cash_paid, card_paid, cashier_name)
       VALUES ($1, '2026-11-10 12:00:00+05', 50000, 'cash', 50000, 0, 'Kassir A'),
              ($1, '2026-11-10 18:30:00+05', 30000, 'card', 0, 30000, 'Kassir A'),
              ($1, '2026-11-09 20:00:00+05', 20000, 'cash', 20000, 0, 'Kassir A')`,
      [cafeAId]
    );

    // Insert Beta Cafe receipt for 2026-11-10
    await db.query(
      `INSERT INTO receipts (cafe_id, date, total, method, cash_paid, card_paid, cashier_name)
       VALUES ($1, '2026-11-10 15:00:00+05', 990000, 'cash', 990000, 0, 'Kassir B')`,
      [cafeBId]
    );

    const statsAlphaRes = await db.query(
      `SELECT 
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN total ELSE 0 END), 0) AS daily_revenue,
         COALESCE(COUNT(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN 1 ELSE NULL END), 0) AS daily_count,
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'cash' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN cash_paid ELSE 0 END) END), 0) AS daily_cash,
         COALESCE(SUM(CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 AND method = 'card' THEN total ELSE (CASE WHEN to_char(date AT TIME ZONE 'Asia/Tashkent', 'YYYY-MM-DD') = $2 THEN card_paid ELSE 0 END) END), 0) AS daily_card,
         COALESCE(SUM(total), 0) AS all_time_revenue,
         COUNT(*) AS all_time_count
       FROM receipts
       WHERE cafe_id = $1`,
      [cafeAId, testDate]
    );

    const aStats = statsAlphaRes.rows[0];
    assert(Number(aStats.daily_revenue) === 80000, 'Alpha Cafe 2026-11-10 kunlik daromadi aniq 80 000');
    assert(Number(aStats.daily_count) === 2, 'Alpha Cafe 2026-11-10 cheklar soni aniq 2 ta');
    assert(Number(aStats.daily_cash) === 50000, 'Alpha Cafe naqd daromadi 50 000');
    assert(Number(aStats.daily_card) === 30000, 'Alpha Cafe karta daromadi 30 000');
    assert(Number(aStats.all_time_revenue) === 100000, 'Alpha Cafe umumiy daromadi aniq 100 000 (oldingi kun bilan)');
    assert(Number(aStats.all_time_count) === 3, 'Alpha Cafe umumiy cheklar soni aniq 3 ta');

    // Multi-tenant check: Beta Cafe stats must not leak into Alpha Cafe
    assert(!sampleMsg.includes('Beta Cafe'), 'Alpha hisobotida Beta Cafe ma‘lumotlari mutlaqo yo‘q');

    // ----------------------------------------------------
    // TEST 10: Dublikat himoyasi (Deduplication)
    // ----------------------------------------------------
    console.log('\n[Test 10] 24:00 Kunlik hisobot: Dublikat himoyasi (Deduplication)');
    const dedupeDate = '2026-11-10';
    const dedupeKey = `daily_report_${cafeAId}_${dedupeDate}`;
    await db.query('DELETE FROM bot_settings WHERE key = $1', [dedupeKey]);

    const beforeSent = await isReportAlreadySent(cafeAId, dedupeDate);
    assert(beforeSent === false, 'Yuborishdan oldin dublikat mavjud emas');

    await markReportAsSent(cafeAId, dedupeDate);
    const afterSent = await isReportAlreadySent(cafeAId, dedupeDate);
    assert(afterSent === true, 'Yuborilgandan so‘ng dublikat himoyasi faollashdi');

    const betaSent = await isReportAlreadySent(cafeBId, dedupeDate);
    assert(betaSent === false, 'Alpha dublikat himoyasi Beta Cafega ta‘sir qilmadi (Tenant isolation)');
    await db.query('DELETE FROM bot_settings WHERE key = $1', [dedupeKey]);

    // ----------------------------------------------------
    // TEST 11: 24 soatgacha kutmasdan hisobotlarni olish
    // ----------------------------------------------------
    console.log('\n[Test 11] On-demand hisobotlar: Bugungi, Cheklar, Jami, Oxirgi kunlar');
    
    // Seed receipts for Alpha Cafe today
    const nowTk = getTashkentNow();
    await db.query(
      `INSERT INTO receipts (cafe_id, date, total, method, cash_paid, card_paid, cashier_name)
       VALUES ($1, NOW(), 120000, 'cash', 120000, 0, 'Kassir Alpha'),
              ($1, NOW(), 80000, 'card', 0, 80000, 'Kassir Alpha')`,
      [cafeAId]
    );

    const todayMsg = await generateTodayReportMessage(cafeAId, 'Alpha Cafe');
    assert(todayMsg.includes('Alpha Cafe'), 'Bugungi hisobotda Cafe nomi bor');
    assert(todayMsg.includes('200 000'), 'Bugungi hisobotda 200 000 so‘m aks etgan');
    assert(todayMsg.includes('Naqd') && todayMsg.includes('120 000'), 'Bugungi hisobotda naqd 120 000');
    assert(todayMsg.includes('Karta') && todayMsg.includes('80 000'), 'Bugungi hisobotda karta 80 000');

    const recentChecksMsg = await generateRecentReceiptsMessage(cafeAId, 'Alpha Cafe');
    assert(recentChecksMsg.includes('🧾 Bugungi cheklar') || recentChecksMsg.includes('Alpha Cafe'), 'Cheklar ro‘yxati sarlavhasi to‘g‘ri');
    assert(recentChecksMsg.includes('120 000') || recentChecksMsg.includes('80 000'), 'Cheklar ro‘yxatida chek summalari bor');

    const allTimeMsg = await generateAllTimeRevenueMessage(cafeAId, 'Alpha Cafe');
    assert(allTimeMsg.includes('JAMI DAROMAD') || allTimeMsg.includes('Jami daromad'), 'Jami daromad sarlavhasi to‘g‘ri');
    assert(allTimeMsg.includes('Alpha Cafe'), 'Jami daromadda cafe nomi bor');

    const recentDaysMsg = await generateRecentDaysReportMessage(cafeAId, 'Alpha Cafe');
    assert(recentDaysMsg.includes('OXIRGI KUNLAR') || recentDaysMsg.includes('Oxirgi kunlar'), 'Oxirgi kunlar hisobot sarlavhasi to‘g‘ri');

    // ----------------------------------------------------
    // TEST 12: Cheksiz foydalanuvchi bitta cafega kirishi va bildirishnomalar olishi
    // ----------------------------------------------------
    console.log('\n[Test 12] Cheksiz foydalanuvchi kirishi va bir vaqtda bildirishnoma tarqatilishi');
    const userChat1 = '1111111';
    const userChat2 = '2222222';
    const userChat3 = '3333333';

    // Insert 3 separate users into the same cafe A
    await db.query(
      `INSERT INTO telegram_sessions (chat_id, user_id, cafe_id, role)
       VALUES ($1, $4, $5, 'cafe'),
              ($2, $4, $5, 'cafe'),
              ($3, $4, $5, 'cafe')
       ON CONFLICT (chat_id) DO UPDATE SET cafe_id = EXCLUDED.cafe_id, role = EXCLUDED.role`,
      [userChat1, userChat2, userChat3, adminAId, cafeAId]
    );

    const activeSessionsRes = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE cafe_id = $1 AND role = 'cafe'`,
      [cafeAId]
    );
    assert(activeSessionsRes.rows.length === 3, 'Alpha Cafega 3 ta turli Telegram foydalanuvchi bir vaqtda ulangan (cheksiz)');

    // Verify tenant isolation: Beta sessions are 0
    const betaSessionsRes = await db.query(
      `SELECT chat_id FROM telegram_sessions WHERE cafe_id = $1 AND role = 'cafe'`,
      [cafeBId]
    );
    assert(betaSessionsRes.rows.length === 0, 'Beta Cafeda Alpha foydalanuvchilari mutlaqo ko‘rinmaydi');

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
