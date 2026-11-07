const assert = require('assert');
const http = require('http');
const db = require('../src/config/db');
const app = require('../src/app');
const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'zavero_secret_key_change_in_production_2026';

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      username: user.username,
      role: user.role || 'admin',
      cafeId: user.cafe_id,
      name: user.name || 'Admin',
    },
    JWT_SECRET,
    { expiresIn: '1h' }
  );
}

async function runTests() {
  console.log('🧪 [TEST] Starting Multi-Tenant & Hall/Table Isolation Test Suite...\n');
  await db.initDb();

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}`;

  try {
    // 1. Fetch Family Cafe and Tovuq Cafe
    const familyCafeRes = await db.query("SELECT * FROM cafes WHERE cafe_id = '89f104ec-462e-466d-878c-a97615d9a372'");
    const tovuqCafeRes = await db.query("SELECT * FROM cafes WHERE cafe_id = 'tovuq_cafe'");
    assert(familyCafeRes.rows.length > 0, 'Family Cafe must exist');
    assert(tovuqCafeRes.rows.length > 0, 'Tovuq Cafe must exist');

    const familyUserRes = await db.query("SELECT * FROM users WHERE cafe_id = '89f104ec-462e-466d-878c-a97615d9a372' LIMIT 1");
    const tovuqUserRes = await db.query("SELECT * FROM users WHERE cafe_id = 'tovuq_cafe' LIMIT 1");
    assert(familyUserRes.rows.length > 0, 'Family Cafe user must exist');
    assert(tovuqUserRes.rows.length > 0, 'Tovuq Cafe user must exist');

    const familyToken = generateToken(familyUserRes.rows[0]);
    const tovuqToken = generateToken(tovuqUserRes.rows[0]);

    // TEST 1: MULTI-TENANT ISOLATION
    console.log('--- TEST 1: Multi-Tenant Isolation between Family Cafe and Tovuq Cafe ---');
    const familyProdRes = await fetch(`${baseUrl}/api/products`, {
      headers: { 'Authorization': `Bearer ${familyToken}` }
    });
    const familyProdData = await familyProdRes.json();
    assert.strictEqual(familyProdRes.status, 200);

    const tovuqProdRes = await fetch(`${baseUrl}/api/products`, {
      headers: { 'Authorization': `Bearer ${tovuqToken}` }
    });
    const tovuqProdData = await tovuqProdRes.json();
    assert.strictEqual(tovuqProdRes.status, 200);

    console.log(`✅ Family Cafe products count: ${familyProdData.products.length}`);
    console.log(`✅ Tovuq Cafe products count: ${tovuqProdData.products.length}`);

    // Ensure no cross-pollination
    const familyProductIds = new Set(familyProdData.products.map(p => p.id));
    for (const tp of tovuqProdData.products) {
      assert(!familyProductIds.has(tp.id), `Tovuq product ID ${tp.id} leaked into Family Cafe!`);
    }
    console.log('✅ PASS: Zero product crossover between Family Cafe and Tovuq Cafe.');

    // TEST 2: HALL & TABLE ISOLATION WITHIN THE SAME CAFE
    console.log('\n--- TEST 2: Hall & Table Isolation within the same Cafe ---');
    // Find two different halls for Family Cafe
    const hallsRes = await db.query(
      "SELECT id, name FROM halls WHERE cafe_id = '89f104ec-462e-466d-878c-a97615d9a372' ORDER BY id ASC LIMIT 2"
    );
    assert(hallsRes.rows.length >= 2, 'Need at least 2 halls in Family Cafe to test hall isolation');
    const hallA = hallsRes.rows[0];
    const hallB = hallsRes.rows[1];
    console.log(`Testing with Hall A: "${hallA.name}" (ID ${hallA.id}) and Hall B: "${hallB.name}" (ID ${hallB.id})`);

    // Ensure each hall has a table with number 1
    let tableA = (await db.query(
      "SELECT * FROM restaurant_tables WHERE cafe_id = '89f104ec-462e-466d-878c-a97615d9a372' AND hall_id = $1 AND number = 1",
      [hallA.id]
    )).rows[0];
    if (!tableA) {
      const ins = await db.query(
        "INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ('89f104ec-462e-466d-878c-a97615d9a372', $1, 1, 4, 'free') RETURNING *",
        [hallA.id]
      );
      tableA = ins.rows[0];
    }

    let tableB = (await db.query(
      "SELECT * FROM restaurant_tables WHERE cafe_id = '89f104ec-462e-466d-878c-a97615d9a372' AND hall_id = $1 AND number = 1",
      [hallB.id]
    )).rows[0];
    if (!tableB) {
      const ins = await db.query(
        "INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ('89f104ec-462e-466d-878c-a97615d9a372', $1, 1, 4, 'free') RETURNING *",
        [hallB.id]
      );
      tableB = ins.rows[0];
    }

    console.log(`Table A: ID ${tableA.id}, Hall: "${hallA.name}", Number: ${tableA.number}`);
    console.log(`Table B: ID ${tableB.id}, Hall: "${hallB.name}", Number: ${tableB.number}`);
    assert.notStrictEqual(tableA.id, tableB.id, 'Table A and Table B must have distinct IDs');

    // Ensure clean state for test tables
    await db.query("UPDATE restaurant_tables SET status='free', total=0, order_id=NULL, started_by=NULL WHERE id IN ($1, $2)", [tableA.id, tableB.id]);
    await db.query("DELETE FROM table_orders WHERE table_id IN ($1, $2)", [tableA.id, tableB.id]);

    // Step A: Place distinct orders on Table A and Table B
    const orderAItems = [
      { product: { id: 1, name: 'Taom Hall A', price: 50000, categoryId: 1 }, qty: 1 }
    ];
    const orderBItems = [
      { product: { id: 2, name: 'Taom Hall B', price: 75000, categoryId: 1 }, qty: 2 }
    ];

    const saveOrderARes = await fetch(`${baseUrl}/api/tables/${tableA.id}/order`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${familyToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ items: orderAItems, note: 'Order on Hall A Table 1' }),
    });
    assert.strictEqual(saveOrderARes.status, 200, 'Order on Table A must succeed');

    const saveOrderBRes = await fetch(`${baseUrl}/api/tables/${tableB.id}/order`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${familyToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ items: orderBItems, note: 'Order on Hall B Table 1' }),
    });
    assert.strictEqual(saveOrderBRes.status, 200, 'Order on Table B must succeed');

    // Verify both tables are occupied in database
    const statusCheckBefore = await db.query(
      'SELECT id, hall_id, number, status, total FROM restaurant_tables WHERE id IN ($1, $2)',
      [tableA.id, tableB.id]
    );
    for (const row of statusCheckBefore.rows) {
      assert.strictEqual(row.status, 'occupied', `Table ${row.id} should be occupied`);
    }
    console.log('✅ Both Table A (Hall A) and Table B (Hall B) are successfully occupied with distinct orders.');

    // Step B: Checkout Table B ONLY
    const checkoutPayload = {
      tableId: tableB.id,
      receipt: {
        id: Date.now(),
        date: new Date().toISOString(),
        items: orderBItems,
        total: 150000,
        method: 'cash',
        cashierName: 'Kassir Test',
        tableId: tableB.id,
        tableNumber: tableB.number,
        hallId: hallB.id,
        hallName: hallB.name,
        cashPaid: 150000,
        cardPaid: 0,
        printStatus: 'unprinted',
      },
      items: orderBItems,
      idempotencyKey: `test_checkout_${Date.now()}`,
    };

    const checkoutRes = await fetch(`${baseUrl}/api/receipts/checkout`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${familyToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(checkoutPayload),
    });
    const checkoutData = await checkoutRes.json();

    assert.strictEqual(checkoutRes.status, 200, `Checkout failed: ${JSON.stringify(checkoutData)}`);
    assert(checkoutData.success, 'Checkout response should be success');
    console.log(`✅ Table B checked out successfully. Receipt #${checkoutData.receipt.id} generated.`);

    // Step C: Verify Table B is free and its order is deleted
    const tableBAfter = (await db.query('SELECT status, total FROM restaurant_tables WHERE id = $1', [tableB.id])).rows[0];
    assert.strictEqual(tableBAfter.status, 'free', 'Table B must be status: free');
    assert.strictEqual(parseFloat(tableBAfter.total), 0, 'Table B total must be 0');

    const orderBAfter = await db.query('SELECT * FROM table_orders WHERE table_id = $1', [tableB.id]);
    assert.strictEqual(orderBAfter.rows.length, 0, 'Table B order must be deleted');
    console.log('✅ Verified Table B is freed and order deleted.');

    // Step D: CRITICAL VERIFICATION — Table A MUST STILL BE OCCUPIED WITH ORDER INTACT!
    const tableAAfter = (await db.query('SELECT status, total FROM restaurant_tables WHERE id = $1', [tableA.id])).rows[0];
    assert.strictEqual(tableAAfter.status, 'occupied', 'CRITICAL BUG: Table A in Hall A was improperly marked as free!');
    assert(parseFloat(tableAAfter.total) > 0, 'Table A total must remain intact');

    const orderAAfter = await db.query('SELECT * FROM table_orders WHERE table_id = $1', [tableA.id]);
    assert.strictEqual(orderAAfter.rows.length, 1, 'CRITICAL BUG: Table A order was deleted!');
    console.log('🌟 PASS: Table A in Hall A remained OCCUPIED with orders 100% intact after Table B in Hall B was paid!');

    // Cleanup Table A
    await db.query("UPDATE restaurant_tables SET status='free', total=0, order_id=NULL WHERE id = $1", [tableA.id]);
    await db.query("DELETE FROM table_orders WHERE table_id = $1", [tableA.id]);

    console.log('\n🎉 ALL TESTS PASSED SUCCESSFULLY! ZERO DATA LEAKAGE AND PERFECT TABLE ISOLATION!\n');
  } finally {
    server.close();
  }
  process.exit(0);
}

runTests().catch(err => {
  console.error('❌ Test failed with error:', err);
  process.exit(1);
});
