const express = require('express');
const router = express.Router();
const c = require('../controllers/notificationController');
const auth = require('../middleware/authMiddleware');
const { requireDirector } = require('../middleware/roleMiddleware');

router.use(auth);

// GET /api/notifications - List all notifications for cafe
router.get('/', c.list);

// POST /api/notifications - Create notification (Director only)
router.post('/', requireDirector, c.create);

// PUT /api/notifications/:id/read - Mark as read (Cafe owner/staff or Director)
router.put('/:id/read', c.markAsRead);

// DELETE /api/notifications/:id - Delete notification (Director only)
router.delete('/:id', requireDirector, c.remove);

module.exports = router;
