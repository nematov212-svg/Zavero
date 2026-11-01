const express = require('express');
const router = express.Router();
const c = require('../controllers/receiptController');
const auth = require('../middleware/authMiddleware');
const {
  getIo,
  getPrinterStationCount,
  isJobDuplicate,
  printerRoom,
} = require('../socket/socketHandler');

// Public receipt view for mobile Telegram WebApp openLink print fallback
router.get('/:id/view', c.viewReceiptHtml);

router.use(auth);
router.get('/', c.list);
router.post('/', c.createReceipt);
router.post('/checkout', c.checkout);

// GET /api/receipts/printer-status — Check if any printer station is currently active for this cafe
router.get('/printer-status', (req, res) => {
  const cafeId = req.user?.cafeId;
  const count = getPrinterStationCount(cafeId);
  res.json({ success: true, hasStation: count > 0, stationCount: count });
});

// POST /api/receipts/print-job — Remote Cloud/Station print dispatch
router.post('/print-job', async (req, res) => {
  const cafeId = req.user?.cafeId;
  if (!cafeId) {
    return res.status(400).json({ success: false, routedToStation: false, message: 'Kafeni aniqlab bo‘lmadi' });
  }

  const cafeStr = String(cafeId);
  const count = getPrinterStationCount(cafeStr);
  if (count === 0) {
    return res.json({
      success: false,
      routedToStation: false,
      message: 'Printer qurilmasi ulanmagan, chek ekranda ko‘rsatildi',
    });
  }

  const job = req.body || {};

  // 5-soniyalik deduplication tekshiruvi (takroriy bosish oldi olinadi)
  if (isJobDuplicate(cafeStr, job.id)) {
    return res.json({
      success: true,
      routedToStation: true,
      duplicate: true,
      message: 'Chek kassa printeriga yuborildi va chop etilmoqda',
    });
  }

  const io = getIo();
  if (io) {
    io.to(printerRoom(cafeStr)).emit('EXECUTE_PRINT_JOB', {
      ...job,
      cafeId: cafeStr,
      timestamp: new Date().toISOString(),
    });
  }

  return res.json({
    success: true,
    routedToStation: true,
    message: 'Chek kassa printeriga yuborildi va chop etilmoqda',
  });
});

module.exports = router;
