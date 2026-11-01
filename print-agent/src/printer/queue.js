const fs = require('fs');
const path = require('path');
const { sendNetworkRaw } = require('./network');
const { sendUsbRaw } = require('./usb');
const { sendBluetoothRaw } = require('./bluetooth');
const { decodeBase64Image, pngToEscPosRaster, buildTestReceiptBuffer } = require('./escpos');

const logFile = path.join(__dirname, '../../logs/agent.log');

function log(msg, level = 'INFO') {
  const line = `[${new Date().toISOString()}] [${level}] ${msg}\n`;
  console.log(line.trim());
  try {
    fs.appendFileSync(logFile, line);
  } catch (_) {}
}

class PrintQueue {
  constructor() {
    this.queue = [];
    this.isProcessing = false;
    this.recentJobs = new Map(); // jobId -> { timestamp, status, error }
  }

  isDuplicate(jobId) {
    if (!jobId) return false;
    const existing = this.recentJobs.get(jobId);
    if (!existing) return false;
    // Debounce within 60 seconds
    const diff = Date.now() - existing.timestamp;
    return diff < 60000;
  }

  getJob(jobId) {
    return this.recentJobs.get(jobId) || null;
  }

  async addJob(payload) {
    const { jobId, type, printerConfig, image, rawBytes, openDrawer } = payload;

    if (this.isDuplicate(jobId)) {
      log(`⚠️ Takroriy jobId rad etildi (dublikat himoyasi): ${jobId}`, 'WARN');
      return {
        success: true,
        jobId,
        duplicate: true,
        message: 'Chek allaqachon chiqarilgan (takroriy bosish oldi olindi)',
      };
    }

    const jobRecord = {
      id: jobId || `job_${Date.now()}`,
      type: type || 'xarid',
      status: 'queued',
      timestamp: Date.now(),
      error: null,
    };
    this.recentJobs.set(jobRecord.id, jobRecord);

    return new Promise((resolve) => {
      this.queue.push({
        payload,
        record: jobRecord,
        resolve,
      });
      this.processNext();
    });
  }

  async processNext() {
    if (this.isProcessing || this.queue.length === 0) return;
    this.isProcessing = true;

    const current = this.queue.shift();
    const { payload, record, resolve } = current;

    record.status = 'printing';
    log(`🖨️ Ish boshlandi: ${record.id} (${payload.type || 'xarid'})`);

    let result = { ok: false, error: 'Bajarilmadi' };
    const maxRetries = 3;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        result = await this.executePrint(payload);
        if (result.ok) break;
        log(`⚠️ Urinish ${attempt}/${maxRetries} muvaffaqiyatsiz bo‘ldi: ${result.error}`, 'WARN');
        if (attempt < maxRetries) {
          await new Promise((r) => setTimeout(r, 800));
        }
      } catch (err) {
        result = { ok: false, error: err.message };
        log(`❌ Xatolik (${attempt}/${maxRetries}): ${err.message}`, 'ERROR');
        if (attempt < maxRetries) {
          await new Promise((r) => setTimeout(r, 800));
        }
      }
    }

    if (result.ok) {
      record.status = 'done';
      record.completedAt = Date.now();
      log(`✅ Chek muvaffaqiyatli chiqarildi: ${record.id}`);
      resolve({ success: true, jobId: record.id, status: 'done' });
    } else {
      record.status = 'failed';
      record.error = result.error;
      log(`❌ Chek chiqarish yakunda xatolik bilan tugadi: ${record.id} - ${result.error}`, 'ERROR');
      resolve({ success: false, jobId: record.id, status: 'failed', error: result.error });
    }

    this.isProcessing = false;
    // Process next item in queue
    setImmediate(() => this.processNext());
  }

  async executePrint(payload) {
    const { printerConfig = {}, image, rawBytes, type, openDrawer } = payload;
    const connType = (printerConfig.type || 'wifi').toLowerCase();

    // 1. Prepare ESC/POS data buffer
    let dataBuffer;
    if (type === 'test') {
      dataBuffer = buildTestReceiptBuffer({
        type: connType,
        ip: printerConfig.ip,
        port: printerConfig.port,
        device: printerConfig.deviceId,
      });
    } else if (rawBytes) {
      dataBuffer = Buffer.isBuffer(rawBytes) ? rawBytes : Buffer.from(rawBytes);
    } else if (image) {
      const pngBuf = decodeBase64Image(image);
      if (!pngBuf) {
        return { ok: false, error: 'Yaroqli rasm ma‘lumotlari topilmadi' };
      }
      dataBuffer = await pngToEscPosRaster(pngBuf, {
        targetWidth: printerConfig.paperWidth === 58 ? 384 : 576,
        openDrawer: openDrawer === true,
      });
    } else {
      return { ok: false, error: 'Chop etish uchun ma‘lumot (image yoki rawBytes) berilmadi' };
    }

    // 2. Dispatch to transport
    if (connType === 'wifi' || connType === 'network' || connType === 'ip') {
      const ip = (printerConfig.ip || '').trim();
      const port = parseInt(printerConfig.port || 9100, 10);
      return sendNetworkRaw(ip, port, dataBuffer);
    } else if (connType === 'usb') {
      const deviceId = (printerConfig.deviceId || printerConfig.name || '').trim();
      return sendUsbRaw(deviceId, dataBuffer);
    } else if (connType === 'bluetooth' || connType === 'bt') {
      const deviceId = (printerConfig.deviceId || printerConfig.name || '').trim();
      return sendBluetoothRaw(deviceId, dataBuffer);
    } else {
      return { ok: false, error: `Noma‘lum ulanish turi: "${connType}". "wifi", "usb", yoki "bluetooth" bo‘lishi kerak.` };
    }
  }
}

module.exports = {
  PrintQueue,
  log,
};

