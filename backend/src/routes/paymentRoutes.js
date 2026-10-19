const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');

// Click webhooks (Prepare & Complete can be sent to /click or /click/prepare & /click/complete)
router.post('/click', paymentController.handleClick);
router.post('/click/prepare', paymentController.handleClick);
router.post('/click/complete', paymentController.handleClick);

// Payme JSON-RPC 2.0 webhook
router.post('/payme', paymentController.handlePayme);

// Check subscription status by telegram ID
router.get('/status/:telegramId', paymentController.checkSubscriptionStatus);

// Test payment activation for staging/demo
router.post('/test-pay', paymentController.testPayment);

module.exports = router;
