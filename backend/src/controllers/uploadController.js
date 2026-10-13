const db = require('../config/db');

// POST /api/upload — multipart image upload. Rasm faylning o'zi (bytelar)
// PostgreSQL bazasiga saqlanadi (Render'ning vaqtinchalik diskiga emas),
// shuning uchun server qayta ishga tushsa/uyg'onsa ham rasm yo'qolmaydi.
const uploadImage = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'Fayl yuborilmadi.' });
  }
  try {
    const cafeId = req.user?.cafeId || req.headers['x-cafe-id'] || null;
    const result = await db.query(
      'INSERT INTO images (mime_type, data, cafe_id) VALUES ($1, $2, $3) RETURNING id',
      [req.file.mimetype, req.file.buffer, cafeId]
    );
    const id = result.rows[0].id;
    const rawProto = req.headers['x-forwarded-proto'] || (req.secure ? 'https' : req.protocol);
    const host = req.get('host') || '';
    const scheme = (host.includes('onrender.com') || rawProto === 'https') ? 'https' : rawProto;
    const url = process.env.APP_URL
      ? `${process.env.APP_URL.replace(/\/$/, '')}/api/upload/${id}`
      : `${scheme}://${host}/api/upload/${id}`;
    return res.status(201).json({ success: true, url });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Rasmni saqlashda xatolik: ' + error.message });
  }
};

// GET /api/upload/:id — bazada saqlangan rasmni qaytaradi.
const getImage = async (req, res) => {
  try {
    const result = await db.query('SELECT mime_type, data FROM images WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).send('Rasm topilmadi.');
    }
    const { mime_type, data } = result.rows[0];
    res.set('Content-Type', mime_type);
    res.set('Cache-Control', 'public, max-age=31536000, immutable');
    return res.send(data);
  } catch (error) {
    return res.status(500).send('Xatolik: ' + error.message);
  }
};

module.exports = { uploadImage, getImage };
