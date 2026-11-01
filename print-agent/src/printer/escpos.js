const { PNG } = require('pngjs');

// ESC/POS Command Constants
const ESC = 0x1B;
const GS = 0x1D;

const CMD = {
  INIT: Buffer.from([ESC, 0x40]), // ESC @
  ALIGN_LEFT: Buffer.from([ESC, 0x61, 0x00]),
  ALIGN_CENTER: Buffer.from([ESC, 0x61, 0x01]),
  ALIGN_RIGHT: Buffer.from([ESC, 0x61, 0x02]),
  BOLD_ON: Buffer.from([ESC, 0x45, 0x01]),
  BOLD_OFF: Buffer.from([ESC, 0x45, 0x00]),
  DOUBLE_ON: Buffer.from([GS, 0x21, 0x11]),
  DOUBLE_OFF: Buffer.from([GS, 0x21, 0x00]),
  FEED_LINES: (n) => Buffer.from([ESC, 0x64, n]),
  CUT: Buffer.from([GS, 0x56, 0x42, 0x00]), // GS V 66 0 (Feed and partial cut)
  DRAWER_KICK: Buffer.from([ESC, 0x70, 0x00, 0x19, 0xFA]), // ESC p 0 25 250
  STATUS_QUERY: Buffer.from([0x10, 0x04, 0x01]), // DLE EOT 1: Printer status
  STATUS_OFFLINE_QUERY: Buffer.from([0x10, 0x04, 0x02]), // DLE EOT 2: Offline status
  STATUS_ERROR_QUERY: Buffer.from([0x10, 0x04, 0x03]), // DLE EOT 3: Error status
  STATUS_PAPER_QUERY: Buffer.from([0x10, 0x04, 0x04]), // DLE EOT 4: Roll paper status
};

/**
 * Decode Base64 Data URL or raw base64 to Buffer
 */
function decodeBase64Image(dataUrl) {
  if (typeof dataUrl !== 'string') return null;
  const match = dataUrl.match(/^data:image\/\w+;base64,(.+)$/);
  const base64Str = match ? match[1] : dataUrl;
  return Buffer.from(base64Str, 'base64');
}

/**
 * Parse a PNG buffer and convert to ESC/POS Raster bit-image (GS v 0)
 * Cropping empty rows at the bottom to eliminate trailing blank space.
 * @param {Buffer} pngBuffer 
 * @param {Object} options { targetWidth: 576, dither: true }
 * @returns {Promise<Buffer>}
 */
