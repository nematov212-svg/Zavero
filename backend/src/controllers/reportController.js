const db = require('../config/db');
const { mapReport } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

/**
 * Single Source of Truth for Today's SQL Aggregated Financial Metrics
 * Calculated live via PostgreSQL (SUM/COUNT/GROUP BY) with Tashkent timezone (UTC+5).
 */
const getTodayReportData = async (cafeId) => {
  let resetCondition = '';
  const queryParams = [cafeId];

  try {
    const settingsRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settingsData = settingsRes.rows[0]?.data || {};
    if (settingsData.reports_reset_at) {
      queryParams.push(new Date(settingsData.reports_reset_at));
      resetCondition = ' AND (created_at >= $2 OR date >= $2)';
    }
  } catch (_) {}

  const summaryRes = await db.query(
    `SELECT 
       COALESCE(SUM(total), 0)::bigint as total_revenue,
       COUNT(*)::int as order_count,
       COALESCE(SUM(CASE WHEN method = 'cash' THEN total ELSE cash_paid END), 0)::bigint as cash_total,
       COALESCE(SUM(CASE WHEN method = 'card' THEN total ELSE card_paid END), 0)::bigint as card_total,
       COALESCE(ROUND(AVG(total)), 0)::bigint as average_check
     FROM receipts
     WHERE cafe_id = $1 
       AND (
         (date AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
         OR (created_at AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
       )${resetCondition}`,
    queryParams
  );
  const summary = summaryRes.rows[0] || {};

  const waiterRes = await db.query(
    `SELECT 
       COALESCE(NULLIF(TRIM(cashier_name), ''), 'Kassa') as waiter,
       COUNT(*)::int as order_count,
       COALESCE(SUM(total), 0)::bigint as total_revenue
     FROM receipts
     WHERE cafe_id = $1 
       AND (
         (date AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
         OR (created_at AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
       )${resetCondition}
     GROUP BY COALESCE(NULLIF(TRIM(cashier_name), ''), 'Kassa')
     ORDER BY total_revenue DESC`,
    queryParams
  );

  const itemsRes = await db.query(
    `SELECT 
       COALESCE(item->'product'->>'name', item->>'name', 'Noma''lum') as name,
       SUM(COALESCE((item->>'qty')::numeric, 1))::int as qty,
       SUM(COALESCE((item->'product'->>'price')::numeric, (item->>'price')::numeric, 0) * COALESCE((item->>'qty')::numeric, 1))::bigint as total_revenue
     FROM receipts r,
     LATERAL jsonb_array_elements(r.items) as item
     WHERE r.cafe_id = $1 
       AND (
         (r.date AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
         OR (r.created_at AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
       )${resetCondition}
     GROUP BY COALESCE(item->'product'->>'name', item->>'name', 'Noma''lum')
     ORDER BY qty DESC
     LIMIT 20`,
    queryParams
  );

  const hallRes = await db.query(
    `SELECT 
       COALESCE(NULLIF(TRIM(hall_name), ''), 'Zal') as hall_name,
       COUNT(*)::int as order_count,
       COALESCE(SUM(total), 0)::bigint as total_revenue
     FROM receipts
     WHERE cafe_id = $1 
       AND (
         (date AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
         OR (created_at AT TIME ZONE 'Asia/Tashkent')::date = (CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tashkent')::date
       )${resetCondition}
     GROUP BY COALESCE(NULLIF(TRIM(hall_name), ''), 'Zal')
     ORDER BY total_revenue DESC`,
    queryParams
  );

  return {
    totalRevenue: parseInt(summary.total_revenue, 10) || 0,
    orderCount: parseInt(summary.order_count, 10) || 0,
    cashTotal: parseInt(summary.cash_total, 10) || 0,
    cardTotal: parseInt(summary.card_total, 10) || 0,
    averageCheck: parseInt(summary.average_check, 10) || 0,
    waiters: waiterRes.rows.map(w => ({
      name: w.waiter,
      orderCount: parseInt(w.order_count, 10) || 0,
      totalRevenue: parseInt(w.total_revenue, 10) || 0,
    })),
    topProducts: itemsRes.rows.map(i => ({
      name: i.name,
      quantity: parseInt(i.qty, 10) || 0,
      totalRevenue: parseInt(i.total_revenue, 10) || 0,
    })),
    halls: hallRes.rows.map(h => ({
      name: h.hall_name,
      orderCount: parseInt(h.order_count, 10) || 0,
      totalRevenue: parseInt(h.total_revenue, 10) || 0,
    })),
    updatedAt: new Date().toISOString(),
  };
};

