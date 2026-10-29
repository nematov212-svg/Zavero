const db = require('../config/db');
const { mapReceipt, mapReport } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

const dateIdFrom = (d) => new Date(d).toISOString().substring(0, 10);

const list = async (req, res) => {
  const result = await db.query(
    'SELECT * FROM receipts WHERE cafe_id = $1 ORDER BY date DESC LIMIT 200',
    [req.user.cafeId]
  );
  res.json({ success: true, receipts: result.rows.map(mapReceipt) });
};

// POST /api/receipts/checkout — finalize payment: save receipt, decrement stock,
// update the day's report, free the table. Mirrors CloudService.completeCheckout.
const checkout = async (req, res) => {
  const cafeId = req.user.cafeId;
  const { receipt, tableId, items, idempotencyKey } = req.body;

  if (!receipt || !items) {
    return res.status(400).json({ success: false, message: 'receipt va items kiritilishi shart.' });
  }

  // IDEMPOTENCY: Takroriy so'rov bo'lsa darhol mavjud chekni qaytaramiz (dublikat to'lovning oldi olinadi)
  if (idempotencyKey) {
    try {
      const existing = await db.query(
        'SELECT * FROM receipts WHERE cafe_id = $1 AND idempotency_key = $2 LIMIT 1',
        [cafeId, idempotencyKey]
      );
      if (existing.rows.length > 0) {
        return res.json({
          success: true,
          message: 'To‘lov allaqachon qayd etilgan (idempotent)',
          receipt: mapReceipt(existing.rows[0]),
          isDuplicate: true,
        });
      }
    } catch (_) {}
  }

  try {
    const { receiptRow, reportRow, effectiveTableId } = await db.withTransaction(async (client) => {

      const date = receipt.date ? new Date(receipt.date) : new Date();
      const dateId = dateIdFrom(date);

      const receiptResult = await client.query(
        `INSERT INTO receipts (cafe_id, date, items, total, method, cashier_name, table_number, hall_name, cash_paid, card_paid, idempotency_key)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
        [
          cafeId, date, JSON.stringify(items), receipt.total || 0, receipt.method || 'cash',
          receipt.cashierName || '', receipt.tableNumber ?? null, receipt.hallName ?? null,
          receipt.cashPaid || 0, receipt.cardPaid || 0, idempotencyKey || null,
        ]
      );
      const receiptRow = receiptResult.rows[0];

      for (const item of items) {
        await client.query(
          'UPDATE products SET stock = GREATEST(stock - $1, 0) WHERE id = $2 AND cafe_id = $3',
          [item.qty, item.product.id, cafeId]
        );
      }

      const reportRes = await client.query(
        'SELECT * FROM reports WHERE cafe_id = $1 AND date_id = $2',
        [cafeId, dateId]
      );

      let qty = {}, rev = {}, tableRev = {}, totalRev = 0, orderCount = 0, topProduct = '';
      if (reportRes.rows.length > 0) {
        const existing = reportRes.rows[0];
        qty = existing.product_quantities || {};
        rev = existing.product_revenue || {};
        tableRev = existing.table_revenue || {};
        totalRev = parseFloat(existing.total_revenue);
        orderCount = existing.order_count;
        topProduct = existing.top_product || '';
      }

      totalRev += receipt.total || 0;
      orderCount += 1;

      for (const item of items) {
        const name = item.product.name;
        qty[name] = (qty[name] || 0) + item.qty;
        rev[name] = (rev[name] || 0) + item.product.price * item.qty;
      }
      if (receipt.tableNumber) {
        const key = `Stol ${receipt.tableNumber}`;
        tableRev[key] = (tableRev[key] || 0) + (receipt.total || 0);
      }
      let topQty = 0;
      for (const [name, q] of Object.entries(qty)) {
        if (q > topQty) { topQty = q; topProduct = name; }
      }

      const reportResult = await client.query(
        `INSERT INTO reports (cafe_id, date_id, total_revenue, order_count, product_quantities, product_revenue, top_product, table_revenue, updated_at)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,CURRENT_TIMESTAMP)
         ON CONFLICT (cafe_id, date_id) DO UPDATE SET
           total_revenue=$3, order_count=$4, product_quantities=$5, product_revenue=$6, top_product=$7, table_revenue=$8, updated_at=CURRENT_TIMESTAMP
         RETURNING *`,
        [cafeId, dateId, totalRev, orderCount, JSON.stringify(qty), JSON.stringify(rev), topProduct, JSON.stringify(tableRev)]
      );

      let effectiveTableId = null;
      let effectiveTableNumber = receipt.tableNumber ? parseInt(receipt.tableNumber, 10) : null;

      if (tableId) {
        const idCheck = await client.query(
          'SELECT id, number FROM restaurant_tables WHERE cafe_id = $1 AND id = $2 LIMIT 1',
          [cafeId, parseInt(tableId, 10)]
        );
        if (idCheck.rows.length > 0) {
          effectiveTableId = idCheck.rows[0].id;
          if (!effectiveTableNumber) effectiveTableNumber = idCheck.rows[0].number;
        }
      }

      if (!effectiveTableId && effectiveTableNumber) {
        const numCheck = await client.query(
          'SELECT id, number FROM restaurant_tables WHERE cafe_id = $1 AND number = $2 LIMIT 1',
          [cafeId, effectiveTableNumber]
        );
        if (numCheck.rows.length > 0) {
          effectiveTableId = numCheck.rows[0].id;
        }
      }

      if (effectiveTableId) {
        await client.query(
          `UPDATE restaurant_tables SET status='free', order_id=NULL, total=0, started_by=NULL, updated_at=CURRENT_TIMESTAMP
           WHERE id=$1 AND cafe_id=$2`,
          [effectiveTableId, cafeId]
        );
        await client.query('DELETE FROM table_orders WHERE table_id = $1', [effectiveTableId]);
      }
      if (effectiveTableNumber) {
        await client.query(
          `UPDATE restaurant_tables SET status='free', order_id=NULL, total=0, started_by=NULL, updated_at=CURRENT_TIMESTAMP
           WHERE number=$1 AND cafe_id=$2`,
          [effectiveTableNumber, cafeId]
        );
        await client.query(
          `DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE number = $1 AND cafe_id = $2)`,
          [effectiveTableNumber, cafeId]
        );
      }

      await client.query(
        'INSERT INTO activity_logs (cafe_id, action, details, performed_by) VALUES ($1,$2,$3,$4)',
        [
          cafeId, 'checkout_completed',
          `Chek #${receiptRow.id} yaratildi. Jami: ${receipt.total} so'm. Kassir: ${receipt.cashierName || ''}`,
          receipt.cashierName || '',
        ]
      );

      return { receiptRow, reportRow: reportResult.rows[0], effectiveTableId, effectiveTableNumber };
    });

    notifyCafe(cafeId, 'RECEIPT_ADDED', { receipt: mapReceipt(receiptRow) });
    notifyCafe(cafeId, 'REPORT_UPDATED', { report: mapReport(reportRow) });
    try {
      const { sendGeneralTelegramNotification } = require('../bot/telegramBot');
      const methodLabel = receipt.method === 'card' ? '💳 Karta' : '💵 Naqd';
      const tbl = receipt.tableNumber ? `${receipt.tableNumber}-stol` : (receipt.hallName || 'Stol');
      sendGeneralTelegramNotification({
        cafeId,
        title: `🧾 YANGI TO'LOV / CHEK #${receiptRow.id}`,
        message: `💵 <b>Summa:</b> ${(receipt.total || 0).toLocaleString()} so'm\n💳 <b>To'lov:</b> ${methodLabel}\n🪑 <b>Joy:</b> ${tbl}\n👤 <b>Kassir/Ofitsiant:</b> ${receipt.cashierName || 'Admin'}\n⏰ <b>Vaqt:</b> ${new Date().toLocaleTimeString('uz-UZ')}`,
      }).catch(() => {});
    } catch (_) {}
    if (effectiveTableId || effectiveTableNumber) {
      notifyCafe(cafeId, 'TABLE_RELEASED', { tableId: effectiveTableId, tableNumber: effectiveTableNumber });
      notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId: effectiveTableId, tableNumber: effectiveTableNumber, status: 'free' });
      notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId: effectiveTableId, tableNumber: effectiveTableNumber, items: [], note: '' });
    }

    return res.json({ success: true, receipt: mapReceipt(receiptRow), report: mapReport(reportRow) });
  } catch (error) {
    console.error('checkout error:', error);
    return res.status(500).json({ success: false, message: "To'lovni yakunlashda xatolik: " + error.message });
  }
};

module.exports = { list, checkout };
