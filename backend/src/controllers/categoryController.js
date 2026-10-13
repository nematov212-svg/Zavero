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
    if (id) {
      const existing = await db.query('SELECT id FROM categories WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          'UPDATE categories SET name = $1, icon_code_point = $2 WHERE id = $3 AND cafe_id = $4 RETURNING *',
          [name, iconCodePoint, id, cafeId]
        );
        row = result.rows[0];
      }
    }
    if (!row) {
      const result = await db.query(
        'INSERT INTO categories (cafe_id, name, icon_code_point) VALUES ($1,$2,$3) RETURNING *',
        [cafeId, name, iconCodePoint]
      );
      row = result.rows[0];
    }

    notifyCafe(cafeId, 'CATEGORIES_UPDATED', { category: mapCategory(row) });
    res.json({ success: true, category: mapCategory(row) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id } = req.params;
    await db.query('DELETE FROM categories WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    notifyCafe(cafeId, 'CATEGORIES_UPDATED', { deletedId: parseInt(id, 10) });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
