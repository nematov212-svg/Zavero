const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../config/jwt');

let ioInstance = null;

const cafeRoom = (cafeId) => `cafe_${cafeId}`;
const printerRoom = (cafeId) => `printer_${cafeId}`;

// Real-time Printer Stations Tracking (Cafe ID -> Set of socket.id)
const printerStationsByCafe = new Map();
// Deduplication cache: `${cafeId}_${jobId}` -> timestamp (5 second debounce)
const recentPrintJobs = new Map();

const getPrinterStationCount = (cafeId) => {
  if (!cafeId) return 0;
  const set = printerStationsByCafe.get(String(cafeId));
  return set ? set.size : 0;
};

const isJobDuplicate = (cafeId, jobId) => {
  if (!jobId) return false;
  const key = `${cafeId}_${jobId}`;
  const now = Date.now();
  const lastTime = recentPrintJobs.get(key);
  if (lastTime && (now - lastTime < 5000)) {
    return true;
  }
  recentPrintJobs.set(key, now);
  if (recentPrintJobs.size > 1000) {
    for (const [k, time] of recentPrintJobs.entries()) {
      if (now - time > 30000) recentPrintJobs.delete(k);
    }
  }
  return false;
};

const initSocket = (io) => {
  ioInstance = io;

  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (token) {
      try {
        const secret = getJwtSecret();
        const decoded = jwt.verify(token, secret);
        socket.user = decoded; // { id, username, cafeId }
      } catch (err) {
        console.warn('⚠️  [Socket.IO] Invalid token in handshake:', err.message);
      }
    }
    next();
  });

  io.on('connection', (socket) => {
    console.log(`🔌 [Socket.IO] Client connected: ${socket.id}`);

    if (socket.user?.role === 'director') {
      socket.join('director_room');
      console.log(`👑 [Socket.IO] Joined director_room`);
    }

    if (socket.user?.cafeId) {
      socket.join(cafeRoom(socket.user.cafeId));
      socket.emit('AUTHENTICATED', { success: true, cafeId: socket.user.cafeId });
      console.log(`👤 [Socket.IO] Auto-joined room ${cafeRoom(socket.user.cafeId)}`);
    }

    socket.on('JOIN_CAFE', (data) => {
      let joinCafeId = typeof data === 'string' ? data : (data?.cafeId || data?.id);
      let token = typeof data === 'object' ? data?.token : null;
      if (token) {
        try {
          const secret = getJwtSecret();
          const decoded = jwt.verify(token, secret);
          socket.user = decoded;
          if (decoded.role === 'director') {
            socket.join('director_room');
          }
        } catch (e) {
          console.error('[Socket.IO] JOIN_CAFE token error:', e.message);
          return socket.emit('ERROR', { success: false, message: 'Invalid token' });
        }
      }

      const role = socket.user?.role;
      const userCafeId = socket.user?.cafeId;

      if (role === 'director') {
        // SaaS Director can join any cafe room
        const targetCafe = joinCafeId || userCafeId;
        if (targetCafe) {
          socket.join(cafeRoom(targetCafe));
          socket.emit('JOINED_CAFE', { cafeId: targetCafe, success: true });
          console.log(`👑 [Socket.IO] Director joined room ${cafeRoom(targetCafe)}`);
        }
      } else if (userCafeId) {
        // Cafe users can ONLY join their own authorized cafe room
        if (joinCafeId && joinCafeId !== userCafeId) {
          console.warn(`🚨 [Socket.IO] Cross-tenant join blocked: user from ${userCafeId} attempted to join ${joinCafeId}`);
          return socket.emit('ERROR', { success: false, message: 'Unauthorized cafe room access' });
        }
        socket.join(cafeRoom(userCafeId));
        socket.emit('JOINED_CAFE', { cafeId: userCafeId, success: true });
        console.log(`👤 [Socket.IO] Joined room ${cafeRoom(userCafeId)}`);
      } else if (joinCafeId) {
        // Public QR Menu Guest client connecting for real-time menu & promo banner updates
        socket.join(cafeRoom(joinCafeId));
        socket.emit('JOINED_CAFE', { cafeId: joinCafeId, success: true, guest: true });
        console.log(`📱 [Socket.IO] Public QR Menu guest joined room ${cafeRoom(joinCafeId)}`);
      } else {
        // Unauthenticated client cannot join private cafe rooms
        return socket.emit('ERROR', { success: false, message: 'Authentication required' });
      }
    });

    socket.on('LEAVE_CAFE', ({ cafeId }) => {
      if (cafeId) {
        socket.leave(cafeRoom(cafeId));
        console.log(`👤 [Socket.IO] Left room ${cafeRoom(cafeId)}`);
      }
    });

    socket.on('PING', () => socket.emit('PONG', { time: new Date().toISOString() }));

    socket.on('STAFF_STATUS_UPDATE', (payload = {}) => {
      // SECURITY: Only emit to authorized cafe room
      const targetCafeId = socket.user?.role === 'director' ? (payload.cafeId || socket.user?.cafeId) : socket.user?.cafeId;
      if (!targetCafeId) {
        return socket.emit('ERROR', { message: 'Authentication required' });
      }
      notifyCafe(targetCafeId, 'STAFF_STATUS_UPDATED', payload);
      console.log(`☕ [Socket.IO] STAFF_STATUS_UPDATED for cafe ${targetCafeId}:`, payload.userName || payload.staffName, payload.statusText);
      try {
        const { sendGeneralTelegramNotification } = require('../bot/telegramBot');
        const isOnBreak = payload.isOnBreak === true;
        const uName = payload.userName || payload.staffName || 'Xodim';
        const uRole = payload.role === 'waiter' ? 'Ofitsiant' : (payload.role || 'Xodim');
        const statusDesc = isOnBreak ? '☕ Dam olishga chiqdi' : '🟢 Ishga qaytdi / Faol';
        sendGeneralTelegramNotification({
          cafeId: targetCafeId,
          title: `${statusDesc} — ${uName}`,
          message: `👤 <b>Xodim:</b> ${uName} (${uRole})\n📍 <b>Holat:</b> ${statusDesc}\n⏰ <b>Vaqt:</b> ${new Date().toLocaleTimeString('uz-UZ')}`,
        }).catch(() => { });
      } catch (_) { }
    });

    socket.on('STAFF_MOVEMENT_UPDATE', (payload = {}) => {
      const targetCafeId = socket.user?.role === 'director' ? (payload.cafeId || socket.user?.cafeId) : socket.user?.cafeId;
      if (targetCafeId) {
        notifyCafe(targetCafeId, 'STAFF_MOVEMENT_UPDATED', payload);
      }
    });

    socket.on('BANNERS_UPDATED', (payload = {}) => {
      const targetCafeId = socket.user?.role === 'director' ? (payload.cafeId || socket.user?.cafeId) : socket.user?.cafeId;
      if (targetCafeId) {
        notifyCafe(targetCafeId, 'BANNERS_UPDATED', payload);
        console.log(`📢 [Socket.IO] BANNERS_UPDATED forwarded to cafe ${targetCafeId}`);
      }
    });

    // ========================================================
    // CLOUD / STATION PRINTING REAL-TIME HANDLERS
    // ========================================================
    socket.on('REGISTER_PRINTER_STATION', (data = {}) => {
      const cafeId = socket.user?.cafeId || data.cafeId;
      if (!cafeId) return;
      const cafeStr = String(cafeId);
      socket.join(printerRoom(cafeStr));
      if (!printerStationsByCafe.has(cafeStr)) {
        printerStationsByCafe.set(cafeStr, new Set());
      }
      printerStationsByCafe.get(cafeStr).add(socket.id);
      socket.isPrinterStation = true;
      socket.printerCafeId = cafeStr;
      const count = printerStationsByCafe.get(cafeStr).size;
      console.log(`🖨️ [Socket.IO] Printer station registered for cafe ${cafeStr}: ${socket.id} (total: ${count})`);
      socket.emit('PRINTER_STATION_STATUS', { registered: true, cafeId: cafeStr, count });
    });

    socket.on('UNREGISTER_PRINTER_STATION', (data = {}) => {
      const cafeId = socket.user?.cafeId || data.cafeId || socket.printerCafeId;
      if (!cafeId) return;
      const cafeStr = String(cafeId);
      socket.leave(printerRoom(cafeStr));
      if (printerStationsByCafe.has(cafeStr)) {
        printerStationsByCafe.get(cafeStr).delete(socket.id);
      }
      socket.isPrinterStation = false;
      const count = printerStationsByCafe.get(cafeStr)?.size || 0;
      console.log(`🖨️ [Socket.IO] Printer station unregistered for cafe ${cafeStr}: ${socket.id} (remaining: ${count})`);
      socket.emit('PRINTER_STATION_STATUS', { registered: false, cafeId: cafeStr, count });
    });

    socket.on('REQUEST_PRINT_JOB', (job = {}, callback) => {
      const cafeId = socket.user?.cafeId || job.cafeId;
      if (!cafeId) {
        const res = { success: false, routedToStation: false, message: 'Kafeni aniqlab bo‘lmadi' };
        if (typeof callback === 'function') callback(res);
        return socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
      }
      const cafeStr = String(cafeId);
      const count = getPrinterStationCount(cafeStr);
      if (count === 0) {
        const res = { success: false, routedToStation: false, message: 'Printer qurilmasi ulanmagan' };
        if (typeof callback === 'function') callback(res);
        return socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
      }

      // 5-soniyalik deduplication tekshiruvi (takroriy bosish himoyasi)
      if (isJobDuplicate(cafeStr, job.id)) {
        console.log(`⚠️ [Socket.IO] Takroriy print job rad etildi: ${job.id}`);
        const res = { success: true, routedToStation: true, duplicate: true, message: 'Takroriy chek so‘rovi (5s debounced)' };
        if (typeof callback === 'function') callback(res);
        return socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
      }

      // Kassa printeri xonasiga yuborish
      ioInstance.to(printerRoom(cafeStr)).emit('EXECUTE_PRINT_JOB', {
        ...job,
        cafeId: cafeStr,
        timestamp: new Date().toISOString(),
      });
      console.log(`🖨️ [Socket.IO] Print job ${job.id || 'unknown'} (${job.type || 'receipt'}) forwarded to ${printerRoom(cafeStr)} (${count} stations)`);

      const res = { success: true, routedToStation: true, message: 'Chek kassa printeriga yuborildi va chop etilmoqda' };
      if (typeof callback === 'function') callback(res);
      socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
    });

    socket.on('disconnect', (reason) => {
      if (socket.printerCafeId && printerStationsByCafe.has(socket.printerCafeId)) {
        printerStationsByCafe.get(socket.printerCafeId).delete(socket.id);
        const rem = printerStationsByCafe.get(socket.printerCafeId).size;
        console.log(`🖨️ [Socket.IO] Printer station disconnected: ${socket.id} (remaining: ${rem})`);
      }
      console.log(`❌ [Socket.IO] Disconnected: ${socket.id} (${reason})`);
    });
  });
};

