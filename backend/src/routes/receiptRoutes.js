const express = require('express');
const router = express.Router();
const c = require('../controllers/receiptController');
const auth = require('../middleware/authMiddleware');
router.use(auth);
router.get('/', c.list);
router.post('/checkout', c.checkout);
module.exports = router;
