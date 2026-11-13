const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../config/jwt');
const db = require('../config/db');

let ioInstance = null;

const cafeRoom = (cafeId) => `cafe_${cafeId}`;
const printerRoom = (cafeId) => `printer_${cafeId}`;

// Real-time Printer Stations Tracking (Cafe ID -> Map of socket.id -> station details)
const printerStationDetailsByCafe = new Map();
// Deduplication cache: `${cafeId}_${jobId}` -> timestamp (5 second debounce)
const recentPrintJobs = new Map();

// Active Sockets per Cafe (cafeId -> Set of socket.id) for Online/Offline presence tracking
const activeSocketsByCafe = new Map();

const getActiveCafePresence = () => {
  const presence = {};
  let onlineCount = 0;
  for (const [cId, sockets] of activeSocketsByCafe.entries()) {
    if (sockets && sockets.size > 0) {
      presence[cId] = true;
      onlineCount++;
    } else {
      presence[cId] = false;
    }
  }
  return { presence, onlineCount };
};

const broadcastPresenceToDirector = () => {
  const { presence, onlineCount } = getActiveCafePresence();
  notifyDirector('CAFE_PRESENCE_UPDATED', { presence, onlineCount });
};

const registerCafeSocket = (cId, sId) => {
  if (!cId || cId === 'zavero') return;
  const cStr = String(cId);
  if (!activeSocketsByCafe.has(cStr)) activeSocketsByCafe.set(cStr, new Set());
  activeSocketsByCafe.get(cStr).add(sId);
  broadcastPresenceToDirector();
};

const unregisterCafeSocket = (cId, sId) => {
  if (!cId) return;
  const cStr = String(cId);
  if (activeSocketsByCafe.has(cStr)) {
    activeSocketsByCafe.get(cStr).delete(sId);
    if (activeSocketsByCafe.get(cStr).size === 0) {
      activeSocketsByCafe.delete(cStr);
    }
    broadcastPresenceToDirector();
  }
};

const getActiveStationInfo = (cafeId) => {
  if (!cafeId) return { hasStation: false, stationCount: 0, stationName: null, isPrinterReady: false };
  const cafeStr = String(cafeId);
  const map = printerStationDetailsByCafe.get(cafeStr);
  if (!map || map.size === 0) {
    return { hasStation: false, stationCount: 0, stationName: null, isPrinterReady: false };
  }
  const now = Date.now();
  let validCount = 0;
  let activeName = null;
  let anyReady = false;
  for (const [sId, info] of map.entries()) {
    // If heartbeat received within last 12 seconds
    if (now - info.lastHeartbeat < 12000) {
      validCount++;
      activeName = info.stationName || activeName || 'Kassa stansiyasi';
      if (info.isPrinterReady) anyReady = true;
    } else {
      map.delete(sId);
    }
  }
  return {
    hasStation: validCount > 0,
    stationCount: validCount,
    stationName: activeName,
    isPrinterReady: anyReady,
  };
};

