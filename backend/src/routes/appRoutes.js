const express = require('express');
const router = express.Router();
const appController = require('../controllers/appController');

router.get('/version', appController.getAppVersion);

module.exports = router;
