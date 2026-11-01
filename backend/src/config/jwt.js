// Centralized JWT configuration without hardcoded production secrets
const getJwtSecret = () => {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        "❌ [Security Error] JWT_SECRET muhit o'zgaruvchisi topilmadi! Production rejimida JWT_SECRET o'rnatilishi shart."
      );
    }
    // Only in local development fallback
    return 'zavero_local_dev_fallback_secret_key_only';
  }
  return secret;
};

// Access token: short-lived (15 minutes by default)
const getJwtAccessExpiresIn = () => {
  return process.env.JWT_ACCESS_EXPIRES_IN || '15m';
};

// Legacy alias
const getJwtExpiresIn = () => {
  return getJwtAccessExpiresIn();
};

module.exports = { getJwtSecret, getJwtAccessExpiresIn, getJwtExpiresIn };
