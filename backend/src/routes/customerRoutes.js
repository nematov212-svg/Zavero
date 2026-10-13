const express = require('express');
const router = express.Router();
const c = require('../controllers/customerController');
const auth = require('../middleware/authMiddleware');
router.use(auth);
router.get('/', c.list);
router.post('/', c.save);
router.delete('/:id', c.remove);
module.exports = router;
