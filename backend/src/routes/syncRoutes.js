const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');
const auth = require('../middleware/auth');

// Barcha sync so'rovlari autentifikatsiya (JWT token) talab qiladi
router.use(auth);

// GET /api/sync/bootstrap — Oflayn rejim uchun boshlang'ich kesh
router.get('/bootstrap', syncController.bootstrap);

// GET /api/sync/changes — O'zgarishlar delta ro'yxati
router.get('/changes', syncController.changes);

// POST /api/sync/push — Oflayn amallar to'plamini (batch) yuborish
router.post('/push', syncController.push);

module.exports = router;
