const db = require('../config/db');

/** Icon code points copied from Flutter's Icons.* (Material) so client rendering matches exactly. */
const ICONS = {
  lunch_dining: 0xf1e5,
  fastfood: 0xe57a,
  bakery_dining: 0xf095,
  ramen_dining: 0xf19d,
  local_dining: 0xe556,
  local_pizza: 0xe55d,
  local_bar: 0xe540,
  emoji_food_beverage: 0xea60,
  coffee: 0xe174,
  grain: 0xe793,
  icecream: 0xe564,
  cake: 0xe7e9,
  rice_bowl: 0xf1eb,
  home_work: 0xef42,
  stairs: 0xf1a9,
  park: 0xea63,
  cabin: 0xea6c,
  water: 0xef77,
};

/**
 * Seed a brand-new cafe workspace with sensible defaults
 * (mirrors the previous CloudService.initializeNewCafe on the client).
 */
const seedNewCafe = async (client, cafeId, cafeName) => {
  const existing = await client.query('SELECT 1 FROM cafes WHERE cafe_id = $1', [cafeId]);
  if (existing.rows.length > 0) return;

  await client.query('INSERT INTO cafes (cafe_id, cafe_name) VALUES ($1, $2)', [cafeId, cafeName]);

  await client.query(
    'INSERT INTO settings (cafe_id, data) VALUES ($1, $2)',
    [
      cafeId,
      JSON.stringify({
        restaurantName: cafeName,
        restaurantAddress: 'Samarqand Urgut yuqori masjid oldida',
        restaurantPhone: '',
        receiptFooterNote: '',
        darkMode: false,
        paperWidthMm: 80,
        receiptBoldHeader: true,
        showWaiterName: true,
        showTableName: true,
        showDateTime: true,
        showDeveloperTag: true,
        showCustomerCount: true,
      }),
    ]
  );

  const defaultCategories = [
    ['Шаурма', ICONS.lunch_dining],
    ['Пита', ICONS.bakery_dining],
    ['Лаваш', ICONS.fastfood],
    ['Донер', ICONS.ramen_dining],
    ['Хот-дог', ICONS.local_dining],
    ['Напитки', ICONS.local_bar],
    ['Чай-кофе', ICONS.coffee],
    ['Мороженое', ICONS.icecream],
    ['Семечка', ICONS.grain],
    ['Dessert', ICONS.cake],
  ];
  const categoryIds = {};
  for (const [name, icon] of defaultCategories) {
    const res = await client.query(
      'INSERT INTO categories (cafe_id, name, icon_code_point) VALUES ($1, $2, $3) RETURNING id',
      [cafeId, name, icon]
    );
    categoryIds[name] = res.rows[0].id;
  }

  const defaultProducts = [
    ['Мини шаурма', 25000, categoryIds['Шаурма'], ICONS.lunch_dining],
    ['Средняя шаурма', 35000, categoryIds['Шаурма'], ICONS.lunch_dining],
    ['Большая шаурма', 40000, categoryIds['Шаурма'], ICONS.lunch_dining],

    ['Средняя пита', 35000, categoryIds['Пита'], ICONS.bakery_dining],
    ['Большая пита', 40000, categoryIds['Пита'], ICONS.bakery_dining],

    ['Мини лаваш', 35000, categoryIds['Лаваш'], ICONS.fastfood],
    ['Средний лаваш', 40000, categoryIds['Лаваш'], ICONS.fastfood],
    ['Большой лаваш', 50000, categoryIds['Лаваш'], ICONS.fastfood],

    ['Мини донер', 40000, categoryIds['Донер'], ICONS.ramen_dining],
    ['Большой донер', 50000, categoryIds['Донер'], ICONS.ramen_dining],

    ['Мини хот-дог', 15000, categoryIds['Хот-дог'], ICONS.local_dining],
    ['Средний хот-дог', 20000, categoryIds['Хот-дог'], ICONS.local_dining],
    ['Большой хот-дог', 25000, categoryIds['Хот-дог'], ICONS.local_dining],
    ['Сосиска', 5000, categoryIds['Хот-дог'], ICONS.local_dining],

    ['Кока-Кола 0.5 л', 8000, categoryIds['Напитки'], ICONS.local_bar],
    ['Кока-Кола 1 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
    ['Кока-Кола 1.5 л', 17000, categoryIds['Напитки'], ICONS.local_bar],
    ['Кока-Кола 2 л', 20000, categoryIds['Напитки'], ICONS.local_bar],
    ['Фьюс Ти 0.5 л', 9000, categoryIds['Напитки'], ICONS.local_bar],
    ['Фьюс Ти 1 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
    ['Сок 1 л', 16000, categoryIds['Напитки'], ICONS.local_bar],
    ['Мохито 0.5 л', 14000, categoryIds['Напитки'], ICONS.local_bar],
    ['Флеш Энергетик 0.5 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
    ['Адреналин 0.5 л', 18000, categoryIds['Напитки'], ICONS.local_bar],
    ['Кола стекло', 5000, categoryIds['Напитки'], ICONS.local_bar],
    ['Пепси', 10000, categoryIds['Напитки'], ICONS.local_bar],
    ['Чортоқ', 15000, categoryIds['Напитки'], ICONS.local_bar],
    ['Газированные напитки', 10000, categoryIds['Напитки'], ICONS.local_bar],
    ['Пульпи 1 л', 17000, categoryIds['Напитки'], ICONS.local_bar],
    ['Пульпи 0.5 л', 10000, categoryIds['Напитки'], ICONS.local_bar],
    ['Фьюс Ти', 18000, categoryIds['Напитки'], ICONS.local_bar],
    ['Вода Нестле 1 л', 6000, categoryIds['Напитки'], ICONS.local_bar],

    ['Чай зелёный', 5000, categoryIds['Чай-кофе'], ICONS.coffee],
    ['Чай с лимоном', 15000, categoryIds['Чай-кофе'], ICONS.coffee],
    ['Капучино', 7000, categoryIds['Чай-кофе'], ICONS.coffee],
    ['МакКофе 3в1', 3000, categoryIds['Чай-кофе'], ICONS.coffee],

    ['Шоколадное мороженое', 10000, categoryIds['Мороженое'], ICONS.icecream],
    ['Мороженое ассорти', 15000, categoryIds['Мороженое'], ICONS.icecream],
    ['Мороженое ассорти', 20000, categoryIds['Мороженое'], ICONS.icecream],
    ['Эскимо', 22000, categoryIds['Мороженое'], ICONS.icecream],

    ['Семечки 100 г', 18000, categoryIds['Семечка'], ICONS.grain],
    ['Семечки 160 г', 25000, categoryIds['Семечка'], ICONS.grain],
    ['Семечки 200 г', 35000, categoryIds['Семечка'], ICONS.grain],
    ['Курт', 10000, categoryIds['Семечка'], ICONS.grain],
  ];

  for (const [name, price, catId, icon] of defaultProducts) {
    if (catId) {
      await client.query(
        'INSERT INTO products (cafe_id, name, price, category_id, stock, icon_code_point) VALUES ($1,$2,$3,$4,$5,$6)',
        [cafeId, name, price, catId, 100, icon]
      );
    }
  }

  const hallSpecs = [
    ['Zal', 9, ICONS.home_work, 'assets/images/hall_zal.png'],
    ['Podval', 6, ICONS.stairs, null],
    ['Dala', 6, ICONS.park, null],
    ['Saboy', 5, ICONS.cabin, null],
    ["Soy bo'yi", 4, ICONS.water, 'assets/images/hall_soyboyi.png'],
  ];

  for (const [name, tableCount, icon, imageAsset] of hallSpecs) {
    const hallRes = await client.query(
      'INSERT INTO halls (cafe_id, name, icon_code_point, image_asset) VALUES ($1,$2,$3,$4) RETURNING id',
      [cafeId, name, icon, imageAsset]
    );
    const hallId = hallRes.rows[0].id;
    for (let i = 1; i <= tableCount; i++) {
      await client.query(
        'INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1,$2,$3,$4,$5)',
        [cafeId, hallId, i, 4, 'free']
      );
    }
  }

  await client.query(
    'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1,$2,$3,$4,$5)',
    [cafeId, 'Tasodifiy mijoz', '-', '', 0]
  );
};

/**
 * Ensures that the cafe has default categories and products.
 * If categories or products are missing/empty, populates them automatically.
 */
const ensureCafeSeeded = async (cafeId) => {
  try {
    const cafeExists = await db.query('SELECT 1 FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeExists.rows.length === 0) {
      await db.withTransaction(async (client) => {
        await seedNewCafe(client, cafeId, 'ZAVERO');
      });
      return;
    }

    const catRes = await db.query('SELECT COUNT(*) FROM categories WHERE cafe_id = $1', [cafeId]);
    const prodRes = await db.query('SELECT COUNT(*) FROM products WHERE cafe_id = $1', [cafeId]);
    const catCount = parseInt(catRes.rows[0].count, 10);
    const prodCount = parseInt(prodRes.rows[0].count, 10);

    if (catCount === 0 || prodCount === 0) {
      console.log(`🌱 [Seed] Restoring missing categories/products for cafe "${cafeId}"...`);
      await db.withTransaction(async (client) => {
        await restoreDefaultMenu(cafeId, client);
      });
    }
  } catch (err) {
    console.error('ensureCafeSeeded error:', err.message);
  }
};

/**
 * Force-restores or seeds default categories and products for a cafe.
 */
const restoreDefaultMenu = async (cafeId, externalClient = null) => {
  const runner = async (client) => {
    const defaultCategories = [
      ['Шаурма', ICONS.lunch_dining],
      ['Пита', ICONS.bakery_dining],
      ['Лаваш', ICONS.fastfood],
      ['Донер', ICONS.ramen_dining],
      ['Хот-дог', ICONS.local_dining],
      ['Напитки', ICONS.local_bar],
      ['Чай-кофе', ICONS.coffee],
      ['Мороженое', ICONS.icecream],
      ['Семечка', ICONS.grain],
      ['Dessert', ICONS.cake],
    ];

    const categoryIds = {};
    for (const [name, icon] of defaultCategories) {
      const existing = await client.query(
        'SELECT id FROM categories WHERE cafe_id = $1 AND LOWER(TRIM(name)) = LOWER(TRIM($2))',
        [cafeId, name]
      );
      if (existing.rows.length > 0) {
        categoryIds[name] = existing.rows[0].id;
      } else {
        const res = await client.query(
          'INSERT INTO categories (cafe_id, name, icon_code_point) VALUES ($1, $2, $3) RETURNING id',
          [cafeId, name, icon]
        );
        categoryIds[name] = res.rows[0].id;
      }
    }

    const defaultProducts = [
      ['Мини шаурма', 25000, categoryIds['Шаурма'], ICONS.lunch_dining],
      ['Средняя шаурма', 35000, categoryIds['Шаурма'], ICONS.lunch_dining],
      ['Большая шаурма', 40000, categoryIds['Шаурма'], ICONS.lunch_dining],

      ['Средняя пита', 35000, categoryIds['Пита'], ICONS.bakery_dining],
      ['Большая пита', 40000, categoryIds['Пита'], ICONS.bakery_dining],

      ['Мини лаваш', 35000, categoryIds['Лаваш'], ICONS.fastfood],
      ['Средний лаваш', 40000, categoryIds['Лаваш'], ICONS.fastfood],
      ['Большой лаваш', 50000, categoryIds['Лаваш'], ICONS.fastfood],

      ['Мини донер', 40000, categoryIds['Донер'], ICONS.ramen_dining],
      ['Большой донер', 50000, categoryIds['Донер'], ICONS.ramen_dining],

      ['Мини хот-дог', 15000, categoryIds['Хот-дог'], ICONS.local_dining],
      ['Средний хот-дог', 20000, categoryIds['Хот-дог'], ICONS.local_dining],
      ['Большой хот-дог', 25000, categoryIds['Хот-дог'], ICONS.local_dining],
      ['Сосиска', 5000, categoryIds['Хот-дог'], ICONS.local_dining],

      ['Кока-Кола 0.5 л', 8000, categoryIds['Напитки'], ICONS.local_bar],
      ['Кока-Кола 1 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
      ['Кока-Кола 1.5 л', 17000, categoryIds['Напитки'], ICONS.local_bar],
      ['Кока-Кола 2 л', 20000, categoryIds['Напитки'], ICONS.local_bar],
      ['Фьюс Ти 0.5 л', 9000, categoryIds['Напитки'], ICONS.local_bar],
      ['Фьюс Ти 1 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
      ['Сок 1 л', 16000, categoryIds['Напитки'], ICONS.local_bar],
      ['Мохито 0.5 л', 14000, categoryIds['Напитки'], ICONS.local_bar],
      ['Флеш Энергетик 0.5 л', 13000, categoryIds['Напитки'], ICONS.local_bar],
      ['Адреналин 0.5 л', 18000, categoryIds['Напитки'], ICONS.local_bar],
      ['Кола стекло', 5000, categoryIds['Напитки'], ICONS.local_bar],
      ['Пепси', 10000, categoryIds['Напитки'], ICONS.local_bar],
      ['Чортоқ', 15000, categoryIds['Напитки'], ICONS.local_bar],
      ['Газированные напитки', 10000, categoryIds['Напитки'], ICONS.local_bar],
      ['Пульпи 1 л', 17000, categoryIds['Напитки'], ICONS.local_bar],
      ['Пульпи 0.5 л', 10000, categoryIds['Напитки'], ICONS.local_bar],
      ['Фьюс Ти', 18000, categoryIds['Напитки'], ICONS.local_bar],
      ['Вода Нестле 1 л', 6000, categoryIds['Напитки'], ICONS.local_bar],

      ['Чай зелёный', 5000, categoryIds['Чай-кофе'], ICONS.coffee],
      ['Чай с лимоном', 15000, categoryIds['Чай-кофе'], ICONS.coffee],
      ['Капучино', 7000, categoryIds['Чай-кофе'], ICONS.coffee],
      ['МакКофе 3в1', 3000, categoryIds['Чай-кофе'], ICONS.coffee],

      ['Шоколадное мороженое', 10000, categoryIds['Мороженое'], ICONS.icecream],
      ['Мороженое ассорти', 15000, categoryIds['Мороженое'], ICONS.icecream],
      ['Мороженое ассорти', 20000, categoryIds['Мороженое'], ICONS.icecream],
      ['Эскимо', 22000, categoryIds['Мороженое'], ICONS.icecream],

      ['Семечки 100 г', 18000, categoryIds['Семечка'], ICONS.grain],
      ['Семечки 160 г', 25000, categoryIds['Семечка'], ICONS.grain],
      ['Семечки 200 г', 35000, categoryIds['Семечка'], ICONS.grain],
      ['Курт', 10000, categoryIds['Семечка'], ICONS.grain],
    ];

    for (const [name, price, catId, icon] of defaultProducts) {
      if (catId) {
        const existingP = await client.query(
          'SELECT id FROM products WHERE cafe_id = $1 AND LOWER(TRIM(name)) = LOWER(TRIM($2))',
          [cafeId, name]
        );
        if (existingP.rows.length === 0) {
          await client.query(
            'INSERT INTO products (cafe_id, name, price, category_id, stock, icon_code_point) VALUES ($1,$2,$3,$4,$5,$6)',
            [cafeId, name, price, catId, 100, icon]
          );
        }
      }
    }
  };

  if (externalClient) {
    await runner(externalClient);
  } else {
    await db.withTransaction(runner);
  }
};

const seedDefaultHallsAndTables = async (client, cafeId) => {
  const existingHalls = await client.query('SELECT COUNT(*) FROM halls WHERE cafe_id = $1', [cafeId]);
  if (parseInt(existingHalls.rows[0].count, 10) > 0) return;

  const hallSpecs = [
    ['Zal', 9, ICONS.home_work, 'assets/images/hall_zal.png'],
    ['Podval', 6, ICONS.stairs, null],
    ['Dala', 6, ICONS.park, null],
    ['Saboy', 5, ICONS.cabin, null],
    ["Soy bo'yi", 4, ICONS.water, 'assets/images/hall_soyboyi.png'],
  ];

  for (const [name, tableCount, icon, imageAsset] of hallSpecs) {
    const hallRes = await client.query(
      'INSERT INTO halls (cafe_id, name, icon_code_point, image_asset) VALUES ($1,$2,$3,$4) RETURNING id',
      [cafeId, name, icon, imageAsset]
    );
    const hallId = hallRes.rows[0].id;
    for (let i = 1; i <= tableCount; i++) {
      await client.query(
        'INSERT INTO restaurant_tables (cafe_id, hall_id, number, seats, status) VALUES ($1,$2,$3,$4,$5)',
        [cafeId, hallId, i, 4, 'free']
      );
    }
  }
};

module.exports = { seedNewCafe, ensureCafeSeeded, restoreDefaultMenu, seedDefaultHallsAndTables };

