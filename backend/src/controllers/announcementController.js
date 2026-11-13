const db = require('../config/db');
const { getTenantCafeId } = require('../utils/tenantHelper');

// GET /api/announcements — List announcements for the current cafe tenant
const list = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const userId = req.user?.id;
    const isDirector = req.user?.role === 'director' || req.user?.role === 'super_admin';

    let queryText = '';
    let params = [];

    if (isDirector && !cafeId) {
      // Director viewing all sent announcements
      queryText = `
        SELECT a.*,
               (SELECT COUNT(*) FROM announcement_reads ar WHERE ar.announcement_id = a.id) as reads_count
        FROM announcements a
        ORDER BY a.created_at DESC
        LIMIT 100
      `;
    } else {
      // Cafe viewing announcements targeted to them (har bir xodim o'z o'qilganlik holatini ko'radi)
      params = [cafeId, userId || null];
      queryText = `
        SELECT 
          a.id,
          a.title,
          a.message,
          a.priority,
          a.target_type,
          a.target_cafes,
          a.created_by,
          a.created_at,
          (ar.id IS NOT NULL) AS is_read,
          ar.read_at
        FROM announcements a
        LEFT JOIN announcement_reads ar 
          ON a.id = ar.announcement_id AND (ar.user_id = $2 OR (ar.user_id IS NULL AND ar.cafe_id = $1))
        WHERE a.target_type = 'all' 
           OR a.target_cafes::jsonb @> to_jsonb($1::text)
           OR a.target_cafes::text LIKE '%' || $1 || '%'
        ORDER BY a.created_at DESC
        LIMIT 60
      `;
    }

    const result = await db.query(queryText, params);
    const announcements = result.rows.map((row) => ({
      id: row.id,
      title: row.title,
      message: row.message,
      priority: row.priority || 'normal',
      targetType: row.target_type,
      targetCafes: row.target_cafes,
      createdBy: row.created_by || 'Director',
      createdAt: row.created_at,
      isRead: !!row.is_read,
      readAt: row.read_at,
      readsCount: parseInt(row.reads_count || 0),
    }));

    const unreadCount = announcements.filter((a) => !a.isRead).length;

    return res.json({
      success: true,
      announcements,
      unreadCount,
    });
  } catch (error) {
    console.error('announcement list error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/announcements/:id/read — Mark an announcement as read by this specific employee
const markAsRead = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const announcementId = parseInt(req.params.id, 10);
    const userId = req.user?.id || null;
    const readBy = req.user?.name || req.user?.username || 'Kafe xodimi';

    if (isNaN(announcementId)) {
      return res.status(400).json({ success: false, message: 'ID noto‘g‘ri' });
    }

    await db.query(
      `INSERT INTO announcement_reads (announcement_id, cafe_id, user_id, read_by, read_at)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
       ON CONFLICT DO NOTHING`,
      [announcementId, cafeId, userId, readBy]
    );

    return res.json({ success: true, message: 'O‘qildi deb belgilandi.' });
  } catch (error) {
    console.error('markAsRead error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/announcements/read-all — Mark all announcements as read for this employee
const markAllAsRead = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const userId = req.user?.id || null;
    const readBy = req.user?.name || req.user?.username || 'Kafe xodimi';

    const unreadRes = await db.query(
      `SELECT a.id 
       FROM announcements a
       LEFT JOIN announcement_reads ar 
         ON a.id = ar.announcement_id AND (ar.user_id = $2 OR (ar.user_id IS NULL AND ar.cafe_id = $1))
       WHERE (a.target_type = 'all' 
              OR a.target_cafes::jsonb @> to_jsonb($1::text)
              OR a.target_cafes::text LIKE '%' || $1 || '%')
         AND ar.id IS NULL`,
      [cafeId, userId]
    );

    for (const row of unreadRes.rows) {
      await db.query(
        `INSERT INTO announcement_reads (announcement_id, cafe_id, user_id, read_by, read_at)
         VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
         ON CONFLICT DO NOTHING`,
        [row.id, cafeId, userId, readBy]
      );
    }

    return res.json({ success: true, count: unreadRes.rows.length, message: 'Barcha e‘lonlar o‘qildi deb belgilandi.' });
  } catch (error) {
    console.error('markAllAsRead error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  list,
  markAsRead,
  markAllAsRead,
};

