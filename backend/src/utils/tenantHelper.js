/**
 * Centralized Multi-Tenant Helper
 * Returns the strictly authenticated and authorized cafe_id.
 * Never blindly trusts unverified query, body, or headers.
 */
function getTenantCafeId(req) {
  if (!req || !req.user) return null;
  return req.user.cafeId || null;
}

module.exports = { getTenantCafeId };
