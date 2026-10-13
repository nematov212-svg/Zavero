const rateLimit = require('express-rate-limit');

// 1. Strict rate limiter for Authentication & Login endpoints (Prevents brute force & password guessing)
const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15, // Max 15 attempts per 15 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: "Juda ko'p urinishlar amalga oshirildi. Iltimos, 15 daqiqadan so'ng qayta urinib ko'ring.",
  },
});

// 2. Public QR Order Rate Limiter (Prevents spamming restaurant kitchen with fake orders)
const publicOrderRateLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 20, // Max 20 orders per 5 minutes per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: "Qisqa vaqt ichida juda ko'p buyurtma yuborildi. Iltimos, bir oz kutib qayta urinib ko'ring.",
  },
});

// 3. Public QR Menu Reading Rate Limiter (Prevents scraping / DoS)
const publicMenuRateLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 120, // Max 120 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: "Juda ko'p so'rov yuborildi. Iltimos, kuting.",
  },
});

// 4. Global API Rate Limiter
const generalApiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 300, // Max 300 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: "Tizimga juda ko'p so'rovlar kelmoqda. Iltimos, birozdan so'ng qayta urinib ko'ring.",
  },
});

module.exports = {
  authRateLimiter,
  publicOrderRateLimiter,
  publicMenuRateLimiter,
  generalApiLimiter,
};
