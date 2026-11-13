const express = require('express');
const router = express.Router();
const c = require('../controllers/announcementController');
const auth = require('../middleware/authMiddleware');

router.use(auth);

// GET /api/announcements — List announcements for cafe
router.get('/', c.list);

// POST /api/announcements/read-all — Mark all as read
router.post('/read-all', c.markAllAsRead);

// POST /api/announcements/:id/read — Mark one as read
router.post('/:id/read', c.markAsRead);

module.exports = router;

