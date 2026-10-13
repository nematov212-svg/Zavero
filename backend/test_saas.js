require('dotenv').config();
const http = require('http');
const app = require('./src/app');
const db = require('./src/config/db');

async function runTests() {
  console.log('--- Starting ZAVERO SaaS Integration Test Suite ---');
  
  // Start server on ephemeral port
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const baseUrl = `http://localhost:${port}`;
  console.log(`Test server running at ${baseUrl}`);

  async function request(path, options = {}) {
    const res = await fetch(`${baseUrl}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
        ...(options.headers || {}),
      },
      method: options.method || 'GET',
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    const json = await res.json().catch(() => ({}));
    return { status: res.status, data: json };
  }

  let passed = 0;
  let directorToken = '';
  let testCafeId = '';
  let workerToken = '';
  const testCafeSlug = `testsaas${Date.now()}`;
  const testCafeEmail = `${testCafeSlug}@cafe.uz`;
  const testWorkerEmail = `worker${Date.now()}@ishchi.uz`;

  try {
    // 1. Director Login
    console.log('\n[Test 1] Director Login (director@zavero.uz)');
    const dLogin = await request('/api/auth/login', {
      method: 'POST',
      body: {
        username: 'director@zavero.uz',
        password: 'Zavero@2026#Admin91',
      },
    });
    if (dLogin.status === 200 && dLogin.data.token && dLogin.data.user?.role === 'director') {
      directorToken = dLogin.data.token;
      console.log('✓ PASS: Director login succeeded. Role: director');
      passed++;
    } else {
      throw new Error(`FAIL: Director login failed: ${JSON.stringify(dLogin.data)}`);
    }

    // 2. Director Metrics
    console.log('\n[Test 2] Director Fetch Metrics');
    const metrics = await request('/api/director/metrics', { token: directorToken });
    if (metrics.status === 200 && metrics.data.metrics) {
      console.log('✓ PASS: Metrics returned: totalCafes =', metrics.data.metrics.totalCafes);
      passed++;
    } else {
      throw new Error(`FAIL: Fetch metrics failed: ${JSON.stringify(metrics.data)}`);
    }

    // 3. Create Cafe (@cafe.uz)
    console.log('\n[Test 3] Create Cafe with 30-day trial');
    const cafeRes = await request('/api/director/cafes', {
      method: 'POST',
      token: directorToken,
      body: {
        cafeName: 'Test SaaS Cafe',
        receiptName: 'Test Cafe POS',
        ownerEmail: testCafeEmail,
        ownerPassword: 'Password123!',
        ownerName: 'Test Owner',
        ownerPhone: '+998901234567',
        durationDays: 30,
      },
    });
    if (cafeRes.status === 201 && (cafeRes.data.cafeId || cafeRes.data.cafe?.cafe_id)) {
      testCafeId = cafeRes.data.cafeId || cafeRes.data.cafe.cafe_id;
      console.log('✓ PASS: Cafe created with cafe_id:', testCafeId);
      passed++;
    } else {
      throw new Error(`FAIL: Cafe creation failed: ${JSON.stringify(cafeRes.data)}`);
    }

    // 4. Create Worker User (@ishchi.uz)
    console.log('\n[Test 4] Create Worker User (@ishchi.uz)');
    const workerRes = await request('/api/director/users', {
      method: 'POST',
      token: directorToken,
      body: {
        cafeId: testCafeId,
        email: testWorkerEmail,
        password: 'WorkerPassword123!',
        name: 'Test Worker',
        surname: 'Cashier',
        role: 'cashier',
      },
    });
    if (workerRes.status === 201 && workerRes.data.user?.id) {
      console.log('✓ PASS: Worker created with role: cashier');
      passed++;
    } else {
      throw new Error(`FAIL: Worker creation failed: ${JSON.stringify(workerRes.data)}`);
    }

    // 5. Worker Domain Check (Reject invalid domain)
    console.log('\n[Test 5] Reject worker with invalid domain (@gmail.com)');
    const invalidWorkerRes = await request('/api/director/users', {
      method: 'POST',
      token: directorToken,
      body: {
        cafeId: testCafeId,
        email: `invalid_${Date.now()}@gmail.com`,
        password: 'Password123!',
        name: 'Invalid',
        role: 'waiter',
      },
    });
    if (invalidWorkerRes.status === 400) {
      console.log('✓ PASS: Successfully rejected non-@ishchi.uz domain for worker');
      passed++;
    } else {
      throw new Error(`FAIL: Should have rejected invalid worker domain: ${JSON.stringify(invalidWorkerRes.data)}`);
    }

    // 6. Worker Login
    console.log('\n[Test 6] Worker Login');
    const wLogin = await request('/api/auth/login', {
      method: 'POST',
      body: {
        username: testWorkerEmail,
        password: 'WorkerPassword123!',
        deviceId: 'dev_test_worker_1',
        deviceName: 'Cashier POS Terminal',
      },
    });
    if (wLogin.status === 200 && wLogin.data.token && wLogin.data.user?.role === 'cashier') {
      workerToken = wLogin.data.token;
      console.log('✓ PASS: Worker login successful. Token received.');
      passed++;
    } else {
      throw new Error(`FAIL: Worker login failed: ${JSON.stringify(wLogin.data)}`);
    }

    // 7. RBAC Guard: Worker cannot access /api/employees
    console.log('\n[Test 7] RBAC: Worker accessing /api/employees (expect 403)');
    const empRes = await request('/api/employees', { token: workerToken });
    if (empRes.status === 403) {
      console.log('✓ PASS: Worker correctly forbidden from /api/employees (403)');
      passed++;
    } else {
      throw new Error(`FAIL: Worker was NOT forbidden from /api/employees, status: ${empRes.status}`);
    }

    // 8. RBAC Guard: Worker cannot access /api/reports/dashboard
    console.log('\n[Test 8] RBAC: Worker accessing /api/reports/dashboard (expect 403)');
    const repRes = await request('/api/reports/dashboard', { token: workerToken });
    if (repRes.status === 403) {
      console.log('✓ PASS: Worker correctly forbidden from /api/reports/dashboard (403)');
      passed++;
    } else {
      throw new Error(`FAIL: Worker was NOT forbidden from /api/reports/dashboard, status: ${repRes.status}`);
    }

    // 9. Worker CAN access /api/products
    console.log('\n[Test 9] Worker accessing /api/products (expect 200)');
    const prodRes = await request('/api/products', { token: workerToken });
    if (prodRes.status === 200) {
      console.log('✓ PASS: Worker successfully accessed /api/products');
      passed++;
    } else {
      throw new Error(`FAIL: Worker could not access /api/products, status: ${prodRes.status}`);
    }

    // 10. Director Blocks Cafe
    console.log('\n[Test 10] Director Blocks Cafe');
    const blockRes = await request(`/api/director/cafes/${testCafeId}/block`, {
      method: 'POST',
      token: directorToken,
      body: { reason: 'Test block enforcement' },
    });
    if (blockRes.status === 200) {
      console.log('✓ PASS: Cafe status set to blocked');
      passed++;
    } else {
      throw new Error(`FAIL: Block cafe failed: ${JSON.stringify(blockRes.data)}`);
    }

    // 11. Subscription Enforcement: Worker requests are rejected when cafe is blocked
    console.log('\n[Test 11] Subscription Guard: Blocked cafe worker rejected on /api/products (expect 403)');
    const blockedProdRes = await request('/api/products', { token: workerToken });
    if (blockedProdRes.status === 403 && (blockedProdRes.data.isBlocked || blockedProdRes.data.message?.includes('to\'xtatilgan'))) {
      console.log('✓ PASS: Blocked cafe correctly returned 403 to worker');
      passed++;
    } else {
      throw new Error(`FAIL: Blocked cafe request was not blocked with 403: status=${blockedProdRes.status}, body=${JSON.stringify(blockedProdRes.data)}`);
    }

    // 12. Director Extends Subscription and Unblocks Cafe
    console.log('\n[Test 12] Director Extends Subscription (+30 days) and Unblocks');
    const extRes = await request(`/api/director/cafes/${testCafeId}/extend`, {
      method: 'POST',
      token: directorToken,
      body: { days: 30, reason: 'Test extension' },
    });
    const unblockRes = await request(`/api/director/cafes/${testCafeId}/unblock`, {
      method: 'POST',
      token: directorToken,
    });
    if (extRes.status === 200 && unblockRes.status === 200) {
      console.log('✓ PASS: Cafe subscription extended and status unblocked');
      passed++;
    } else {
      throw new Error(`FAIL: Extend or unblock failed`);
    }

    // 13. Worker can access /api/products again
    console.log('\n[Test 13] Worker accessing /api/products after unblock (expect 200)');
    const unblockedProdRes = await request('/api/products', { token: workerToken });
    if (unblockedProdRes.status === 200) {
      console.log('✓ PASS: Worker access restored after unblock');
      passed++;
    } else {
      throw new Error(`FAIL: Worker access not restored: status=${unblockedProdRes.status}`);
    }

    // 14. Customer Account Creation & Login Test (@mijoz.uz)
    console.log('\n[Test 14] Director creates Customer (@mijoz.uz) and Customer logs in');
    const customerEmail = `customer_${Date.now()}@mijoz.uz`;
    const customerPass = 'MijozPass2026!';
    const createCustRes = await request('/api/director/users', {
      method: 'POST',
      token: directorToken,
      body: {
        cafeId: testCafeId,
        email: customerEmail,
        password: customerPass,
        name: 'Aziz',
        surname: 'Mijoz',
        phone: '+998911112233',
        role: 'customer',
      },
    });

    if (createCustRes.status === 201 && createCustRes.data.user?.id) {
      console.log('✓ PASS: Customer user created by director with role: customer');
    } else {
      throw new Error(`FAIL: Create customer failed: ${JSON.stringify(createCustRes.data)}`);
    }

    const custLoginRes = await request('/api/auth/login', {
      method: 'POST',
      body: {
        username: customerEmail,
        password: customerPass,
      },
    });

    if (custLoginRes.status === 200 && custLoginRes.data.token && custLoginRes.data.user?.role === 'customer') {
      console.log('✓ PASS: Customer logged in successfully! Role:', custLoginRes.data.user.role);
      passed++;
    } else {
      throw new Error(`FAIL: Customer login failed: ${JSON.stringify(custLoginRes.data)}`);
    }

    console.log(`\n========================================`);
    console.log(`ALL ${passed}/14 BACKEND SAAS INTEGRATION TESTS PASSED!`);
    console.log(`========================================`);

  } finally {
    // Cleanup test data
    if (testCafeId) {
      try {
        await db.query('DELETE FROM audit_logs WHERE cafe_id = $1', [testCafeId]);
        await db.query('DELETE FROM devices WHERE cafe_id = $1', [testCafeId]);
        await db.query('DELETE FROM subscription_events WHERE cafe_id = $1', [testCafeId]);
        await db.query('DELETE FROM subscriptions WHERE cafe_id = $1', [testCafeId]);
        await db.query('DELETE FROM users WHERE cafe_id = $1', [testCafeId]);
        await db.query('DELETE FROM cafes WHERE cafe_id = $1', [testCafeId]);
        console.log('\n[Cleanup] Test cafe data successfully cleaned up.');
      } catch (cleanErr) {
        console.warn('Cleanup error:', cleanErr.message);
      }
    }
    server.close();
    await db.pool.end();
  }
}

runTests().catch((err) => {
  console.error('\nTEST SUITE FAILED:', err);
  process.exit(1);
});
