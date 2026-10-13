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

module.exports = { list, getOne, clearDay, clearMonth, clearAll };
