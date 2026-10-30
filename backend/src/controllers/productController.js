const db = require('../config/db');
const { mapProduct } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { getTenantCafeId } = require('../utils/tenantHelper');

const list = async (req, res) => {
  const cafeId = getTenantCafeId(req);
  const result = await db.query('SELECT * FROM products WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]);
  res.json({ success: true, products: result.rows.map(mapProduct) });
};

const save = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id, name, price, categoryId, stock, iconCodePoint, imageUrl, originalName } = req.body;

    let row;
    const cleanName = name ? name.trim() : '';
    const cleanOrigName = originalName ? originalName.trim() : '';
    const safeCatId = categoryId ? parseInt(categoryId, 10) : null;
    const safePrice = (price !== undefined && price !== null) ? Number(price) : 0;
    const safeStock = (stock !== undefined && stock !== null) ? parseInt(stock, 10) : 0;
    const safeIconCodePoint = (iconCodePoint !== undefined && iconCodePoint !== null) ? Number(iconCodePoint) : 0xe532;

    if (id) {
      const existing = await db.query('SELECT id FROM products WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Mahsulot topilmadi' });
      }
      const result = await db.query(
        `UPDATE products SET name=$1, price=$2, category_id=$3, stock=$4, icon_code_point=$5,
         image_url=$6, updated_at=CURRENT_TIMESTAMP WHERE id=$7 AND cafe_id=$8 RETURNING *`,
        [cleanName, safePrice, safeCatId, safeStock, safeIconCodePoint, imageUrl || null, id, cafeId]
      );
      row = result.rows[0];
    } else if (cleanOrigName || cleanName) {
      const nameToMatch = cleanOrigName || cleanName;
      const existingByName = await db.query(
        'SELECT id FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND cafe_id = $2',
        [nameToMatch, cafeId]
      );
      if (existingByName.rows.length > 0) {
        const existingId = existingByName.rows[0].id;
        const result = await db.query(
          `UPDATE products SET name=$1, price=$2, category_id=$3, stock=$4, icon_code_point=$5,
           image_url=$6, updated_at=CURRENT_TIMESTAMP WHERE id=$7 AND cafe_id=$8 RETURNING *`,
          [cleanName, safePrice, safeCatId, safeStock, safeIconCodePoint, imageUrl || null, existingId, cafeId]
        );
        row = result.rows[0];
      }
    }

    if (!row && !id && cleanName) {
      const result = await db.query(
        `INSERT INTO products (cafe_id, name, price, category_id, stock, icon_code_point, image_url)
         VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [cafeId, cleanName, safePrice, safeCatId, safeStock, safeIconCodePoint, imageUrl || null]
      );
      row = result.rows[0];
    }

    if (row) {
      notifyCafe(cafeId, 'PRODUCTS_UPDATED', { product: mapProduct(row) });
      return res.json({ success: true, product: mapProduct(row) });
    }

    res.status(400).json({ success: false, message: 'Invalid product data' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { id } = req.params;
    const { name } = req.query;

    const numericId = parseInt(id, 10);
    let deletedId = !isNaN(numericId) ? numericId : null;

    if (deletedId) {
      const resById = await db.query('DELETE FROM products WHERE id = $1 AND cafe_id = $2 RETURNING id', [deletedId, cafeId]);
      if (resById.rows.length === 0 && name) {
        const resByName = await db.query('DELETE FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND cafe_id = $2 RETURNING id', [name, cafeId]);
        if (resByName.rows.length > 0) {
          deletedId = resByName.rows[0].id;
        } else {
          return res.status(404).json({ success: false, message: 'Mahsulot topilmadi' });
        }
      } else if (resById.rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Mahsulot topilmadi' });
      }
    } else if (name) {
      const resByName = await db.query('DELETE FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND cafe_id = $2 RETURNING id', [name, cafeId]);
      if (resByName.rows.length > 0) {
        deletedId = resByName.rows[0].id;
      } else {
        return res.status(404).json({ success: false, message: 'Mahsulot topilmadi' });
      }
    } else {
      return res.status(400).json({ success: false, message: 'ID yoki nom ko\'rsatilishi shart' });
    }

    notifyCafe(cafeId, 'PRODUCTS_UPDATED', { deletedId: deletedId || numericId });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const bulkRemove = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    const { ids } = req.body;
    if (Array.isArray(ids) && ids.length > 0) {
      await db.query('DELETE FROM products WHERE id = ANY($1::int[]) AND cafe_id = $2', [ids, cafeId]);
      notifyCafe(cafeId, 'PRODUCTS_UPDATED', { deletedIds: ids });
      return res.json({ success: true, count: ids.length });
    }
    return res.status(400).json({ success: false, message: 'Hech qanday ovqat tanlanmadi' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { list, save, remove, bulkRemove };
