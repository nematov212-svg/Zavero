const db = require('../config/db');
const { mapTable, mapCartItems } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { seedDefaultHallsAndTables } = require('../utils/seedCafe');
const { getTenantCafeId } = require('../utils/tenantHelper');

const list = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const [tableR, tableOrdR] = await Promise.all([
      db.query('SELECT * FROM restaurant_tables WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM table_orders WHERE cafe_id = $1', [cafeId]),
    ]);

    const tableOrders = {};
    const tableNotes = {};
    for (const row of tableOrdR.rows) {
      tableOrders[row.table_id] = mapCartItems(row.items);
      if (row.note) tableNotes[row.table_id] = row.note;
    }

    res.json({
      success: true,
      tables: tableR.rows.map(mapTable),
      tableOrders,
      tableNotes,
    });
  } catch (error) {
    console.error('table list error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/tables/:id/order — save/replace the live cart for a table (mirrors saveTableOrder + lockTableForCheckout)
const saveOrder = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const tableId = parseInt(req.params.id, 10);
  const { items, note, forceOccupy } = req.body;
  const username = req.user.username;

  try {
    if (!items || items.length === 0) {
      return release(req, res);
    }

    const result = await db.withTransaction(async (client) => {
      const tableRes = await client.query(
        'SELECT * FROM restaurant_tables WHERE id = $1 AND cafe_id = $2 FOR UPDATE',
        [tableId, cafeId]
      );
      if (tableRes.rows.length === 0) throw Object.assign(new Error('Stol topilmadi'), { status: 404 });

      const table = tableRes.rows[0];
      const orderRes = await client.query('SELECT * FROM table_orders WHERE table_id = $1', [tableId]);
      const existingOrder = orderRes.rows[0];

      if (table.status === 'occupied' && existingOrder && existingOrder.started_by &&
        existingOrder.started_by !== username && !forceOccupy) {
        throw Object.assign(new Error('Bu stol hozir band'), { status: 409, code: 'TABLE_BUSY' });
      }

      const total = items.reduce((s, i) => s + (i.product.price * i.qty), 0);
      const startedBy = existingOrder ? (existingOrder.started_by || username) : username;

      await client.query(
        `UPDATE restaurant_tables SET status='occupied', order_id=$1, total=$2, started_by=$3,
         updated_at=CURRENT_TIMESTAMP WHERE id=$4`,
        [`${tableId}`, total, startedBy, tableId]
      );

      await client.query(
        `INSERT INTO table_orders (table_id, cafe_id, items, note, started_by, updated_at)
         VALUES ($1,$2,$3,$4,$5,CURRENT_TIMESTAMP)
         ON CONFLICT (table_id) DO UPDATE SET items=$3, note=$4, started_by=$5, updated_at=CURRENT_TIMESTAMP`,
        [tableId, cafeId, JSON.stringify(items), note || '', startedBy]
      );

      const updatedTable = await client.query('SELECT * FROM restaurant_tables WHERE id = $1', [tableId]);
      return updatedTable.rows[0];
    });

    notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', {
      tableId,
      tableNumber: result.number,
      table: mapTable(result),
      items: mapCartItems(items),
      note: note || '',
    });
    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', {
      tableId,
      tableNumber: result.number,
      status: 'occupied',
    });

    return res.json({ success: true, table: mapTable(result) });
  } catch (error) {
    if (error.code === 'TABLE_BUSY') {
      return res.status(409).json({ success: false, code: 'TABLE_BUSY', message: error.message });
    }
    console.error('saveOrder error:', error);
    return res.status(error.status || 500).json({ success: false, message: error.message });
  }
};

