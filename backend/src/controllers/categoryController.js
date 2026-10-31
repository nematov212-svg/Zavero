const db = require('../config/db');
const { mapCategory } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { getTenantCafeId } = require('../utils/tenantHelper');

const list = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const result = await db.query('SELECT * FROM categories WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]);
  res.json({ success: true, categories: result.rows.map(mapCategory) });
};

// Upsert: if body.id exists in this cafe -> update, else insert
const save = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id, name, iconCodePoint } = req.body;

    let row;
    const cleanName = name ? name.trim() : '';
    const safeIcon = iconCodePoint ? parseInt(iconCodePoint, 10) : 0xe532;

    if (id && parseInt(id, 10) > 0) {
      const existing = await db.query('SELECT id FROM categories WHERE id = $1 AND cafe_id = $2', [parseInt(id, 10), cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          'UPDATE categories SET name = $1, icon_code_point = $2 WHERE id = $3 AND cafe_id = $4 RETURNING *',
          [cleanName, safeIcon, parseInt(id, 10), cafeId]
        );
        row = result.rows[0];
      }
    }

    if (!row && cleanName) {
      const existingByName = await db.query(
        'SELECT id FROM categories WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND cafe_id = $2',
        [cleanName, cafeId]
      );
      if (existingByName.rows.length > 0) {
        const existingId = existingByName.rows[0].id;
        const result = await db.query(
          'UPDATE categories SET name = $1, icon_code_point = $2 WHERE id = $3 AND cafe_id = $4 RETURNING *',
          [cleanName, safeIcon, existingId, cafeId]
        );
        row = result.rows[0];
      } else {
        const result = await db.query(
          'INSERT INTO categories (cafe_id, name, icon_code_point) VALUES ($1,$2,$3) RETURNING *',
          [cafeId, cleanName, safeIcon]
        );
        row = result.rows[0];
      }
    }

    if (row) {
      notifyCafe(cafeId, 'CATEGORIES_UPDATED', { category: mapCategory(row) });
      return res.json({ success: true, category: mapCategory(row) });
    }

    return res.status(400).json({ success: false, message: 'Kategoriya nomi kiritilishi shart' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id } = req.params;
    const delRes = await db.query('DELETE FROM categories WHERE id = $1 AND cafe_id = $2 RETURNING id', [id, cafeId]);
    if (delRes.rowCount === 0) {
      return res.status(404).json({ success: false, message: 'Kategoriya topilmadi' });
    }
    notifyCafe(cafeId, 'CATEGORIES_UPDATED', { deletedId: parseInt(id, 10) });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
