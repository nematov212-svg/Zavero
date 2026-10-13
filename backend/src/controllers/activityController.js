const db = require('../config/db');

const create = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { action, details, performedBy } = req.body;
    await db.query(
      'INSERT INTO activity_logs (cafe_id, action, details, performed_by) VALUES ($1,$2,$3,$4)',
      [cafeId, action || '', details || '', performedBy || '']
    );
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const list = async (req, res) => {
  const result = await db.query(
    'SELECT * FROM activity_logs WHERE cafe_id = $1 ORDER BY timestamp DESC LIMIT 200',
    [req.user.cafeId]
  );
  res.json({
    success: true,
    logs: result.rows.map((r) => ({
      id: `${r.id}`,
      action: r.action,
      details: r.details,
      performedBy: r.performed_by,
      timestamp: new Date(r.timestamp).toISOString(),
    })),
  });
};

module.exports = { create, list };
