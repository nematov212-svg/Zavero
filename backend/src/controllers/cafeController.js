const db = require('../config/db');
const mappers = require('../utils/mappers');
const { restoreDefaultMenu, seedDefaultHallsAndTables } = require('../utils/seedCafe');
const { getTenantCafeId } = require('../utils/tenantHelper');

// GET /api/cafe/full — one-shot full workspace load (mirrors old loadFullCafeData)
const getFullCafeData = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;

    const [cafeInfoR, settingsR, catR, prodR, hallR, tableR, tableOrdR, custR, recR, ordR, empR, repR] = await Promise.all([
      db.query('SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT * FROM categories WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM products WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM halls WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM restaurant_tables WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM table_orders WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT * FROM customers WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM receipts WHERE cafe_id = $1 ORDER BY date DESC LIMIT 200', [cafeId]),
      db.query('SELECT * FROM customer_orders WHERE cafe_id = $1 ORDER BY date DESC LIMIT 100', [cafeId]),
      db.query('SELECT * FROM employees WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM reports WHERE cafe_id = $1 ORDER BY date_id DESC LIMIT 90', [cafeId]),
    ]);

    const cafeInfo = cafeInfoR.rows[0] || {};
    const settingsData = { ...(settingsR.rows[0]?.data || {}) };
    const receiptName = cafeInfo.receipt_name !== undefined && cafeInfo.receipt_name !== null
      ? cafeInfo.receipt_name
      : (settingsData.receiptName || null);
    settingsData.receiptName = receiptName;
    settingsData.cafeName = cafeInfo.cafe_name || settingsData.restaurantName || 'ZAVERO';

    const tableOrders = {};
    const tableNotes = {};
    for (const row of tableOrdR.rows) {
      tableOrders[row.table_id] = mappers.mapCartItems(row.items);
      if (row.note) tableNotes[row.table_id] = row.note;
    }

    const payload = {
      cafeName: cafeInfo.cafe_name || 'ZAVERO',
      receiptName: receiptName,
      settings: settingsData,
      categories: catR.rows.map(mappers.mapCategory),
      products: prodR.rows.map(mappers.mapProduct),
      halls: hallR.rows.map(mappers.mapHall),
      tables: tableR.rows.map(mappers.mapTable),
      tableOrders,
      tableNotes,
      customers: custR.rows.map(mappers.mapCustomer),
      receipts: recR.rows.map(mappers.mapReceipt),
      customerOrders: ordR.rows.map(mappers.mapCustomerOrder),
      employees: empR.rows.map(mappers.mapEmployee),
      reports: repR.rows.map(mappers.mapReport),
    };

    return res.json({
      success: true,
      data: payload,
      ...payload,
    });
  } catch (error) {
    console.error('getFullCafeData error:', error);
    return res.status(500).json({ success: false, message: 'Ma\'lumotlarni olishda xatolik: ' + error.message });
  }
};

