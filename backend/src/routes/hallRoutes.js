const express = require('express');
const router = express.Router();
const c = require('../controllers/hallController');
const auth = require('../middleware/authMiddleware');
const { requireAdmin } = require('../middleware/roleMiddleware');

router.use(auth);
router.get('/', c.list);
router.post('/', requireAdmin, c.save);
router.delete('/:id', requireAdmin, c.remove);
router.post('/:id/delete', requireAdmin, c.remove);

module.exports = router;
