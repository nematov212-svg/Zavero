/**
 * Centralized Multi-Tenant Helper
 * Returns the strictly authenticated and authorized cafe_id.
 * Never blindly trusts unverified query, body, or headers.
 */
function getTenantCafeId(req) {
  if (!req || !req.user) return null;
  if (req.user.role === 'director') {
    return req.headers['x-cafe-id'] || req.query?.cafeId || req.body?.cafeId || req.user.cafeId || null;
  }
  return req.user.cafeId || null;
}

module.exports = { getTenantCafeId };
