const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const { requireDirector } = require('../middleware/roleMiddleware');
const c = require('../controllers/directorController');

// All director endpoints require Director role
router.use(auth);
router.use(requireDirector);

router.get('/metrics', c.getMetrics);
router.get('/cafes', c.listCafes);
router.get('/cafes/:cafeId', c.getCafeDetail);
router.get('/cafes/:cafeId/overview', c.getCafeOverview);
router.post('/cafes', c.createCafe);
router.put('/cafes/:cafeId', c.updateCafe);
router.post('/cafes/:cafeId/update', c.updateCafe);
router.delete('/cafes/:cafeId', c.deleteCafe);
router.post('/cafes/:cafeId/delete', c.deleteCafe);
router.delete('/cafes/delete/:cafeId', c.deleteCafe);
router.post('/cafes/delete', c.deleteCafe);
router.delete('/cafes', c.deleteCafe);
router.get('/cafes/:cafeId/receipt', c.getCafeReceiptSettings);
router.put('/cafes/:cafeId/receipt', c.updateCafeReceiptSettings);
router.post('/cafes/:cafeId/receipt', c.updateCafeReceiptSettings);

router.post('/cafes/:cafeId/block', c.blockCafe);
router.put('/cafes/:cafeId/block', c.blockCafe);
router.post('/cafes/:cafeId/unblock', c.unblockCafe);
router.put('/cafes/:cafeId/unblock', c.unblockCafe);
router.post('/cafes/:cafeId/extend', c.extendSubscription);
router.put('/cafes/:cafeId/extend', c.extendSubscription);
router.post('/cafes/:cafeId/maintenance', c.toggleMaintenance);
router.put('/cafes/:cafeId/maintenance', c.toggleMaintenance);

router.post('/users', c.createUser);
router.put('/users/:userId/status', c.toggleUserActive);
router.post('/users/:userId/status', c.toggleUserActive);
router.get('/audit-logs', c.getAuditLogs);
router.put('/app-version', require('../controllers/appController').setAppVersion);
router.post('/app-version', require('../controllers/appController').setAppVersion);

// Support & Issues management
router.get('/support-tickets', c.listSupportTickets);
router.post('/support-tickets/:ticketId/start-fix', c.startFixTicket);
router.post('/support-tickets/:ticketId/resolve', c.resolveTicket);

module.exports = router;
