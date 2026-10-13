const bcrypt = require('bcryptjs');
const { randomUUID } = require('crypto');
const db = require('../config/db');
const { seedNewCafe, seedDefaultHallsAndTables } = require('../utils/seedCafe');
const { invalidateCafeCache } = require('../middleware/authMiddleware');

const slugifyCafe = (name) => {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '')
    .slice(0, 40);
};

// GET /api/director/metrics
const getMetrics = async (req, res) => {
  try {
    const cafeStatsRes = await db.query(`
      SELECT 
        COUNT(*) FILTER (WHERE cafe_id != 'zavero') AS total_cafes,
        COUNT(*) FILTER (WHERE cafe_id != 'zavero' AND status = 'active' AND (end_date IS NULL OR end_date >= CURRENT_TIMESTAMP)) AS active_cafes,
        COUNT(*) FILTER (WHERE cafe_id != 'zavero' AND status = 'blocked') AS blocked_cafes,
        COUNT(*) FILTER (WHERE cafe_id != 'zavero' AND status != 'blocked' AND end_date < CURRENT_TIMESTAMP) AS expired_cafes
      FROM cafes
    `);

    const userStatsRes = await db.query(`
      SELECT 
        COUNT(*) FILTER (WHERE role != 'director') AS total_users,
        COUNT(*) FILTER (WHERE role IN ('worker', 'cashier', 'waiter', 'courier')) AS total_workers,
        COUNT(*) FILTER (WHERE role = 'admin') AS total_owners
      FROM users
    `);

    const deviceStatsRes = await db.query(`
      SELECT COUNT(*) AS active_devices FROM devices WHERE is_active = true
    `);

    const orderStatsRes = await db.query(`
      SELECT 
        (SELECT COUNT(*) FROM receipts) + (SELECT COUNT(*) FROM customer_orders) AS total_orders,
        (SELECT COUNT(*) FROM receipts WHERE date >= CURRENT_DATE) + (SELECT COUNT(*) FROM customer_orders WHERE date >= CURRENT_DATE) AS today_orders,
        (SELECT COALESCE(SUM(total), 0) FROM receipts WHERE date >= CURRENT_DATE) AS today_revenue,
        (SELECT COALESCE(SUM(total), 0) FROM receipts) AS total_revenue
    `);

    const cStats = cafeStatsRes.rows[0];
    const uStats = userStatsRes.rows[0];
    const dStats = deviceStatsRes.rows[0];
    const oStats = orderStatsRes.rows[0];

    return res.json({
      success: true,
      metrics: {
        totalCafes: parseInt(cStats.total_cafes || 0),
        activeCafes: parseInt(cStats.active_cafes || 0),
        blockedCafes: parseInt(cStats.blocked_cafes || 0),
        expiredCafes: parseInt(cStats.expired_cafes || 0),
        totalUsers: parseInt(uStats.total_users || 0),
        totalWorkers: parseInt(uStats.total_workers || 0),
        totalOwners: parseInt(uStats.total_owners || 0),
        activeDevices: parseInt(dStats.active_devices || 0),
        totalOrders: parseInt(oStats.total_orders || 0),
        todayOrders: parseInt(oStats.today_orders || 0),
        todayRevenue: parseFloat(oStats.today_revenue || 0),
        totalRevenue: parseFloat(oStats.total_revenue || 0),
      },
    });
  } catch (error) {
    console.error('getMetrics error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// GET /api/director/cafes
const listCafes = async (req, res) => {
  try {
    const { q, status } = req.query;

    const result = await db.query(`
      SELECT 
        c.*,
        (SELECT COUNT(*) FROM users u WHERE u.cafe_id = c.cafe_id) AS users_count,
        (SELECT COUNT(*) FROM restaurant_tables t WHERE t.cafe_id = c.cafe_id) AS tables_count,
        (SELECT COUNT(*) FROM receipts r WHERE r.cafe_id = c.cafe_id) AS receipts_count,
        (SELECT COUNT(*) FROM devices d WHERE d.cafe_id = c.cafe_id AND d.is_active = true) AS active_devices_count
      FROM cafes c
      WHERE c.cafe_id != 'zavero'
      ORDER BY c.created_at DESC
    `);

    const now = new Date();

    let cafes = result.rows.map((row) => {
      const isBlocked = row.status === 'blocked';
      const isExpired = row.end_date ? new Date(row.end_date) < now : false;
      let computedStatus = 'active';
      if (isBlocked) computedStatus = 'blocked';
      else if (isExpired) computedStatus = 'expired';

      return {
        id: row.cafe_id,
        cafeId: row.cafe_id,
        name: row.cafe_name,
        receiptName: row.receipt_name || row.cafe_name,
        ownerName: row.owner_name,
        ownerPhone: row.owner_phone,
        ownerEmail: row.owner_email,
        status: computedStatus,
        rawStatus: row.status,
        isBlocked,
        isExpired,
        startDate: row.start_date,
        endDate: row.end_date,
        usersCount: parseInt(row.users_count || 0),
        tablesCount: parseInt(row.tables_count || 0),
        receiptsCount: parseInt(row.receipts_count || 0),
        activeDevicesCount: parseInt(row.active_devices_count || 0),
        createdAt: row.created_at,
      };
    });

    if (q && q.trim()) {
      const term = q.trim().toLowerCase();
      cafes = cafes.filter((c) =>
        (c.name && c.name.toLowerCase().includes(term)) ||
        (c.cafeId && c.cafeId.toLowerCase().includes(term)) ||
        (c.ownerName && c.ownerName.toLowerCase().includes(term)) ||
        (c.ownerEmail && c.ownerEmail.toLowerCase().includes(term)) ||
        (c.ownerPhone && c.ownerPhone.includes(term))
      );
    }

    if (status && status !== 'all') {
      cafes = cafes.filter((c) => c.status === status);
    }

    return res.json({ success: true, cafes });
  } catch (error) {
    console.error('listCafes error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// GET /api/director/cafes/:cafeId
const getCafeDetail = async (req, res) => {
  try {
    const { cafeId } = req.params;

    const cafeRes = await db.query(
      `SELECT c.*,
              (SELECT COUNT(*) FROM restaurant_tables t WHERE t.cafe_id = c.cafe_id) AS tables_count,
              (SELECT COUNT(*) FROM receipts r WHERE r.cafe_id = c.cafe_id) AS receipts_count,
              (SELECT COALESCE(SUM(r.total), 0) FROM receipts r WHERE r.cafe_id = c.cafe_id) AS total_revenue
       FROM cafes c WHERE c.cafe_id = $1`,
      [cafeId]
    );

    if (cafeRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Cafe topilmadi.' });
    }

    const row = cafeRes.rows[0];
    const now = new Date();
    const isBlocked = row.status === 'blocked';
    const isExpired = row.end_date ? new Date(row.end_date) < now : false;

    // Users
    const usersRes = await db.query(
      `SELECT id, username, name, surname, phone, email, role, is_active, created_at
       FROM users WHERE cafe_id = $1 ORDER BY role, name`,
      [cafeId]
    );

    // Devices
    const devicesRes = await db.query(
      `SELECT d.*, u.name as user_name
       FROM devices d
       LEFT JOIN users u ON d.user_id = u.id
       WHERE d.cafe_id = $1 ORDER BY d.last_seen DESC`,
      [cafeId]
    );

    // Subscription Events
    const eventsRes = await db.query(
      `SELECT * FROM subscription_events WHERE cafe_id = $1 ORDER BY created_at DESC LIMIT 30`,
      [cafeId]
    );

    return res.json({
      success: true,
      cafe: {
        id: row.cafe_id,
        cafeId: row.cafe_id,
        name: row.cafe_name,
        receiptName: row.receipt_name || row.cafe_name,
        ownerName: row.owner_name,
        ownerPhone: row.owner_phone,
        ownerEmail: row.owner_email,
        status: isBlocked ? 'blocked' : (isExpired ? 'expired' : 'active'),
        rawStatus: row.status,
        isBlocked,
        isExpired,
        startDate: row.start_date,
        endDate: row.end_date,
        tablesCount: parseInt(row.tables_count || 0),
        receiptsCount: parseInt(row.receipts_count || 0),
        totalRevenue: parseFloat(row.total_revenue || 0),
        createdAt: row.created_at,
        users: usersRes.rows,
        devices: devicesRes.rows,
        events: eventsRes.rows,
      },
    });
  } catch (error) {
    console.error('getCafeDetail error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// POST /api/director/cafes
const createCafe = async (req, res) => {
  try {
    const { cafeId, cafeName, receiptName, ownerName, ownerPhone, ownerEmail, ownerPassword, durationDays } = req.body;

    if (!cafeName || !cafeName.trim()) {
      return res.status(400).json({ success: false, message: 'Cafe nomi kiritilishi shart.' });
    }
    if (!ownerEmail || !ownerEmail.trim()) {
      return res.status(400).json({ success: false, message: 'Cafe egasi emaili kiritilishi shart.' });
    }

    const cleanEmail = ownerEmail.trim().toLowerCase();
    if (!cleanEmail.endsWith('@cafe.uz')) {
      return res.status(400).json({
        success: false,
        message: "Cafe egasi emaili qat'iy ravishda '@cafe.uz' bilan tugashi shart (masalan: samarqand@cafe.uz)",
      });
    }

    if (!ownerPassword || !/^\d{4,}$/.test(ownerPassword.trim())) {
      return res.status(400).json({
        success: false,
        message: "Parol kamida 4 ta raqamdan iborat bo'lishi kerak (faqat raqam).",
      });
    }

    // Determine unique cafe_id: Always use RFC4122 UUID for absolute multi-tenant uniqueness
    let generatedSlug = (cafeId && /^[0-9a-fA-F-]{36}$/.test(cafeId.trim()))
      ? cafeId.trim().toLowerCase()
      : randomUUID();

    // Ensure uniqueness
    const existingCafe = await db.query('SELECT cafe_id FROM cafes WHERE cafe_id = $1', [generatedSlug]);
    if (existingCafe.rows.length > 0) {
      generatedSlug = randomUUID();
    }

    // Check user uniqueness
    const existingUser = await db.query(
      'SELECT id FROM users WHERE LOWER(username) = $1 OR LOWER(email) = $1',
      [cleanEmail]
    );
    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: "Ushbu email bilan foydalanuvchi allaqachon ro'yxatdan o'tgan.",
      });
    }

    const days = parseInt(durationDays || 30);
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(ownerPassword.trim(), salt);

    await db.withTransaction(async (client) => {
      // 1. Insert cafe
      await client.query(
        `INSERT INTO cafes (cafe_id, cafe_name, receipt_name, owner_name, owner_phone, owner_email, status, start_date, end_date)
         VALUES ($1, $2, $3, $4, $5, $6, 'active', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + ($7 || ' days')::INTERVAL)`,
        [
          generatedSlug,
          cafeName.trim(),
          (receiptName && receiptName.trim()) ? receiptName.trim() : cafeName.trim(),
          ownerName || '',
          ownerPhone || '',
          cleanEmail,
          days,
        ]
      );

      // 2. Initialize minimal blank settings (ZERO products, ZERO tables, ZERO categories, ZERO halls)
      const { address } = req.body;
      await client.query(
        `INSERT INTO settings (cafe_id, data)
         VALUES ($1, $2)
         ON CONFLICT (cafe_id) DO NOTHING`,
        [
          generatedSlug,
          JSON.stringify({
            restaurantName: cafeName.trim(),
            receiptName: (receiptName && receiptName.trim()) ? receiptName.trim() : cafeName.trim(),
            restaurantAddress: address ? address.trim() : '',
            restaurantPhone: ownerPhone ? ownerPhone.trim() : '',
          }),
        ]
      );

      // 3. Create owner user
      const userRes = await client.query(
        `INSERT INTO users (cafe_id, username, password_hash, name, phone, email, role, is_active, must_change_password)
         VALUES ($1, $2, $3, $4, $5, $6, 'admin', true, false) RETURNING id`,
        [generatedSlug, cleanEmail, passwordHash, ownerName || cafeName.trim(), ownerPhone || '', cleanEmail]
      );

      // 4. Record subscription
      await client.query(
        `INSERT INTO subscriptions (cafe_id, user_id, start_date, end_date, status, payment_status)
         VALUES ($1, $2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + ($3 || ' days')::INTERVAL, 'active', 'paid')`,
        [generatedSlug, userRes.rows[0].id, days]
      );

      // 5. Record event
      await client.query(
        `INSERT INTO subscription_events (cafe_id, user_id, event_type, reason, created_by)
         VALUES ($1, $2, 'create', $3, 'ZAVERO Director')`,
        [generatedSlug, userRes.rows[0].id, `Cafe ochildi (${days} kunlik obuna)`]
      );

      // 6. Audit log
      await client.query(
        `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
         VALUES ($1, 'director', $2, 'create_cafe', 'cafe', $2, $3)`,
        [req.user.id, generatedSlug, JSON.stringify({ cafeName, ownerEmail, days })]
      );
    });

    invalidateCafeCache(generatedSlug);

    return res.status(201).json({
      success: true,
      message: "Yangi cafe muvaffaqiyatli yaratildi!",
      cafeId: generatedSlug,
    });
  } catch (error) {
    console.error('createCafe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// POST /api/director/users
const createUser = async (req, res) => {
  try {
    const { cafeId, name, surname, phone, role, email, password } = req.body;

    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'Cafe tanlanishi shart.' });
    }
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Foydalanuvchi ismi kiritilishi shart.' });
    }
    if (!email || !email.trim()) {
      return res.status(400).json({ success: false, message: 'Email kiritilishi shart.' });
    }
    if (!password || !/^\d{4,}$/.test(password.trim())) {
      return res.status(400).json({
        success: false,
        message: "Parol kamida 4 ta raqamdan iborat bo'lishi kerak (faqat raqam).",
      });
    }

    const cleanEmail = email.trim().toLowerCase();
    const targetRole = (role || 'worker').toLowerCase();

    // Enforce role-specific domain rules:
    // Director: director@zavero.uz
    // Cafe: <nom>@cafe.uz
    // Ishchi: <nom>@ishchi.uz
    // Mijoz: <nom>@mijoz.uz
    if (targetRole === 'admin' && !cleanEmail.endsWith('@cafe.uz')) {
      return res.status(400).json({
        success: false,
        message: "Cafe egasi roli uchun email formati '@cafe.uz' bilan tugashi shart (masalan: cafe@cafe.uz).",
      });
    } else if ((targetRole === 'worker' || targetRole === 'cashier' || targetRole === 'waiter') && !cleanEmail.endsWith('@ishchi.uz')) {
      return res.status(400).json({
        success: false,
        message: "Ishchi roli uchun email formati '@ishchi.uz' bilan tugashi shart (masalan: ali@ishchi.uz).",
      });
    } else if (targetRole === 'customer' && !cleanEmail.endsWith('@mijoz.uz')) {
      return res.status(400).json({
        success: false,
        message: "Mijoz roli uchun email formati '@mijoz.uz' bilan tugashi shart (masalan: client@mijoz.uz).",
      });
    }

    // Check duplicate
    const checkUser = await db.query(
      'SELECT id FROM users WHERE LOWER(username) = $1 OR LOWER(email) = $1',
      [cleanEmail]
    );
    if (checkUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        message: 'Ushbu email bilan foydalanuvchi allaqachon mavjud.',
      });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password.trim(), salt);

    const userRes = await db.query(
      `INSERT INTO users (cafe_id, username, password_hash, name, surname, phone, email, role, is_active, must_change_password)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, false) RETURNING id, username, name, email, role`,
      [cafeId, cleanEmail, passwordHash, name.trim(), surname || '', phone || '', cleanEmail, targetRole]
    );

    // Audit log
    await db.query(
      `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
       VALUES ($1, 'director', $2, 'create_user', 'user', $3, $4)`,
      [req.user.id, cafeId, String(userRes.rows[0].id), JSON.stringify({ email: cleanEmail, role: targetRole })]
    );

    return res.status(201).json({
      success: true,
      message: 'Foydalanuvchi muvaffaqiyatli yaratildi!',
      user: userRes.rows[0],
    });
  } catch (error) {
    console.error('createUser error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// POST /api/director/cafes/:cafeId/block
const blockCafe = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const { reason } = req.body;

    if (cafeId === 'zavero') {
      return res.status(400).json({ success: false, message: 'Tizim cafesi bloklanishi mumkin emas.' });
    }

    await db.query(`UPDATE cafes SET status = 'blocked' WHERE cafe_id = $1`, [cafeId]);

    await db.query(
      `INSERT INTO subscription_events (cafe_id, event_type, reason, created_by)
       VALUES ($1, 'block', $2, 'ZAVERO Director')`,
      [cafeId, reason || 'Director tomonidan bloklandi']
    );

    await db.query(
      `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
       VALUES ($1, 'director', $2, 'block_cafe', 'cafe', $2, $3)`,
      [req.user.id, cafeId, JSON.stringify({ reason })]
    );

    invalidateCafeCache(cafeId);

    return res.json({ success: true, message: 'Cafe muvaffaqiyatli bloklandi.' });
  } catch (error) {
    console.error('blockCafe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// POST /api/director/cafes/:cafeId/unblock
const unblockCafe = async (req, res) => {
  try {
    const { cafeId } = req.params;

    await db.query(`UPDATE cafes SET status = 'active' WHERE cafe_id = $1`, [cafeId]);

    await db.query(
      `INSERT INTO subscription_events (cafe_id, event_type, reason, created_by)
       VALUES ($1, 'unblock', 'Director tomonidan blokdan chiqarildi', 'ZAVERO Director')`,
      [cafeId]
    );

    await db.query(
      `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id)
       VALUES ($1, 'director', $2, 'unblock_cafe', 'cafe', $2)`,
      [req.user.id, cafeId]
    );

    invalidateCafeCache(cafeId);

    return res.json({ success: true, message: 'Cafe blokdan muvaffaqiyatli chiqarildi.' });
  } catch (error) {
    console.error('unblockCafe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// POST /api/director/cafes/:cafeId/extend
const extendSubscription = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const { days, newEndDate } = req.body;

    const cafeRes = await db.query('SELECT * FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Cafe topilmadi.' });
    }

    const currentCafe = cafeRes.rows[0];
    const now = new Date();
    let calculatedEndDate;

    if (newEndDate) {
      calculatedEndDate = new Date(newEndDate);
    } else {
      const daysToAdd = parseInt(days || 30);
      if (isNaN(daysToAdd) || daysToAdd <= 0) {
        return res.status(400).json({ success: false, message: 'Yaroqli kunlar soni kiritilishi shart.' });
      }

      // If current end_date is in the future, extend from current end_date. Otherwise extend from now.
      const baseDate = currentCafe.end_date && new Date(currentCafe.end_date) > now
        ? new Date(currentCafe.end_date)
        : now;

      calculatedEndDate = new Date(baseDate.getTime() + daysToAdd * 24 * 60 * 60 * 1000);
    }

    await db.query(
      `UPDATE cafes SET end_date = $1, status = 'active' WHERE cafe_id = $2`,
      [calculatedEndDate.toISOString(), cafeId]
    );

    await db.query(
      `INSERT INTO subscription_events (cafe_id, event_type, reason, created_by)
       VALUES ($1, 'extend', $2, 'ZAVERO Director')`,
      [cafeId, `Obuna muddati uzaytirildi: ${calculatedEndDate.toISOString().slice(0, 10)} gacha`]
    );

    await db.query(
      `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
       VALUES ($1, 'director', $2, 'extend_subscription', 'cafe', $2, $3)`,
      [req.user.id, cafeId, JSON.stringify({ days, newEndDate: calculatedEndDate.toISOString() })]
    );

    invalidateCafeCache(cafeId);

    return res.json({
      success: true,
      message: `Obuna muddati muvaffaqiyatli uzaytirildi! Yangi muddat: ${calculatedEndDate.toISOString().slice(0, 10)}`,
      newEndDate: calculatedEndDate.toISOString(),
    });
  } catch (error) {
    console.error('extendSubscription error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// GET /api/director/audit-logs
const getAuditLogs = async (req, res) => {
  try {
    const limit = parseInt(req.query.limit || 100);
    const offset = parseInt(req.query.offset || 0);

    const result = await db.query(
      `SELECT a.*, u.name as actor_name, c.cafe_name
       FROM audit_logs a
       LEFT JOIN users u ON a.actor_id = u.id
       LEFT JOIN cafes c ON a.cafe_id = c.cafe_id
       ORDER BY a.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    return res.json({ success: true, logs: result.rows });
  } catch (error) {
    console.error('getAuditLogs error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// PUT /api/director/users/:userId/status
const toggleUserActive = async (req, res) => {
  try {
    const { userId } = req.params;
    const { isActive } = req.body;

    await db.query('UPDATE users SET is_active = $1 WHERE id = $2', [!!isActive, userId]);

    return res.json({ success: true, message: 'Foydalanuvchi holati yangilandi.' });
  } catch (error) {
    console.error('toggleUserActive error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// PUT /api/director/cafes/:cafeId
const updateCafe = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const {
      cafeName,
      receiptName,
      ownerName,
      ownerPhone,
      ownerEmail,
      ownerPassword,
      startDate,
      endDate,
      status,
      address,
    } = req.body;

    if (cafeId === 'zavero') {
      return res.status(400).json({ success: false, message: 'Tizim kafesi o\'zgartirilishi mumkin emas.' });
    }

    const check = await db.query('SELECT * FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (check.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Bunday kafe topilmadi.' });
    }
    const currentCafe = check.rows[0];

    const updatedName = cafeName ? cafeName.trim() : currentCafe.cafe_name;
    const updatedReceipt = receiptName ? receiptName.trim() : (currentCafe.receipt_name || updatedName);
    const updatedOwner = ownerName !== undefined ? ownerName.trim() : currentCafe.owner_name;
    const updatedPhone = ownerPhone !== undefined ? ownerPhone.trim() : currentCafe.owner_phone;
    const updatedEmail = ownerEmail ? ownerEmail.trim().toLowerCase() : currentCafe.owner_email;
    const updatedStatus = status || currentCafe.status;
    const updatedStart = startDate || currentCafe.start_date;
    const updatedEnd = endDate || currentCafe.end_date;

    await db.withTransaction(async (client) => {
      // 1. Update cafe
      await client.query(
        `UPDATE cafes 
         SET cafe_name = $1, receipt_name = $2, owner_name = $3, owner_phone = $4, owner_email = $5,
             status = $6, start_date = $7, end_date = $8
         WHERE cafe_id = $9`,
        [updatedName, updatedReceipt, updatedOwner, updatedPhone, updatedEmail, updatedStatus, updatedStart, updatedEnd, cafeId]
      );

      // 2. Update settings address/phone if present
      if (address !== undefined || ownerPhone !== undefined) {
        const settingsRes = await client.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
        let data = {};
        if (settingsRes.rows.length > 0 && settingsRes.rows[0].data) {
          data = typeof settingsRes.rows[0].data === 'string' ? JSON.parse(settingsRes.rows[0].data) : settingsRes.rows[0].data;
        }
        if (address !== undefined) data.restaurantAddress = address.trim();
        if (ownerPhone !== undefined) data.restaurantPhone = ownerPhone.trim();
        data.restaurantName = updatedName;
        data.receiptName = updatedReceipt;

        await client.query(
          `INSERT INTO settings (cafe_id, data) VALUES ($1, $2)
           ON CONFLICT (cafe_id) DO UPDATE SET data = $2`,
          [cafeId, JSON.stringify(data)]
        );
      }

      // 3. Update admin user credentials if requested
      if (ownerPassword && ownerPassword.trim()) {
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(ownerPassword.trim(), salt);
        await client.query(
          `UPDATE users 
           SET password_hash = $1, name = $2, phone = $3, email = $4, updated_at = CURRENT_TIMESTAMP
           WHERE cafe_id = $5 AND role = 'admin'`,
          [passwordHash, updatedOwner || updatedName, updatedPhone, updatedEmail, cafeId]
        );
      } else if (ownerEmail || ownerName || ownerPhone) {
        await client.query(
          `UPDATE users 
           SET name = $1, phone = $2, email = $3, updated_at = CURRENT_TIMESTAMP
           WHERE cafe_id = $4 AND role = 'admin'`,
          [updatedOwner || updatedName, updatedPhone, updatedEmail, cafeId]
        );
      }

      // 4. Audit log
      await client.query(
        `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
         VALUES ($1, 'director', $2, 'update_cafe', 'cafe', $2, $3)`,
        [req.user.id, cafeId, JSON.stringify({ cafeName: updatedName, updatedStatus })]
      );
    });

    invalidateCafeCache(cafeId);

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { cafeId });

    return res.json({ success: true, message: 'Kafe ma\'lumotlari muvaffaqiyatli saqlandi.' });
  } catch (error) {
    console.error('updateCafe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// DELETE /api/director/cafes/:cafeId
const deleteCafe = async (req, res) => {
  try {
    const cafeId = req.params.cafeId || req.body?.cafeId || req.query?.cafeId;
    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'Kafe ID ko\'rsatilmadi.' });
    }
    if (cafeId === 'zavero') {
      return res.status(400).json({ success: false, message: 'Tizim kafesi o\'chirilishi mumkin emas.' });
    }

    const check = await db.query('SELECT cafe_name FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (check.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Bunday kafe topilmadi.' });
    }
    const cafeName = check.rows[0].cafe_name;

    await db.withTransaction(async (client) => {
      // Cascading safe cleanup across all tables
      await client.query('DELETE FROM table_orders WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM customer_orders WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM receipts WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM reports WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM activity_logs WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM images WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM customers WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM restaurant_tables WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM halls WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM products WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM categories WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM devices WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM notifications WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM employees WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM subscriptions WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM subscription_events WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM audit_logs WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM users WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM settings WHERE cafe_id = $1', [cafeId]);
      await client.query('DELETE FROM cafes WHERE cafe_id = $1', [cafeId]);

      await client.query(
        `INSERT INTO audit_logs (actor_id, actor_role, cafe_id, action, target_type, target_id, metadata)
         VALUES ($1, 'director', 'zavero', 'delete_cafe', 'cafe', $2, $3)`,
        [req.user.id, cafeId, JSON.stringify({ cafeName })]
      );
    });

    invalidateCafeCache(cafeId);

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'CAFE_DELETED', { cafeId });

    return res.json({ success: true, message: `"${cafeName}" kafesi muvaffaqiyatli o'chirildi.` });
  } catch (error) {
    console.error('deleteCafe error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// GET /api/director/cafes/:cafeId/overview
const getCafeOverview = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const cafeRes = await db.query('SELECT * FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Cafe topilmadi.' });
    }
    const cafe = cafeRes.rows[0];

    const statsRes = await db.query(`
      SELECT 
        (SELECT COUNT(*) FROM products WHERE cafe_id = $1) AS products_count,
        (SELECT COUNT(*) FROM categories WHERE cafe_id = $1) AS categories_count,
        (SELECT COUNT(*) FROM restaurant_tables WHERE cafe_id = $1) AS tables_count,
        (SELECT COUNT(*) FROM restaurant_tables WHERE cafe_id = $1 AND status != 'free') AS busy_tables_count,
        (SELECT COUNT(*) FROM users WHERE cafe_id = $1) AS staff_count,
        (SELECT COUNT(*) FROM receipts WHERE cafe_id = $1 AND date >= CURRENT_DATE) AS today_receipts_count,
        (SELECT COALESCE(SUM(total), 0) FROM receipts WHERE cafe_id = $1 AND date >= CURRENT_DATE) AS today_revenue,
        (SELECT COALESCE(SUM(total), 0) FROM receipts WHERE cafe_id = $1) AS total_revenue
    `, [cafeId]);

    const s = statsRes.rows[0];

    return res.json({
      success: true,
      cafe,
      stats: {
        productsCount: parseInt(s.products_count || 0),
        categoriesCount: parseInt(s.categories_count || 0),
        tablesCount: parseInt(s.tables_count || 0),
        busyTablesCount: parseInt(s.busy_tables_count || 0),
        staffCount: parseInt(s.staff_count || 0),
        todayReceiptsCount: parseInt(s.today_receipts_count || 0),
        todayRevenue: parseFloat(s.today_revenue || 0),
        totalRevenue: parseFloat(s.total_revenue || 0),
      }
    });
  } catch (error) {
    console.error('getCafeOverview error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

// GET /api/director/support-tickets
const listSupportTickets = async (req, res) => {
  try {
    const result = await db.query(`
      SELECT st.*, c.cafe_name, c.is_under_maintenance 
      FROM support_tickets st
      LEFT JOIN cafes c ON c.cafe_id = st.cafe_id
      ORDER BY 
        CASE WHEN st.status = 'pending' THEN 1 WHEN st.status = 'in_progress' THEN 2 ELSE 3 END,
        st.created_at DESC
      LIMIT 100
    `);
    res.json({ success: true, tickets: result.rows });
  } catch (error) {
    console.error('listSupportTickets error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/director/support-tickets/:ticketId/start-fix
const startFixTicket = async (req, res) => {
  try {
    const { ticketId } = req.params;
    const ticketRes = await db.query('SELECT * FROM support_tickets WHERE id = $1', [ticketId]);
    if (ticketRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Murojaat topilmadi.' });
    }
    const ticket = ticketRes.rows[0];
    const cafeId = ticket.cafe_id;

    await db.query('UPDATE cafes SET is_under_maintenance = true WHERE cafe_id = $1', [cafeId]);
    await db.query("UPDATE support_tickets SET status = 'in_progress' WHERE id = $1", [ticketId]);

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'CAFE_MAINTENANCE_STATUS', { cafeId, isUnderMaintenance: true });

    res.json({ success: true, message: 'Muammoni tuzatish boshlandi. Kafe tizimi vaqtincha to\'xtatildi.' });
  } catch (error) {
    console.error('startFixTicket error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/director/support-tickets/:ticketId/resolve
const resolveTicket = async (req, res) => {
  try {
    const { ticketId } = req.params;
    const ticketRes = await db.query('SELECT * FROM support_tickets WHERE id = $1', [ticketId]);
    if (ticketRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Murojaat topilmadi.' });
    }
    const ticket = ticketRes.rows[0];
    const cafeId = ticket.cafe_id;

    await db.query('UPDATE cafes SET is_under_maintenance = false WHERE cafe_id = $1', [cafeId]);
    await db.query("UPDATE support_tickets SET status = 'resolved', resolved_at = CURRENT_TIMESTAMP WHERE id = $1", [ticketId]);

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'CAFE_MAINTENANCE_STATUS', { cafeId, isUnderMaintenance: false });

    res.json({ success: true, message: 'Muammo hal qilindi. Kafe ilovasi to\'liq qayta ishga tushirildi.' });
  } catch (error) {
    console.error('resolveTicket error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/director/cafes/:cafeId/maintenance
const toggleMaintenance = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const { isUnderMaintenance } = req.body;
    await db.query('UPDATE cafes SET is_under_maintenance = $1 WHERE cafe_id = $2', [!!isUnderMaintenance, cafeId]);
    
    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'CAFE_MAINTENANCE_STATUS', { cafeId, isUnderMaintenance: !!isUnderMaintenance });

    res.json({ success: true, isUnderMaintenance: !!isUnderMaintenance });
  } catch (error) {
    console.error('toggleMaintenance error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/director/cafes/:cafeId/receipt
const getCafeReceiptSettings = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const cafeRes = await db.query('SELECT cafe_name, receipt_name FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kafe topilmadi.' });
    }
    const settingsRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    let data = {};
    if (settingsRes.rows.length > 0 && settingsRes.rows[0].data) {
      data = typeof settingsRes.rows[0].data === 'string' ? JSON.parse(settingsRes.rows[0].data) : settingsRes.rows[0].data;
    }
    return res.json({
      success: true,
      receiptSettings: {
        cafeId,
        cafeName: cafeRes.rows[0].cafe_name,
        receiptName: data.receiptName || cafeRes.rows[0].receipt_name || cafeRes.rows[0].cafe_name,
        restaurantAddress: data.restaurantAddress || '',
        restaurantPhone: data.restaurantPhone || '',
        receiptHeader: data.receiptHeader || '',
        receiptFooter: data.receiptFooter || 'Xaridingiz uchun rahmat!',
        receiptLogoUrl: data.receiptLogoUrl || '',
        showLogoOnReceipt: data.showLogoOnReceipt !== false,
        servicePercent: data.servicePercent || 0,
      },
    });
  } catch (error) {
    console.error('getCafeReceiptSettings error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT/POST /api/director/cafes/:cafeId/receipt
const updateCafeReceiptSettings = async (req, res) => {
  try {
    const { cafeId } = req.params;
    const {
      receiptName,
      restaurantAddress,
      restaurantPhone,
      receiptHeader,
      receiptFooter,
      receiptLogoUrl,
      showLogoOnReceipt,
      servicePercent,
    } = req.body;

    const check = await db.query('SELECT cafe_name FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (check.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kafe topilmadi.' });
    }

    const settingsRes = await db.query('SELECT data FROM settings WHERE cafe_id = $1', [cafeId]);
    let data = {};
    if (settingsRes.rows.length > 0 && settingsRes.rows[0].data) {
      data = typeof settingsRes.rows[0].data === 'string' ? JSON.parse(settingsRes.rows[0].data) : settingsRes.rows[0].data;
    }

    if (receiptName !== undefined) data.receiptName = receiptName.trim();
    if (restaurantAddress !== undefined) data.restaurantAddress = restaurantAddress.trim();
    if (restaurantPhone !== undefined) data.restaurantPhone = restaurantPhone.trim();
    if (receiptHeader !== undefined) data.receiptHeader = receiptHeader.trim();
    if (receiptFooter !== undefined) data.receiptFooter = receiptFooter.trim();
    if (receiptLogoUrl !== undefined) data.receiptLogoUrl = receiptLogoUrl.trim();
    if (showLogoOnReceipt !== undefined) data.showLogoOnReceipt = !!showLogoOnReceipt;
    if (servicePercent !== undefined) data.servicePercent = Number(servicePercent) || 0;

    await db.query(
      `INSERT INTO settings (cafe_id, data) VALUES ($1, $2)
       ON CONFLICT (cafe_id) DO UPDATE SET data = $2`,
      [cafeId, JSON.stringify(data)]
    );

    if (receiptName) {
      await db.query('UPDATE cafes SET receipt_name = $1 WHERE cafe_id = $2', [receiptName.trim(), cafeId]);
    }

    const { notifyCafe } = require('../socket/socketHandler');
    notifyCafe(cafeId, 'SETTINGS_UPDATED', { cafeId, settings: data });

    return res.json({
      success: true,
      message: 'Chek sozlamalari muvaffaqiyatli saqlandi.',
      receiptSettings: data,
    });
  } catch (error) {
    console.error('updateCafeReceiptSettings error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getMetrics,
  listCafes,
  getCafeDetail,
  getCafeOverview,
  createCafe,
  updateCafe,
  deleteCafe,
  createUser,
  blockCafe,
  unblockCafe,
  extendSubscription,
  getAuditLogs,
  toggleUserActive,
  listSupportTickets,
  startFixTicket,
  resolveTicket,
  toggleMaintenance,
  getCafeReceiptSettings,
  updateCafeReceiptSettings,
};
