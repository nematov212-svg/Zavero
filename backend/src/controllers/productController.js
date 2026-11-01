const path = require('path');
const fs = require('fs');
const db = require('../config/db');
const { mapProduct } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');
const { getTenantCafeId } = require('../utils/tenantHelper');

// Server diskidagi yuklangan rasm faylini o'chirish yordamchisi
const deleteLocalImageIfExists = (imageUrl) => {
  if (!imageUrl || typeof imageUrl !== 'string') return;
  try {
    const match = imageUrl.match(/(?:^|\/)uploads\/([^/?#]+)/);
    if (match && match[1]) {
      const fileName = match[1];
      const filePath = path.join(__dirname, '../../uploads', fileName);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
        console.log(`🗑️ [Product Image] Fayl o'chirildi: ${fileName}`);
      }
    }
  } catch (err) {
    console.warn('⚠️ [Product Image Delete Warning]:', err.message);
  }
};

const ensureDeletedProductsTable = async () => {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS deleted_products (
        id SERIAL PRIMARY KEY,
        cafe_id VARCHAR(64) NOT NULL,
        product_id INTEGER,
        product_name VARCHAR(150) NOT NULL,
        deleted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_deleted_products_cafe ON deleted_products(cafe_id);
    `);
  } catch (_) {}
};

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

    // 1. Agar id berilgan bo'lsa, avval bazada mavjudligini tekshiramiz
    if (id && parseInt(id, 10) > 0) {
      const existing = await db.query('SELECT id FROM products WHERE id = $1 AND cafe_id = $2', [parseInt(id, 10), cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          `UPDATE products SET name=$1, price=$2, category_id=$3, stock=$4, icon_code_point=$5,
           image_url=$6, updated_at=CURRENT_TIMESTAMP WHERE id=$7 AND cafe_id=$8 RETURNING *`,
          [cleanName, safePrice, safeCatId, safeStock, safeIconCodePoint, imageUrl || null, parseInt(id, 10), cafeId]
        );
        row = result.rows[0];
      }
    }

    // 2. Agar id bo'yicha topilmasa, lekin nomi (yoki eski nomi) bo'yicha bazada bor bo'lsa -> UPDATE
    if (!row && (cleanOrigName || cleanName)) {
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

    // 3. Agar mavjud bo'lmasa -> INSERT (hech qachon 404 qaytarmasdan yangi taom sifatida PostgreSQL bazasiga yozamiz)
    if (!row && cleanName) {
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

    return res.status(400).json({ success: false, message: 'Taom ma\'lumotlari noto\'g\'ri' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const remove = async (req, res) => {
  try {
    await ensureDeletedProductsTable();
    const cafeId = getTenantCafeId(req);
    const { id } = req.params;
    const { name } = req.query;

    const numericId = parseInt(id, 10);
    let targetId = !isNaN(numericId) ? numericId : null;

    let targetProduct = null;
    if (targetId) {
      const findRes = await db.query(
        'SELECT id, name, image_url FROM products WHERE id = $1 AND cafe_id = $2',
        [targetId, cafeId]
      );
      if (findRes.rows.length > 0) {
        targetProduct = findRes.rows[0];
      }
    }
    if (!targetProduct && name) {
      const findByName = await db.query(
        'SELECT id, name, image_url FROM products WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND cafe_id = $2',
        [name, cafeId]
      );
      if (findByName.rows.length > 0) {
        targetProduct = findByName.rows[0];
      }
    }

    if (!targetProduct) {
      return res.status(404).json({ success: false, message: 'Mahsulot topilmadi' });
    }

    // 1. Agar serverga yuklangan rasm fayli bo'lsa, uni diskdan o'chirish
    deleteLocalImageIfExists(targetProduct.image_url);

    // 2. PostgreSQL bazasidan haqiqiy to'liq o'chirish (Hard Delete)
    await db.query('DELETE FROM products WHERE id = $1 AND cafe_id = $2', [targetProduct.id, cafeId]);

    // 3. Qaytib chiqmasligi uchun o'chirilganlar ro'yxatiga (deleted_products) yozib qo'yish
    await db.query(
      `INSERT INTO deleted_products (cafe_id, product_id, product_name)
       VALUES ($1, $2, $3)`,
      [cafeId, targetProduct.id, targetProduct.name]
    ).catch(() => {});

    // 4. Barcha qurilmalarga real-time Socket.IO xabari
    notifyCafe(cafeId, 'PRODUCTS_UPDATED', { deletedId: targetProduct.id, name: targetProduct.name });
    console.log(`✅ [Product] Taom butunlay o'chirildi: "${targetProduct.name}" (ID: ${targetProduct.id}, Kafe: ${cafeId})`);

    return res.json({ success: true, message: 'Mahsulot muvaffaqiyatli o\'chirildi', deletedId: targetProduct.id });
  } catch (error) {
    console.error('remove product error:', error);
    res.status(500).json({ success: false, message: 'O\'chirishda xatolik: ' + error.message });
  }
};

const bulkRemove = async (req, res) => {
  try {
    await ensureDeletedProductsTable();
    const cafeId = getTenantCafeId(req);
    const rawIds = req.body.ids || req.body.productIds;

    if (!Array.isArray(rawIds) || rawIds.length === 0) {
      return res.status(400).json({ success: false, message: 'Hech qanday ovqat tanlanmadi' });
    }

    const ids = rawIds.map((x) => parseInt(x, 10)).filter((x) => !isNaN(x) && x > 0);
    if (ids.length === 0) {
      return res.status(400).json({ success: false, message: 'Yaroqli ovqat IDlari topilmadi' });
    }

    // 1. O'chirilishi kerak bo'lgan ovqatlarning rasmlari va nomlarini olish
    const prodsRes = await db.query(
      'SELECT id, name, image_url FROM products WHERE id = ANY($1::int[]) AND cafe_id = $2',
      [ids, cafeId]
    );

    for (const p of prodsRes.rows) {
      deleteLocalImageIfExists(p.image_url);
      await db.query(
        `INSERT INTO deleted_products (cafe_id, product_id, product_name)
         VALUES ($1, $2, $3)`,
        [cafeId, p.id, p.name]
      ).catch(() => {});
    }

    // 2. PostgreSQL bazasidan to'liq o'chirish (Hard Delete)
    await db.query('DELETE FROM products WHERE id = ANY($1::int[]) AND cafe_id = $2', [ids, cafeId]);

    // 3. Real-time xabar
    notifyCafe(cafeId, 'PRODUCTS_UPDATED', { deletedIds: ids });
    console.log(`✅ [Product] ${ids.length} ta ovqat butunlay o'chirildi (Kafe: ${cafeId})`);

    return res.json({ success: true, count: prodsRes.rows.length, deletedIds: ids });
  } catch (error) {
    console.error('bulkRemove products error:', error);
    res.status(500).json({ success: false, message: 'O\'chirishda xatolik: ' + error.message });
  }
};

module.exports = { list, save, remove, bulkRemove };
