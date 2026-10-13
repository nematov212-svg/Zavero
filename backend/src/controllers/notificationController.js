const db = require('../config/db');
const { notifyCafe } = require('../socket/socketHandler');

const mapNotification = (r) => ({
  id: r.id,
  cafeId: r.cafe_id,
  title: r.title,
  message: r.message,
  priority: r.priority || 'normal', // normal, urgent, info
  scheduledAt: r.scheduled_at,
  isRead: !!r.is_read,
  readAt: r.read_at,
  createdBy: r.created_by || 'ZAVERO Director',
  createdAt: r.created_at,
});

// GET /api/notifications
const list = async (req, res) => {
  try {
    const cafeId = (req.user.role === 'director' && (req.query.cafeId || req.headers['x-cafe-id'])) || req.user.cafeId;
    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'Cafe tanlanishi shart.' });
    }

    const result = await db.query(
      `SELECT * FROM notifications 
       WHERE cafe_id = $1 
       ORDER BY CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END, created_at DESC`,
      [cafeId]
    );

    return res.json({
      success: true,
      notifications: result.rows.map(mapNotification),
    });
  } catch (error) {
    console.error('Notification list error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/notifications
const create = async (req, res) => {
  try {
    const cafeId = (req.user.role === 'director' && (req.body.cafeId || req.headers['x-cafe-id'])) || req.user.cafeId;
    const { title, message, priority, scheduledAt } = req.body;

    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'Cafe tanlanishi shart.' });
    }
    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Sarlavha (title) kiritilishi shart.' });
    }
    if (!message || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Xabar matni kiritilishi shart.' });
    }

    const result = await db.query(
      `INSERT INTO notifications (cafe_id, title, message, priority, scheduled_at, created_by)
       VALUES ($1, $2, $3, $4, COALESCE($5, CURRENT_TIMESTAMP), $6) RETURNING *`,
      [
        cafeId,
        title.trim(),
        message.trim(),
        priority || 'normal',
        scheduledAt ? new Date(scheduledAt) : null,
        req.user.role === 'director' ? 'ZAVERO Director' : req.user.username,
      ]
    );

    const notification = mapNotification(result.rows[0]);
    notifyCafe(cafeId, 'NEW_NOTIFICATION', { notification });

    return res.status(201).json({
      success: true,
      message: 'Ogohlantirish muvaffaqiyatli yuborildi!',
      notification,
    });
  } catch (error) {
    console.error('Notification create error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/notifications/:id/read
const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const cafeId = (req.user.role === 'director' && (req.query.cafeId || req.headers['x-cafe-id'])) || req.user.cafeId;

    await db.query(
      `UPDATE notifications SET is_read = true, read_at = CURRENT_TIMESTAMP 
       WHERE id = $1 AND ($2 = 'zavero' OR cafe_id = $2)`,
      [id, cafeId]
    );

    notifyCafe(cafeId, 'NOTIFICATION_READ', { id: parseInt(id, 10) });

    return res.json({ success: true, message: "Xabar o'qilgan deb belgilandi." });
  } catch (error) {
    console.error('Notification markAsRead error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/notifications/:id
const remove = async (req, res) => {
  try {
    const { id } = req.params;
    const cafeId = (req.user.role === 'director' && (req.query.cafeId || req.headers['x-cafe-id'])) || req.user.cafeId;

    await db.query(
      `DELETE FROM notifications WHERE id = $1 AND ($2 = 'zavero' OR cafe_id = $2)`,
      [id, cafeId]
    );

    notifyCafe(cafeId, 'NOTIFICATION_DELETED', { id: parseInt(id, 10) });

    return res.json({ success: true, message: "Ogohlantirish o'chirildi." });
  } catch (error) {
    console.error('Notification remove error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, create, markAsRead, remove };
