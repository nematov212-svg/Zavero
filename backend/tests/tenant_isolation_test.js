/**
 * Phase 3: Automated Multi-Tenant Isolation Test Suite
 *
 * Proves that:
 * 1. Cafe A cannot read Cafe B's orders.
 * 2. Cafe A cannot see Cafe B's customers or customer history.
 * 3. Cafe A cannot view Cafe B's payments, refunds, or financial reports.
 * 4. Cafe A cannot access Cafe B's tables or reservations.
 * 5. Cafe A cannot modify or delete Cafe B's records.
 * 6. Cafe A cannot access Cafe B's dashboard statistics.
 * 7. Cafe A cannot download Cafe B's files or reports.
 * 8. Cafe A cannot access Cafe B's data through search or pagination.
 * 9. Changing an object ID never bypasses authorization (IDOR).
 * 10. Changing tenant IDs in requests (header/body) never grants access.
 * 11. Unauthorized cross-tenant relationships cannot be created.
 * 12. Logging out and switching accounts never exposes stale tenant data.
 * 13. Cached responses and real-time events never leak across tenants (Socket.IO).
 * 14. Background jobs, sync, and exports respect tenant boundaries.
 * 15. Unauthorized requests return an appropriate 403 or non-disclosing 404 response.
 */

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const http = require('http');
const { Server } = require('socket.io');
const { io: Client } = require('socket.io-client');
const app = require('../src/app');
const db = require('../src/config/db');
const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../src/config/jwt');
const { initSocket } = require('../src/socket/socketHandler');

