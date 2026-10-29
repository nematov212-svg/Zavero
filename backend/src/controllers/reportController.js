const db = require('../config/db');
const { mapReport } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

// GET /api/reports
const list = async (req, res) => {
  const result = await db.query(
    'SELECT * FROM reports WHERE cafe_id = $1 ORDER BY date_id DESC LIMIT 90',
    [req.user.cafeId]
  );
  res.json({ success: true, reports: result.rows.map(mapReport) });
};

// GET /api/reports/:dateId
const getOne = async (req, res) => {
  const { dateId } = req.params;
  const result = await db.query(
    'SELECT * FROM reports WHERE cafe_id = $1 AND date_id = $2',
    [req.user.cafeId, dateId]
  );
  if (result.rows.length === 0) return res.json({ success: true, report: null });
  res.json({ success: true, report: mapReport(result.rows[0]) });
};

// DELETE /api/reports/:dateId — clear a single day's report (mirrors clearReport)
const clearDay = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { dateId } = req.params;
    await db.query('DELETE FROM reports WHERE cafe_id = $1 AND date_id = $2', [cafeId, dateId]);
    notifyCafe(cafeId, 'REPORT_CLEARED', { dateId });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/reports/month/:yearMonth (e.g. 2026-08)
const clearMonth = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { yearMonth } = req.params;
    const result = await db.query(
      "DELETE FROM reports WHERE cafe_id = $1 AND date_id LIKE $2 RETURNING date_id",
      [cafeId, `${yearMonth}%`]
    );
    notifyCafe(cafeId, 'REPORT_CLEARED', { yearMonth, count: result.rows.length });
    res.json({ success: true, count: result.rows.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/reports — clear ALL reports for this cafe
const clearAll = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const result = await db.query('DELETE FROM reports WHERE cafe_id = $1 RETURNING date_id', [cafeId]);
    notifyCafe(cafeId, 'REPORT_CLEARED', { all: true, count: result.rows.length });
    res.json({ success: true, count: result.rows.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reports/analytics?startDate=...&endDate=...
const getAnalytics = async (req, res) => {
  const cafeId = req.user.cafeId;
  const { startDate, endDate } = req.query;

  try {
    let dateFilter = '1=1';
    const params = [cafeId];

    if (startDate && endDate) {
      params.push(startDate, endDate);
      dateFilter = `created_at >= $2::timestamp AND created_at <= ($3::timestamp + INTERVAL '1 day')`;
    } else if (startDate) {
      params.push(startDate);
      dateFilter = `created_at >= $2::timestamp`;
    }

    const summaryQuery = `
      SELECT 
        COUNT(*) as total_receipts,
        COALESCE(SUM(total), 0) as total_revenue,
        COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE cash_paid END), 0) as cash_revenue,
        COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE card_paid END), 0) as card_revenue
      FROM receipts
      WHERE cafe_id = $1 AND ${dateFilter}
    `;

    const summaryRes = await db.query(summaryQuery, params);
    const summary = summaryRes.rows[0];

    // Daily trend
    const trendQuery = `
      SELECT 
        TO_CHAR(created_at, 'YYYY-MM-DD') as date,
        COUNT(*) as receipts_count,
        COALESCE(SUM(total), 0) as revenue
      FROM receipts
      WHERE cafe_id = $1 AND ${dateFilter}
      GROUP BY TO_CHAR(created_at, 'YYYY-MM-DD')
      ORDER BY date ASC
    `;
    const trendRes = await db.query(trendQuery, params);

    // Waiter / Cashier performance
    const waiterQuery = `
      SELECT 
        COALESCE(NULLIF(cashier_name, ''), 'Kassir') as waiter,
        COUNT(*) as receipts_count,
        COALESCE(SUM(total), 0) as revenue
      FROM receipts
      WHERE cafe_id = $1 AND ${dateFilter}
      GROUP BY cashier_name
      ORDER BY revenue DESC
    `;
    const waiterRes = await db.query(waiterQuery, params);

    // Top selling items
    const itemsQuery = `
      SELECT 
        item->>'name' as name,
        SUM((item->>'qty')::numeric) as qty,
        SUM((item->>'price')::numeric * (item->>'qty')::numeric) as total
      FROM receipts r,
      LATERAL jsonb_array_elements(r.items) as item
      WHERE r.cafe_id = $1 AND ${dateFilter}
      GROUP BY item->>'name'
      ORDER BY qty DESC
      LIMIT 10
    `;
    const itemsRes = await db.query(itemsQuery, params);

    return res.json({
      success: true,
      summary: {
        totalReceipts: parseInt(summary.total_receipts, 10) || 0,
        totalRevenue: parseFloat(summary.total_revenue) || 0,
        cashRevenue: parseFloat(summary.cash_revenue) || 0,
        cardRevenue: parseFloat(summary.card_revenue) || 0,
        averageCheck: parseInt(summary.total_receipts, 10) > 0 ? Math.round(parseFloat(summary.total_revenue) / parseInt(summary.total_receipts, 10)) : 0,
      },
      trend: trendRes.rows.map(r => ({
        date: r.date,
        receiptsCount: parseInt(r.receipts_count, 10) || 0,
        revenue: parseFloat(r.revenue) || 0,
      })),
      waiters: waiterRes.rows.map(r => ({
        waiter: r.waiter,
        receiptsCount: parseInt(r.receipts_count, 10) || 0,
        revenue: parseFloat(r.revenue) || 0,
      })),
      topItems: itemsRes.rows.map(r => ({
        name: r.name,
        quantity: parseFloat(r.qty) || 0,
        revenue: parseFloat(r.total) || 0,
      })),
    });
  } catch (error) {
    console.error('getAnalytics error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reports/export/csv?startDate=...&endDate=...
const exportCsv = async (req, res) => {
  const cafeId = req.user.cafeId;
  const { startDate, endDate } = req.query;

  try {
    let dateFilter = '1=1';
    const params = [cafeId];
    if (startDate && endDate) {
      params.push(startDate, endDate);
      dateFilter = `created_at >= $2::timestamp AND created_at <= ($3::timestamp + INTERVAL '1 day')`;
    }

    const receiptsRes = await db.query(
      `SELECT id, table_number, cashier_name, total, method, created_at
       FROM receipts
       WHERE cafe_id = $1 AND ${dateFilter}
       ORDER BY created_at DESC`,
      params
    );

    let csv = 'Chek ID,Sana va Vaqt,Stol,Xodim,To‘lov turi,Jami Summa\n';
    receiptsRes.rows.forEach(r => {
      const d = new Date(r.created_at).toISOString();
      const method = r.method === 'cash' ? 'Naqd' : 'Karta';
      csv += `${r.id},"${d}",${r.table_number || 'Kassa'},"${r.cashier_name || ''}",${method},${r.total}\n`;
    });

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="zavero_hisobot_${cafeId}.csv"`);
    return res.send(csv);
  } catch (error) {
    console.error('exportCsv error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, getOne, clearDay, clearMonth, clearAll, getAnalytics, exportCsv };
