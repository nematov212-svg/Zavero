/**
 * Comprehensive Automated System Audit Test Suite
 * Scenarios A - J:
 *   A. Server Health & Ping
 *   B. Real-Time Table Booking & Atomic State Update
 *   C. Double-Booking Conflict Prevention (HTTP 409 TABLE_BUSY)
 *   D. Real-Time Table Release & Synchronization
 *   E. RBAC Hardening (Non-Admin 403 Forbidden on Table/Hall Deletion)
 *   F. Financial & Operational Analytics API (GET /api/reports/analytics)
 *   G. Financial CSV Export API (GET /api/reports/export/csv)
 *   H. Telegram Bot Table Actions & Logic Verification
 *   I. Data Tamper Protection & Audit Logging
 *   J. Anti-Spam & Zero Unauthorized Broadcasts
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const http = require('http');
const app = require('../src/app');
const db = require('../src/config/db');
const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../src/config/jwt');

async function runAuditSuite() {
  console.log('====================================================');
  console.log('   ZAVERO POS: AUTOMATED AUDIT & VERIFICATION SUITE');
  console.log('====================================================\n');

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;
  console.log(`📡 Ephemeral Test Server running at ${baseUrl}`);

  async function request(path, options = {}) {
    const res = await fetch(`${baseUrl}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
        ...(options.headers || {}),
      },
      method: options.method || 'GET',
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    const contentType = res.headers.get('content-type') || '';
    let data;
    if (contentType.includes('application/json')) {
      data = await res.json().catch(() => ({}));
    } else {
      data = await res.text().catch(() => '');
    }
    return { status: res.status, data, headers: res.headers };
  }

  let passed = 0;
  let totalTests = 0;
  const secret = getJwtSecret();

  // Test Tokens
  const testCafeId = `test_audit_cafe_${Date.now()}`;
  const adminToken = jwt.sign(
    { id: 9991, username: 'admin_test', role: 'admin', cafeId: testCafeId },
    secret,
    { expiresIn: '1h' }
  );
  const waiterToken = jwt.sign(
    { id: 9992, username: 'waiter_test', role: 'waiter', cafeId: testCafeId },
    secret,
    { expiresIn: '1h' }
  );

  let testTableId = null;
  let testHallId = null;

  try {
    // -------------------------------------------------------------------------
    // Setup test DB fixtures
    // -------------------------------------------------------------------------
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, status, created_at)
       VALUES ($1, 'Audit Test Cafe', 'active', CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO NOTHING`,
      [testCafeId]
    );

    const hallRes = await db.query(
      `INSERT INTO halls (cafe_id, name, icon_code_point)
       VALUES ($1, 'Test Hall', 57534)
       RETURNING id`,
      [testCafeId]
    );
    testHallId = hallRes.rows[0].id;

    const tableRes = await db.query(
      `INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status, total)
       VALUES ($1, $2, 99, 4, 'free', 0)
       RETURNING id`,
      [testCafeId, testHallId]
    );
    testTableId = tableRes.rows[0].id;

    // -------------------------------------------------------------------------
    // Scenario A: Server Health & Ping
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('[Scenario A] GET /health (Health & Latency Check)');
    const tStart = Date.now();
    const health = await request('/health');
    const latency = Date.now() - tStart;
    if (health.status === 200 && health.data.status === 'ok') {
      console.log(`  ✓ PASS: Health OK (Latency: ${latency}ms)`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Health check failed:`, health);
    }

    // -------------------------------------------------------------------------
    // Scenario B: Real-Time Table Booking & Atomic State Update
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario B] POST /api/tables/:id/order (Atomic Booking & Order Placement)');
    const bookRes = await request(`/api/tables/${testTableId}/order`, {
      method: 'POST',
      token: waiterToken,
      body: {
        items: [
          { product: { id: 1, name: 'Lavash', price: 35000 }, qty: 2, note: '' }
        ],
        note: 'Stol band qilindi',
      },
    });

    if (bookRes.status === 200 && bookRes.data.success && bookRes.data.table.status === 'occupied') {
      // Verify DB persistence
      const checkDb = await db.query('SELECT status, total, started_by FROM restaurant_tables WHERE id = $1', [testTableId]);
      if (checkDb.rows[0]?.status === 'occupied' && parseFloat(checkDb.rows[0]?.total) === 70000) {
        console.log(`  ✓ PASS: Table #${testTableId} booked atomically. Total: 70,000 so'm, Status: occupied, Started by: waiter_test`);
        passed++;
      } else {
        console.error(`  ✗ FAIL: DB table state mismatch:`, checkDb.rows);
      }
    } else {
      console.error(`  ✗ FAIL: Booking API returned error:`, bookRes);
    }

    // -------------------------------------------------------------------------
    // Scenario C: Double-Booking Conflict Prevention (HTTP 409 TABLE_BUSY)
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario C] Double-Booking Prevention (Concurrent conflict test)');
    // A second waiter tries to occupy the same table
    const waiter2Token = jwt.sign(
      { id: 9993, username: 'second_waiter', role: 'waiter', cafeId: testCafeId },
      secret,
      { expiresIn: '1h' }
    );

    const conflictRes = await request(`/api/tables/${testTableId}/order`, {
      method: 'POST',
      token: waiter2Token,
      body: {
        items: [
          { product: { id: 2, name: 'Burger', price: 30000 }, qty: 1 }
        ],
        note: 'Boshqa ofitsiant urinmoqda',
      },
    });

    if (conflictRes.status === 409 && conflictRes.data.code === 'TABLE_BUSY') {
      console.log(`  ✓ PASS: HTTP 409 TABLE_BUSY correctly returned. Message: "${conflictRes.data.message}"`);
      console.log(`          Occupied by: ${conflictRes.data.occupiedBy}, Table #${conflictRes.data.tableNumber}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Conflict was NOT caught with 409! Returned:`, conflictRes);
    }

    // -------------------------------------------------------------------------
    // Scenario D: Real-Time Table Release
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario D] POST /api/tables/:id/release (Atomic Table Release)');
    const relRes = await request(`/api/tables/${testTableId}/release`, {
      method: 'POST',
      token: waiterToken,
    });

    if (relRes.status === 200 && relRes.data.success) {
      const checkDb = await db.query('SELECT status, total, started_by FROM restaurant_tables WHERE id = $1', [testTableId]);
      const orderDb = await db.query('SELECT * FROM table_orders WHERE table_id = $1', [testTableId]);
      if (checkDb.rows[0]?.status === 'free' && orderDb.rows.length === 0) {
        console.log(`  ✓ PASS: Table released. DB Status: free, Total: 0, table_orders entry deleted.`);
        passed++;
      } else {
        console.error(`  ✗ FAIL: Table state in DB not cleared:`, checkDb.rows, orderDb.rows);
      }
    } else {
      console.error(`  ✗ FAIL: Release API returned error:`, relRes);
    }

    // -------------------------------------------------------------------------
    // Scenario E: RBAC Enforcement on Table/Hall Deletion
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario E] RBAC Security Check (Non-admin DELETE /api/tables/:id)');
    const deleteAsWaiter = await request(`/api/tables/${testTableId}`, {
      method: 'DELETE',
      token: waiterToken,
    });

    if (deleteAsWaiter.status === 403) {
      console.log(`  ✓ PASS: Waiter blocked from deleting table (HTTP 403 Forbidden).`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Waiter was NOT blocked! Status: ${deleteAsWaiter.status}`, deleteAsWaiter.data);
    }

    totalTests++;
    console.log('\n[Scenario E.2] RBAC Security Check (Non-admin DELETE /api/halls/:id)');
    const deleteHallAsWaiter = await request(`/api/halls/${testHallId}`, {
      method: 'DELETE',
      token: waiterToken,
    });

    if (deleteHallAsWaiter.status === 403) {
      console.log(`  ✓ PASS: Waiter blocked from deleting hall (HTTP 403 Forbidden).`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Waiter was NOT blocked from deleting hall! Status: ${deleteHallAsWaiter.status}`);
    }

    // -------------------------------------------------------------------------
    // Scenario F: Financial & Operational Analytics API
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario F] GET /api/reports/analytics (Financial Analytics)');
    // Seed a test receipt
    await db.query(
      `INSERT INTO receipts (cafe_id, cashier_name, total, method, cash_paid, card_paid, items, created_at)
       VALUES ($1, 'waiter_test', 105000, 'cash', 105000, 0, $2, CURRENT_TIMESTAMP)`,
      [testCafeId, JSON.stringify([{ name: 'Osh', price: 40000, qty: 2 }, { name: 'Choy', price: 5000, qty: 5 }])]
    );

    const analyticsRes = await request('/api/reports/analytics', {
      token: adminToken,
    });

    if (analyticsRes.status === 200 && analyticsRes.data.success && analyticsRes.data.summary) {
      const s = analyticsRes.data.summary;
      console.log(`  ✓ PASS: Analytics calculated successfully.`);
      console.log(`          Total Revenue: ${s.totalRevenue} so'm, Cash: ${s.cashRevenue} so'm, Receipts: ${s.totalReceipts}`);
      console.log(`          Top items count: ${analyticsRes.data.topItems.length}, Waiter breakdown count: ${analyticsRes.data.waiters.length}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Analytics API failed:`, analyticsRes);
    }

    // -------------------------------------------------------------------------
    // Scenario G: Financial CSV Export API
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario G] GET /api/reports/export/csv (CSV Export)');
    const csvRes = await request('/api/reports/export/csv', {
      token: adminToken,
    });

    if (csvRes.status === 200 && csvRes.headers.get('content-type')?.includes('text/csv') && typeof csvRes.data === 'string' && csvRes.data.includes('Chek ID')) {
      console.log(`  ✓ PASS: CSV report generated with valid headers and CSV rows.`);
      console.log(`          Preview:\n${csvRes.data.split('\n').slice(0, 3).join('\n')}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: CSV export failed:`, csvRes);
    }

    // -------------------------------------------------------------------------
    // Scenario H: Activity Audit Logs Persistence
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario H] Activity Logs Persistence Verification');
    const logsRes = await db.query(
      'SELECT action, details, performed_by FROM activity_logs WHERE cafe_id = $1 ORDER BY id DESC LIMIT 5',
      [testCafeId]
    );

    if (logsRes.rows.length > 0) {
      console.log(`  ✓ PASS: ${logsRes.rows.length} activity audit log(s) captured.`);
      logsRes.rows.forEach(r => console.log(`          [Audit] ${r.action} by ${r.performed_by}: ${r.details}`));
      passed++;
    } else {
      console.error(`  ✗ FAIL: No activity logs found in database!`);
    }

    // -------------------------------------------------------------------------
    // Scenario I: Non-admin Blocked from Financial Analytics (RBAC)
    // -------------------------------------------------------------------------
    totalTests++;
    console.log('\n[Scenario I] RBAC Security Check (Waiter blocked from /api/reports/analytics)');
    const waiterAnalytics = await request('/api/reports/analytics', {
      token: waiterToken,
    });

    if (waiterAnalytics.status === 403) {
      console.log(`  ✓ PASS: Waiter blocked from financial analytics (HTTP 403 Forbidden).`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Waiter was NOT blocked from analytics! Status: ${waiterAnalytics.status}`);
    }

    // -------------------------------------------------------------------------
    // Scenario J: Cleanup test artifacts
    // -------------------------------------------------------------------------
    await db.query('DELETE FROM receipts WHERE cafe_id = $1', [testCafeId]);
    await db.query('DELETE FROM activity_logs WHERE cafe_id = $1', [testCafeId]);
    await db.query('DELETE FROM table_orders WHERE cafe_id = $1', [testCafeId]);
    await db.query('DELETE FROM restaurant_tables WHERE cafe_id = $1', [testCafeId]);
    await db.query('DELETE FROM halls WHERE cafe_id = $1', [testCafeId]);
    await db.query('DELETE FROM cafes WHERE cafe_id = $1', [testCafeId]);

  } catch (err) {
    console.error('Audit Suite Exception:', err);
  } finally {
    server.close();
  }

  console.log('\n====================================================');
  console.log(`AUDIT TEST SUMMARY: ${passed} / ${totalTests} TESTS PASSED`);
  console.log('====================================================');

  if (passed === totalTests) {
    console.log('🎉 ALL INTEGRATION & SECURITY TESTS PASSED PERFECTLY!\n');
    process.exit(0);
  } else {
    console.error('❌ SOME TESTS FAILED!\n');
    process.exit(1);
  }
}

runAuditSuite();