// POST /api/tables/:id/release
const release = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const tableId = parseInt(req.params.id, 10);
  try {
    let releasedTableNumber = null;
    await db.withTransaction(async (client) => {
      const up = await client.query(
        `UPDATE restaurant_tables SET status='free', order_id=NULL, total=0, started_by=NULL,
         updated_at=CURRENT_TIMESTAMP WHERE id=$1 AND cafe_id=$2 RETURNING number`,
        [tableId, cafeId]
      );
      if (up.rows.length > 0) releasedTableNumber = up.rows[0].number;
      await client.query('DELETE FROM table_orders WHERE table_id = $1', [tableId]);
    });

    notifyCafe(cafeId, 'TABLE_RELEASED', { tableId, tableNumber: releasedTableNumber });
    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId, tableNumber: releasedTableNumber, status: 'free' });
    notifyCafe(cafeId, 'TABLE_ORDER_UPDATED', { tableId, tableNumber: releasedTableNumber, items: [], note: '' });
    return res.json({ success: true });
  } catch (error) {
    console.error('release error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/tables/:id/status
const updateStatus = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const tableId = parseInt(req.params.id, 10);
  const { status } = req.body;
  try {
    const result = await db.query(
      `UPDATE restaurant_tables SET status=$1, updated_at=CURRENT_TIMESTAMP WHERE id=$2 AND cafe_id=$3 RETURNING *`,
      [status, tableId, cafeId]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Stol topilmadi' });

    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableId, status });
    return res.json({ success: true, table: mapTable(result.rows[0]) });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/tables
const createTable = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { hallId, number, seats } = req.body;
    const num = parseInt(number, 10);
    const hId = parseInt(hallId, 10);
    const s = parseInt(seats, 10) || 4;

    const result = await db.query(
      `INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status)
       VALUES ($1, $2, $3, $4, 'free') RETURNING *`,
      [cafeId, hId, num, s]
    );
    const newTable = mapTable(result.rows[0]);
    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { table: newTable });
    return res.status(201).json({ success: true, table: newTable });
  } catch (error) {
    console.error('createTable error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/tables/:id
const updateTable = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const tableId = parseInt(req.params.id, 10);
    const { number, seats, hallId } = req.body;
    const updates = [];
    const values = [tableId, cafeId];
    let idx = 3;

    if (number !== undefined) {
      updates.push(`number = $${idx++}`);
      values.push(parseInt(number, 10));
    }
    if (seats !== undefined) {
      updates.push(`seats = $${idx++}`);
      values.push(parseInt(seats, 10));
    }
    if (hallId !== undefined) {
      updates.push(`hall_id = $${idx++}`);
      values.push(parseInt(hallId, 10));
    }
    if (updates.length === 0) {
      return res.status(400).json({ success: false, message: 'O\'zgartirish uchun ma\'lumot berilmadi' });
    }

    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    const result = await db.query(
      `UPDATE restaurant_tables SET ${updates.join(', ')} WHERE id = $1 AND cafe_id = $2 RETURNING *`,
      values
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Stol topilmadi' });
    }
    const updated = mapTable(result.rows[0]);
    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { table: updated });
    return res.json({ success: true, table: updated });
  } catch (error) {
    console.error('updateTable error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/tables/:id
const removeTable = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const rawId = req.params.id || req.body?.tableId || req.body?.id || req.query?.id;
    const tableId = parseInt(rawId, 10);
    if (isNaN(tableId)) {
      return res.status(400).json({ success: false, message: 'Stol ID noto\'g\'ri' });
    }

    await db.withTransaction(async (client) => {
      await client.query('DELETE FROM table_orders WHERE table_id = $1', [tableId]);
      if (req.user?.role === 'director' || !cafeId) {
        await client.query('DELETE FROM restaurant_tables WHERE id = $1', [tableId]);
      } else {
        await client.query('DELETE FROM restaurant_tables WHERE id = $1 AND cafe_id = $2', [tableId, cafeId]);
      }
    });

    if (cafeId) {
      notifyCafe(cafeId, 'TABLE_RELEASED', { tableId });
      notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { tableDeleted: tableId });
    }
    return res.json({ success: true, tableId });
  } catch (error) {
    console.error('removeTable error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/tables/clear-all or DELETE /api/tables/clear-all
const clearAllTables = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    await db.withTransaction(async (client) => {
      await client.query('DELETE FROM table_orders WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM restaurant_tables WHERE cafe_id = $1', [cafeId]);
    });

    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { clearedAll: true });
    return res.json({ success: true, message: 'Barcha stollar o\'chirildi' });
  } catch (error) {
    console.error('clearAllTables error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/tables/clear-hall/:hallId or DELETE /api/tables/clear-hall/:hallId
const clearHallTables = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const hallId = parseInt(req.params.hallId, 10);
    if (isNaN(hallId)) {
      return res.status(400).json({ success: false, message: 'Zal ID noto\'g\'ri' });
    }

    await db.withTransaction(async (client) => {
      await client.query(
        'DELETE FROM table_orders WHERE table_id IN (SELECT id FROM restaurant_tables WHERE hall_id = $1 AND cafe_id = $2)',
        [hallId, cafeId]
      );
      await client.query('DELETE FROM restaurant_tables WHERE hall_id = $1 AND cafe_id = $2', [hallId, cafeId]);
    });

    notifyCafe(cafeId, 'TABLE_STATUS_UPDATED', { clearedHall: hallId });
    return res.json({ success: true, hallId, message: 'Zal stollari o\'chirildi' });
  } catch (error) {
    console.error('clearHallTables error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, saveOrder, release, updateStatus, createTable, updateTable, removeTable, clearAllTables, clearHallTables };

