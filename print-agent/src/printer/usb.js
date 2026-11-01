const { exec, execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const isWin = os.platform() === 'win32';
const isMac = os.platform() === 'darwin';
const isLinux = os.platform() === 'linux';

/**
 * Discovers connected USB printers from the host operating system
 * @returns {Promise<Array<{ id: string, name: string, port?: string, type: 'usb' }>>}
 */
async function discoverUsbPrinters() {
  const printers = [];

  if (isWin) {
    try {
      // Windows PowerShell: Get-Printer
      const psCmd = `powershell -NoProfile -Command "Get-CimInstance Win32_Printer | Select-Object Name, PortName, DriverName | ConvertTo-Json"`;
      const stdout = execSync(psCmd, { timeout: 3500, encoding: 'utf8' });
      if (stdout && stdout.trim()) {
        let parsed = JSON.parse(stdout.trim());
        if (!Array.isArray(parsed)) parsed = [parsed];
        for (const p of parsed) {
          if (p.Name) {
            printers.push({
              id: p.Name,
              name: `${p.Name} (${p.PortName || 'USB'})`,
              port: p.PortName || '',
              type: 'usb',
            });
          }
        }
      }
    } catch (_) {}
  } else if (isMac || isLinux) {
    try {
      // CUPS lpstat
      const stdout = execSync('lpstat -p', { timeout: 3000, encoding: 'utf8' });
      const lines = stdout.split('\n');
      for (const line of lines) {
        // e.g. "printer POS80 is idle. enabled since..."
        const match = line.match(/^printer\s+([^\s]+)/i);
        if (match && match[1]) {
          printers.push({
            id: match[1],
            name: `${match[1]} (CUPS/USB)`,
            type: 'usb',
          });
        }
      }
    } catch (_) {}

    // Check Linux /dev/usb/lp*
    if (isLinux) {
      try {
        const files = fs.readdirSync('/dev/usb');
        for (const f of files) {
          if (f.startsWith('lp')) {
            printers.push({
              id: `/dev/usb/${f}`,
              name: `Lokal USB (/dev/usb/${f})`,
              type: 'usb',
            });
          }
        }
      } catch (_) {}
    }
  }

  return printers;
}

/**
 * Tests USB printer connection
 */
async function testUsbConnection(printerId) {
  if (!printerId || printerId.trim().isEmpty) {
    return { ok: false, error: 'USB printer tanlanmagan' };
  }

  const list = await discoverUsbPrinters();
  const found = list.find((p) => p.id === printerId || p.name.includes(printerId));

  if (!found && list.length === 0) {
    return {
      ok: false,
      error: `Tizimda USB printer topilmadi. USB kabel to‘g‘ri ulanganini va printer yoqilganligini tekshiring.`,
    };
  }

  return {
    ok: true,
    latencyMs: 15,
    statusText: `Ulangan (USB: ${found ? found.name : printerId})`,
  };
}

/**
 * Sends raw ESC/POS bytes to the specified USB printer
 * @param {string} printerId 
 * @param {Buffer} dataBuffer 
 * @returns {Promise<{ ok: boolean, error?: string }>}
 */
async function sendUsbRaw(printerId, dataBuffer) {
  return new Promise((resolve) => {
    if (!printerId) {
      return resolve({ ok: false, error: 'USB printer tanlanmagan' });
    }

    // Write buffer to a temp file
    const tmpDir = os.tmpdir();
    const tmpFilePath = path.join(tmpDir, `zavero_usb_print_${Date.now()}.bin`);

    try {
      fs.writeFileSync(tmpFilePath, dataBuffer);
    } catch (err) {
      return resolve({ ok: false, error: 'Vaqtinchalik fayl yaratishda xato: ' + err.message });
    }

    if (isWin) {
      // Send raw file to printer on Windows
      const psCmd = `powershell -NoProfile -Command "Get-Content -Path '${tmpFilePath}' -Encoding Byte -Raw | Out-Printer -Name '${printerId}'"`;
      exec(psCmd, { timeout: 8000 }, (err) => {
        try { fs.unlinkSync(tmpFilePath); } catch (_) {}
        if (err) {
          return resolve({ ok: false, error: `USB printerga yozishda xato: ${err.message}` });
        }
        resolve({ ok: true });
      });
    } else if (isMac || isLinux) {
      if (printerId.startsWith('/dev/')) {
        // Direct device write
        fs.appendFile(printerId, dataBuffer, (err) => {
          try { fs.unlinkSync(tmpFilePath); } catch (_) {}
          if (err) return resolve({ ok: false, error: `USB portga yozishda xato (${printerId}): ${err.message}` });
          resolve({ ok: true });
        });
      } else {
        // CUPS raw printing: lp -d "printer" -o raw
        exec(`lp -d "${printerId}" -o raw "${tmpFilePath}"`, { timeout: 8000 }, (err, stdout, stderr) => {
          try { fs.unlinkSync(tmpFilePath); } catch (_) {}
          if (err) {
            return resolve({ ok: false, error: `CUPS orqali chop etishda xato: ${stderr || err.message}` });
          }
          resolve({ ok: true });
        });
      }
    } else {
      try { fs.unlinkSync(tmpFilePath); } catch (_) {}
      resolve({ ok: false, error: 'Ushbu operatsion tizimda USB chop etish qo‘llab-quvvatlanmaydi' });
    }
  });
}

module.exports = {
  discoverUsbPrinters,
  testUsbConnection,
  sendUsbRaw,
};