// POST /api/cafe/restore-menu — force-restore default categories and products
const restoreMenu = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    await restoreDefaultMenu(cafeId);
    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'CATEGORIES_UPDATED', {});
    notifyCafe(cafeId, 'PRODUCTS_UPDATED', {});
    return res.json({ success: true, message: 'Barcha asliy menyu va ovqatlar tiklandi!' });
  } catch (error) {
    console.error('restoreMenu error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/settings
const getSettings = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const [settingsR, cafeR] = await Promise.all([
      db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1', [cafeId]),
    ]);
    const cafeRow = cafeR.rows[0] || {};
    const settingsData = { ...(settingsR.rows[0]?.data || {}) };
    const receiptName = cafeRow.receipt_name !== undefined && cafeRow.receipt_name !== null
      ? cafeRow.receipt_name
      : (settingsData.receiptName || null);
    settingsData.receiptName = receiptName;
    settingsData.cafeName = cafeRow.cafe_name || settingsData.restaurantName || 'ZAVERO';
    return res.json({ success: true, settings: settingsData, receiptName });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/cafe/receipt-name
const updateReceiptName = async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase();
    // PERMISSION: Faqat CAFE_OWNER (admin, owner, director) o'zgartira olsin
    if (role !== 'admin' && role !== 'owner' && role !== 'director') {
      return res.status(403).json({
        success: false,
        message: "Faqat kafe egasi (admin) chek nomini o'zgartirishi mumkin. Xodimlarga ruxsat berilmagan.",
      });
    }

    const cafeId = req.user.cafeId;
    let { receiptName } = req.body;
    if (receiptName !== undefined && receiptName !== null) {
      receiptName = receiptName.toString().trim();
      if (receiptName.length === 0) receiptName = null;
    } else {
      receiptName = null;
    }

    // 1. Update cafes table column receipt_name
    await db.query('UPDATE cafes SET receipt_name = $1 WHERE cafe_id = $2', [receiptName, cafeId]);

    // 2. Keep settings JSON in sync
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const merged = { ...(current.rows[0]?.data || {}), receiptName };
    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged, receiptName });

    return res.json({
      success: true,
      message: "Chek nomi muvaffaqiyatli saqlandi!",
      receiptName,
      settings: merged,
    });
  } catch (error) {
    console.error('updateReceiptName error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/settings (merge)
const saveSettings = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const role = (req.user?.role || '').toLowerCase();
    const incoming = req.body || {};

    // If incoming contains receiptName, verify permission:
    if (incoming.receiptName !== undefined) {
      if (role !== 'admin' && role !== 'owner' && role !== 'director') {
        delete incoming.receiptName;
      } else {
        const rName = incoming.receiptName && incoming.receiptName.toString().trim().length > 0
          ? incoming.receiptName.toString().trim()
          : null;
        incoming.receiptName = rName;
        await db.query('UPDATE cafes SET receipt_name = $1 WHERE cafe_id = $2', [rName, cafeId]);
      }
    }

    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const merged = { ...(current.rows[0]?.data || {}), ...incoming };

    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged });
    if (merged.promoBanners) {
      notifyCafe(cafeId, 'BANNERS_UPDATED', { banners: merged.promoBanners });
    }

    return res.json({ success: true, settings: merged });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/cafe/report-issue
const reportIssue = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { title, description, phone } = req.body;
    const user = req.user;

    const cafeRes = await db.query('SELECT cafe_name FROM cafes WHERE cafe_id = $1', [cafeId]);
    const cafeName = cafeRes.rows[0]?.cafe_name || cafeId;

    const result = await db.query(
      `INSERT INTO support_tickets (cafe_id, cafe_name, user_id, user_name, phone, title, description, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending') RETURNING *`,
      [cafeId, cafeName, user.id, user.name || user.username, phone || '', title || 'Muammo xabari', description || '']
    );

    const ticket = result.rows[0];

    const { notifyDirector } = require('../socket/socketHandler');
    if (notifyDirector) {
      notifyDirector('SUPPORT_ISSUE_REPORTED', { ticket });
    }

    return res.json({ success: true, message: 'Xabaringiz Director boshqaruviga muvaffaqiyatli yuborildi.', ticket });
  } catch (error) {
    console.error('reportIssue error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/cafe/maintenance-status
const getMaintenanceStatus = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const result = await db.query('SELECT is_under_maintenance FROM cafes WHERE cafe_id = $1', [cafeId]);
    const isUnderMaintenance = result.rows[0]?.is_under_maintenance || false;
    return res.json({ success: true, isUnderMaintenance });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/cafe/banners
const getBanners = async (req, res) => {
  try {
    const cafeId = (req.user && getTenantCafeId(req)) || req.query?.cafeId;
    if (!cafeId) return res.json({ success: true, banners: [] });
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settings = current.rows[0]?.data || {};
    return res.json({ success: true, banners: settings.promoBanners || [] });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/cafe/banners
const addBanner = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) return res.status(401).json({ success: false, message: 'Avtorizatsiya talab etiladi' });
    const { imageUrl, tag, title, description } = req.body;
    if (!imageUrl && !title) {
      return res.status(400).json({ success: false, message: 'Rasm yoki sarlavha kiritilishi shart' });
    }
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settings = current.rows[0]?.data || {};
    const banners = Array.isArray(settings.promoBanners) ? [...settings.promoBanners] : [];
    const newBanner = {
      id: 'bnr_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      imageUrl: imageUrl || '',
      tag: tag || 'Zavero Maxsus Taklifi',
      title: title || '',
      description: description || '',
      createdAt: new Date().toISOString(),
    };
    banners.unshift(newBanner);
    const merged = { ...settings, promoBanners: banners };

    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'BANNERS_UPDATED', { banners });
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged });

    return res.json({ success: true, banner: newBanner, banners });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/cafe/banners/:id