// GET /api/reports/today — Live SQL aggregation for today
const getTodayReport = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const data = await getTodayReportData(cafeId);
    return res.json({ success: true, todayReport: data, ...data });
  } catch (error) {
    console.error('getTodayReport error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

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

// DELETE /api/reports/:dateId — clear a single day's report & receipts
const clearDay = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { dateId } = req.params;
    await db.query('DELETE FROM reports WHERE cafe_id = $1 AND date_id = $2', [cafeId, dateId]);
    await db.query(
      `DELETE FROM receipts WHERE cafe_id = $1 AND (TO_CHAR(date, 'YYYY-MM-DD') = $2 OR TO_CHAR(created_at, 'YYYY-MM-DD') = $2)`,
      [cafeId, dateId]
    );
    const updatedToday = await getTodayReportData(cafeId);
    notifyCafe(cafeId, 'REPORT_CLEARED', { dateId, todayReport: updatedToday });
    notifyCafe(cafeId, 'REPORT_UPDATED', { todayReport: updatedToday });
    res.json({ success: true, message: `${dateId} hisoboti va cheklari tozalandi`, todayReport: updatedToday });
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
    await db.query(
      `DELETE FROM receipts WHERE cafe_id = $1 AND (TO_CHAR(date, 'YYYY-MM') = $2 OR TO_CHAR(created_at, 'YYYY-MM') = $2)`,
      [cafeId, yearMonth]
    );
    const updatedToday = await getTodayReportData(cafeId);
    notifyCafe(cafeId, 'REPORT_CLEARED', { yearMonth, count: result.rows.length, todayReport: updatedToday });
    notifyCafe(cafeId, 'REPORT_UPDATED', { todayReport: updatedToday });
    res.json({ success: true, count: result.rows.length, todayReport: updatedToday });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/reports / /api/reports/all — clear ALL reports for this cafe (0 dan tozalash, cheklar arxivda qoladi)
const clearAll = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const nowIso = new Date().toISOString();

    // 1. Saqlangan sozlamalar ichiga reports_reset_at timestamp yozamiz
    const sRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const currentSettings = sRes.rows[0]?.data || {};
    currentSettings.reports_reset_at = nowIso;
    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) 
       VALUES ($1, $2, CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(currentSettings)]
    );

    // 2. Kunlik hisobotlar jadvalini tozalaymiz (cheklar esa cheklar tarixida arxivda saqlanadi!)
    await db.query('DELETE FROM reports WHERE cafe_id = $1', [cafeId]);

    const zeroReport = await getTodayReportData(cafeId);
    notifyCafe(cafeId, 'REPORT_CLEARED', { all: true, todayReport: zeroReport, resetAt: nowIso });
    notifyCafe(cafeId, 'reports_cleared', { all: true, todayReport: zeroReport, resetAt: nowIso });
    notifyCafe(cafeId, 'REPORT_UPDATED', { todayReport: zeroReport, resetAt: nowIso });
    res.json({ success: true, message: 'Barcha hisobotlar muvaffaqiyatli 0 dan tozalandi (cheklar arxivda saqlandi)', todayReport: zeroReport, resetAt: nowIso });
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

module.exports = {
  list,
  getOne,
  getTodayReport,
  getTodayReportData,
  clearDay,
  clearMonth,
  clearAll,
  getAnalytics,
  exportCsv,
};