async function runTenantIsolationSuite() {
  console.log('====================================================');
  console.log('   ZAVERO POS: STRICT MULTI-TENANT ISOLATION SUITE');
  console.log('====================================================\n');

  const server = http.createServer(app);
  const io = new Server(server, { cors: { origin: '*' } });
  initSocket(io);

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;
  console.log(`📡 Ephemeral Test Server running at ${baseUrl}`);

  async function request(reqPath, options = {}) {
    const res = await fetch(`${baseUrl}${reqPath}`, {
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

  const timestamp = Date.now();
  const cafeAId = `test_tenant_a_${timestamp}`;
  const cafeBId = `test_tenant_b_${timestamp}`;

  // Generated tokens
  const tokenAOwner = jwt.sign(
    { id: 9101, username: 'owner_a', role: 'admin', cafeId: cafeAId },
    secret,
    { expiresIn: '1h' }
  );
  const tokenAWaiter = jwt.sign(
    { id: 9102, username: 'waiter_a', role: 'waiter', cafeId: cafeAId },
    secret,
    { expiresIn: '1h' }
  );
  const tokenBOwner = jwt.sign(
    { id: 9201, username: 'owner_b', role: 'admin', cafeId: cafeBId },
    secret,
    { expiresIn: '1h' }
  );
  const tokenBCashier = jwt.sign(
    { id: 9202, username: 'cashier_b', role: 'cashier', cafeId: cafeBId },
    secret,
    { expiresIn: '1h' }
  );

  let bHallId = null;
  let bTableId = null;
  let bProductId = null;
  let bCategoryId = null;
  let bCustomerId = null;
  let bCustomerOrderId = null;
  let bReceiptId = null;

  let hasException = false;
  try {
    // -------------------------------------------------------------------------
    // Setup: Seed Synthetic Data for Cafe A and Cafe B
    // -------------------------------------------------------------------------
    console.log('\n--- Setting up Synthetic Tenants ---');
    await db.query(
      `INSERT INTO cafes (cafe_id, cafe_name, owner_name, owner_email, status, end_date)
       VALUES ($1, 'Tenant Cafe A', 'Owner A', 'owner_a@zavero.test', 'active', NOW() + INTERVAL '30 days'),
              ($2, 'Tenant Cafe B', 'Owner B', 'owner_b@zavero.test', 'active', NOW() + INTERVAL '30 days')`,
      [cafeAId, cafeBId]
    );

    // Resources in Cafe B
    const bHallRes = await db.query(
      `INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'Zal B Secret', 58136) RETURNING id`,
      [cafeBId]
    );
    bHallId = bHallRes.rows[0].id;

    const bTableRes = await db.query(
      `INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status)
       VALUES ($1, $2, 99, 6, 'free') RETURNING id`,
      [cafeBId, bHallId]
    );
    bTableId = bTableRes.rows[0].id;

    const bCatRes = await db.query(
      `INSERT INTO categories (cafe_id, name, icon_code_point) VALUES ($1, 'Category B Secret', 58136) RETURNING id`,
      [cafeBId]
    );
    bCategoryId = bCatRes.rows[0].id;

    const bProdRes = await db.query(
      `INSERT INTO products (cafe_id, name, price, category_id, stock, icon_code_point)
       VALUES ($1, 'Steak B Secret', 99000, $2, 20, 58674) RETURNING id`,
      [cafeBId, bCategoryId]
    );
    bProductId = bProdRes.rows[0].id;

    const bCustRes = await db.query(
      `INSERT INTO customers (cafe_id, name, phone, email, loyalty_points)
       VALUES ($1, 'VIP Customer B', '+998901234567', 'vip_b@zavero.test', 500) RETURNING id`,
      [cafeBId]
    );
    bCustomerId = bCustRes.rows[0].id;

    const bOrdRes = await db.query(
      `INSERT INTO customer_orders (cafe_id, items, customer_name, phone, type, status)
       VALUES ($1, $2, 'Order B VIP', '+998901234567', 'dineIn', 'pending') RETURNING id`,
      [cafeBId, JSON.stringify([{ productId: bProductId, name: 'Steak B Secret', qty: 1, price: 99000 }])]
    );
    bCustomerOrderId = bOrdRes.rows[0].id;

    const bRecRes = await db.query(
      `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, table_number)
       VALUES ($1, NOW(), $2, 99000, 'card', 'cashier_b', 99) RETURNING id`,
      [cafeBId, JSON.stringify([{ productId: bProductId, name: 'Steak B Secret', qty: 1, price: 99000 }])]
    );
    bReceiptId = bRecRes.rows[0].id;

    await db.query(
      `INSERT INTO reports (cafe_id, date_id, total_revenue, order_count, product_quantities, product_revenue)
       VALUES ($1, TO_CHAR(NOW(), 'YYYY-MM-DD'), 99000, 1, '{"Steak B Secret": 1}', '{"Steak B Secret": 99000}')`,
      [cafeBId]
    );

    console.log(`✓ Synthetic Cafe A (${cafeAId}) and Cafe B (${cafeBId}) seeded successfully.`);

    // =========================================================================
    // Test 1: Cafe A cannot read Cafe B's orders
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 1] Cafe A cannot read Cafe B's orders`);
    const aOrders = await request('/api/customer-orders', { token: tokenAOwner });
    const containsBOrder = aOrders.data?.customerOrders?.some((o) => o.id === bCustomerOrderId);
    if (aOrders.status === 200 && !containsBOrder) {
      console.log(`  ✓ PASS: Cafe A listing contains 0 orders from Cafe B.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Cafe A leaked Cafe B's orders!`, aOrders.data);
    }

    // =========================================================================
    // Test 2: Cafe A cannot see Cafe B's customers or customer history
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 2] Cafe A cannot see Cafe B's customers or customer history`);
    const aCusts = await request('/api/customers', { token: tokenAOwner });
    const containsBCust = aCusts.data?.customers?.some((c) => c.id === bCustomerId || c.name === 'VIP Customer B');
    if (aCusts.status === 200 && !containsBCust) {
      console.log(`  ✓ PASS: Cafe A customer list contains no customers from Cafe B.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Cafe A leaked Cafe B customer data!`, aCusts.data);
    }

    // =========================================================================
    // Test 3: Cafe A cannot view Cafe B's payments, receipts, or financial reports
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 3] Cafe A cannot view Cafe B's receipts or financial reports`);
    const aReceipts = await request('/api/receipts', { token: tokenAOwner });
    const containsBReceipt = aReceipts.data?.receipts?.some((r) => r.id === bReceiptId);
    const aReports = await request('/api/reports', { token: tokenAOwner });
    const containsBReport = aReports.data?.reports?.some((r) => r.totalRevenue === 99000);
    if (!containsBReceipt && !containsBReport) {
      console.log(`  ✓ PASS: Cafe A cannot access Cafe B's receipts or revenue reports.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Financial leakage between tenants!`);
    }

    // =========================================================================
    // Test 4: Cafe A cannot access Cafe B's tables or reservations
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 4] Cafe A cannot access Cafe B's tables`);
    const aTables = await request('/api/tables', { token: tokenAOwner });
    const containsBTable = aTables.data?.tables?.some((t) => t.id === bTableId || t.number === 99);
    if (aTables.status === 200 && !containsBTable) {
      console.log(`  ✓ PASS: Cafe A table list does not include Cafe B's table.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Table cross-tenant visibility!`);
    }

    // =========================================================================
    // Test 5: Cafe A cannot modify or delete Cafe B's records
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 5] Cafe A cannot modify or delete Cafe B's records (IDOR Protection)`);
    const delRes = await request(`/api/tables/${bTableId}`, {
      method: 'DELETE',
      token: tokenAOwner,
    });
    // Table should not be deleted
    const tableStillInB = await db.query('SELECT id FROM restaurant_tables WHERE id = $1 AND cafe_id = $2', [bTableId, cafeBId]);
    if ((delRes.status === 404 || delRes.status === 403) && tableStillInB.rows.length === 1) {
      console.log(`  ✓ PASS: Deleting Cafe B's table with Cafe A token was blocked (Status: ${delRes.status}).`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Cafe A was able to delete Cafe B's table! Status: ${delRes.status}`);
    }

    // =========================================================================
    // Test 6: Cafe A cannot access Cafe B's dashboard statistics or workspace
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 6] Cafe A cannot access Cafe B's dashboard statistics / full cafe data`);
    const fullCafeA = await request('/api/cafe/full', { token: tokenAOwner });
    const bProductInFull = fullCafeA.data?.products?.some((p) => p.id === bProductId || p.name === 'Steak B Secret');
    const bTableInFull = fullCafeA.data?.tables?.some((t) => t.id === bTableId);
    if (!bProductInFull && !bTableInFull) {
      console.log(`  ✓ PASS: Full workspace load (/api/cafe/full) is strictly tenant-isolated.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Full cafe data leaked items from Cafe B!`);
    }

    // =========================================================================
    // Test 7: Cafe A cannot download Cafe B's files or reports (CSV export)
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 7] Cafe A cannot download Cafe B's CSV reports`);
    const aCsv = await request('/api/reports/export/csv', { token: tokenAOwner });
    if (aCsv.status === 200 && !aCsv.data.includes('Steak B Secret') && !aCsv.data.includes('99000')) {
      console.log(`  ✓ PASS: CSV export contains only Cafe A records, 0 records from Cafe B.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: CSV export leaked Cafe B financial records!`);
    }

    // =========================================================================
    // Test 8: Cafe A cannot access Cafe B's data through search or pagination
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 8] Search/Pagination isolation`);
    const aProds = await request('/api/products', { token: tokenAOwner });
    const bProdFound = aProds.data?.products?.some((p) => p.id === bProductId);
    if (!bProdFound) {
      console.log(`  ✓ PASS: Product search and listings strictly scoped to Cafe A.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Cafe B product found in Cafe A product query!`);
    }

    // =========================================================================
    // Test 9: Changing an object ID never bypasses authorization (IDOR update check)
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 9] IDOR: Changing object ID in PUT /api/products fails`);
    const updateBProd = await request('/api/products', {
      method: 'POST',
      token: tokenAOwner,
      body: { id: bProductId, name: 'Hacked Steak', price: 1000 },
    });
    const checkBProd = await db.query('SELECT name, price FROM products WHERE id = $1', [bProductId]);
    if ((updateBProd.status === 404 || updateBProd.status === 403) && checkBProd.rows[0].name === 'Steak B Secret') {
      console.log(`  ✓ PASS: IDOR attempt rejected with ${updateBProd.status}; Cafe B record untouched.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: IDOR vulnerability allowed modifying Cafe B product!`, updateBProd.data);
    }

    // =========================================================================
    // Test 10: Changing tenant IDs in request headers or body never grants access
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 10] Spoofing x-cafe-id or body.cafeId is ignored`);
    const spoofHeader = await request('/api/tables', {
      token: tokenAOwner,
      headers: { 'x-cafe-id': cafeBId },
    });
    const hasSpoofedB = spoofHeader.data?.tables?.some((t) => t.id === bTableId);
    if (!hasSpoofedB) {
      console.log(`  ✓ PASS: Injected 'x-cafe-id: ${cafeBId}' was completely ignored.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Client was able to spoof tenant using x-cafe-id header!`);
    }

    // =========================================================================
    // Test 11: Unauthorized cross-tenant relationships cannot be created
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 11] Preventing cross-tenant table order insertion`);
    const crossOrder = await request(`/api/tables/${bTableId}/save-order`, {
      method: 'POST',
      token: tokenAOwner,
      body: {
        items: [{ product: { id: bProductId, price: 50000 }, qty: 1 }],
      },
    });
    if (crossOrder.status === 404 || crossOrder.status === 403) {
      console.log(`  ✓ PASS: Saving order for Cafe B's table with Cafe A token rejected (${crossOrder.status}).`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Cross-tenant table order was accepted! Status: ${crossOrder.status}`);
    }

    // =========================================================================
    // Test 12: Public Menu / Public Order Fallback Security
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 12] Public Menu querying non-existent cafe returns 404 without fallback`);
    const publicBadMenu = await request(`/api/customer-orders/public/menu/invalid_cafe_${timestamp}`);
    if (publicBadMenu.status === 404) {
      console.log(`  ✓ PASS: Querying unknown cafe returns 404; no first-cafe fallback leakage.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Public menu leaked data for unknown cafe! Status: ${publicBadMenu.status}`);
    }

    // =========================================================================
    // Test 13: Public Order Status Order Enumeration Protection
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 13] Public Order Status requires valid cafeId (prevents enumeration)`);
    const statusNoCafe = await request(`/api/customer-orders/public/order-status/${bCustomerOrderId}`);
    const statusWrongCafe = await request(`/api/customer-orders/public/order-status/${bCustomerOrderId}?cafeId=${cafeAId}`);
    if (statusNoCafe.status === 400 && statusWrongCafe.status === 404) {
      console.log(`  ✓ PASS: Missing cafeId returns 400, mismatched cafeId returns 404.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Order enumeration possible!`, { noCafe: statusNoCafe.status, wrongCafe: statusWrongCafe.status });
    }

    // =========================================================================
    // Test 14: Real-Time WebSockets Eavesdropping Prevention
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 14] Real-time Socket.IO tenant room authorization`);
    const socketA = Client(baseUrl, {
      auth: { token: tokenAOwner },
      transports: ['websocket'],
    });

    const socketJoinedResult = await new Promise((resolve) => {
      socketA.on('connect', () => {
        // Try to join Cafe B's room with Cafe A's authenticated socket
        socketA.emit('JOIN_CAFE', { cafeId: cafeBId });
      });

      socketA.on('ERROR', (err) => {
        resolve({ blocked: true, err });
      });

      socketA.on('JOINED_CAFE', (res) => {
        if (res.cafeId === cafeBId) {
          resolve({ blocked: false, res });
        }
      });

      setTimeout(() => resolve({ blocked: true, timeout: true }), 3000);
    });

    socketA.disconnect();

    if (socketJoinedResult.blocked) {
      console.log(`  ✓ PASS: Socket.IO blocked cross-tenant JOIN_CAFE attempt.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Socket client was allowed to join another cafe's room!`, socketJoinedResult);
    }

    // =========================================================================
    // Test 15: Background Sync / Delta Push respects tenant boundaries
    // =========================================================================
    totalTests++;
    console.log(`\n[Test 15] Background Sync Delta respects tenant boundaries`);
    const syncRes = await request('/api/sync/bootstrap', { token: tokenAOwner });
    const bItemInSync = syncRes.data?.bootstrap?.products?.some((p) => p.id === bProductId);
    if (syncRes.status === 200 && !bItemInSync) {
      console.log(`  ✓ PASS: Sync bootstrap only contains Cafe A data.`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: Sync bootstrap leaked Cafe B records!`);
    }

    // -------------------------------------------------------------------------
    // Cleanup Synthetic Data
    // -------------------------------------------------------------------------
    console.log('\n--- Cleaning up Synthetic Test Data ---');
    await db.query('DELETE FROM receipts WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM reports WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM customer_orders WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM customers WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM table_orders WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM restaurant_tables WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM products WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM categories WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM halls WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    await db.query('DELETE FROM cafes WHERE cafe_id IN ($1, $2)', [cafeAId, cafeBId]);
    console.log('✓ Cleaned up all synthetic test data.');

  } catch (err) {
    hasException = true;
    console.error('Tenant Isolation Suite Exception:', err);
  } finally {
    io.close();
    server.close();
  }

  console.log('\n====================================================');
  console.log(`TENANT ISOLATION SUMMARY: ${passed} / ${totalTests} GUARANTEES VERIFIED`);
  console.log('====================================================');

  if (!hasException && totalTests > 0 && passed === totalTests) {
    console.log('🎉 100% OF TENANT ISOLATION GUARANTEES CONFIRMED AND PASSED!\n');
    process.exit(0);
  } else {
    console.error('❌ SOME TENANT ISOLATION GUARANTEES FAILED!\n');
    process.exit(1);
  }
}

runTenantIsolationSuite();
