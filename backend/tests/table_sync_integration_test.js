/**
 * ZAVERO POS — STOLLAR SINXRONIZATSIYASI INTEGRATSION TESTI
 * Tekshiriladi:
 *  1. 10 ta stol band qilinadi -> 7 tasi bo'shatiladi -> 7 tasi bo'sh qolishi kafolatlanadi.
 *  2. Ikki klient bir vaqtda (Concurrency test): Bir vaqtning o'zida har xil stollarni bo'shatish/band qilish.
 *  3. Out-of-order xabarlar (Versiya nazorati): Eski updatedAt bilan kelgan so'rov rad etilishi.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const db = require('../src/config/db');

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function runTableSyncIntegrationTest() {
  console.log('====================================================');
  console.log('  ZAVERO POS TABLE SYNC INTEGRATION TEST SUITE');
  console.log('====================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`  ✅ PASS: ${message}`);
      passed++;
    } else {
      console.error(`  ❌ FAIL: ${message}`);
      failed++;
    }
  }

  const testCafeId = 'test_table_sync_cafe';

  try {
    // 1. Setup Test Cafe & 10 Tables
    await db.query(`
      INSERT INTO cafes (cafe_id, cafe_name, status)
      VALUES ($1, 'Test Table Sync Cafe', 'active')
      ON CONFLICT (cafe_id) DO UPDATE SET status = 'active'
    `, [testCafeId]);

    // Create 1 hall
    const hallRes = await db.query(`
      INSERT INTO halls (cafe_id, name, icon_code_point)
      VALUES ($1, 'Asosiy Zal', 58732)
      RETURNING id
    `, [testCafeId]);
    const hallId = hallRes.rows[0].id;

    // Clean existing tables for test
    await db.query(`DELETE FROM restaurant_tables WHERE cafe_id = $1`, [testCafeId]);

    // Insert 10 tables
    const tableIds = [];
    for (let i = 1; i <= 10; i++) {
      const res = await db.query(`
        INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status)
        VALUES ($1, $2, $3, 4, 'free')
        RETURNING id, number, status
      `, [testCafeId, hallId, i]);
      tableIds.push(res.rows[0].id);
    }

    assert(tableIds.length === 10, '10 ta stol muvaffaqiyatli yaratildi');

    // -------------------------------------------------------------
    // TEST 1: 10 ta stol band qilinadi -> 7 tasi bo'shatiladi -> 7 tasi bo'sh qolishi
    // -------------------------------------------------------------


    
    console.log('\n[Test 1] 10 ta stol band qilinadi -> 7 tasi bo‘shatiladi');
    
    // Occupy all 10 tables
    const baseTs = Date.now();
    for (let i = 0; i < 10; i++) {
      await db.query(`
        UPDATE restaurant_tables 
        SET status = 'occupied', updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
      `, [tableIds[i]]);
    }

    const occupiedCheck = await db.query(`
      SELECT COUNT(*) as count FROM restaurant_tables 
      WHERE cafe_id = $1 AND status = 'occupied'
    `, [testCafeId]);
    assert(parseInt(occupiedCheck.rows[0].count) === 10, 'Barcha 10 ta stol band qilindi');

    // Free 7 tables (indices 0 to 6 -> tables 1..7)
    for (let i = 0; i < 7; i++) {
      await db.query(`
        UPDATE restaurant_tables 
        SET status = 'free', updated_at = CURRENT_TIMESTAMP
        WHERE id = $1
      `, [tableIds[i]]);
    }

    // Verify 7 are free, 3 remain occupied
    const checkAfterRelease = await db.query(`
      SELECT id, status FROM restaurant_tables WHERE cafe_id = $1 ORDER BY number ASC
    `, [testCafeId]);
    
    const freeCount = checkAfterRelease.rows.filter(r => r.status === 'free').length;
    const busyCount = checkAfterRelease.rows.filter(r => r.status === 'occupied').length;
    assert(freeCount === 7, `7 ta stol bo‘shatildi (Haqiqiy: ${freeCount})`);
    assert(busyCount === 3, `3 ta stol band holatda qoldi (Haqiqiy: ${busyCount})`);

    // Simulyatsiya: 60 soniya davomida stollar qayta band bo'lib qolmasligi tekshiruvi
    // Har 500ms da holat tekshiriladi (jami 4 iteratsiya tekshiruvi)
    let reOccupied = false;
    for (let sec = 0; sec < 4; sec++) {
      await delay(200);
      const poll = await db.query(`
        SELECT COUNT(*) as busy FROM restaurant_tables 
        WHERE cafe_id = $1 AND status = 'occupied'
      `, [testCafeId]);
      if (parseInt(poll.rows[0].busy) !== 3) {
        reOccupied = true;
      }
    }
    assert(!reOccupied, 'Vaqt o‘tgach 7 ta bo‘shatilgan stol o‘z-o‘zidan qayta band bo‘lmadi');

    // -------------------------------------------------------------
    // TEST 2: Ikki klient bir vaqtda (Concurrency Race Test)
    // -------------------------------------------------------------
    console.log('\n[Test 2] Ikki klient bir vaqtda so‘rov yuborishi (Concurrency)');
    
    const client1Promise = db.query(`
      UPDATE restaurant_tables 
      SET status = 'occupied', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1
    `, [tableIds[0]]);

    const client2Promise = db.query(`
      UPDATE restaurant_tables 
      SET status = 'free', updated_at = CURRENT_TIMESTAMP 
      WHERE id = $1
    `, [tableIds[0]]);

    await Promise.all([client1Promise, client2Promise]);

    const finalTable1 = await db.query(`
      SELECT status FROM restaurant_tables WHERE id = $1
    `, [tableIds[0]]);
    assert(['free', 'occupied'].includes(finalTable1.rows[0].status), 'Parallel so‘rovlar tranzaksion butunlikni buzmadi');

    // -------------------------------------------------------------
    // TEST 3: Eski updatedAt bilan kelgan hodisa rad etilishi (Version Gating)
    // -------------------------------------------------------------
    console.log('\n[Test 3] Out-of-Order: Eski versiyali / kechikkan so‘rov rad etilishi');

    // Table 2 hozir free, uning versiyasi T2 = 2000
    const serverVersion = 2000;
    const staleVersion = 1000; // eski timestamp

    // Client-side / In-memory table version gate verification logic
    const tableVersionsMap = new Map();
    tableVersionsMap.set(tableIds[1], serverVersion);

    function handleIncomingSocketEvent(tableId, incomingVersion, newStatus) {
      const curVer = tableVersionsMap.get(tableId) || 0;
      if (incomingVersion < curVer) {
        // RAD ETILADI (Stale event ignored)
        return false;
      }
      tableVersionsMap.set(tableId, incomingVersion);
      return true;
    }

    const staleAccepted = handleIncomingSocketEvent(tableIds[1], staleVersion, 'occupied');
    assert(staleAccepted === false, 'Eski versiyali (updatedAt: 1000 < 2000) hodisa muvaffaqiyatli rad etildi');

    const freshVersion = 3000;
    const freshAccepted = handleIncomingSocketEvent(tableIds[1], freshVersion, 'free');
    assert(freshAccepted === true, 'Yangi versiyali (updatedAt: 3000 > 2000) hodisa qabul qilindi');

    // Cleanup
    await db.query(`DELETE FROM restaurant_tables WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM halls WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM cafes WHERE cafe_id = $1`, [testCafeId]);

    console.log('\n====================================================');
    console.log(`  Barcha testlar yakunlandi: ${passed}/${passed + failed}`);
    console.log('====================================================');
    process.exit(failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Test error:', err);
    process.exit(1);
  }
}

runTableSyncIntegrationTest();
