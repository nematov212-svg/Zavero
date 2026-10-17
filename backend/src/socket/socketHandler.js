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

    socket.on('JOIN_CAFE', ({ cafeId, token }) => {
      let joinCafeId = cafeId;
      if (token) {
        try {
          const secret = getJwtSecret();
          const decoded = jwt.verify(token, secret);
          socket.user = decoded;
          if (decoded.role === 'director') {
            socket.join('director_room');
          }
          joinCafeId = (decoded.role === 'director' ? cafeId : decoded.cafeId) || cafeId;
        } catch (e) {
          console.error('[Socket.IO] JOIN_CAFE token error:', e.message);
        }
      }
      if (joinCafeId) {
        socket.join(cafeRoom(joinCafeId));
        socket.emit('JOINED_CAFE', { cafeId: joinCafeId, success: true });
        console.log(`👤 [Socket.IO] Joined room ${cafeRoom(joinCafeId)}`);
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
      const targetCafeId = socket.user?.cafeId || payload.cafeId;
      if (targetCafeId) {
        notifyCafe(targetCafeId, 'STAFF_STATUS_UPDATED', payload);
        console.log(`☕ [Socket.IO] STAFF_STATUS_UPDATED for cafe ${targetCafeId}:`, payload.staffName, payload.statusText);
      }
    });

    socket.on('STAFF_MOVEMENT_UPDATE', (payload = {}) => {
      const targetCafeId = socket.user?.cafeId || payload.cafeId;
      if (targetCafeId) {
        notifyCafe(targetCafeId, 'STAFF_MOVEMENT_UPDATED', payload);
      }
    });

    socket.on('BANNERS_UPDATED', (payload = {}) => {
      const targetCafeId = socket.user?.cafeId || payload.cafeId;
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
  const data = { ...payload, timestamp: new Date().toISOString() };
  ioInstance.to(cafeRoom(cafeId)).emit(event, data);
  console.log(`📡 [Socket.IO] '${event}' -> ${cafeRoom(cafeId)}`);
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
