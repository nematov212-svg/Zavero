const express = require('express');
const router = express.Router();
const c = require('../controllers/reportController');
const auth = require('../middleware/authMiddleware');
const { requireAdmin } = require('../middleware/roleMiddleware');

router.use(auth);

// Live today report accessible to all authenticated cafe roles (Waiters, Cashiers, Admins, Directors)
router.get('/today', c.getTodayReport);

// Administrative / Full historical reports & deletions require Admin or Director
router.get('/', requireAdmin, c.list);
router.get('/analytics', requireAdmin, c.getAnalytics);
router.get('/export/csv', requireAdmin, c.exportCsv);
router.delete('/month/:yearMonth', requireAdmin, c.clearMonth);
router.delete('/all', requireAdmin, c.clearAll);
router.delete('/', requireAdmin, c.clearAll);
router.get('/:dateId', requireAdmin, c.getOne);
router.delete('/:dateId', requireAdmin, c.clearDay);

module.exports = router;
