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
    // 1. Support Hardware Print Agent token authentication via header
    const printToken = req.headers['x-print-token'] || req.headers['x-agent-key'];
    const authHeader = req.headers.authorization;

    if (printToken || (authHeader && authHeader.startsWith('Bearer agy_print_'))) {
      const token = printToken || authHeader.split(' ')[1];
      const cafeRes = await db.query(
        'SELECT cafe_id, cafe_name, status, end_date FROM cafes WHERE print_agent_token = $1',
        [token]
      );
      if (cafeRes.rows.length === 0) {
        return res.status(401).json({
          success: false,
          message: 'Yaroqsiz print agent kaliti (Unauthorized Print Agent).',
        });
      }
      const cafe = cafeRes.rows[0];
      req.user = {
        id: 0,
        username: 'print_agent',
        cafeId: cafe.cafe_id,
        role: 'print_agent',
      };
      req.isPrintAgent = true;
      req.cafe = cafe;
      return next();
    }

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: "Avtorizatsiyadan o'tilmagan. Token topilmadi.",
      });
    }

    const token = authHeader.split(' ')[1];
    const secret = getJwtSecret();

    const decoded = jwt.verify(token, secret);
    req.user = { ...decoded }; // { id, username, cafeId, role }

    // Verify user is active and token_version matches current session version
    const userDbRes = await db.query(
      'SELECT is_active, token_version FROM users WHERE id = $1',
      [decoded.id]
    );
    if (userDbRes.rows.length === 0 || userDbRes.rows[0].is_active === false) {
      return res.status(401).json({
        success: false,
        message: 'Foydalanuvchi tizimdan chiqarilgan yoki bloklangan.',
      });
    }
    const currentTokenVersion = userDbRes.rows[0].token_version || 1;
    if (decoded.tokenVersion && decoded.tokenVersion !== currentTokenVersion) {
      return res.status(401).json({
        success: false,
        message: 'Sessiya muddati tugadi yoki bekor qilindi. Iltimos, qaytadan kiring.',
      });
    }

    // 2. Multi-Tenant Role Verification & Isolation
    if (decoded.role === 'super_admin') {
      const targetCafe = req.headers['x-cafe-id'] || req.query?.cafeId || (req.body && req.body?.cafeId);
      if (targetCafe) {
        req.user.cafeId = targetCafe;
      }
      return next();
    }

    if (decoded.role === 'director') {
      const targetCafe = req.headers['x-cafe-id'] || req.query?.cafeId || (req.body && req.body?.cafeId);
      if (targetCafe) {
        // STRICT CHECK: Does this director own or belong to this cafe?
        const authRes = await db.query(
          `SELECT 1 FROM user_cafes WHERE user_id = $1 AND cafe_id = $2
           UNION
           SELECT 1 FROM cafes WHERE cafe_id = $2 AND (director_id = $1 OR owner_email = $3)`,
          [decoded.id, targetCafe, decoded.username || '']
        );
        if (authRes.rows.length === 0) {
          // Return 404 to avoid leaking existence of other tenants
          return res.status(404).json({ success: false, message: 'Cafe topilmadi.' });
        }
        req.user.cafeId = targetCafe;
      }
      return next();
    }

    // Standard Cafe roles (admin, cashier, waiter, chef, worker):
    // MUST NEVER TRUST client-provided cafe_id in headers, query, or body.
    // Tenant is strictly bound to token.
    if (!decoded.cafeId) {
      return res.status(403).json({
        success: false,
        message: 'Foydalanuvchi hech qanday kafega biriktirilmagan.',
      });
    }

    // Verify user membership in user_cafes or direct users table
    const memberCheck = await db.query(
      'SELECT role FROM user_cafes WHERE user_id = $1 AND cafe_id = $2',
      [decoded.id, decoded.cafeId]
    );
    if (memberCheck.rows.length === 0) {
      const userCheck = await db.query(
        'SELECT role FROM users WHERE id = $1 AND cafe_id = $2 AND is_active = true',
        [decoded.id, decoded.cafeId]
      );
      if (userCheck.rows.length > 0) {
        await db.query(
          'INSERT INTO user_cafes (user_id, cafe_id, role) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING',
          [decoded.id, decoded.cafeId, userCheck.rows[0].role]
        ).catch(() => {});
      } else {
        return res.status(403).json({
          success: false,
          message: 'Ushbu kafega kirish huquqingiz bekor qilingan.',
        });
      }
    }

    // 3. Check Cafe Subscription & Block status
    const cafe = await getCafeStatus(decoded.cafeId);
    if (!cafe) {
      return res.status(404).json({
        success: false,
        message: "Ushbu cafe topilmadi yoki o'chirilgan.",
      });
    }

    const isBlocked = cafe.status === 'blocked';
    const isExpired = cafe.end_date ? new Date(cafe.end_date) < new Date() : false;

    // Allow /api/auth/me, change-credentials and password change even if blocked so UI knows state
    const isAuthExempt = req.baseUrl === '/api/auth' && (
      req.path === '/me' ||
      req.path === '/password' ||
      req.path === '/profile' ||
      req.path === '/change-credentials' ||
      req.path === '/logout'
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
