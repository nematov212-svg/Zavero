const db = require('../config/db');
const { mapHall } = require('../utils/mappers');
const { seedDefaultHallsAndTables } = require('../utils/seedCafe');
const { getTenantCafeId } = require('../utils/tenantHelper');
const { notifyCafe } = require('../socket/socketHandler');

const list = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const result = await db.query('SELECT * FROM halls WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]);
  res.json({ success: true, halls: result.rows.map(mapHall) });
};

// POST /api/halls
const save = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id, name, iconCodePoint, imageAsset } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Zal nomi kiritilishi shart' });
    }

    const cleanName = name.trim();
    const safeIcon = iconCodePoint ? parseInt(iconCodePoint, 10) : 0xe318; // default home/room icon

    let row;
    if (id) {
      const existing = await db.query('SELECT id FROM halls WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          'UPDATE halls SET name = $1, icon_code_point = $2, image_asset = $3 WHERE id = $4 AND cafe_id = $5 RETURNING *',
          [cleanName, safeIcon, imageAsset || null, id, cafeId]
        );
        row = result.rows[0];
      }
    }

    if (!row) {
      const result = await db.query(
        'INSERT INTO halls (cafe_id, name, icon_code_point, image_asset) VALUES ($1, $2, $3, $4) RETURNING *',
        [cafeId, cleanName, safeIcon, imageAsset || null]
      );
      row = result.rows[0];
    }

    const mapped = mapHall(row);
    notifyCafe(cafeId, 'HALLS_UPDATED', { hall: mapped });
    return res.status(201).json({ success: true, hall: mapped });
  } catch (error) {
    console.error('save hall error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/halls/:id
const remove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const hallId = parseInt(req.params.id, 10);

    // Delete tables associated with this hall or cascade
    await db.withTransaction(async (client) => {
      // First delete table_orders for tables in this hall
      await client.query(
        `DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE hall_id = $1 AND cafe_id = $2)`,
        [hallId, cafeId]
      );
      // Delete tables in this hall
      await client.query(
        'DELETE FROM restaurant_tables WHERE hall_id = $1 AND cafe_id = $2',
        [hallId, cafeId]
      );
      // Delete hall
      await client.query(
        'DELETE FROM halls WHERE id = $1 AND cafe_id = $2',
        [hallId, cafeId]
      );
    });

    notifyCafe(cafeId, 'HALLS_UPDATED', { deletedId: hallId });
    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { hallDeleted: hallId });
    return res.json({ success: true, hallId });
  } catch (error) {
    console.error('remove hall error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
