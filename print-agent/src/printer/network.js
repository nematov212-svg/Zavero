const net = require('net');
const { CMD } = require('./escpos');

/**
 * Validates IPv4 address string
 */
function isValidIpv4(ip) {
  if (!ip || typeof ip !== 'string') return false;
  const parts = ip.trim().split('.');
  if (parts.length !== 4) return false;
  return parts.every((p) => {
    const n = parseInt(p, 10);
    return !isNaN(n) && n >= 0 && n <= 255 && String(n) === p;
  });
}

/**
 * Sends a raw buffer to a network thermal printer via TCP socket
 * @param {string} ip 
 * @param {number} port 
 * @param {Buffer} dataBuffer 
 * @param {number} timeoutMs 
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
function sendNetworkRaw(ip, port = 9100, dataBuffer, timeoutMs = 5000) {
  return new Promise((resolve) => {
    if (!isValidIpv4(ip)) {
      return resolve({
        ok: false,
        error: `Noto‘g‘ri IP-manzil: "${ip}". To‘g‘ri format: masalan 192.168.1.100`,
      });
    }

    const socket = new net.Socket();
    let isResolved = false;

    const cleanupAndResolve = (result) => {
      if (isResolved) return;
      isResolved = true;
      try {
        socket.destroy();
      } catch (_) {}
      resolve(result);
    };

    socket.setTimeout(timeoutMs);

    socket.on('connect', () => {
      socket.write(dataBuffer, () => {
        // Allow a small pause for printer reception before closing
        setTimeout(() => {
          cleanupAndResolve({ ok: true });
        }, 120);
      });
    });

    socket.on('timeout', () => {
      cleanupAndResolve({
        ok: false,
        error: `Printerdan javob yo‘q (${ip}:${port}). Timeout (${timeoutMs / 1000}s). Printer yoqilganmi va bir xil Wi-Fi tarmog‘idami?`,
      });
    });

    socket.on('error', (err) => {
      let msg = err.message || 'Noma\'lum xatolik';
      if (err.code === 'ECONNREFUSED') {
        msg = `Ulanish rad etildi (${ip}:${port}). 9100 port yopiq yoki printerning IP manzili noto‘g‘ri.`;
      } else if (err.code === 'EHOSTUNREACH' || err.code === 'ENETUNREACH') {
        msg = `Printerning IP-manzili (${ip}) tarmoqda topilmadi. Kompyuter va printer bir xil Wi-Fi tarmog‘idami?`;
      } else if (err.code === 'ETIMEDOUT') {
        msg = `Printerga ulanish vaqti tugadi (${ip}:${port}).`;
      }
      cleanupAndResolve({ ok: false, error: msg });
    });

    try {
      socket.connect(port, ip.trim());
    } catch (err) {
      cleanupAndResolve({ ok: false, error: err.message });
    }
  });
}

/**
 * Tests connection to a network thermal printer and measures latency
 * @param {string} ip 
 * @param {number} port 
 * @param {number} timeoutMs 
 * @returns {Promise<{ ok: boolean, latencyMs?: number, error?: string, statusText?: string }>}
 */
function testNetworkConnection(ip, port = 9100, timeoutMs = 3000) {
  return new Promise((resolve) => {
    if (!isValidIpv4(ip)) {
      return resolve({
        ok: false,
        error: `Noto‘g‘ri IP-manzil: "${ip}". To‘g‘ri format: 192.168.x.x`,
      });
    }

    const start = Date.now();
    const socket = new net.Socket();
    let isResolved = false;

    const cleanupAndResolve = (result) => {
      if (isResolved) return;
      isResolved = true;
      try {
        socket.destroy();
      } catch (_) {}
      resolve(result);
    };

    socket.setTimeout(timeoutMs);

    socket.on('connect', () => {
      const latencyMs = Date.now() - start;
      // Send DLE EOT 1 status query
      socket.write(CMD.STATUS_QUERY, () => {
        // Small delay to read any status byte if printer supports two-way DLE EOT
        setTimeout(() => {
          cleanupAndResolve({
            ok: true,
            latencyMs,
            statusText: `Ulangan (${latencyMs} ms)`,
          });
        }, 80);
      });
    });

    socket.on('data', (data) => {
      const latencyMs = Date.now() - start;
      const statusByte = data[0];
      let statusDetail = 'Tayyor';
      if (statusByte !== undefined) {
        if (statusByte & 0x08) statusDetail = 'Offline';
        if (statusByte & 0x20) statusDetail = 'Qopqoq ochiq';
      }
      cleanupAndResolve({
        ok: true,
        latencyMs,
        statusText: `Ulangan (${latencyMs} ms, ${statusDetail})`,
      });
    });

    socket.on('timeout', () => {
      cleanupAndResolve({
        ok: false,
        error: `Printer javob bermadi (${ip}:${port}) - timeout 3s. Printer yoqilganmi va IP to‘g‘rimi?`,
      });
    });

    socket.on('error', (err) => {
      let msg = err.message || 'Ulanishda xato';
      if (err.code === 'ECONNREFUSED') {
        msg = `Port ${port} rad etildi. IP ${ip} bo‘yicha printer topilmadi yoki port noto‘g‘ri.`;
      } else if (err.code === 'EHOSTUNREACH' || err.code === 'ENETUNREACH') {
        msg = `IP ${ip} tarmoqda topilmadi. IP manzilini tekshiring.`;
      }
      cleanupAndResolve({ ok: false, error: msg });
    });

    try {
      socket.connect(port, ip.trim());
    } catch (err) {
      cleanupAndResolve({ ok: false, error: err.message });
    }
  });
}

module.exports = {
  isValidIpv4,
  sendNetworkRaw,
  testNetworkConnection,
};
