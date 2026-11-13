const requireRoles = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Avtorizatsiyadan o'tilmagan. Token topilmadi.",
      });
    }

    // Director roli faqat SaaS boshqaruviga ega, cafe operatsion marshrutlariga kira olmaydi
    if (req.user.role === 'director' && !allowedRoles.includes('director')) {
      return res.status(403).json({
        success: false,
        message: "Director roli cafe operatsion tizimiga (stollar, cheklar, buyurtmalar, xodimlar) to'g'ridan-to'g'ri kira olmaydi. Faqat SaaS boshqaruv huquqiga ega.",
      });
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
const requireAdmin = requireRoles('admin');
const requireCafeStaff = requireRoles('admin', 'cashier', 'waiter', 'chef', 'worker');

module.exports = { requireRoles, requireDirector, requireAdmin, requireCafeStaff };
