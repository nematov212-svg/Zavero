const requireRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Avtorizatsiyadan o'tilmagan. Token topilmadi.",
      });
    }

    // Director is SaaS Super-Admin, has access to all operational routes
    if (req.user.role === 'director') {
      return next();
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: "Ushbu amalni bajarish uchun sizda yetarli ruxsat yo'q.",
      });
    }

    next();
  };
};

const requireDirector = requireRoles('director');
const requireAdmin = requireRoles('admin', 'director');

module.exports = { requireRoles, requireDirector, requireAdmin };
