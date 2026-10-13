const express = require('express');
const router = express.Router();
const c = require('../controllers/activityController');
const auth = require('../middleware/authMiddleware');
router.use(auth);
router.get('/', c.list);
router.post('/', c.create);
module.exports = router;
