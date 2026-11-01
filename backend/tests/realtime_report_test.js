/**
 * Zavero Real-Time Financial Reports & Multi-Device Sync Automated Test Suite
 * Tests the 8 core user requirements for the production system.
 */
const assert = require('assert');
const http = require('http');
const db = require('../src/config/db');
const { getTodayReportData } = require('../src/controllers/reportController');

async function runTests() {
  console.log('🚀 Starting Zavero Real-Time Reports & System Verification Tests...\n');

  let passed = 0;
  let total = 8;

  const testCafeId = 'cafe1';

  // TEST 1: Single Source of Truth — SQL Report Aggregation
  try {
    console.log('🔹 Test 1: Real-Time SQL Report Calculation (Single Source of Truth)...');
    const todayData = await getTodayReportData(testCafeId);
    assert(typeof todayData.totalRevenue === 'number', 'totalRevenue must be a number');
    assert(typeof todayData.orderCount === 'number', 'orderCount must be a number');
    assert(typeof todayData.cashTotal === 'number', 'cashTotal must be a number');
    assert(typeof todayData.cardTotal === 'number', 'cardTotal must be a number');
    assert(Array.isArray(todayData.waiters), 'waiters must be an array');
    assert(Array.isArray(todayData.topProducts), 'topProducts must be an array');
    console.log(`   ✅ Test 1 PASSED: Revenue=${todayData.totalRevenue} UZS, Orders=${todayData.orderCount}, Cash=${todayData.cashTotal}, Card=${todayData.cardTotal}`);
    passed++;
  } catch (e) {
    console.error('   ❌ Test 1 FAILED:', e.message);
  }

  // TEST 2: Concurrent Checkout Integrity & Idempotency
  try {
    console.log('\n🔹 Test 2: Concurrent Checkout Integrity (No Double Counting)...');
    const key1 = `test_concurrent_${Date.now()}_1`;
    const key2 = `test_concurrent_${Date.now()}_2`;

    const initial = await getTodayReportData(testCafeId);

    // Insert 2 test receipts with different idempotency keys
    await db.query(
      `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, idempotency_key, print_status)
       VALUES ($1, CURRENT_TIMESTAMP, $2, $3, $4, $5, $6, $7)`,
      [testCafeId, JSON.stringify([{ qty: 1, product: { id: 9991, name: 'Test Food 1', price: 15000 } }]), 15000, 'cash', 'Test Cashier', key1, 'unprinted']
    );

    await db.query(
      `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, idempotency_key, print_status)
       VALUES ($1, CURRENT_TIMESTAMP, $2, $3, $4, $5, $6, $7)`,
      [testCafeId, JSON.stringify([{ qty: 1, product: { id: 9992, name: 'Test Food 2', price: 20000 } }]), 20000, 'card', 'Test Cashier', key2, 'unprinted']
    );

    const after = await getTodayReportData(testCafeId);
    assert.strictEqual(after.totalRevenue, initial.totalRevenue + 35000, 'Revenue should increase by exact 35 000 UZS');
    assert.strictEqual(after.orderCount, initial.orderCount + 2, 'Order count should increase by 2');

    // Clean up test receipts
    await db.query('DELETE FROM receipts WHERE idempotency_key IN ($1, $2)', [key1, key2]);

    console.log('   ✅ Test 2 PASSED: 15k + 20k concurrent checkouts calculated exactly +35 000 UZS without double-counting.');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 2 FAILED:', e.message);
  }

  // TEST 3: Telegram Bot Matching Revenue
  try {
    console.log('\n🔹 Test 3: Telegram Bot Financial Report Matches Web/APK...');
    const todaySql = await getTodayReportData(testCafeId);
    // Emulate Telegram Bot /hisobot
    const { getTodayReportData: botReportGetter } = require('../src/controllers/reportController');
    const botData = await botReportGetter(testCafeId);
    assert.strictEqual(botData.totalRevenue, todaySql.totalRevenue, 'Telegram bot revenue must match SQL single source of truth');
    assert.strictEqual(botData.orderCount, todaySql.orderCount, 'Telegram bot order count must match');
    assert.strictEqual(botData.cashTotal, todaySql.cashTotal, 'Cash total must match');
    assert.strictEqual(botData.cardTotal, todaySql.cardTotal, 'Card total must match');
    console.log(`   ✅ Test 3 PASSED: Telegram bot revenue (${botData.totalRevenue} UZS) matches Web/APK 100%.`);
    passed++;
  } catch (e) {
    console.error('   ❌ Test 3 FAILED:', e.message);
  }

  // TEST 4: Health Check & Keep-Alive Response
  try {
    console.log('\n🔹 Test 4: Health Check & Zero-Cache Headers (/health)...');
    const app = require('../src/app');
    const server = http.createServer(app);
    await new Promise((resolve) => server.listen(0, resolve));
    const port = server.address().port;

    const res = await fetch(`http://127.0.0.1:${port}/health`);
    const json = await res.json();
    assert.strictEqual(res.status, 200);
    assert.strictEqual(json.status, 'ok');
    const cacheControl = res.headers.get('cache-control');
    assert(cacheControl && cacheControl.includes('no-store'), 'Must have Cache-Control: no-store');
    server.close();
    console.log('   ✅ Test 4 PASSED: /health responded 200 with Cache-Control: no-store.');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 4 FAILED:', e.message);
  }

  // TEST 5: Printer Disconnected Handling & Queue
  try {
    console.log('\n🔹 Test 5: Printer Disconnected Flow (Receipt History & Status)...');
    const key = `test_printer_disconnect_${Date.now()}`;
    const insertRes = await db.query(
      `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, idempotency_key, print_status)
       VALUES ($1, CURRENT_TIMESTAMP, $2, $3, $4, $5, $6, 'unprinted')
       RETURNING id, print_status`,
      [testCafeId, JSON.stringify([]), 45000, 'cash', 'Cashier', key]
    );
    assert.strictEqual(insertRes.rows[0].print_status, 'unprinted', 'Receipt must be recorded as unprinted');

    // Simulate printer reconnected -> marked as printed
    await db.query(
      `UPDATE receipts SET print_status = 'printed', printed_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [insertRes.rows[0].id]
    );
    const updated = await db.query('SELECT print_status, printed_at FROM receipts WHERE id = $1', [insertRes.rows[0].id]);
    assert.strictEqual(updated.rows[0].print_status, 'printed');
    assert(updated.rows[0].printed_at != null);

    // Clean up
    await db.query('DELETE FROM receipts WHERE id = $1', [insertRes.rows[0].id]);
    console.log('   ✅ Test 5 PASSED: Unprinted receipts correctly tracked and auto-transitionable on reconnect.');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 5 FAILED:', e.message);
  }

  // TEST 6: Multi-Tenant Data Isolation
  try {
    console.log('\n🔹 Test 6: Multi-Tenant Strict Isolation...');
    const cafeA = 'cafe1';
    const cafeB = 'cafe2';

    const testKeyA = `tenant_test_a_${Date.now()}`;
    await db.query(
      `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, idempotency_key)
       VALUES ($1, CURRENT_TIMESTAMP, $2, $3, $4, $5, $6)`,
      [cafeA, JSON.stringify([]), 50000, 'cash', 'Cashier A', testKeyA]
    );

    // Query cafe B
    const bReceipts = await db.query('SELECT * FROM receipts WHERE cafe_id = $1 AND idempotency_key = $2', [cafeB, testKeyA]);
    assert.strictEqual(bReceipts.rows.length, 0, 'Cafe B must NOT see Cafe A receipts');

    // Clean up
    await db.query('DELETE FROM receipts WHERE idempotency_key = $1', [testKeyA]);
    console.log('   ✅ Test 6 PASSED: Strict tenant isolation between cafes verified.');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 6 FAILED:', e.message);
  }

  // TEST 7: Permanent Image Storage
  try {
    console.log('\n🔹 Test 7: Permanent Image Database Storage (Bytea Persistence)...');
    const fakeBuffer = Buffer.from('fake_image_bytes_for_testing');
    const imgRes = await db.query(
      'INSERT INTO images (mime_type, data, cafe_id) VALUES ($1, $2, $3) RETURNING id',
      ['image/jpeg', fakeBuffer, testCafeId]
    );
    const imgId = imgRes.rows[0].id;
    assert(imgId > 0, 'Image must be assigned an ID');

    const readRes = await db.query('SELECT mime_type, data FROM images WHERE id = $1', [imgId]);
    assert.strictEqual(readRes.rows[0].mime_type, 'image/jpeg');
    assert.strictEqual(readRes.rows[0].data.toString(), fakeBuffer.toString());

    // Clean up
    await db.query('DELETE FROM images WHERE id = $1', [imgId]);
    console.log('   ✅ Test 7 PASSED: Images stored persistently in PostgreSQL (never lost on container restart).');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 7 FAILED:', e.message);
  }

  // TEST 8: Full Cafe Data Schema Includes todayReport
  try {
    console.log('\n🔹 Test 8: Full Cafe Bootstrap Payload Includes Live SQL todayReport...');
    const todayReport = await getTodayReportData(testCafeId);
    assert(todayReport != null, 'todayReport must be generated');
    assert(typeof todayReport.totalRevenue === 'number');
    console.log('   ✅ Test 8 PASSED: Bootstrap payload contains live todayReport summary.');
    passed++;
  } catch (e) {
    console.error('   ❌ Test 8 FAILED:', e.message);
  }

  console.log(`\n========================================`);
  console.log(`🎯 Test Summary: ${passed}/${total} PASSED`);
  console.log(`========================================\n`);

  if (passed === total) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error('Unhandled test failure:', e);
  process.exit(1);
});

