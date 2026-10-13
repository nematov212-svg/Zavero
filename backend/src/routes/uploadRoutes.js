const express = require('express');
const multer = require('multer');
const router = express.Router();
const c = require('../controllers/uploadController');
const auth = require('../middleware/authMiddleware');

// Diqqat: rasm faylni serverning diskiga YOZMAYMIZ — Render'ning bepul
// rejasida disk vaqtinchalik (server qayta ishga tushganda tozalanadi).
// Shuning uchun rasmni xotirada (memory) ushlab, keyin ma'lumotlar
// bazasiga (doimiy) saqlaymiz — server qayta tiklansa ham yo'qolmaydi.
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: { fileSize: 4 * 1024 * 1024 }, // 4MB (bazada saqlanadigani uchun kichikroq limit)
  fileFilter: (req, file, cb) => {
    if (/^image\/(jpeg|png|webp|gif)$/.test(file.mimetype)) cb(null, true);
    else cb(new Error('Faqat rasm fayllari qabul qilinadi (jpg, png, webp, gif).'));
  },
});

router.post('/', auth, upload.single('image'), c.uploadImage);
router.get('/:id', c.getImage);
module.exports = router;
