const db = require('../config/db');
const { mapCustomerOrder, mapCategory, mapProduct, mapCustomer, mapTable, mapCartItems } = require('../utils/mappers');
const { notifyCafe } = require('../socket/socketHandler');

const list = async (req, res) => {
  const result = await db.query(
    'SELECT * FROM customer_orders WHERE cafe_id = $1 ORDER BY date DESC LIMIT 100',
    [req.user.cafeId]
  );
  res.json({ success: true, customerOrders: result.rows.map(mapCustomerOrder) });
};

const save = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id, date, items, customerName, phone, type, tableNumber, hallId, deliveryAddress, status } = req.body;

    let row;
    if (id) {
      const existing = await db.query('SELECT id FROM customer_orders WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
      if (existing.rows.length > 0) {
        const result = await db.query(
          `UPDATE customer_orders SET items=$1, customer_name=$2, phone=$3, type=$4, table_number=$5,
           hall_id=$6, delivery_address=$7, status=$8, updated_at=CURRENT_TIMESTAMP
           WHERE id=$9 AND cafe_id=$10 RETURNING *`,
          [JSON.stringify(items || []), customerName || '', phone || '', type || 'dineIn',
           tableNumber ?? null, hallId ?? null, deliveryAddress ?? null, status || 'pending', id, cafeId]
        );
        row = result.rows[0];
      }
    }
    if (!row) {
      const result = await db.query(
        `INSERT INTO customer_orders (cafe_id, date, items, customer_name, phone, type, table_number, hall_id, delivery_address, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
        [cafeId, date ? new Date(date) : new Date(), JSON.stringify(items || []), customerName || '',
         phone || '', type || 'dineIn', tableNumber ?? null, hallId ?? null, deliveryAddress ?? null, status || 'pending']
      );
      row = result.rows[0];
    }

    notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order: mapCustomerOrder(row) });
    res.json({ success: true, order: mapCustomerOrder(row) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const updateStatus = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id } = req.params;
    const { status } = req.body;
    const result = await db.query(
      'UPDATE customer_orders SET status=$1, updated_at=CURRENT_TIMESTAMP WHERE id=$2 AND cafe_id=$3 RETURNING *',
      [status, id, cafeId]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Buyurtma topilmadi' });

    const order = mapCustomerOrder(result.rows[0]);
    notifyCafe(cafeId, 'CUSTOMER_ORDER_UPDATED', { order });
    res.json({ success: true, order });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUBLIC: GET /api/customer-orders/public/menu/:cafeId
const getPublicMenu = async (req, res) => {
  try {
    const { cafeId } = req.params;
    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'cafeId kiritilishi shart' });
    }

    let cafeRes = await db.query(
      'SELECT cafe_id, cafe_name, receipt_name, owner_name, owner_email, status, end_date FROM cafes WHERE cafe_id = $1',
      [cafeId]
    );

    if (cafeRes.rows.length === 0) {
      cafeRes = await db.query(
        `SELECT c.cafe_id, c.cafe_name, c.receipt_name, c.owner_name, c.owner_email, c.status, c.end_date
         FROM cafes c
         LEFT JOIN users u ON u.cafe_id = c.cafe_id
         WHERE LOWER(TRIM(c.cafe_name)) = LOWER(TRIM($1))
            OR LOWER(TRIM(c.owner_name)) = LOWER(TRIM($1))
            OR LOWER(TRIM(c.owner_email)) = LOWER(TRIM($1))
            OR LOWER(TRIM(u.username)) = LOWER(TRIM($1))
         LIMIT 1`,
        [cafeId]
      );
    }

    if (cafeRes.rows.length === 0) {
      cafeRes = await db.query(
        `SELECT c.cafe_id, c.cafe_name, c.receipt_name, c.owner_name, c.owner_email, c.status, c.end_date
         FROM cafes c
         WHERE c.status != 'blocked'
         ORDER BY c.created_at ASC, c.cafe_id ASC
         LIMIT 1`
      );
    }

    if (cafeRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kafe topilmadi' });
    }
    const cafe = cafeRes.rows[0];
    if (cafe.status === 'blocked') {
      return res.status(403).json({ success: false, message: 'Ushbu kafe faoliyati vaqtincha to‘xtatilgan.' });
    }

    const realCafeId = cafe.cafe_id;
    const [catRes, prodRes, settingsRes, tablesRes] = await Promise.all([
      db.query('SELECT * FROM categories WHERE cafe_id = $1 ORDER BY id ASC', [realCafeId]),
      db.query('SELECT * FROM products WHERE cafe_id = $1 ORDER BY id ASC', [realCafeId]),
      db.query('SELECT data FROM settings WHERE cafe_id = $1', [realCafeId]),
      db.query('SELECT id, number, seats, hall_id, status FROM restaurant_tables WHERE cafe_id = $1 ORDER BY number ASC', [realCafeId]),
    ]);

    let settings = {};
    if (settingsRes.rows.length > 0 && settingsRes.rows[0].data) {
      settings = typeof settingsRes.rows[0].data === 'string' ? JSON.parse(settingsRes.rows[0].data) : settingsRes.rows[0].data;
    }

    const resolvedCafeName = cafe.cafe_name || cafe.receipt_name || 'Kafe';

    return res.json({
      success: true,
      cafe: {
        id: realCafeId,
        cafeId: realCafeId,
        name: resolvedCafeName,
        cafeName: resolvedCafeName,
        receiptName: cafe.receipt_name || resolvedCafeName,
        address: settings.restaurantAddress || '',
        phone: settings.restaurantPhone || '',
        logoUrl: settings.appLogoUrl || settings.receiptLogoUrl || '',
        servicePercent: settings.servicePercent || 0,
      },
      banners: Array.isArray(settings.promoBanners) ? settings.promoBanners : [],
      categories: catRes.rows.map(mapCategory),
      products: prodRes.rows.map(mapProduct),
      tables: tablesRes.rows,
    });
  } catch (error) {
    console.error('getPublicMenu error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUBLIC: POST /api/customer-orders/public/order
const createPublicOrder = async (req, res) => {
  try {
    const { cafeId, tableNumber, tableName, hallId, items, customerName, phone, notes } = req.body;
    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'cafeId kiritilishi shart' });
    }
    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Kamida 1 ta taom tanlang' });
    }

    let cafeCheck = await db.query('SELECT cafe_id, status FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeCheck.rows.length === 0) {
      cafeCheck = await db.query(
        `SELECT c.cafe_id, c.status
         FROM cafes c
         LEFT JOIN users u ON u.cafe_id = c.cafe_id
         WHERE LOWER(TRIM(c.cafe_name)) = LOWER(TRIM($1))
            OR LOWER(TRIM(c.owner_name)) = LOWER(TRIM($1))
            OR LOWER(TRIM(c.owner_email)) = LOWER(TRIM($1))
            OR LOWER(TRIM(u.username)) = LOWER(TRIM($1))
         LIMIT 1`,
        [cafeId]
      );
    }

    if (cafeCheck.rows.length === 0) {
      cafeCheck = await db.query(
        `SELECT c.cafe_id, c.status
         FROM cafes c
         WHERE c.status != 'blocked'
         ORDER BY c.created_at ASC, c.cafe_id ASC
         LIMIT 1`
      );
    }

    if (cafeCheck.rows.length === 0 || cafeCheck.rows[0].status === 'blocked') {
      return res.status(403).json({ success: false, message: 'Ushbu kafe hozirda buyurtma qabul qila olmaydi.' });
    }

    const realCafeId = cafeCheck.rows[0].cafe_id;
    const orderDate = new Date();
    const displayCustomer = customerName && customerName.trim()
      ? `${customerName.trim().substring(0, 80)} (${tableName || `Stol #${tableNumber || 1}`})`
      : (tableName ? `${tableName} mijoz` : `Stol #${tableNumber || 1}`);

    // SECURITY: Extract product IDs and query authentic prices from database
    const rawProdIds = (Array.isArray(items) ? items : [])
      .map(item => parseInt(item.productId || item.id || (item.product && item.product.id) || 0, 10))
      .filter(id => !isNaN(id) && id > 0);

    let dbProductsMap = new Map();
    if (rawProdIds.length > 0) {
      const dbProds = await db.query(
        'SELECT id, name, price, category_id, image_url FROM products WHERE cafe_id = $1 AND id = ANY($2::int[])',
        [realCafeId, rawProdIds]
      );
      for (const p of dbProds.rows) {
        dbProductsMap.set(p.id, p);
      }
    }

    const normalizedItems = (Array.isArray(items) ? items : []).map(item => {
      const prodId = parseInt(item.productId || item.id || (item.product && item.product.id) || 0, 10);
      const dbProd = dbProductsMap.get(prodId);

      // SECURITY: Always prioritize authentic server database price over any client-provided price
      const name = dbProd ? dbProd.name : (item.name || item.productName || 'Taom');
      const price = dbProd ? parseFloat(dbProd.price) : parseFloat(item.price || 0);
      const rawQty = parseInt(item.qty || item.quantity || item.count || 1, 10);
      const qty = Math.max(1, Math.min(50, isNaN(rawQty) ? 1 : rawQty)); // Enforce limit: 1 to 50
      const note = typeof item.note === 'string' ? item.note.substring(0, 200) : '';
      const imageUrl = dbProd ? (dbProd.image_url || '') : (item.imageUrl || item.image || '');
      const categoryId = dbProd ? dbProd.category_id : (item.categoryId || 1);

      return {
        productId: prodId,
        name: name,
        price: price,
        qty: qty,
        quantity: qty,
        note: note,
        total: price * qty,
        product: {
          id: prodId,
          name: name,
          price: price,
          categoryId: categoryId,
          imageUrl: imageUrl,
          stock: 999,
        }
      };
    }).filter(i => i.qty > 0 && i.price >= 0);

    if (normalizedItems.length === 0) {
      return res.status(400).json({ success: false, message: "Buyurtmada haqiqiy taomlar topilmadi." });
    }

    // IDEMPOTENCY / DEDUPLICATION: Prevent double submission from rapid taps or network retry
    const existingRecent = await db.query(
      `SELECT * FROM customer_orders
       WHERE cafe_id = $1 
         AND (table_number = $2 OR delivery_address = $3)
         AND date > NOW() - INTERVAL '45 seconds'
         AND status = 'pending'
       ORDER BY date DESC LIMIT 1`,
      [
        realCafeId,
        tableNumber ? parseInt(tableNumber, 10) : null,
        tableName || (tableNumber ? `${tableNumber}-stol` : ''),
      ]
    );

    if (existingRecent.rows.length > 0) {
      const recentOrder = existingRecent.rows[0];
      const recentItems = typeof recentOrder.items === 'string' ? recentOrder.items : JSON.stringify(recentOrder.items);
      const newItemsStr = JSON.stringify(normalizedItems);
      if (recentItems === newItemsStr) {
        return res.status(200).json({
          success: true,
          message: 'Buyurtmangiz allaqachon qabul qilingan!',
          order: mapCustomerOrder(recentOrder),
          isDuplicate: true,
        });
      }
    }

    const result = await db.query(
      `INSERT INTO customer_orders (cafe_id, date, items, customer_name, phone, type, table_number, hall_id, delivery_address, status)
       VALUES ($1, $2, $3, $4, $5, 'dineIn', $6, $7, $8, 'pending') RETURNING *`,
      [
        realCafeId,
        orderDate,
        JSON.stringify(normalizedItems),
        displayCustomer,
        phone ? String(phone).substring(0, 30) : '',
        tableNumber ? parseInt(tableNumber, 10) : null,
        hallId ? parseInt(hallId, 10) : null,
        tableName || (tableNumber ? `${tableNumber}-stol` : ''),
      ]
    );

    const createdOrder = mapCustomerOrder(result.rows[0]);

    // 1. Mijozlar (Customers) ro'yxatiga qo'shish / yangilash va real-time xabar berish
    const cleanCustName = (customerName || '').trim();
    const cleanPhone = (phone || '').trim();
    if (cleanCustName && cleanCustName.toLowerCase() !== 'mijoz') {
      try {
        let custRow;
        if (cleanPhone) {
          const existingCust = await db.query(
            'SELECT id FROM customers WHERE cafe_id = $1 AND (phone = $2 OR LOWER(name) = LOWER($3)) LIMIT 1',
            [realCafeId, cleanPhone, cleanCustName]
          );
          if (existingCust.rows.length > 0) {
            const up = await db.query(
              'UPDATE customers SET name = $1, phone = $2 WHERE id = $3 AND cafe_id = $4 RETURNING *',
              [cleanCustName, cleanPhone, existingCust.rows[0].id, realCafeId]
            );
            custRow = up.rows[0];
          } else {
            const ins = await db.query(
              'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1, $2, $3, \'\', 0) RETURNING *',
              [realCafeId, cleanCustName, cleanPhone]
            );
            custRow = ins.rows[0];
          }
        } else {
          const existingCust = await db.query(
            'SELECT id FROM customers WHERE cafe_id = $1 AND LOWER(name) = LOWER($2) LIMIT 1',
            [realCafeId, cleanCustName]
          );
          if (existingCust.rows.length === 0) {
            const ins = await db.query(
              'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1, $2, \'\', \'\', 0) RETURNING *',
              [realCafeId, cleanCustName]
            );
            custRow = ins.rows[0];
          } else {
            custRow = existingCust.rows[0];
          }
        }
        if (custRow) {
          notifyCafe(realCafeId, 'CUSTOMERS_UPDATED', { customer: mapCustomer(custRow) });
        }
      } catch (custErr) {
        console.warn('Customer upsert warning in QR order:', custErr.message);
      }
    }

    // 2. Stolni avtomatik BAND (occupied) qilish va jonli table_orders ga kiritish
    const num = parseInt(tableNumber, 10);
    if (!isNaN(num)) {
      try {
        const tableCheck = await db.query(
          'SELECT * FROM restaurant_tables WHERE cafe_id = $1 AND number = $2 LIMIT 1',
          [realCafeId, num]
        );
        if (tableCheck.rows.length > 0) {
          const tableRow = tableCheck.rows[0];
          const totalAmount = normalizedItems.reduce((s, i) => s + (i.price * i.qty), 0);

          await db.query(
            `UPDATE restaurant_tables SET status='occupied', order_id=$1, total=$2, started_by=$3, updated_at=CURRENT_TIMESTAMP WHERE id=$4`,
            [`${result.rows[0].id}`, totalAmount, cleanCustName || 'QR Mijoz', tableRow.id]
          );

          await db.query(
            `INSERT INTO table_orders (table_id, cafe_id, items, note, started_by, updated_at)
             VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
             ON CONFLICT (table_id) DO UPDATE SET items=$3, note=$4, started_by=$5, updated_at=CURRENT_TIMESTAMP`,
            [tableRow.id, realCafeId, JSON.stringify(normalizedItems), notes || `QR Buyurtma: ${cleanCustName || ''}`, cleanCustName || 'QR Mijoz']
          );

          notifyCafe(realCafeId, 'TABLE_STATUS_UPDATED', {
            tableId: tableRow.id,
            status: 'occupied',
            table: mapTable({ ...tableRow, status: 'occupied', total: totalAmount })
          });
          notifyCafe(realCafeId, 'TABLE_ORDER_UPDATED', {
            tableId: tableRow.id,
            table: mapTable({ ...tableRow, status: 'occupied', total: totalAmount }),
            items: mapCartItems(normalizedItems),
            note: notes || '',
          });
        }
      } catch (tblErr) {
        console.warn('Table occupy warning in QR order:', tblErr.message);
      }
    }

    // Send real-time notification to cafe POS terminals
    notifyCafe(realCafeId, 'NEW_CUSTOMER_ORDER', {
      order: createdOrder,
      tableNumber,
      tableName: tableName || `${tableNumber}-stol`,
      message: `${tableName || `Stol #${tableNumber}`} dan yangi buyurtma keldi!`,
    });
    notifyCafe(realCafeId, 'CUSTOMER_ORDER_UPDATED', { order: createdOrder });

    // Send Telegram Notification (Image 5 & Telegram bot sync)
    try {
      const { sendCustomerOrderNotification } = require('../bot/telegramBot');
      if (typeof sendCustomerOrderNotification === 'function') {
        sendCustomerOrderNotification(realCafeId, createdOrder);
      }
    } catch (tgErr) {
      console.warn('⚠️ Telegram order notification error:', tgErr.message);
    }

    return res.status(201).json({
      success: true,
      message: 'Buyurtmangiz muvaffaqiyatli qabul qilindi!',
      order: createdOrder,
    });
  } catch (error) {
    console.error('createPublicOrder error:', error);
    res.status(500).json({ success: false, message: 'Buyurtmani qabul qilishda xatolik yuz berdi.' });
  }
};

// PUBLIC: POST /api/customer-orders/public/customer — register customer when scanning QR code
const registerPublicCustomer = async (req, res) => {
  try {
    const { cafeId, name, phone } = req.body;
    if (!cafeId) return res.status(400).json({ success: false, message: 'cafeId kiritilishi shart' });
    const cleanName = (name || '').trim();
    const cleanPhone = (phone || '').trim();
    if (!cleanName && !cleanPhone) {
      return res.status(400).json({ success: false, message: 'Ism yoki telefon kiritilishi shart' });
    }

    let cafeCheck = await db.query('SELECT cafe_id FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeCheck.rows.length === 0) {
      cafeCheck = await db.query('SELECT cafe_id FROM cafes WHERE LOWER(TRIM(cafe_name)) = LOWER(TRIM($1)) LIMIT 1', [cafeId]);
    }
    if (cafeCheck.rows.length === 0) {
      cafeCheck = await db.query('SELECT cafe_id FROM cafes WHERE status != \'blocked\' ORDER BY created_at ASC, cafe_id ASC LIMIT 1');
    }
    if (cafeCheck.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kafe topilmadi' });
    }
    const realCafeId = cafeCheck.rows[0].cafe_id;

    let custRow;
    if (cleanPhone) {
      const existing = await db.query(
        'SELECT id FROM customers WHERE cafe_id = $1 AND (phone = $2 OR LOWER(name) = LOWER($3)) LIMIT 1',
        [realCafeId, cleanPhone, cleanName]
      );
      if (existing.rows.length > 0) {
        const up = await db.query(
          'UPDATE customers SET name = COALESCE(NULLIF($1, \'\'), name), phone = $2 WHERE id = $3 AND cafe_id = $4 RETURNING *',
          [cleanName, cleanPhone, existing.rows[0].id, realCafeId]
        );
        custRow = up.rows[0];
      } else {
        const ins = await db.query(
          'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1, $2, $3, \'\', 0) RETURNING *',
          [realCafeId, cleanName || 'Mehmon', cleanPhone]
        );
        custRow = ins.rows[0];
      }
    } else {
      const existing = await db.query(
        'SELECT id FROM customers WHERE cafe_id = $1 AND LOWER(name) = LOWER($2) LIMIT 1',
        [realCafeId, cleanName]
      );
      if (existing.rows.length === 0) {
        const ins = await db.query(
          'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1, $2, \'\', \'\', 0) RETURNING *',
          [realCafeId, cleanName]
        );
        custRow = ins.rows[0];
      } else {
        custRow = existing.rows[0];
      }
    }

    const mapped = mapCustomer(custRow);
    notifyCafe(realCafeId, 'CUSTOMERS_UPDATED', { customer: mapped });
    return res.json({ success: true, customer: mapped });
  } catch (error) {
    console.error('registerPublicCustomer error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

// PUBLIC: GET /api/customer-orders/public/order-status/:orderId
const getPublicOrderStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { cafeId } = req.query;

    if (!orderId || isNaN(parseInt(orderId, 10))) {
      return res.status(400).json({ success: false, message: 'Yaroqsiz orderId' });
    }

    const parsedOrderId = parseInt(orderId, 10);
    const query = cafeId
      ? 'SELECT * FROM customer_orders WHERE id = $1 AND cafe_id = $2'
      : 'SELECT * FROM customer_orders WHERE id = $1';
    const params = cafeId ? [parsedOrderId, cafeId] : [parsedOrderId];

    const result = await db.query(query, params);
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Buyurtma topilmadi' });
    }

    return res.json({
      success: true,
      order: mapCustomerOrder(result.rows[0]),
    });
  } catch (error) {
    console.error('getPublicOrderStatus error:', error);
    res.status(500).json({ success: false, message: 'Serverda xatolik yuz berdi.' });
  }
};

const remove = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const { id } = req.params;
    await db.query('DELETE FROM customer_orders WHERE id = $1 AND cafe_id = $2', [id, cafeId]);
    notifyCafe(cafeId, 'CUSTOMER_ORDER_DELETED', { orderId: Number(id) });
    res.json({ success: true, message: 'Buyurtma o‘chirildi', orderId: Number(id) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

const clearCompleted = async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    await db.query(
      `DELETE FROM customer_orders WHERE cafe_id = $1 AND status IN ('completed', 'cancelled', 'delivered')`,
      [cafeId]
    );
    notifyCafe(cafeId, 'CUSTOMER_ORDERS_CLEARED', {});
    res.json({ success: true, message: 'Eski buyurtmalar tozalandi' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  list,
  save,
  updateStatus,
  remove,
  clearCompleted,
  getPublicMenu,
  createPublicOrder,
  registerPublicCustomer,
  getPublicOrderStatus,
};
