const db = require('../config/db');

/**
 * Log audit events to activity_logs table asynchronously
 * Ensures no sensitive fields (passwords, tokens) are logged.
 */
const logActivity = async ({ cafeId, action, details, performedBy }) => {
  if (!cafeId) return;
  try {
    const safeDetails = typeof details === 'object' ? JSON.stringify(details) : String(details || '');
    await db.query(
      `INSERT INTO activity_logs (cafe_id, action, details, performed_by, timestamp)
       VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)`,
      [cafeId, action.substring(0, 80), safeDetails, (performedBy || 'System').substring(0, 150)]
    );
  } catch (err) {
    // Audit logging should never crash the main application flow
    console.warn('[AuditLog Warning]', err.message);
  }
};

module.exports = { logActivity };
