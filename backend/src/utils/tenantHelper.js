/**
 * Multi-Tenant Helper
 * Ensures strict cafe isolation for standard cafe accounts (admin, cashier, waiter, etc.)
 * while allowing SaaS Director to inspect and manage any cafe via x-cafe-id, query, or body.
 */
function getTenantCafeId(req) {
  if (!req || !req.user) return null;
  if (req.user.role === 'director') {
    const target = req.headers['x-cafe-id'] || req.query?.cafeId || req.body?.cafeId || req.user.cafeId;
    return target;
  }
  return req.user.cafeId;
}

module.exports = { getTenantCafeId };
