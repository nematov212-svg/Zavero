const db = require('../config/db');
const {
  mapCategory,
  mapProduct,
  mapHall,
  mapTable,
  mapCustomer,
  mapReceipt,
  mapCustomerOrder,
} = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

const dateIdFrom = (d) => new Date(d).toISOString().substring(0, 10);

/**
 * GET /api/sync/bootstrap — Oflayn rejim uchun to'liq boshlang'ich ma'lumotlar to'plami
 */
const bootstrap = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;

    const [
      catRes,
      prodRes,
      hallRes,
      tableRes,
      tblOrderRes,
      custRes,
      rcptRes,
      settingsRes,
    ] = await Promise.all([
      db.query('SELECT * FROM categories WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM products WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM halls WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM restaurant_tables WHERE cafe_id = $1 ORDER BY number ASC', [cafeId]),
      db.query('SELECT * FROM table_orders WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT * FROM customers WHERE cafe_id = $1 ORDER BY id DESC LIMIT 500', [cafeId]),
      db.query('SELECT * FROM receipts WHERE cafe_id = $1 ORDER BY date DESC LIMIT 100', [cafeId]),
      db.query('SELECT * FROM cafes WHERE cafe_id = $1 LIMIT 1', [cafeId]),
    ]);

    const tableOrdersMap = {};
    for (const row of tblOrderRes.rows) {
      tableOrdersMap[row.table_id] = row.items || [];
    }

    res.json({
      success: true,
      serverTime: new Date().toISOString(),
      bootstrap: {
        categories: catRes.rows.map(mapCategory),
        products: prodRes.rows.map(mapProduct),
        halls: hallRes.rows.map(mapHall),
        tables: tableRes.rows.map(mapTable),
        tableOrders: tableOrdersMap,
        customers: custRes.rows.map(mapCustomer),
        receipts: rcptRes.rows.map(mapReceipt),
        cafe: settingsRes.rows[0] || null,
      },
    });
  } catch (error) {
    console.error('syncController bootstrap error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * GET /api/sync/changes?since=<ISO_DATE> — O'zgarishlarni delta ko'rinishida yuklash
 */
const changes = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const since = req.query.since ? new Date(req.query.since) : new Date(Date.now() - 24 * 3600 * 1000);

    const [prodRes, tableRes, rcptRes, orderRes] = await Promise.all([
      db.query(
        'SELECT * FROM products WHERE cafe_id = $1 AND updated_at > $2 ORDER BY updated_at ASC',
        [cafeId, since]
      ),
      db.query(
        'SELECT * FROM restaurant_tables WHERE cafe_id = $1 AND updated_at > $2 ORDER BY updated_at ASC',
        [cafeId, since]
      ),
      db.query(
        'SELECT * FROM receipts WHERE cafe_id = $1 AND date > $2 ORDER BY date ASC',
        [cafeId, since]
      ),
      db.query(
        'SELECT * FROM customer_orders WHERE cafe_id = $1 AND updated_at > $2 ORDER BY updated_at ASC',
        [cafeId, since]
      ),
    ]);

    res.json({
      success: true,
      serverTime: new Date().toISOString(),
      changes: {
        products: prodRes.rows.map(mapProduct),
        tables: tableRes.rows.map(mapTable),
        receipts: rcptRes.rows.map(mapReceipt),
        customerOrders: orderRes.rows.map(mapCustomerOrder),
      },
    });
  } catch (error) {
    console.error('syncController changes error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/sync/push — Oflayn bajarilgan amallarni to'plam (batch) tarzida qabul qilish
 */
const push = async (req, res) => {
  const cafeId = req.user.cafeId;
  const { operations } = req.body;

  if (!Array.isArray(operations) || operations.length === 0) {
    return res.status(400).json({ success: false, message: 'operations massivi talab qilinadi.' });
  }

  const results = [];

  try {
    await db.withTransaction(async (client) => {
      for (const op of operations) {
        const { id, entityType, actionType, payload, idempotencyKey } = op;
        const idemp = idempotencyKey || `idemp_${id}`;

        // 1. CHEK / TO'LOV AMALI (RECEIPT CHECKOUT)
        if (entityType === 'receipt' || actionType === 'checkout') {
          // Idempotency tekshiruvi: avval qo'shilganmi?
          const checkDup = await client.query(
            'SELECT id FROM receipts WHERE cafe_id = $1 AND idempotency_key = $2 LIMIT 1',
            [cafeId, idemp]
          );

          if (checkDup.rows.length > 0) {
            results.push({ id, status: 'already_applied', receiptId: checkDup.rows[0].id });
            continue;
          }

          const receipt = payload.receipt || payload;
          const items = payload.items || receipt.items || [];
          const date = receipt.date ? new Date(receipt.date) : new Date();
          const dateId = dateIdFrom(date);

          const insReceipt = await client.query(
            `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, table_number, hall_name, cash_paid, card_paid, idempotency_key)
             VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
            [
              cafeId,
              date,
              JSON.stringify(items),
              receipt.total || 0,
              receipt.method || 'cash',
              receipt.cashierName || '',
              receipt.tableNumber ?? null,
              receipt.hallName ?? null,
              receipt.cashPaid || 0,
              receipt.cardPaid || 0,
              idemp,
            ]
          );

          // Ombor qoldig'ini kamaytirish
          for (const item of items) {
            const prodId = item.productId || item.product?.id || item.id;
            const qty = item.qty || item.quantity || 1;
            if (prodId) {
              await client.query(
                'UPDATE products SET stock = GREATEST(stock - $1, 0), updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND cafe_id = $3',
                [qty, prodId, cafeId]
              );
            }
          }

          // Hisobotni (reports) yangilash
          const reportRes = await client.query(
            'SELECT * FROM reports WHERE cafe_id = $1 AND date_id = $2',
            [cafeId, dateId]
          );

          let qtyMap = {}, revMap = {}, totalRev = 0, orderCount = 0;
          if (reportRes.rows.length > 0) {
            const row = reportRes.rows[0];
            qtyMap = row.product_quantities || {};
            revMap = row.product_revenue || {};
            totalRev = parseFloat(row.total_revenue || 0);
            orderCount = row.order_count || 0;
          }

          for (const item of items) {
            const name = item.product?.name || item.name || 'Noma\'lum';
            const price = parseFloat(item.product?.price || item.price || 0);
            const q = parseInt(item.qty || item.quantity || 1, 10);
            qtyMap[name] = (qtyMap[name] || 0) + q;
            revMap[name] = (revMap[name] || 0) + price * q;
          }
          totalRev += parseFloat(receipt.total || 0);
          orderCount += 1;

          await client.query(
            `INSERT INTO reports (cafe_id, date_id, total_revenue, order_count, product_quantities, product_revenue, updated_at)
             VALUES ($1,$2,$3,$4,$5,$6,CURRENT_TIMESTAMP)
             ON CONFLICT (cafe_id, date_id) DO UPDATE SET
               total_revenue = $3, order_count = $4, product_quantities = $5, product_revenue = $6, updated_at = CURRENT_TIMESTAMP`,
            [cafeId, dateId, totalRev, orderCount, JSON.stringify(qtyMap), JSON.stringify(revMap)]
          );

          // Agar stol ko'rsatilgan bo'lsa stolni bo'shatamiz
          const tableId = payload.tableId;
          if (tableId) {
            await client.query(
              `UPDATE restaurant_tables SET status = 'free', order_id = NULL, total = 0, started_by = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $1 AND cafe_id = $2`,
              [tableId, cafeId]
            );
            await client.query(
              'DELETE FROM table_orders WHERE table_id = $1 AND cafe_id = $2',
              [tableId, cafeId]
            );
            notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId, status: 'free' });
          }

          notifyCafe(cafeId, 'RECEIPT_CREATED', { receipt: mapReceipt(insReceipt.rows[0]) });
          results.push({ id, status: 'applied', receiptId: insReceipt.rows[0].id });
        }

        // 2. STOL BUYURTMASI (TABLE ORDER)
        else if (entityType === 'table_order') {
          const tableId = payload.tableId || op.entityId;
          const items = payload.items || [];
          const note = payload.note || '';
          const startedBy = payload.startedBy || 'Ofitsiant';

          await client.query(
            `INSERT INTO table_orders (table_id, cafe_id, items, note, started_by, updated_at)
             VALUES ($1,$2,$3,$4,$5,CURRENT_TIMESTAMP)
             ON CONFLICT (table_id) DO UPDATE SET
               items = $3, note = $4, started_by = $5, updated_at = CURRENT_TIMESTAMP`,
            [tableId, cafeId, JSON.stringify(items), note, startedBy]
          );

          notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId, items, note });
          results.push({ id, status: 'applied' });
        }

        // 3. BOSHQA AMALLAR
        else {
          results.push({ id, status: 'applied' });
        }
      }
    });

    res.json({
      success: true,
      serverTime: new Date().toISOString(),
      results,
    });
  } catch (error) {
    console.error('syncController push error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  bootstrap,
  changes,
  push,
};
