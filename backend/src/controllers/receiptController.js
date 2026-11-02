const db = require('../config/db');
const { mapReceipt, mapReport } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { getTodayReportData } = require('./reportController');

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
  const effectiveIdempotencyKey = idempotencyKey || (receipt.id ? `rcpt_${receipt.id}` : null);
  if (effectiveIdempotencyKey) {
    try {
      const existing = await db.query(
        'SELECT * FROM receipts WHERE cafe_id = $1 AND idempotency_key = $2 LIMIT 1',
        [cafeId, effectiveIdempotencyKey]
      );
      if (existing.rows.length > 0) {
        // Stolni baribir bo'shatish kerak
        if (tableId) {
          await db.query(`UPDATE restaurant_tables SET status='free', order_id=NULL, total=0 WHERE id=$1 AND cafe_id=$2`, [tableId, cafeId]).catch(() => {});
          await db.query(`DELETE FROM table_orders WHERE table_id=$1 AND cafe_id=$2`, [tableId, cafeId]).catch(() => {});
        }
        if (receipt.tableNumber) {
          await db.query(`UPDATE restaurant_tables SET status='free', order_id=NULL, total=0 WHERE number=$1 AND cafe_id=$2`, [receipt.tableNumber, cafeId]).catch(() => {});
          await db.query(`DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE number=$1 AND cafe_id=$2) AND cafe_id=$2`, [receipt.tableNumber, cafeId]).catch(() => {});
        }
        notifyCafe(cafeId, 'TABLE_RELEASED', { tableId, tableNumber: receipt.tableNumber });
        notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId, tableNumber: receipt.tableNumber, status: 'free' });
        notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId, tableNumber: receipt.tableNumber, items: [], note: '' });
        return res.json({
          success: true,
          message: 'To‘lov allaqachon qayd etilgan (idempotent)',
          receipt: mapReceipt(existing.rows[0]),
          isDuplicate: true,
        });
      }
    } catch (_) {}
  }

  // RECENT CHECK DEDUPLICATION: 30 soniya ichida aynan shu stol va summaga chek urilgan bo'lsa qaytaramiz
  try {
    let tblNum = receipt.tableNumber ? parseInt(receipt.tableNumber, 10) : null;
    if (!tblNum && tableId) {
      const tblRes = await db.query('SELECT number FROM restaurant_tables WHERE id = $1 AND cafe_id = $2', [tableId, cafeId]);
      if (tblRes.rows.length > 0) tblNum = parseInt(tblRes.rows[0].number, 10);
    }
    const rTotal = parseFloat(receipt.total) || 0;
    if (tblNum && rTotal > 0) {
      const recent = await db.query(
        `SELECT * FROM receipts 
         WHERE cafe_id = $1 AND table_number = $2 AND ABS(total - $3) < 0.01 
           AND (created_at >= NOW() - INTERVAL '30 seconds' OR date >= NOW() - INTERVAL '30 seconds')
         ORDER BY id DESC LIMIT 1`,
        [cafeId, tblNum, rTotal]
      );
      if (recent.rows.length > 0) {
        console.log(`⚠️ [Checkout] Takroriy bosish aniqlandi (Stol #${tblNum}, Summa: ${rTotal}). Dublikat rad etildi.`);
        if (tableId) {
          await db.query(`UPDATE restaurant_tables SET status='free', order_id=NULL, total=0 WHERE id=$1 AND cafe_id=$2`, [tableId, cafeId]).catch(() => {});
          await db.query(`DELETE FROM table_orders WHERE table_id=$1 AND cafe_id=$2`, [tableId, cafeId]).catch(() => {});
        }
        await db.query(`UPDATE restaurant_tables SET status='free', order_id=NULL, total=0 WHERE number=$1 AND cafe_id=$2`, [tblNum, cafeId]).catch(() => {});
        await db.query(`DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE number=$1 AND cafe_id=$2) AND cafe_id=$2`, [tblNum, cafeId]).catch(() => {});
        notifyCafe(cafeId, 'TABLE_RELEASED', { tableId, tableNumber: tblNum });
        notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId, tableNumber: tblNum, status: 'free' });
        notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId, tableNumber: tblNum, items: [], note: '' });
        return res.json({
          success: true,
          message: 'To‘lov allaqachon qayd etilgan (takroriy bosish oldi olindi)',
          receipt: mapReceipt(recent.rows[0]),
          isDuplicate: true,
        });
      }
    }
  } catch (_) {}

  try {
    const { receiptRow, reportRow, effectiveTableId, effectiveTableNumber } = await db.withTransaction(async (client) => {

      const date = receipt.date ? new Date(receipt.date) : new Date();
      const dateId = dateIdFrom(date);

      const printStatus = receipt.printStatus || req.body.printStatus || 'unprinted';
      const isPrinted = printStatus === 'printed';

      const waiterId = req.user?.id || receipt.waiterId || req.body.waiterId || null;
      const deviceType = req.body.deviceType || receipt.deviceType || req.headers['x-device-type'] || 'web';

      const receiptResult = await client.query(
        `INSERT INTO receipts (
           cafe_id, date, items, total, method, cashier_name, table_number,
           hall_name, cash_paid, card_paid, idempotency_key, print_status, printed_at,
           waiter_id, device_type
         )
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15) RETURNING *`,
        [
          cafeId, date, JSON.stringify(items), receipt.total || 0, receipt.method || 'cash',
          receipt.cashierName || '', receipt.tableNumber ?? null, receipt.hallName ?? null,
          receipt.cashPaid || 0, receipt.cardPaid || 0, effectiveIdempotencyKey || null,
          printStatus, isPrinted ? date : null,
          waiterId, deviceType,
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
          'SELECT id, number FROM restaurant_tables WHERE cafe_id = $1 AND id = $2 FOR UPDATE LIMIT 1',
          [cafeId, parseInt(tableId, 10)]
        );
        if (idCheck.rows.length > 0) {
          effectiveTableId = idCheck.rows[0].id;
          if (!effectiveTableNumber) effectiveTableNumber = idCheck.rows[0].number;
        }
      }

      if (!effectiveTableId && effectiveTableNumber) {
        const numCheck = await client.query(
          'SELECT id, number FROM restaurant_tables WHERE cafe_id = $1 AND number = $2 FOR UPDATE LIMIT 1',
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
        await client.query('DELETE FROM table_orders WHERE table_id = $1 AND cafe_id = $2', [effectiveTableId, cafeId]);
      }
      if (tableId && parseInt(tableId, 10) !== effectiveTableId) {
        await client.query(
          `UPDATE restaurant_tables SET status='free', order_id=NULL, total=0, started_by=NULL, updated_at=CURRENT_TIMESTAMP
           WHERE id=$1 AND cafe_id=$2`,
          [parseInt(tableId, 10), cafeId]
        ).catch(() => {});
        await client.query('DELETE FROM table_orders WHERE table_id = $1 AND cafe_id = $2', [parseInt(tableId, 10), cafeId]).catch(() => {});
      }
      if (effectiveTableNumber) {
        let hallFilter = '';
        const params = [effectiveTableNumber, cafeId];
        if (receipt.hallName) {
          params.push(receipt.hallName.trim());
          hallFilter = ` AND hall_id IN (SELECT id FROM halls WHERE cafe_id = $2 AND LOWER(TRIM(name)) = LOWER(TRIM($3)))`;
        }
        await client.query(
          `UPDATE restaurant_tables SET status='free', order_id=NULL, total=0, started_by=NULL, updated_at=CURRENT_TIMESTAMP
           WHERE number=$1 AND cafe_id=$2${hallFilter}`,
          params
        );
        await client.query(
          `DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE number = $1 AND cafe_id = $2${hallFilter})`,
          params
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

      return { receiptRow, reportRow: reportResult.rows[0], effectiveTableId: effectiveTableId || tableId, effectiveTableNumber };
    });

    let todayReport = null;
    try {
      todayReport = await getTodayReportData(cafeId);
    } catch (e) {
      console.warn('⚠️ getTodayReportData in checkout error:', e.message);
    }

    notifyCafe(cafeId, 'RECEIPT_ADDED', { receipt: mapReceipt(receiptRow), todayReport });
    notifyCafe(cafeId, 'REPORT_UPDATED', { report: mapReport(reportRow), todayReport });

    // 6-TALAB: Telegram bot orqali chek yuborish (agar sozlamada yoqilgan bo'lsa)
    try {
      db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]).then((sRes) => {
        const cSettings = sRes.rows[0]?.data || {};
        const chatInput = cSettings.telegramReceiptsChatId || cSettings.telegramReceiptChatId;
        if (cSettings.telegramReceiptsEnabled && chatInput) {
          sendReceiptNotificationToTelegram(chatInput, receiptRow, items, cSettings, cafeId);
        }
      }).catch(() => {});
    } catch (_) {}
    const relId = effectiveTableId || tableId;
    if (relId || effectiveTableNumber) {
      notifyCafe(cafeId, 'TABLE_RELEASED', { tableId: relId, tableNumber: effectiveTableNumber });
      notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId: relId, tableNumber: effectiveTableNumber, status: 'free' });
      notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId: relId, tableNumber: effectiveTableNumber, items: [], note: '' });
    }

    return res.json({ success: true, receipt: mapReceipt(receiptRow), report: mapReport(reportRow), todayReport });
  } catch (error) {
    if (error.code === '23505' && effectiveIdempotencyKey) {
      try {
        const existing = await db.query(
          'SELECT * FROM receipts WHERE cafe_id = $1 AND idempotency_key = $2 LIMIT 1',
          [cafeId, effectiveIdempotencyKey]
        );
        if (existing.rows.length > 0) {
          return res.json({
            success: true,
            message: 'To‘lov allaqachon qayd etilgan (idempotent conflict resolved)',
            receipt: mapReceipt(existing.rows[0]),
            isDuplicate: true,
          });
        }
      } catch (_) {}
    }
    console.error('checkout error:', error);
    return res.status(500).json({ success: false, message: "To'lovni yakunlashda xatolik: " + error.message });
  }
};