const deleteBanner = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) return res.status(401).json({ success: false, message: 'Avtorizatsiya talab etiladi' });
    const { id } = req.params;
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settings = current.rows[0]?.data || {};
    let banners = Array.isArray(settings.promoBanners) ? [...settings.promoBanners] : [];
    banners = banners.filter(b => b.id !== id);
    const merged = { ...settings, promoBanners: banners };

    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'BANNERS_UPDATED', { banners });
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged });

    return res.json({ success: true, banners });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/cafe/banners/:id
const updateBanner = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) return res.status(401).json({ success: false, message: 'Avtorizatsiya talab etiladi' });
    const { id } = req.params;
    const { imageUrl, tag, title, description } = req.body;
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settings = current.rows[0]?.data || {};
    let banners = Array.isArray(settings.promoBanners) ? [...settings.promoBanners] : [];
    const index = banners.findIndex(b => b.id === id);
    if (index === -1) {
      return res.status(404).json({ success: false, message: 'Banner topilmadi' });
    }
    banners[index] = {
      ...banners[index],
      imageUrl: imageUrl !== undefined ? imageUrl : banners[index].imageUrl,
      tag: tag !== undefined ? tag : banners[index].tag,
      title: title !== undefined ? title : banners[index].title,
      description: description !== undefined ? description : banners[index].description,
      updatedAt: new Date().toISOString(),
    };
    const merged = { ...settings, promoBanners: banners };

    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'BANNERS_UPDATED', { banners });
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged });

    return res.json({ success: true, banner: banners[index], banners });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/cafe/banners — batch save all promo banners
const saveBanners = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) return res.status(401).json({ success: false, message: 'Avtorizatsiya talab etiladi' });
    const { banners } = req.body;
    if (!Array.isArray(banners)) {
      return res.status(400).json({ success: false, message: 'Banners ro‘yxati (array) talab etiladi' });
    }
    const current = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    const settings = current.rows[0]?.data || {};
    const merged = { ...settings, promoBanners: banners };

    await db.query(
      `INSERT INTO settings (cafe_id, data, updated_at) VALUES ($1,$2,CURRENT_TIMESTAMP)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2, updated_at = CURRENT_TIMESTAMP`,
      [cafeId, JSON.stringify(merged)]
    );

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'BANNERS_UPDATED', { banners });
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { settings: merged });

    return res.json({ success: true, banners });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/cafe/backup — full cafe data backup JSON
const getBackupData = async (req, res) => {
  try {
    const cafeId = getTenantCafeId(req);
    if (!cafeId) return res.status(401).json({ success: false, message: 'Avtorizatsiya talab etiladi' });

    const [cafeR, settingsR, catR, prodR, hallR, tableR, recR, repR] = await Promise.all([
      db.query('SELECT cafe_id, cafe_name, receipt_name, owner_name, owner_email FROM cafes WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]),
      db.query('SELECT * FROM categories WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM products WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM halls WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM restaurant_tables WHERE cafe_id = $1 ORDER BY id ASC', [cafeId]),
      db.query('SELECT * FROM receipts WHERE cafe_id = $1 ORDER BY date DESC LIMIT 500', [cafeId]),
      db.query('SELECT * FROM reports WHERE cafe_id = $1 ORDER BY date_id DESC LIMIT 365', [cafeId]),
    ]);

    const backup = {
      version: '1.0',
      exportedAt: new Date().toISOString(),
      cafe: cafeR.rows[0] || {},
      settings: settingsR.rows[0]?.data || {},
      categories: catR.rows,
      products: prodR.rows,
      halls: hallR.rows,
      tables: tableR.rows,
      receipts: recR.rows,
      reports: repR.rows,
    };

    return res.json({ success: true, backup });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getFullCafeData,
  restoreMenu,
  getSettings,
  saveSettings,
  updateReceiptName,
  reportIssue,
  getMaintenanceStatus,
  getBanners,
  addBanner,
  updateBanner,
  deleteBanner,
  saveBanners,
  getBackupData,
};



