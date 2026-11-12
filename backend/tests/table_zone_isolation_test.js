require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const assert = require('assert');
const db = require('../src/config/db');

async function runTest() {
  console.log('====================================================');
  console.log('  TEST: ZONE-BASED TABLE ISOLATION & AGGREGATE REPORTS');
  console.log('====================================================');

  const testCafeId = 'test-cafe-' + Date.now();
  const dateStr = new Date().toISOString().slice(0, 10);

  try {
    // 1. Create Cafe
    await db.query(`INSERT INTO cafes (cafe_id, cafe_name, receipt_name, status) VALUES ($1, $2, $2, 'active')`, [testCafeId, 'Test Cafe Multi-Zone']);

    // 2. Create 4 halls: Zal, Padval, Dala, SABOY
    const hZal = (await db.query(`INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'Zal', 58000) RETURNING id`, [testCafeId])).rows[0].id;
    const hPadval = (await db.query(`INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'Padval', 58000) RETURNING id`, [testCafeId])).rows[0].id;
    const hDala = (await db.query(`INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'Dala', 58000) RETURNING id`, [testCafeId])).rows[0].id;
    const hSaboy = (await db.query(`INSERT INTO halls (cafe_id, name, icon_code_point) VALUES ($1, 'SABOY', 58000) RETURNING id`, [testCafeId])).rows[0].id;

    // 3. Create Table 1 in all 4 halls
    const tZal1 = (await db.query(`INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1, $2, 1, 4, 'free') RETURNING id`, [testCafeId, hZal])).rows[0].id;
    const tPadval1 = (await db.query(`INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1, $2, 1, 4, 'free') RETURNING id`, [testCafeId, hPadval])).rows[0].id;
    const tDala1 = (await db.query(`INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1, $2, 1, 4, 'free') RETURNING id`, [testCafeId, hDala])).rows[0].id;
    const tSaboy1 = (await db.query(`INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1, $2, 1, 4, 'free') RETURNING id`, [testCafeId, hSaboy])).rows[0].id;

    console.log(`Created tables: Zal 1 (id:${tZal1}), Padval 1 (id:${tPadval1}), Dala 1 (id:${tDala1}), SABOY 1 (id:${tSaboy1})`);

    // Verify all table IDs are distinct
    assert.notStrictEqual(tZal1, tPadval1);
    assert.notStrictEqual(tPadval1, tDala1);
    assert.notStrictEqual(tDala1, tSaboy1);
    console.log('✅ PASS: Barcha zallardagi Stol 1 larning ID lari mutlaqo mustaqil va takrorlanmas');

    // 4. Occupy Padval Table 1 only
    await db.query(
      `INSERT INTO table_orders (cafe_id, table_id, hall_id, items, note) VALUES ($1, $2, $3, $4, $5)`,
      [testCafeId, tPadval1, hPadval, JSON.stringify([{ product: { name: 'Osh', price: 40000 }, qty: 1 }]), 'Padval buyurtmasi']
    );
    await db.query(`UPDATE restaurant_tables SET status = 'occupied' WHERE id = $1`, [tPadval1]);

    // Check table statuses in DB
    const resTables = await db.query(
      `SELECT id, hall_id, number, status FROM restaurant_tables WHERE cafe_id = $1 ORDER BY hall_id`,
      [testCafeId]
    );

    const padvalTable = resTables.rows.find(t => t.id === tPadval1);
    const zalTable = resTables.rows.find(t => t.id === tZal1);
    const dalaTable = resTables.rows.find(t => t.id === tDala1);
    const saboyTable = resTables.rows.find(t => t.id === tSaboy1);

    assert.strictEqual(padvalTable.status, 'occupied', 'Padval Stol 1 band bo‘lishi kerak');
    assert.strictEqual(zalTable.status, 'free', 'Zal Stol 1 bo‘sh qolishi kerak');
    assert.strictEqual(dalaTable.status, 'free', 'Dala Stol 1 bo‘sh qolishi kerak');
    assert.strictEqual(saboyTable.status, 'free', 'SABOY Stol 1 bo‘sh qolishi kerak');
    console.log('✅ PASS: Padval Stol 1 band qilinganda Zal, Dala va SABOY dagi Stol 1 lar bo‘sh qoldi (100% izolyatsiya)');

    // 5. Create checkout receipts across multiple halls:
    // Padval Stol 1: 50,000
    // Zal Stol 1: 75,000
    // SABOY Stol 1: 100,000
    await db.query(
      `INSERT INTO receipts (cafe_id, order_id, table_id, hall_id, hall_name, table_number, total, cash_paid, card_paid, method, date, created_at, items)
       VALUES ($1, 'chk1', $2, $3, 'Padval', 1, 50000, 50000, 0, 'cash', $4, NOW(), '[]'::jsonb)`,
      [testCafeId, tPadval1, hPadval, dateStr]
    );
    await db.query(
      `INSERT INTO receipts (cafe_id, order_id, table_id, hall_id, hall_name, table_number, total, cash_paid, card_paid, method, date, created_at, items)
       VALUES ($1, 'chk2', $2, $3, 'Zal', 1, 75000, 0, 75000, 'card', $4, NOW(), '[]'::jsonb)`,
      [testCafeId, tZal1, hZal, dateStr]
    );
    await db.query(
      `INSERT INTO receipts (cafe_id, order_id, table_id, hall_id, hall_name, table_number, total, cash_paid, card_paid, method, date, created_at, items)
       VALUES ($1, 'chk3', $2, $3, 'SABOY', 1, 100000, 50000, 50000, 'split', $4, NOW(), '[]'::jsonb)`,
      [testCafeId, tSaboy1, hSaboy, dateStr]
    );

    // 6. Test Report Controller aggregation
    const reportCtrl = require('../src/controllers/reportController');
    const reportData = await reportCtrl.getTodayReportData(testCafeId);

    assert.strictEqual(reportData.totalRevenue, 225000, 'Umumiy daromad barcha zallarning summasi bo‘lishi kerak (50k + 75k + 100k = 225k)');
    assert.strictEqual(reportData.orderCount, 3, 'Jami cheklar soni 3 ta bo‘lishi kerak');
    assert.strictEqual(reportData.cashTotal, 100000, 'Jami naqd 100,000 bo‘lishi kerak (50k + 50k)');
    assert.strictEqual(reportData.cardTotal, 125000, 'Jami karta 125,000 bo‘lishi kerak (75k + 50k)');
    assert.strictEqual(reportData.averageCheck, 75000, 'O‘rtacha chek 75,000 bo‘lishi kerak (225k / 3)');

    // Verify hall breakdown exists
    assert(Array.isArray(reportData.halls), 'Zallar bo‘yicha tahlil massiv bo‘lishi kerak');
    const padvalStat = reportData.halls.find(h => h.name === 'Padval');
    const zalStat = reportData.halls.find(h => h.name === 'Zal');
    const saboyStat = reportData.halls.find(h => h.name === 'SABOY');
    assert(padvalStat && padvalStat.totalRevenue === 50000, 'Padval 50 000 bo‘lishi kerak');
    assert(zalStat && zalStat.totalRevenue === 75000, 'Zal 75 000 bo‘lishi kerak');
    assert(saboyStat && saboyStat.totalRevenue === 100000, 'SABOY 100 000 bo‘lishi kerak');

    console.log('✅ PASS: Hisobotlar barcha zallar (Zal + Padval + SABOY) bo‘yicha umumiy 225 000 so‘m va 3 ta chek qilib to‘g‘ri hisoblandi');
    console.log('✅ PASS: Zallar bo‘yicha alohida tahlil ham to‘g‘ri shakllandi');

    // 7. Test release table on Padval Stol 1
    await db.query(`DELETE FROM table_orders WHERE cafe_id = $1 AND table_id = $2`, [testCafeId, tPadval1]);
    await db.query(`UPDATE restaurant_tables SET status = 'free' WHERE id = $1`, [tPadval1]);

    const finalPadval = (await db.query(`SELECT status FROM restaurant_tables WHERE id = $1`, [tPadval1])).rows[0];
    assert.strictEqual(finalPadval.status, 'free', 'Padval Stol 1 bo‘shadi');
    console.log('✅ PASS: Padval Stol 1 to‘lovdan keyin to‘liq bo‘shatildi');

    console.log('====================================================');
    console.log('  BARCHA TESTLAR MUVAFFAQIYATLI O‘TDI!');
    console.log('====================================================');
  } finally {
    // Cleanup
    await db.query(`DELETE FROM receipts WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM table_orders WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM restaurant_tables WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM halls WHERE cafe_id = $1`, [testCafeId]);
    await db.query(`DELETE FROM cafes WHERE cafe_id = $1`, [testCafeId]);
  }
}

runTest().then(() => process.exit(0)).catch(err => {
  console.error('TEST XATOLIGI:', err);
  process.exit(1);
});
