const db = require('../config/db');
const { mapCustomer } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

const list = async (req, res) => {
  const result = await db.query('SELECT * FROM customers WHERE cafe_id = $1 ORDER BY id ASC', [req.user.cafeId]);
  res.json({ success: true, customers: result.rows.map(mapCustomer) });
};

const save = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id, name, phone, email, loyaltyPoints } = req.body;

    let row;
    if (id) {
      const existing = await db.query('SELECT id FROM customers WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          'UPDATE customers SET name=$1, phone=$2, email=$3, loyalty_points=$4 WHERE id=$5 AND cafe_id=$6 RETURNING *',
          [name, phone || '', email || '', loyaltyPoints || 0, id, cafeId]
        );
        row = result.rows[0];
      }
    }
    if (!row) {
      const result = await db.query(
        'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1,$2,$3,$4,$5) RETURNING *',
        [cafeId, name, phone || '', email || '', loyaltyPoints || 0]
      );
      row = result.rows[0];
    }

    notifyCafe(cafeId, 'CUSTOMERS_UPDATED', { customer: mapCustomer(row) });
    res.json({ success: true, customer: mapCustomer(row) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id } = req.params;
    await db.query('DELETE FROM customers WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    notifyCafe(cafeId, 'CUSTOMERS_UPDATED', { deletedId: parseInt(id, 10) });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove };
