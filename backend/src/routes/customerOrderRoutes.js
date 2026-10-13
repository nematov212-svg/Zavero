const express = require('express');
const router = express.Router();
const c = require('../controllers/customerOrderController');
const auth = require('../middleware/authMiddleware');

const { publicMenuRateLimiter, publicOrderRateLimiter } = require('../middleware/rateLimitMiddleware');

// Public endpoints for Table QR Menu & Ordering (no auth required, strictly rate limited)
router.get('/public/menu/:cafeId', publicMenuRateLimiter, c.getPublicMenu);
router.post('/public/order', publicOrderRateLimiter, c.createPublicOrder);
router.post('/public/customer', publicOrderRateLimiter, c.registerPublicCustomer);
router.get('/public/order-status/:orderId', publicMenuRateLimiter, c.getPublicOrderStatus);

// Authenticated POS endpoints
router.use(auth);
router.get('/', c.list);
router.post('/', c.save);
router.put('/:id/status', c.updateStatus);
router.post('/:id/status', c.updateStatus);
router.delete('/:id', c.remove);
router.post('/clear-completed', c.clearCompleted);

module.exports = router;
