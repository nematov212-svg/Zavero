const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });
const http = require('http');
const app = require('../src/app');
const db = require('../src/config/db');
const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../src/config/jwt');

async function testCheckoutDeduplication() {
  console.log('--- Testing Checkout Deduplication & Table Release ---');
  const server = http.createServer(app);
  await new Promise((r) => server.listen(0, r));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;

  const secret = getJwtSecret();
  const testCafeId = `test_dedup_cafe_${Date.now()}`;
  const token = jwt.sign({ cafeId: testCafeId, role: 'admin', name: 'Tester' }, secret, { expiresIn: '1h' });

  // 1. Seed cafe, hall and table
  await db.query(`INSERT INTO cafes (cafe_id, cafe_name, status) VALUES ($1, 'Dedup Cafe', 'active') ON CONFLICT DO NOTHING`, [testCafeId]);
  const hallRes = await db.query(
    `INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'Asosiy Zal', 57534) RETURNING id`,
    [testCafeId]
  );
  const hallId = hallRes.rows[0].id;
  const tblRes = await db.query(
    `INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1, $2, 77, 4, 'occupied') RETURNING id`,
    [testCafeId, hallId]
  );
  const tableId = tblRes.rows[0].id;

  // Insert sample order on table
  await db.query(
    `INSERT INTO table_orders (table_id, cafe_id, items, note) VALUES ($1, $2, '[]', 'test note') ON CONFLICT (table_id) DO UPDATE SET note = 'test note'`,
    [tableId, testCafeId]
  );

  const payload = {
    receipt: {
      id: Date.now(),
      total: 35000,
      method: 'cash',
      tableNumber: 77,
      hallName: 'Zal',
      cashPaid: 35000,
      cardPaid: 0,
      cashierName: 'Tester'
    },
    tableId: tableId,
    items: [
      { product: { id: 9999, name: 'Shaurma mini', price: 35000 }, qty: 1 }
    ]
  };

  async function sendCheckout(idemKey) {
    const res = await fetch(`${baseUrl}/api/receipts/checkout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
      },
      body: JSON.stringify({ ...payload, idempotencyKey: idemKey })
    });
    return { status: res.status, data: await res.json() };
  }

  // Rapidly fire 3 concurrent checkouts with the same idempotency key
  console.log('Firing 3 concurrent checkouts with identical idempotencyKey...');
  const idemKey = `idem_${Date.now()}`;
  const [res1, res2, res3] = await Promise.all([
    sendCheckout(idemKey),
    sendCheckout(idemKey),
    sendCheckout(idemKey)
  ]);

  console.log('Res 1:', res1.status, res1.data.success, res1.data.receipt?.id, 'isDuplicate:', res1.data.isDuplicate);
  console.log('Res 2:', res2.status, res2.data.success, res2.data.receipt?.id, 'isDuplicate:', res2.data.isDuplicate);
  console.log('Res 3:', res3.status, res3.data.success, res3.data.receipt?.id, 'isDuplicate:', res3.data.isDuplicate);

  // Check how many receipts were inserted in database
  const countRes = await db.query(
    `SELECT COUNT(*) FROM receipts WHERE cafe_id = $1 AND table_number = 77`,
    [testCafeId]
  );
  console.log(`Receipt count in DB for table 77: ${countRes.rows[0].count}`);

  if (parseInt(countRes.rows[0].count, 10) !== 1) {
    console.error('❌ FAIL: Expected exactly 1 receipt in DB, got ' + countRes.rows[0].count);
    process.exit(1);
  }
  console.log('✅ PASS: Exactly 1 receipt was created despite 3 concurrent requests!');

  // Check table status in database
  const tblCheck = await db.query(`SELECT status FROM restaurant_tables WHERE id = $1`, [tableId]);
  console.log('Table status in DB:', tblCheck.rows[0]?.status);
  if (tblCheck.rows[0]?.status !== 'free') {
    console.error('❌ FAIL: Expected table status to be free, got ' + tblCheck.rows[0]?.status);
    process.exit(1);
  }
  console.log('✅ PASS: Table is marked free in DB!');

  // Clean up
  await db.query(`DELETE FROM receipts WHERE cafe_id = $1`, [testCafeId]);
  await db.query(`DELETE FROM table_orders WHERE table_id = $1`, [tableId]);
  await db.query(`DELETE FROM restaurant_tables WHERE cafe_id = $1`, [testCafeId]);
  await db.query(`DELETE FROM halls WHERE cafe_id = $1`, [testCafeId]);
  await db.query(`DELETE FROM cafes WHERE cafe_id = $1`, [testCafeId]);

  server.close();
  console.log('🎉 ALL DEDUPLICATION & TABLE RELEASE CHECKS PASSED!');
  process.exit(0);
}

testCheckoutDeduplication().catch((e) => {
  console.error('Test error:', e);
  process.exit(1);
});
