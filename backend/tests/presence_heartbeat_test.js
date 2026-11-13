const http = require('http');
const { Server } = require('socket.io');
const ioClient = require('socket.io-client');
const jwt = require('jsonwebtoken');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { getJwtSecret } = require('../src/config/jwt');
const { initSocket, getActiveCafePresence } = require('../src/socket/socketHandler');
const app = require('../src/app');

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runPresenceTest() {
  console.log('🧪 ============================================================');
  console.log('🧪 PRESENCE HEARTBEAT & MULTI-DEVICE TEST BOSHLANDI');
  console.log('🧪 ============================================================');

  const secret = getJwtSecret();
  const testCafeId = 'test_presence_cafe_xyz';

  // Tokens using valid DB users
  const directorToken = jwt.sign(
    { id: 2, username: 'mirzobek@zavero.uz', role: 'director' },
    secret,
    { expiresIn: '1h' }
  );

  const cafeStaffToken1 = jwt.sign(
    { id: 61, username: 'ofitsiant_ali', role: 'waiter', cafeId: testCafeId },
    secret,
    { expiresIn: '1h' }
  );

  const cafeStaffToken2 = jwt.sign(
    { id: 28, username: 'ilyos@cafe.uz', role: 'admin', cafeId: testCafeId },
    secret,
    { expiresIn: '1h' }
  );

  // 1. Setup local HTTP + Socket.IO server
  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: '*' },
    pingInterval: 5000,
    pingTimeout: 5000,
  });
  initSocket(io);

  const PORT = 4099;
  await new Promise((resolve) => server.listen(PORT, '127.0.0.1', resolve));
  const serverUrl = `http://127.0.0.1:${PORT}`;
  console.log(`✅ Test server ishga tushdi: ${serverUrl}`);

  try {
    // -------------------------------------------------------------
    // Test (f): Security Check - Cafe token vs Director token
    // -------------------------------------------------------------
    console.log('\n🔒 [Test f] Ruxsat tekshiruvi: Director endpointlariga cafe tokeni bilan kirib bo‘lmasligi kerak...');
    const cafeRes = await fetch(`${serverUrl}/api/director/cafes-presence`, {
      headers: { Authorization: `Bearer ${cafeStaffToken1}` },
    });
    console.log(`   Cafe token so'rovi status kodi: ${cafeRes.status} (Kutilgan: 403)`);
    if (cafeRes.status !== 403) {
      throw new Error(`Xavfsizlik buzilishi: cafe tokeni 403 o'rniga ${cafeRes.status} oldi!`);
    }
    console.log('   ✅ Cafe xodimi director/cafes-presence ga kira olmaydi (403 Forbidden).');

    // -------------------------------------------------------------
    // Test (a): Director ulanadi, keyin Cafe Device 1 ulanadi -> Online
    // -------------------------------------------------------------
    console.log('\n📱 [Test a] Director va Cafe Device 1 ulanishi...');
    const directorSocket = ioClient(serverUrl, {
      auth: { token: directorToken },
      transports: ['websocket'],
    });

    let directorReceivedPresence = null;
    directorSocket.on('CAFE_PRESENCE_UPDATED', (data) => {
      directorReceivedPresence = data;
    });

    await sleep(400);

    const cafeDevice1 = ioClient(serverUrl, {
      auth: { token: cafeStaffToken1 },
      transports: ['websocket'],
    });

    await sleep(400);
    // Send presence heartbeat
    cafeDevice1.emit('presence-heartbeat', { cafeId: testCafeId, appVisible: true });
    await sleep(500);

    const snapshot1 = getActiveCafePresence();
    console.log(`   Cafe 1 ulangandan keyingi holat: presence[${testCafeId}]=${snapshot1.presence[testCafeId]}, onlineCount=${snapshot1.onlineCount}`);
    if (!snapshot1.presence[testCafeId]) {
      throw new Error('Cafe Device 1 ulangan bo\'lsa ham Cafe Online bo\'lmadi!');
    }
    console.log('   ✅ [Test a] Cafe ilovasi ulanishi bilan 1 soniyada Online bo\'ldi.');

    // -------------------------------------------------------------
    // Test (d): Ikkinchi qurilma (Device 2) ham ulanadi
    // -------------------------------------------------------------
    console.log('\n📱 [Test d] Ikkinchi qurilma (Device 2) ulanishi va bittasini uzish...');
    const cafeDevice2 = ioClient(serverUrl, {
      auth: { token: cafeStaffToken2 },
      transports: ['websocket'],
    });

    await sleep(400);
    cafeDevice2.emit('presence-heartbeat', { cafeId: testCafeId, appVisible: true });
    await sleep(500);

    console.log('   Device 1 uzilmoqda (masalan ofitsiant chiqib ketdi)...');
    cafeDevice1.disconnect();
    await sleep(1000);

    const snapshotAfterDev1Disconnect = getActiveCafePresence();
    console.log(`   Device 1 uzilgach: presence[${testCafeId}]=${snapshotAfterDev1Disconnect.presence[testCafeId]}`);
    if (!snapshotAfterDev1Disconnect.presence[testCafeId]) {
      throw new Error('Bitta qurilma uzilganda ikkinchisi ishlab turgan bo\'lsa ham Cafe Offline bo\'lib qoldi!');
    }
    console.log('   ✅ [Test d - 1-qism] Ikki qurilmadan biri uzilsa ham Cafe ONLINE bo\'lib qoldi.');

    // -------------------------------------------------------------
    // Test (b): Ikkinchi qurilma ham uziladi -> Grace period -> Offline
    // -------------------------------------------------------------
    console.log('\n🔌 [Test b] Ikkinchi qurilma ham uzilmoqda (barcha qurilmalar chiqdi)...');
    cafeDevice2.disconnect();
    await sleep(1000);

    // Darhol grace periodda turishi kerak (miltillamasligi uchun)
    const snapshotInGrace = getActiveCafePresence();
    console.log(`   Uzilishdan darhol keyin (Grace Period ichida): presence[${testCafeId}]=${snapshotInGrace.presence[testCafeId]}`);

    console.log('   Grace period (12-13 soniya) kutilmoqda...');
    await sleep(13000);

    const snapshotAfterGrace = getActiveCafePresence();
    console.log(`   Grace period o'tgach: presence[${testCafeId}]=${snapshotAfterGrace.presence[testCafeId]}`);
    if (snapshotAfterGrace.presence[testCafeId] === true) {
      throw new Error('Hamma qurilmalar uzilgach grace perioddan keyin ham Cafe Offline bo\'lmadi!');
    }
    console.log('   ✅ [Test b] Barcha qurilmalar uzilgach 12-13 soniya grace perioddan keyin Cafe OFFLINE bo\'ldi.');

    // -------------------------------------------------------------
    // Test (c): Qayta ulanish (DevTools Offline -> Online simulatsiyasi)
    // -------------------------------------------------------------
    console.log('\n🔄 [Test c] Qayta ulanish testi...');
    const cafeDeviceReconnect = ioClient(serverUrl, {
      auth: { token: cafeStaffToken1 },
      transports: ['websocket'],
    });
    await sleep(500);
    cafeDeviceReconnect.emit('presence-heartbeat', { cafeId: testCafeId, appVisible: true });
    await sleep(500);

    const snapshotReconnected = getActiveCafePresence();
    console.log(`   Qayta ulangach: presence[${testCafeId}]=${snapshotReconnected.presence[testCafeId]}`);
    if (!snapshotReconnected.presence[testCafeId]) {
      throw new Error('Qayta ulangach Cafe Online bo\'lmadi!');
    }
    console.log('   ✅ [Test c] Tarmoq tiklangach Cafe yana darhol ONLINE bo\'ldi.');

    cafeDeviceReconnect.disconnect();
    directorSocket.disconnect();

    console.log('\n🎉 BARCHA PRESENCE TESTLARI (a, b, c, d, f) 100% MUVAFFAQITYATLI O\'TDI!');
  } finally {
    server.close();
  }
}

runPresenceTest()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Test xatosi:', err);
    process.exit(1);
  });
