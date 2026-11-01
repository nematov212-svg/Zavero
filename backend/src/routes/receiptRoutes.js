const express = require('express');
const router = express.Router();
const c = require('../controllers/receiptController');
const auth = require('../middleware/authMiddleware');
const db = require('../config/db');
const {
  getIo,
  getPrinterStationCount,
  isJobDuplicate,
  printerRoom,
} = require('../socket/socketHandler');

// Public receipt view for mobile Telegram WebApp openLink print fallback
router.get('/:id/view', c.viewReceiptHtml);

// GET /api/receipts/pending-jobs — For Print Agent polling (supports query param or auth)
router.get('/pending-jobs', async (req, res) => {
  try {
    let cafeId = req.query.cafeId;
    if (!cafeId && req.headers.authorization) {
      try {
        const token = req.headers.authorization.split(' ')[1];
        const jwt = require('jsonwebtoken');
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret');
        cafeId = decoded.cafeId;
      } catch (_) {}
    }

    if (!cafeId) {
      return res.status(400).json({ success: false, message: 'cafeId parametri kiritilishi shart' });
    }

    const result = await db.query(
      `SELECT * FROM print_jobs 
       WHERE cafe_id = $1 AND status = 'pending' 
       ORDER BY created_at ASC LIMIT 10`,
      [cafeId]
    );

    return res.json({ success: true, jobs: result.rows });
  } catch (err) {
    console.error('pending-jobs error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/receipts/print-jobs/:id/complete
router.post('/print-jobs/:id/complete', async (req, res) => {
  try {
    const { id } = req.params;
    await db.query(
      `UPDATE print_jobs SET status = 'completed', completed_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [id]
    );
    return res.json({ success: true, id, status: 'completed' });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/receipts/print-jobs/:id/fail
router.post('/print-jobs/:id/fail', async (req, res) => {
  try {
    const { id } = req.params;
    const { error } = req.body || {};
    await db.query(
      `UPDATE print_jobs SET status = 'failed', error_message = $2 WHERE id = $1`,
      [id, error || 'Chop etishda xatolik']
    );
    return res.json({ success: true, id, status: 'failed' });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

router.use(auth);
router.get('/', c.list);
router.get('/unprinted', c.getUnprintedReceipts);
router.patch('/:id/print-status', c.updatePrintStatus);
router.post('/', c.createReceipt);
router.post('/checkout', c.checkout);

// GET /api/receipts/printer-status — Check if any printer station is currently active for this cafe
router.get('/printer-status', (req, res) => {
  const cafeId = req.user?.cafeId;
  const count = getPrinterStationCount(cafeId);
  res.json({ success: true, hasStation: count > 0, stationCount: count });
});

// POST /api/receipts/print-job — Remote Cloud/Station print dispatch & Database persistence
router.post('/print-job', async (req, res) => {
  const cafeId = req.user?.cafeId || req.body?.cafeId;
  if (!cafeId) {
    return res.status(400).json({ success: false, routedToStation: false, message: 'Kafeni aniqlab bo‘lmadi' });
  }

  const cafeStr = String(cafeId);
  const count = getPrinterStationCount(cafeStr);
  const job = req.body || {};
  const jobId = job.id || `job_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;

  // 1. 5-soniyalik deduplication tekshiruvi (takroriy bosish oldi olinadi)
  if (isJobDuplicate(cafeStr, jobId)) {
    return res.json({
      success: true,
      routedToStation: true,
      duplicate: true,
      message: 'Chek allaqachon yuborilgan (takroriy bosish oldi olindi)',
    });
  }

  // 2. Bazaga navbatga (print_jobs) saqlaymiz (agar agent/kassa offline bo'lsa ham yo'qolmaydi)
  try {
    await db.query(
      `INSERT INTO print_jobs (
        id, cafe_id, type, target_printer, status, html, data, image_base64,
        table_number, hall_name, waiter_id, waiter_name
      ) VALUES ($1, $2, $3, $4, 'pending', $5, $6, $7, $8, $9, $10, $11)
      ON CONFLICT (id) DO UPDATE SET 
        status = 'pending',
        html = EXCLUDED.html,
        data = EXCLUDED.data,
        image_base64 = EXCLUDED.image_base64`,
      [
        jobId,
        cafeStr,
        job.type || 'receipt',
        job.targetPrinter || 'cashier',
        job.html || null,
        job.data ? JSON.stringify(job.data) : null,
        job.image || job.image_base64 || null,
        job.tableNumber ? String(job.tableNumber) : null,
        job.hallName || null,
        req.user?.id ? String(req.user.id) : null,
        req.user?.name || 'Ofitsiant',
      ]
    );
  } catch (err) {
    console.error('print_jobs insert error:', err);
  }

  // 3. Agar ulangan kassa printer stansiyalari bo'lsa, real-time Socket.IO orqali darhol uzatamiz
  const io = getIo();
  if (io && count > 0) {
    io.to(printerRoom(cafeStr)).emit('EXECUTE_PRINT_JOB', {
      ...job,
      id: jobId,
      cafeId: cafeStr,
      timestamp: new Date().toISOString(),
    });
  }

  const message = count > 0
    ? 'Chek kassa printeriga yuborildi va chop etilmoqda'
    : 'Chek navbatda, printer ulanganda chiqadi';

  return res.json({
    success: true,
    routedToStation: true,
    jobId,
    message,
    hasActiveStation: count > 0,
  });
});

module.exports = router;
