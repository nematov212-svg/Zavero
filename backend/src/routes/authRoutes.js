const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const { authRateLimiter } = require('../middleware/rateLimitMiddleware');

router.post('/register', authRateLimiter, authController.register);
router.post('/login', authRateLimiter, authController.login);
router.get('/me', authMiddleware, authController.getMe);
router.put('/profile', authMiddleware, authController.updateProfile);
router.post('/profile', authMiddleware, authController.updateProfile);
router.put('/password', authMiddleware, authRateLimiter, authController.changePassword);
router.post('/password', authMiddleware, authRateLimiter, authController.changePassword);
router.put('/change-credentials', authMiddleware, authRateLimiter, authController.changeCredentials);
router.post('/change-credentials', authMiddleware, authRateLimiter, authController.changeCredentials);
router.post('/telegram-verify', authRateLimiter, authController.telegramVerify);

module.exports = router;