async function pngToEscPosRaster(pngBuffer, options = {}) {
  return new Promise((resolve, reject) => {
    new PNG().parse(pngBuffer, (err, png) => {
      if (err) return reject(new Error('PNG faylini o‘qishda xatolik: ' + err.message));

      const width = png.width;
      const height = png.height;

      // Ensure width is multiple of 8
      const widthBytes = Math.ceil(width / 8);
      const paddedWidth = widthBytes * 8;

      // Convert pixels to greyscale luminance (0-255)
      const greyscale = new Float32Array(width * height);
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const idx = (width * y + x) << 2;
          const r = png.data[idx];
          const g = png.data[idx + 1];
          const b = png.data[idx + 2];
          const a = png.data[idx + 3];

          // Treat transparent / semi-transparent pixels as white
          if (a < 128) {
            greyscale[width * y + x] = 255;
          } else {
            // Perceived luminance formula
            greyscale[width * y + x] = 0.299 * r + 0.587 * g + 0.114 * b;
          }
        }
      }

      // Floyd-Steinberg Error Diffusion Dithering for sharp, clear text and QR codes
      const dithered = new Uint8Array(width * height);
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const i = width * y + x;
          const oldPixel = greyscale[i];
          const newPixel = oldPixel < 160 ? 0 : 255; // 0 = black, 255 = white
          dithered[i] = newPixel === 0 ? 1 : 0; // 1 = print dot (black), 0 = white

          const errVal = oldPixel - newPixel;
          if (x + 1 < width) greyscale[i + 1] += (errVal * 7) / 16;
          if (x - 1 >= 0 && y + 1 < height) greyscale[i + width - 1] += (errVal * 3) / 16;
          if (y + 1 < height) greyscale[i + width] += (errVal * 5) / 16;
          if (x + 1 < width && y + 1 < height) greyscale[i + width + 1] += (errVal * 1) / 16;
        }
      }

      // Find last non-empty row (bottom trim)
      let lastNonEmptyRow = height - 1;
      while (lastNonEmptyRow > 10) {
        let hasBlack = false;
        for (let x = 0; x < width; x++) {
          if (dithered[width * lastNonEmptyRow + x] === 1) {
            hasBlack = true;
            break;
          }
        }
        if (hasBlack) break;
        lastNonEmptyRow--;
      }

      // Add small 4-pixel margin below last printed content
      const effectiveHeight = Math.min(height, lastNonEmptyRow + 5);

      // Pack bits into bytes for ESC/POS GS v 0
      // Command format: GS v 0 m xL xH yL yH d1...dk
      // m = 0 (Normal), xL/xH = width in bytes, yL/yH = height in dots
      const xL = widthBytes & 0xff;
      const xH = (widthBytes >> 8) & 0xff;
      const yL = effectiveHeight & 0xff;
      const yH = (effectiveHeight >> 8) & 0xff;

      const header = Buffer.from([GS, 0x76, 0x30, 0x00, xL, xH, yL, yH]);
      const rasterData = Buffer.alloc(widthBytes * effectiveHeight);

      let byteOffset = 0;
      for (let y = 0; y < effectiveHeight; y++) {
        for (let b = 0; b < widthBytes; b++) {
          let byteVal = 0;
          for (let bit = 0; bit < 8; bit++) {
            const x = b * 8 + bit;
            if (x < width) {
              if (dithered[width * y + x] === 1) {
                byteVal |= 0x80 >> bit;
              }
            }
          }
          rasterData[byteOffset++] = byteVal;
        }
      }

      const totalBuffer = Buffer.concat([
        CMD.INIT,
        CMD.ALIGN_CENTER,
        header,
        rasterData,
        CMD.FEED_LINES(3),
        options.openDrawer ? CMD.DRAWER_KICK : Buffer.alloc(0),
        CMD.CUT,
      ]);

      resolve(totalBuffer);
    });
  });
}

/**
 * Generate a standard test receipt for connection verification
 */
function buildTestReceiptBuffer(info = {}) {
  const parts = [];
  parts.push(CMD.INIT);
  parts.push(CMD.ALIGN_CENTER);
  parts.push(CMD.DOUBLE_ON);
  parts.push(CMD.BOLD_ON);
  parts.push(Buffer.from('ZAVERO POS\n', 'utf8'));
  parts.push(CMD.DOUBLE_OFF);
  parts.push(Buffer.from('--- TEST CHEKI ---\n', 'utf8'));
  parts.push(CMD.BOLD_OFF);
  parts.push(Buffer.from('Ulanish turi: ' + (info.type || 'Wi-Fi').toUpperCase() + '\n', 'utf8'));
  if (info.ip) parts.push(Buffer.from('IP: ' + info.ip + ':' + (info.port || 9100) + '\n', 'utf8'));
  if (info.device) parts.push(Buffer.from('Qurilma: ' + info.device + '\n', 'utf8'));
  parts.push(Buffer.from('Sana: ' + new Date().toLocaleString('uz-UZ') + '\n', 'utf8'));
  parts.push(Buffer.from('Holat: PRINTER ISHLAYAPTI OK\n', 'utf8'));
  parts.push(Buffer.from('--------------------------------\n', 'utf8'));
  parts.push(CMD.FEED_LINES(4));
  parts.push(CMD.CUT);
  return Buffer.concat(parts);
}

module.exports = {
  CMD,
  decodeBase64Image,
  pngToEscPosRaster,
  buildTestReceiptBuffer,
};