/** Broadcast an event to every device connected for a cafe (tablet + phone real-time sync). */
const notifyCafe = (cafeId, event, payload = {}) => {
  if (!ioInstance || !cafeId) return;
  const eventId = `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  const entityId = payload.tableId ? `table-${payload.tableId}` : (payload.id ? `${payload.id}` : `cafe-${cafeId}`);
  const entityVersion = payload.version || payload.table?.version || 1;
  const isoTime = new Date().toISOString();

  const data = {
    ...payload,
    eventId,
    eventType: event,
    entityId,
    entityVersion,
    timestamp: isoTime,
    payload: { ...payload },
  };

  ioInstance.to(cafeRoom(cafeId)).emit(event, data);
  console.log(`📡 [Socket.IO] '${event}' (${eventId}) -> ${cafeRoom(cafeId)}`);

  // Persist to outbox_events in background for reliable event auditing
  try {
    const db = require('../config/db');
    db.query(
      `INSERT INTO outbox_events (event_id, event_type, entity_id, entity_version, payload, status, processed_at)
       VALUES ($1, $2, $3, $4, $5, 'processed', CURRENT_TIMESTAMP)
       ON CONFLICT (event_id) DO NOTHING`,
      [eventId, event, entityId, entityVersion, JSON.stringify(payload)]
    ).catch(() => { });
  } catch (_) { }
};

/** Broadcast an event to director room. */
const notifyDirector = (event, payload = {}) => {
  if (!ioInstance) return;
  const data = { ...payload, timestamp: new Date().toISOString() };
  ioInstance.to('director_room').emit(event, data);
  ioInstance.emit(`DIRECTOR_${event}`, data);
  console.log(`📡 [Socket.IO] '${event}' -> director_room`);
};

const getIo = () => ioInstance;

module.exports = {
  initSocket,
  notifyCafe,
  notifyDirector,
  getIo,
  getPrinterStationCount,
  isJobDuplicate,
  printerRoom,
};