// GET /api/receipts/:id/view — Clean 80mm thermal receipt HTML for mobile browser / printing
const viewReceiptHtml = async (req, res) => {
  try {
    const receiptId = req.params.id;
    const result = await db.query('SELECT * FROM receipts WHERE id = $1 LIMIT 1', [receiptId]);
    if (result.rows.length === 0) {
      return res.status(404).send('<h3>Chek topilmadi</h3>');
    }

    const r = result.rows[0];
    const cafeId = r.cafe_id;

    let settings = {};
    try {
      const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1 LIMIT 1', [cafeId]);
      if (sRes.rows.length > 0 && sRes.rows[0].data) {
        settings = typeof sRes.rows[0].data === 'string' ? JSON.parse(sRes.rows[0].data) : sRes.rows[0].data;
      }
    } catch (_) {}

    const cafeName = settings.restaurantName || settings.receiptName || 'Family Cafe';
    const address = settings.restaurantAddress || "Navoi ko'chasi 12, Buxoro";
    const phone = settings.restaurantPhone || "+998 90 123 45 67";
    const slogan = settings.receiptSlogan || "Yaxshi ta'm • Baxtli onlar";
    const footerMsg = settings.receiptFooterNote || "Bizni tanlaganingiz uchun rahmat!";
    const date = new Date(r.date || Date.now());
    const dateStr = `${String(date.getDate()).padStart(2, '0')}.${String(date.getMonth() + 1).padStart(2, '0')}.${date.getFullYear()}`;
    const timeStr = `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
    const checkNo = String(r.id).padStart(6, '0').slice(-6);

    const items = Array.isArray(r.items) ? r.items : (typeof r.items === 'string' ? JSON.parse(r.items) : []);
    const itemsHtml = items.map((item, idx) => {
      const name = item.product?.name || item.name || 'Taom';
      const qty = item.qty || item.quantity || 1;
      const price = Number(item.product?.price || item.price || 0).toLocaleString('uz-UZ').replace(/,/g, ' ');
      return `
        <tr>
          <td style="padding: 3px 2px; text-align: left; font-size: 11px;">${idx + 1}</td>
          <td style="padding: 3px 2px; text-align: left; font-size: 11px; font-weight: 600;">${name}</td>
          <td style="padding: 3px 2px; text-align: center; font-size: 11px;">${qty} dona</td>
          <td style="padding: 3px 2px; text-align: right; font-size: 11px; font-weight: 700;">${price} UZS</td>
        </tr>
      `;
    }).join('');

    const totalStr = Number(r.total || 0).toLocaleString('uz-UZ').replace(/,/g, ' ');
    const cashierName = r.cashier_name || 'Admin';
    const tableInfo = r.table_number ? `${r.table_number}-stol` : (r.table_name || '');

    const html = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Chek #${checkNo}</title>
  <style>
    @page { size: 80mm auto; margin: 0; }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, monospace;
      color: #000;
      background: #fff;
      display: flex;
      justify-content: center;
      padding: 10px 0;
    }
    .receipt {
      width: 80mm;
      max-width: 100%;
      padding: 10px 14px 20px 14px;
      font-size: 12px;
      line-height: 1.35;
    }
    .text-center { text-align: center; }
    .header-logo {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      margin-bottom: 2px;
    }
    .header-title {
      font-size: 20px;
      font-weight: 900;
      letter-spacing: -0.5px;
    }
    .header-sub {
      font-size: 11px;
      color: #333;
      margin-bottom: 6px;
    }
    .meta-table {
      width: 100%;
      font-size: 11.5px;
      margin: 6px 0;
      border-collapse: collapse;
    }
    .meta-table td { padding: 1.5px 0; }
    .divider {
      border-top: 1px dashed #000;
      margin: 6px 0;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin: 6px 0;
    }
    .items-table th {
      border-bottom: 1px dashed #000;
      padding: 4px 2px;
      font-size: 11px;
      text-transform: uppercase;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      font-size: 14.5px;
      font-weight: 900;
      margin-top: 6px;
      padding-top: 4px;
    }
    .footer {
      text-align: center;
      margin-top: 12px;
      font-size: 11px;
    }
    @media print {
      body { padding: 0; }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="header-logo">
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80" fill="none" stroke="black" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" style="width: 38px; height: 30px;">
        <line x1="22" y1="64" x2="78" y2="64" stroke-width="2.2"/>
        <line x1="24" y1="72" x2="76" y2="72" stroke-width="2.2"/>
        <path d="M 22 64 C 6 64 6 36 20 30 C 14 18 32 8 42 16 C 46 8 54 8 58 16 C 68 8 86 18 80 30 C 94 36 94 64 78 64" stroke-width="2.4" fill="none"/>
      </svg>
      <span class="header-title">${cafeName}</span>
    </div>
    <div class="header-sub text-center">${slogan}</div>
    <div class="text-center" style="font-size: 10.5px; color: #444;">${address} • ${phone}</div>
    <div class="divider"></div>

    <table class="meta-table">
      <tr><td>Sana: <b>${dateStr}</b></td><td style="text-align: right;">Vaqt: <b>${timeStr}</b></td></tr>
      <tr><td>Chek №: <b>#${checkNo}</b></td><td style="text-align: right;">Kassir: <b>${cashierName}</b></td></tr>
      ${tableInfo ? `<tr><td colspan="2">Stol / Joy: <b>${tableInfo}</b></td></tr>` : ''}
    </table>

    <table class="items-table">
      <thead>
        <tr>
          <th style="text-align: left; width: 18px;">№</th>
          <th style="text-align: left;">Nomi</th>
          <th style="text-align: center; width: 55px;">Miqdori</th>
          <th style="text-align: right; width: 85px;">Narx</th>
        </tr>
      </thead>
      <tbody>
        ${itemsHtml}
      </tbody>
    </table>

    <div class="divider"></div>
    <div class="total-row">
      <span>JAMI TO'LOV:</span>
      <span>${totalStr} UZS</span>
    </div>
    <div style="font-size: 11.5px; margin-top: 3px; display: flex; justify-content: space-between;">
      <span>To'lov usuli:</span>
      <span><b>${r.method === 'card' ? 'Karta' : 'Naqd pul'}</b></span>
    </div>

    <div class="divider"></div>
    <div style="text-align: center; margin: 8px 0;">
      <div style="font-size: 11px; font-weight: 700; margin-bottom: 4px;">Bizni Instagram'da kuzating</div>
      <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=https%3A%2F%2Fwww.instagram.com%2Ffamily_cafe.1" alt="Instagram QR" style="width: 90px; height: 90px; display: block; margin: 0 auto; border: 1px solid #000; border-radius: 6px; padding: 3px;" />
      <div style="font-size: 11px; font-weight: 700; margin-top: 4px;">Rahmat!</div>
    </div>
    <div class="footer">
      <div>${footerMsg}</div>
      <div style="margin-top: 4px; font-weight: 700; font-size: 10px;">ZAVERO POS BILAN CHOP ETILDI</div>
    </div>
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() {
        try { window.print(); } catch(_) {}
      }, 250);
    };
  </script>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.send(html);
  } catch (error) {
    console.error('viewReceiptHtml error:', error);
    return res.status(500).send('Server xatoligi');
  }
};

// POST /api/receipts — create receipt (supporting sale, bill preview, kitchen ticket)
const createReceipt = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const body = req.body || {};
    const {
      orderId,
      tableName,
      tableNumber,
      hallName,
      items,
      total,
      paymentMethod,
      waiterId,
      waiterName,
      createdAt,
      type,
    } = body;

    const date = createdAt ? new Date(createdAt) : new Date();
    const dateId = dateIdFrom(date);

    let parsedTableNum = tableNumber !== undefined && tableNumber !== null ? parseInt(tableNumber, 10) : null;
    if (isNaN(parsedTableNum)) parsedTableNum = null;
    if (!parsedTableNum && tableName) {
      const match = String(tableName).match(/\d+/);
      if (match) parsedTableNum = parseInt(match[0], 10);
    }

    const receiptTotal = parseFloat(total) || 0;
    const methodStr = paymentMethod || 'cash';
    const cashier = waiterName || req.user.name || 'Ofitsiant';
    const receiptType = type || 'receipt';
    const effectiveOrderId = orderId ? String(orderId) : null;
    const effectiveWaiterId = waiterId ? String(waiterId) : (req.user.id ? String(req.user.id) : null);

    // Xavfsiz ustunlar mavjudligini ta'minlash
    await db.query(`
      ALTER TABLE receipts ADD COLUMN IF NOT EXISTS order_id VARCHAR(64);
      ALTER TABLE receipts ADD COLUMN IF NOT EXISTS waiter_id VARCHAR(64);
      ALTER TABLE receipts ADD COLUMN IF NOT EXISTS type VARCHAR(32) DEFAULT 'receipt';
    `).catch(() => {});

    const result = await db.query(
      `INSERT INTO receipts 
        (cafe_id, date, items, total, method, cashier_name, table_number, hall_name, order_id, waiter_id, type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [
        cafeId,
        date,
        JSON.stringify(items || []),
        receiptTotal,
        methodStr,
        cashier,
        parsedTableNum,
        hallName || null,
        effectiveOrderId,
        effectiveWaiterId,
        receiptType,
      ]
    );

    const savedReceipt = result.rows[0];

    // Agar savdo cheki bo'lsa, kunlik hisobotni ham yangilaymiz
    if (receiptType === 'receipt' && receiptTotal > 0) {
      try {
        const reportRes = await db.query(
          'SELECT * FROM reports WHERE cafe_id = $1 AND date_id = $2',
          [cafeId, dateId]
        );
        let qty = {}, rev = {}, totalRev = 0, orderCount = 0, topProduct = '';
        if (reportRes.rows.length > 0) {
          const existing = reportRes.rows[0];
          qty = existing.product_quantities || {};
          rev = existing.product_revenue || {};
          totalRev = parseFloat(existing.total_revenue) || 0;
          orderCount = existing.order_count || 0;
          topProduct = existing.top_product || '';
        }
        totalRev += receiptTotal;
        orderCount += 1;
        if (Array.isArray(items)) {
          for (const item of items) {
            const prod = item.product || item;
            const name = prod.name || 'Taom';
            const count = parseInt(item.qty || 1, 10);
            const price = parseFloat(prod.price || 0);
            qty[name] = (qty[name] || 0) + count;
            rev[name] = (rev[name] || 0) + price * count;
          }
        }
        let topQty = 0;
        for (const [name, q] of Object.entries(qty)) {
          if (q > topQty) { topQty = q; topProduct = name; }
        }
        await db.query(
          `INSERT INTO reports (cafe_id, date_id, total_revenue, order_count, product_quantities, product_revenue, top_product, updated_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,CURRENT_TIMESTAMP)
           ON CONFLICT (cafe_id, date_id) DO UPDATE SET
             total_revenue=$3, order_count=$4, product_quantities=$5, product_revenue=$6, top_product=$7, updated_at=CURRENT_TIMESTAMP`,
          [cafeId, dateId, totalRev, orderCount, JSON.stringify(qty), JSON.stringify(rev), topProduct]
        );
      } catch (err) {
        console.error('Report update on createReceipt warning:', err.message);
      }
    }

    const mapped = mapReceipt(savedReceipt);
    notifyCafe(cafeId, 'RECEIPT_ADDED', { receipt: mapped });

    return res.status(201).json({
      success: true,
      receipt: mapped,
    });
  } catch (error) {
    console.error('createReceipt error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PATCH /api/receipts/:id/print-status — Chek holatini yangilash ('printed' | 'queued' | 'unprinted')
const updatePrintStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!['printed', 'queued', 'unprinted'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Status noto‘g‘ri' });
    }
    const result = await db.query(
      `UPDATE receipts 
       SET print_status = $1, 
           printed_at = (CASE WHEN $1 = 'printed' THEN CURRENT_TIMESTAMP ELSE printed_at END)
       WHERE id = $2 AND cafe_id = $3 RETURNING *`,
      [status, id, req.user.cafeId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Chek topilmadi' });
    }
    return res.json({ success: true, receipt: mapReceipt(result.rows[0]) });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

// GET /api/receipts/unprinted — Chiqarilmagan yoki navbatda turgan cheklar ro'yxati
const getUnprintedReceipts = async (req, res) => {
  try {
    const result = await db.query(
      `SELECT * FROM receipts 
       WHERE cafe_id = $1 AND (print_status = 'unprinted' OR print_status = 'queued' OR print_status IS NULL)
       ORDER BY date ASC LIMIT 100`,
      [req.user.cafeId]
    );
    return res.json({ success: true, receipts: result.rows.map(mapReceipt) });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
};

// Chat ID yoki telefon raqamini Telegram numeric chat_id ga aylantirib beruvchi resolver
async function resolveChatIds(rawInput, cafeId) {
  if (!rawInput) return [];
  const parts = String(rawInput)
    .split(/[,;\s]+/)
    .map((p) => p.trim())
    .filter(Boolean);

  const resolved = [];

  for (const part of parts) {
    // 1. Agar raqamli chat ID (-1001234567890 yoki 123456789) yoki @kanal bo'lsa
    if (/^-?\d+$/.test(part) || part.startsWith('@')) {
      resolved.push(part);
      continue;
    }

    // 2. Agar telefon raqami bo'lsa (+998507230475 yoki 998507230475)
    const digits = part.replace(/\D/g, '');
    if (digits.length >= 9) {
      const suffix = digits.slice(-9);

      // A) telegram_contact_links jadvalidan tekshiramiz
      try {
        const linkRes = await db.query(
          `SELECT chat_id FROM telegram_contact_links WHERE phone LIKE '%' || $1 LIMIT 1`,
          [suffix]
        );
        if (linkRes.rows.length > 0 && linkRes.rows[0].chat_id) {
          resolved.push(linkRes.rows[0].chat_id);
          continue;
        }
      } catch (_) {}

      // B) telegram_users jadvalidan tekshiramiz
      try {
        const userRes = await db.query(
          `SELECT telegram_id FROM telegram_users WHERE phone LIKE '%' || $1 LIMIT 1`,
          [suffix]
        );
        if (userRes.rows.length > 0 && userRes.rows[0].telegram_id) {
          resolved.push(userRes.rows[0].telegram_id);
          continue;
        }
      } catch (_) {}

      // C) Sozlamalardagi telegramResolvedChatId tekshiramiz
      if (cafeId) {
        try {
          const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1 LIMIT 1', [cafeId]);
          const d = sRes.rows[0]?.data || {};
          if (d.telegramResolvedChatId) {
            resolved.push(d.telegramResolvedChatId);
            continue;
          }
        } catch (_) {}
      }
    }
  }

  return [...new Set(resolved)];
}

// Telegram bot orqali chekni ko'rsatilgan chat(lar)ga jo'natish (Talab 6)
async function sendReceiptNotificationToTelegram(rawChatInput, receipt, items, settings = {}, cafeId = null) {
  try {
    const { getBotInstance } = require('../bot/telegramBot');
    const bot = getBotInstance();
    if (!bot || !bot.telegram) return { ok: false, error: 'Telegram bot serverda faol emas' };

    const effectiveCafeId = cafeId || receipt.cafe_id;
    const targetChatIds = await resolveChatIds(rawChatInput, effectiveCafeId);

    if (targetChatIds.length === 0) {
      console.warn(`⚠️ [Telegram Receipt] Chat ID topilmadi (${rawChatInput}). Chek #${receipt.id} yuborilmadi.`);
      if (receipt.id && typeof receipt.id === 'number') {
        await db.query(`UPDATE receipts SET telegram_status = 'failed' WHERE id = $1`, [receipt.id]).catch(() => {});
      }
      return { ok: false, error: 'Chat ID topilmadi yoki telefon raqami botga ulanmagan' };
    }

    const cafeName = settings.restaurantName || settings.receiptName || 'Family Cafe';
    const dateStr = new Date(receipt.date || new Date()).toLocaleString('uz-UZ', { timeZone: 'Asia/Tashkent' });
    const methodStr = receipt.method === 'card' ? 'Karta' : 'Naqd';
    const tableStr = receipt.table_number ? `Stol #${receipt.table_number}` : (receipt.hall_name || 'Olib ketish');

    let text = `🧾 <b>YANGI TO‘LANGAN CHEK #${receipt.id}</b>\n`;
    text += `🏪 <b>${cafeName}</b>\n`;
    text += `📍 Joy: <b>${tableStr}</b>\n`;
    text += `👤 Kassir/Ofitsiant: <b>${receipt.cashier_name || 'Admin'}</b>\n`;
    text += `🕒 Vaqt: <code>${dateStr}</code>\n`;
    text += `💳 To‘lov usuli: <b>${methodStr}</b>\n`;
    text += `──────────────────\n`;

    const parsedItems = Array.isArray(items) ? items : (typeof items === 'string' ? JSON.parse(items) : []);
    for (const it of parsedItems) {
      const pName = it.product?.name || it.name || 'Mahsulot';
      const qty = it.qty || 1;
      const price = it.product?.price || it.price || 0;
      const lineTotal = price * qty;
      text += `• ${pName} × ${qty} = <b>${Number(lineTotal).toLocaleString('uz-UZ')} so'm</b>\n`;
    }

    text += `──────────────────\n`;
    text += `💰 <b>JAMI: ${Number(receipt.total).toLocaleString('uz-UZ')} so'm</b>\n`;

    let anySuccess = false;
    for (const chatId of targetChatIds) {
      try {
        await bot.telegram.sendMessage(chatId, text, { parse_mode: 'HTML', disable_web_page_preview: true });
        anySuccess = true;
      } catch (sendErr) {
        console.error(`⚠️ [Telegram Receipt] Chat ${chatId} ga yuborishda xatolik:`, sendErr.message);
      }
    }

    if (receipt.id && typeof receipt.id === 'number') {
      const status = anySuccess ? 'sent' : 'failed';
      await db.query(
        `UPDATE receipts SET telegram_status = $1, telegram_sent_at = CURRENT_TIMESTAMP WHERE id = $2`,
        [status, receipt.id]
      ).catch(() => {});
    }

    return { ok: anySuccess };
  } catch (err) {
    console.error('⚠️ [Telegram Receipt] Yuborishda xatolik:', err.message);
    return { ok: false, error: err.message };
  }
}

// POST /api/receipts/:id/resend-telegram
const resendTelegramReceipt = async (req, res) => {
  try {
    const receiptId = req.params.id;
    const cafeId = req.user.cafeId;

    const rRes = await db.query('SELECT * FROM receipts WHERE id = $1 AND cafe_id = $2 LIMIT 1', [receiptId, cafeId]);
    if (rRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Chek topilmadi' });
    }
    const receipt = rRes.rows[0];

    const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1 LIMIT 1', [cafeId]);
    const settings = sRes.rows[0]?.data || {};
    const chatInput = settings.telegramReceiptChatId || settings.telegramReceiptsChatId;

    if (!chatInput) {
      return res.status(400).json({ success: false, message: 'Telegram chat sozlanmagan' });
    }

    const items = typeof receipt.items === 'string' ? JSON.parse(receipt.items) : (receipt.items || []);
    const result = await sendReceiptNotificationToTelegram(chatInput, receipt, items, settings, cafeId);

    if (result.ok) {
      notifyCafe(cafeId, 'RECEIPT_UPDATED', { receipt: mapReceipt({ ...receipt, telegram_status: 'sent' }) });
      return res.json({ success: true, message: 'Chek Telegramga muvaffaqiyatli yuborildi!' });
    } else {
      return res.status(400).json({ success: false, message: result.error || 'Telegramga yuborib bo‘lmadi' });
    }
  } catch (err) {
    console.error('resendTelegramReceipt error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/cafe/test-telegram
const testTelegramConnection = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const rawChat = req.body.chatId;

    const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1 LIMIT 1', [cafeId]);
    const settings = sRes.rows[0]?.data || {};
    const chatInput = rawChat || settings.telegramReceiptChatId || settings.telegramReceiptsChatId;

    if (!chatInput) {
      return res.status(400).json({ success: false, message: 'Telegram chat ID yoki telefon raqami kiritilmagan' });
    }

    const resolved = await resolveChatIds(chatInput, cafeId);
    if (resolved.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Kiritilgan raqam/ID bo‘yicha Telegram chat topilmadi. Telegramda botga /start bosing va "Raqamni ulashish" tugmasini bosing.',
      });
    }

    const { getBotInstance } = require('../bot/telegramBot');
    const bot = getBotInstance();
    if (!bot || !bot.telegram) {
      return res.status(500).json({ success: false, message: 'Telegram bot serverda faol emas' });
    }

    const cafeName = settings.restaurantName || settings.receiptName || 'Family Cafe';
    let count = 0;
    for (const cid of resolved) {
      await bot.telegram.sendMessage(
        cid,
        `🔔 <b>TEST BILDIRISHNOMA: ZAVERO POS</b>\n\n` +
        `🏪 Kafe: <b>${cafeName}</b>\n` +
        `✅ <b>Telegram ulanishi muvaffaqiyatli tekshirildi!</b>\n` +
        `Endi barcha to‘langan cheklar avtomatik ushbu chatga keladi.`,
        { parse_mode: 'HTML' }
      );
      count++;
    }

    return res.json({
      success: true,
      resolvedChatIds: resolved,
      message: `Telegramga test xabar muvaffaqiyatli yuborildi (${count} ta qabul qiluvchi)!`,
    });
  } catch (err) {
    console.error('testTelegramConnection error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = {
  list,
  checkout,
  viewReceiptHtml,
  createReceipt,
  updatePrintStatus,
  getUnprintedReceipts,
  sendReceiptNotificationToTelegram,
  resendTelegramReceipt,
  testTelegramConnection,
  resolveChatIds,
};
