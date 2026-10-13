const db = require('../config/db');

// Default fallback version info
let memoryAppVersion = {
  version: '1.0.0',
  buildNumber: 1,
  downloadUrl: 'https://github.com/mirzobek/zavero/releases/latest',
  forceUpdate: false,
  releaseNotes: "ZAVERO POS ilovasining yangi versiyasi tayyor.",
};

// GET /api/app/version (Public or Authenticated)
const getAppVersion = async (req, res) => {
  try {
    const dbRes = await db.query(
      `SELECT data FROM settings WHERE cafe_id = 'zavero_system_app_version'`
    );
    if (dbRes.rows.length > 0 && dbRes.rows[0].data) {
      const data = typeof dbRes.rows[0].data === 'string'
        ? JSON.parse(dbRes.rows[0].data)
        : dbRes.rows[0].data;
      return res.json({ success: true, ...data });
    }
  } catch (e) {
    console.warn('getAppVersion DB query error, using memory fallback:', e.message);
  }

  return res.json({ success: true, ...memoryAppVersion });
};

// PUT /api/director/app-version (Director Only)
const setAppVersion = async (req, res) => {
  try {
    const { version, buildNumber, downloadUrl, forceUpdate, releaseNotes } = req.body;

    const newConfig = {
      version: version || memoryAppVersion.version,
      buildNumber: buildNumber !== undefined ? parseInt(buildNumber, 10) : memoryAppVersion.buildNumber,
      downloadUrl: downloadUrl || memoryAppVersion.downloadUrl,
      forceUpdate: !!forceUpdate,
      releaseNotes: releaseNotes || memoryAppVersion.releaseNotes,
      updatedAt: new Date().toISOString(),
    };

    memoryAppVersion = { ...newConfig };

    try {
      await db.query(
        `INSERT INTO settings (cafe_id, data)
         VALUES ('zavero_system_app_version', $1)
         ON CONFLICT (cafe_id) DO UPDATE SET data = $1`,
        [JSON.stringify(newConfig)]
      );
    } catch (dbErr) {
      console.warn('Saving app version to DB warning:', dbErr.message);
    }

    return res.json({
      success: true,
      message: 'Ilova versiyasi muvaffaqiyatli yangilandi.',
      appVersion: newConfig,
    });
  } catch (error) {
    console.error('setAppVersion error:', error);
    return res.status(500).json({ success: false, message: 'Serverda xatolik: ' + error.message });
  }
};

module.exports = { getAppVersion, setAppVersion };
