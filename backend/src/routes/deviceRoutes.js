const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const db = require('../config/db');

router.use(auth);

// GET /api/devices - List devices for current cafe
router.get('/', async (req, res) => {
  try {
    let result;
    if (req.user.role === 'director' && req.query.cafeId) {
      result = await db.query(
        `SELECT d.*, u.name as user_name FROM devices d LEFT JOIN users u ON d.user_id = u.id WHERE d.cafe_id = $1 ORDER BY d.last_seen DESC`,
        [req.query.cafeId]
      );
    } else {
      result = await db.query(
        `SELECT d.*, u.name as user_name FROM devices d LEFT JOIN users u ON d.user_id = u.id WHERE d.cafe_id = $1 ORDER BY d.last_seen DESC`,
        [req.user.cafeId]
      );
    }
    return res.json({ success: true, devices: result.rows });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// POST /api/devices/register - Register / heartbeat
router.post('/register', async (req, res) => {
  try {
    const { deviceIdentifier, deviceName, deviceType } = req.body;
    if (!deviceIdentifier) {
      return res.status(400).json({ success: false, message: 'deviceIdentifier kiritilishi shart.' });
    }
    const dName = deviceName || 'Noma\'lum qurilma';
    const dType = deviceType || 'desktop';

    await db.query(
      `INSERT INTO devices (cafe_id, user_id, device_name, device_type, device_identifier, last_seen, is_active)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP, true)
       ON CONFLICT (cafe_id, device_identifier) DO UPDATE SET
         user_id = EXCLUDED.user_id,
         device_name = EXCLUDED.device_name,
         device_type = EXCLUDED.device_type,
         last_seen = CURRENT_TIMESTAMP,
         is_active = true`,
      [req.user.cafeId, req.user.id, dName, dType, deviceIdentifier]
    );

    return res.json({ success: true, message: 'Qurilma qayd etildi.' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

// DELETE /api/devices/:id - Revoke device
router.delete('/:id', async (req, res) => {
  try {
    if (req.user.role === 'director') {
      const delRes = await db.query('DELETE FROM devices WHERE id = $1 RETURNING id', [req.params.id]);
      if (delRes.rowCount === 0) return res.status(404).json({ success: false, message: 'Qurilma topilmadi.' });
    } else {
      const delRes = await db.query('DELETE FROM devices WHERE id = $1 AND cafe_id = $2 RETURNING id', [req.params.id, req.user.cafeId]);
      if (delRes.rowCount === 0) return res.status(404).json({ success: false, message: 'Qurilma topilmadi.' });
    }
    return res.json({ success: true, message: 'Qurilma o\'chirildi.' });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
