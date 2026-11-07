const express = require('express');
const router = express.Router();
const c = require('../controllers/cafeController');
const auth = require('../middleware/authMiddleware');
const { requireAdmin } = require('../middleware/roleMiddleware');

// Heartbeat endpoint (open with cafeId or authenticated token)
router.post('/heartbeat', (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return auth(req, res, () => c.heartbeat(req, res, next));
  }
  return c.heartbeat(req, res, next);
});

router.use(auth);
router.get('/full', c.getFullCafeData);
router.post('/restore-menu', requireAdmin, c.restoreMenu);
router.get('/settings', c.getSettings);
router.put('/settings', requireAdmin, c.saveSettings);
router.post('/test-telegram', requireAdmin, require('../controllers/receiptController').testTelegramConnection);
router.put('/receipt-name', requireAdmin, c.updateReceiptName);
router.get('/banners', c.getBanners);
router.post('/banners', requireAdmin, c.addBanner);
router.put('/banners', requireAdmin, c.saveBanners);
router.put('/banners/:id', requireAdmin, c.updateBanner);
router.delete('/banners/:id', requireAdmin, c.deleteBanner);
router.get('/backup', requireAdmin, c.getBackupData);
router.get('/print-agent-token', requireAdmin, c.getPrintAgentToken);
router.post('/print-agent-token/rotate', requireAdmin, c.rotatePrintAgentToken);
router.post('/report-issue', c.reportIssue);
router.get('/maintenance-status', c.getMaintenanceStatus);
module.exports = router;