const getPrinterStationCount = (cafeId) => {
  return getActiveStationInfo(cafeId).stationCount;
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
      const currentPresence = getActiveCafePresence();
      socket.emit('CAFE_PRESENCE_UPDATED', currentPresence);
      console.log(`👑 [Socket.IO] Joined director_room (Online cafelar: ${currentPresence.onlineCount})`);
    }

    if (socket.user?.cafeId) {
      const uCid = socket.user.cafeId;
      socket.join(cafeRoom(uCid));
      socket.joinedCafeId = uCid;
      registerCafeSocket(uCid, socket.id);
      socket.emit('AUTHENTICATED', { success: true, cafeId: uCid });
      console.log(`👤 [Socket.IO] Auto-joined room ${cafeRoom(uCid)}`);
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
        socket.joinedCafeId = userCafeId;
        registerCafeSocket(userCafeId, socket.id);
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
        unregisterCafeSocket(cafeId, socket.id);
        if (socket.joinedCafeId === cafeId) socket.joinedCafeId = null;
        console.log(`👤 [Socket.IO] Left room ${cafeRoom(cafeId)}`);
      }
    });

    socket.on('PING', () => {
      socket.emit('PONG', { time: new Date().toISOString() });
      const cid = socket.user?.cafeId;
      if (cid && cid !== 'zavero' && cid !== 'local_default') {
        db.query(
          `UPDATE cafes 
           SET online_since = CASE 
                 WHEN last_seen IS NULL OR last_seen < CURRENT_TIMESTAMP - INTERVAL '60 seconds' 
                 THEN CURRENT_TIMESTAMP 
                 ELSE COALESCE(online_since, CURRENT_TIMESTAMP) 
               END,
               last_seen = CURRENT_TIMESTAMP
           WHERE cafe_id = $1`,
          [cid]
        ).catch(() => {});
      }
    });

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
      if (!printerStationDetailsByCafe.has(cafeStr)) {
        printerStationDetailsByCafe.set(cafeStr, new Map());
      }
      const stationName = data.stationName || 'Kassa stansiyasi';
      const isPrinterReady = data.isPrinterReady !== false;
      printerStationDetailsByCafe.get(cafeStr).set(socket.id, {
        socketId: socket.id,
        stationName,
        isPrinterReady,
        lastHeartbeat: Date.now(),
      });
      socket.isPrinterStation = true;
      socket.printerCafeId = cafeStr;
      socket.stationName = stationName;
      const info = getActiveStationInfo(cafeStr);
      console.log(`🖨️ [Socket.IO] Printer station registered for cafe ${cafeStr}: ${socket.id} (${stationName}, ready: ${isPrinterReady})`);
      socket.emit('PRINTER_STATION_STATUS', { registered: true, cafeId: cafeStr, ...info });
      // Broadcast station status to all waiter/mobile devices in cafe
      notifyCafe(cafeStr, 'PRINTER_STATION_STATUS_CHANGED', info);
    });

    socket.on('PRINTER_STATION_HEARTBEAT', (data = {}) => {
      const cafeId = socket.user?.cafeId || data.cafeId || socket.printerCafeId;
      if (!cafeId) return;
      const cafeStr = String(cafeId);
      if (!printerStationDetailsByCafe.has(cafeStr)) {
        printerStationDetailsByCafe.set(cafeStr, new Map());
      }
      const stationName = data.stationName || socket.stationName || 'Kassa stansiyasi';
      const isPrinterReady = data.isPrinterReady !== false;
      const prevInfo = getActiveStationInfo(cafeStr);
      printerStationDetailsByCafe.get(cafeStr).set(socket.id, {
        socketId: socket.id,
        stationName,
        isPrinterReady,
        lastHeartbeat: Date.now(),
      });
      if (prevInfo.isPrinterReady !== isPrinterReady) {
        notifyCafe(cafeStr, 'PRINTER_STATION_STATUS_CHANGED', getActiveStationInfo(cafeStr));
      }
    });

    socket.on('UNREGISTER_PRINTER_STATION', (data = {}) => {
      const cafeId = socket.user?.cafeId || data.cafeId || socket.printerCafeId;
      if (!cafeId) return;
      const cafeStr = String(cafeId);
      socket.leave(printerRoom(cafeStr));
      if (printerStationDetailsByCafe.has(cafeStr)) {
        printerStationDetailsByCafe.get(cafeStr).delete(socket.id);
      }
      socket.isPrinterStation = false;
      const info = getActiveStationInfo(cafeStr);
      console.log(`🖨️ [Socket.IO] Printer station unregistered for cafe ${cafeStr}: ${socket.id} (remaining: ${info.stationCount})`);
      socket.emit('PRINTER_STATION_STATUS', { registered: false, cafeId: cafeStr, ...info });
      notifyCafe(cafeStr, 'PRINTER_STATION_STATUS_CHANGED', info);
    });

    socket.on('REQUEST_PRINT_JOB', (job = {}, callback) => {
      const cafeId = socket.user?.cafeId || job.cafeId;
      if (!cafeId) {
        const res = { success: false, routedToStation: false, message: 'Kafeni aniqlab bo‘lmadi' };
        if (typeof callback === 'function') callback(res);
        return socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
      }
      const cafeStr = String(cafeId);
      const stationInfo = getActiveStationInfo(cafeStr);
      if (!stationInfo.hasStation || !stationInfo.isPrinterReady) {
        const res = {
          success: false,
          routedToStation: false,
          hasActiveStation: false,
          message: 'Kassa printeri oflayn yoki ulanmagan',
        };
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
      console.log(`🖨️ [Socket.IO] Print job ${job.id || 'unknown'} (${job.type || 'receipt'}) forwarded to ${printerRoom(cafeStr)} (${stationInfo.stationName})`);

      const res = { success: true, routedToStation: true, hasActiveStation: true, message: 'Chek kassa printeriga yuborildi' };
      if (typeof callback === 'function') callback(res);
      socket.emit('PRINT_JOB_RESULT', { id: job.id, ...res });
    });

    socket.on('disconnect', (reason) => {
      if (socket.joinedCafeId) {
        unregisterCafeSocket(socket.joinedCafeId, socket.id);
        socket.joinedCafeId = null;
      }
      if (socket.printerCafeId && printerStationDetailsByCafe.has(socket.printerCafeId)) {
        printerStationDetailsByCafe.get(socket.printerCafeId).delete(socket.id);
        const info = getActiveStationInfo(socket.printerCafeId);
        console.log(`🖨️ [Socket.IO] Printer station disconnected: ${socket.id} (remaining: ${info.stationCount})`);
        notifyCafe(socket.printerCafeId, 'PRINTER_STATION_STATUS_CHANGED', info);
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
  getActiveStationInfo,
  getActiveCafePresence,
  isJobDuplicate,
  printerRoom,
};
