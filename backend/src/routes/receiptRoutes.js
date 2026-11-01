const express = require('express');
const router = express.Router();
const c = require('../controllers/receiptController');
const auth = require('../middleware/authMiddleware');

// Public receipt view for mobile Telegram WebApp openLink print fallback
router.get('/:id/view', c.viewReceiptHtml);

router.use(auth);
router.get('/', c.list);
router.post('/checkout', c.checkout);
module.exports = router;
