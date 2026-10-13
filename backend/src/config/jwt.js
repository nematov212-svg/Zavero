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

const getJwtExpiresIn = () => {
  return process.env.JWT_EXPIRES_IN || '30d';
};

module.exports = { getJwtSecret, getJwtExpiresIn };
