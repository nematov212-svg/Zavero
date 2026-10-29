const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const { sendExtensionRequest } = require('../bot/subscriptionBot');

// POST /api/subscription/request-30days
router.post('/request-30days', auth, async (req, res) => {
  try {
    const cafeId = req.user.cafeId;
    const userName = req.user.name || req.user.username;
    const userPhone = req.user.phone || '';
    const { cafeName, currentEndDate } = req.body;

    const result = await sendExtensionRequest({
      cafeId,
      cafeName: cafeName || req.user.cafeName || 'ZAVERO Kafe',
      userName,
      userPhone,
      currentEndDate,
    });

    return res.json({
      success: true,
      message: "30 kunlik obuna so'rovi muvaffaqiyatli yuborildi. Admin tasdiqlashi bilan tizimda ochiladi.",
      ...result,
    });
  } catch (error) {
    console.error('request-30days error:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
