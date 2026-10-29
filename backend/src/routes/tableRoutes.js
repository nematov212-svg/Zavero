const express = require('express');
const router = express.Router();
const c = require('../controllers/tableController');
const auth = require('../middleware/authMiddleware');
const { requireAdmin } = require('../middleware/roleMiddleware');

router.use(auth);

// Read stollar
router.get('/', c.list);

// Operatsiyalar (Ofitsiant, Kassir, Admin)
router.post('/:id/order', c.saveOrder);
router.post('/:id/release', c.release);
router.put('/:id/status', c.updateStatus);

// Struktura o'zgarishlari (Faqat Admin / Director ruxsati bilan)
router.post('/', requireAdmin, c.createTable);
router.put('/:id', requireAdmin, c.updateTable);
router.delete('/:id', requireAdmin, c.removeTable);
router.post('/:id/delete', requireAdmin, c.removeTable);
router.delete('/', requireAdmin, c.removeTable);
router.post('/delete', requireAdmin, c.removeTable);
router.delete('/clear-all', requireAdmin, c.clearAllTables);
router.post('/clear-all', requireAdmin, c.clearAllTables);
router.delete('/clear-hall/:hallId', requireAdmin, c.clearHallTables);
router.post('/clear-hall/:hallId', requireAdmin, c.clearHallTables);

module.exports = router;

