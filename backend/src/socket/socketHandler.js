const jwt = require('jsonwebtoken');
const { getJwtSecret } = require('../config/jwt');

let ioInstance = null;

const cafeRoom = (cafeId) => `cafe_${cafeId}`;

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
        }).catch(() => {});
      } catch (_) {}
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

    socket.on('disconnect', (reason) => {
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
    ).catch(() => {});
  } catch (_) {}
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

module.exports = { initSocket, notifyCafe, notifyDirector, getIo };
