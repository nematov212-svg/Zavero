const jwt = require('jsonwebtoken');
const db = require('../config/db');
const { getJwtSecret } = require('../config/jwt');

// Simple in-memory TTL cache for cafe status checks (15 seconds)
const cafeStatusCache = new Map();
const CACHE_TTL_MS = 15000;

const getCafeStatus = async (cafeId) => {
  const cached = cafeStatusCache.get(cafeId);
  const now = Date.now();
  if (cached && (now - cached.timestamp < CACHE_TTL_MS)) {
    return cached.data;
  }
  const res = await db.query('SELECT status, end_date FROM cafes WHERE cafe_id = $1', [cafeId]);
  const data = res.rows[0] || null;
  cafeStatusCache.set(cafeId, { data, timestamp: now });
  return data;
};

const invalidateCafeCache = (cafeId) => {
  if (cafeId) {
    cafeStatusCache.delete(cafeId);
  } else {
    cafeStatusCache.clear();
  }
};

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: "Avtorizatsiyadan o'tilmagan. Token topilmadi.",
      });
    }

    const token = authHeader.split(' ')[1];
    const secret = getJwtSecret();

    const decoded = jwt.verify(token, secret);
    req.user = decoded; // { id, username, cafeId, role }

    // SaaS Director bypasses cafe-level subscription checks
    if (decoded.role === 'director') {
      const targetCafe = req.headers['x-cafe-id'] || req.query.cafeId || (req.body && req.body.cafeId);
      if (targetCafe) {
        req.user.cafeId = targetCafe;
      }
      return next();
    }

    // Check Cafe Subscription & Block status
    if (decoded.cafeId) {
      const cafe = await getCafeStatus(decoded.cafeId);
      if (!cafe) {
        return res.status(403).json({
          success: false,
          message: 'Ushbu cafe topilmadi yoki o\'chirilgan.',
        });
      }

      const isBlocked = cafe.status === 'blocked';
      const isExpired = cafe.end_date ? new Date(cafe.end_date) < new Date() : false;

      // Allow /api/auth/me, change-credentials and password change even if blocked so UI knows state
      const isAuthExempt = req.baseUrl === '/api/auth' && (
        req.path === '/me' ||
        req.path === '/password' ||
        req.path === '/profile' ||
        req.path === '/change-credentials'
      );

      if ((isBlocked || isExpired) && !isAuthExempt) {
        return res.status(403).json({
          success: false,
          message: "Xizmat muddati tugagan yoki to'xtatilgan. Iltimos, administrator bilan bog'laning.",
          isBlocked,
          isExpired,
        });
      }

      req.cafe = cafe;
    }

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        message: 'Sessiya muddati tugadi. Iltimos qayta kiring.',
        isExpired: true,
      });
    }
    return res.status(401).json({
      success: false,
      message: 'Yaroqsiz token.',
    });
  }
};

module.exports = authMiddleware;
module.exports.invalidateCafeCache = invalidateCafeCache;
