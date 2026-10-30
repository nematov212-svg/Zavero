const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const auth = require('../middleware/authMiddleware');
const { requireDirector } = require('../middleware/roleMiddleware');

// Click webhooks (Prepare & Complete can be sent to /click or /click/prepare & /click/complete)
router.post('/click', paymentController.handleClick);
router.post('/click/prepare', paymentController.handleClick);
router.post('/click/complete', paymentController.handleClick);

// Payme JSON-RPC 2.0 webhook
router.post('/payme', paymentController.handlePayme);

// Check subscription status by telegram ID
router.get('/status/:telegramId', paymentController.checkSubscriptionStatus);

// Test payment activation for staging/demo (strictly restricted to SaaS Director)
router.post('/test-pay', auth, requireDirector, paymentController.testPayment);

module.exports = router;
