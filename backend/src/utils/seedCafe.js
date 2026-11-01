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

const DEFAULT_CATEGORIES = [
  ['Shashlik', ICONS.local_dining],
  ['Milliy taomlar', ICONS.rice_bowl],
  ['Fast food', ICONS.fastfood],
  ['Salatlar', ICONS.lunch_dining],
  ['Garnir va non', ICONS.bakery_dining],
  ['Shirinliklar', ICONS.cake],
  ['Issiq ichimliklar', ICONS.coffee],
  ['Sovuq ichimliklar', ICONS.local_bar],
  ['Sharbatlar', ICONS.emoji_food_beverage],
  ['Boshqa', ICONS.water],
];

const DEFAULT_PRODUCTS = [
  // ── 1. Shashlik ──────────────────────────────────────────────────────────
  ["Mol go'shti shashlik", 22000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80'],
  ["Qo'y go'shti shashlik", 24000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80'],
  ["Tovuq shashlik", 18000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?w=600&auto=format&fit=crop&q=80'],
  ["Qiyma shashlik", 18000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&auto=format&fit=crop&q=80'],
  ["Jigar shashlik", 16000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80'],
  ["Dumba shashlik", 18000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80'],
  ["Lyulya kabob", 20000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1529692236671-f1f6cf9683ba?w=600&auto=format&fit=crop&q=80'],
  ["Tovuq qanot", 19000, 'Shashlik', ICONS.local_dining, 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=600&auto=format&fit=crop&q=80'],

  // ── 2. Milliy taomlar ────────────────────────────────────────────────────
  ["Osh (plov)", 35000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80'],
  ["Bayram oshi", 40000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80'],
  ["Manti", 35000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80'],
  ["Chuchvara", 30000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80'],
  ["Lag'mon", 32000, 'Milliy taomlar', ICONS.ramen_dining, 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80'],
  ["Qovurma lag'mon", 35000, 'Milliy taomlar', ICONS.ramen_dining, 'https://images.unsplash.com/photo-1552611052-33e04de081de?w=600&auto=format&fit=crop&q=80'],
  ["Mastava", 28000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80'],
  ["Sho'rva", 30000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80'],
  ["Norin", 38000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80'],
  ["Dimlama", 42000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&auto=format&fit=crop&q=80'],
  ["Qozon kabob", 45000, 'Milliy taomlar', ICONS.local_dining, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80'],
  ["Tuxum barak", 28000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80'],
  ["Somsa (go'shtli)", 10000, 'Milliy taomlar', ICONS.bakery_dining, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80'],
  ["Somsa (qovoqli)", 7000, 'Milliy taomlar', ICONS.bakery_dining, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80'],
  ["Hasip", 30000, 'Milliy taomlar', ICONS.local_dining, 'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80'],
  ["Do'lma", 35000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80'],
  ["Naryn", 38000, 'Milliy taomlar', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80'],

  // ── 3. Fast food ─────────────────────────────────────────────────────────
  ["Achchiq shaurma (Hot)", 32000, 'Fast food', ICONS.lunch_dining, 'assets/images/shaurma_dish.png'],
  ["Shaurma oddiy", 30000, 'Fast food', ICONS.lunch_dining, 'assets/images/shaurma_dish.png'],
  ["Shaurma pishloqli", 35000, 'Fast food', ICONS.lunch_dining, 'assets/images/shaurma_dish.png'],
  ["Lavash", 35000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1626700051175-6818013e1d4f?w=600&auto=format&fit=crop&q=80'],
  ["Burger", 28000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80'],
  ["Cheeseburger", 32000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80'],
  ["Hot-dog", 18000, 'Fast food', ICONS.local_dining, 'https://images.unsplash.com/photo-1619740455993-9e612b1af08a?w=600&auto=format&fit=crop&q=80'],
  ["Kartoshka fri", 16000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600&auto=format&fit=crop&q=80'],
  ["Nagetsi", 22000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80'],
  ["Pitsa (kichik)", 45000, 'Fast food', ICONS.local_pizza, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80'],
  ["Pitsa (o'rta)", 60000, 'Fast food', ICONS.local_pizza, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80'],
  ["Pitsa (katta)", 75000, 'Fast food', ICONS.local_pizza, 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80'],
  ["Club sendvich", 32000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80'],
  ["Tovuq burger", 28000, 'Fast food', ICONS.fastfood, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80'],

  // ── 4. Salatlar ──────────────────────────────────────────────────────────
  ["Achchiq-chuchuk", 12000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'],
  ["Olivye", 18000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'],
  ["Sezar", 28000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=600&auto=format&fit=crop&q=80'],
  ["Grek salati", 25000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'],
  ["Vitaminli salat", 14000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'],
  ["Qaymoqli bodring-pomidor", 16000, 'Salatlar', ICONS.lunch_dining, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80'],

  // ── 5. Garnir va non ─────────────────────────────────────────────────────
  ["Guruch", 10000, 'Garnir va non', ICONS.rice_bowl, 'https://images.unsplash.com/photo-1516684732162-798a0062be99?w=600&auto=format&fit=crop&q=80'],
  ["Makaron", 10000, 'Garnir va non', ICONS.ramen_dining, 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=600&auto=format&fit=crop&q=80'],
  ["Kartoshka pyure", 12000, 'Garnir va non', ICONS.fastfood, 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=600&auto=format&fit=crop&q=80'],
  ["Tandir non", 4000, 'Garnir va non', ICONS.bakery_dining, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80'],
  ["Patir", 8000, 'Garnir va non', ICONS.bakery_dining, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80'],
  ["Lochira", 6000, 'Garnir va non', ICONS.bakery_dining, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&auto=format&fit=crop&q=80'],

  // ── 6. Shirinliklar ──────────────────────────────────────────────────────
  ["Medovik", 20000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80'],
  ["Napoleon", 22000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80'],
  ["Cheesecake", 26000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=600&auto=format&fit=crop&q=80'],
  ["Muzqaymoq", 12000, 'Shirinliklar', ICONS.icecream, 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&auto=format&fit=crop&q=80'],
  ["Paxlava", 18000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80'],
  ["Chak-chak", 15000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80'],
  ["Holva", 16000, 'Shirinliklar', ICONS.cake, 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=600&auto=format&fit=crop&q=80'],

  // ── 7. Issiq ichimliklar ─────────────────────────────────────────────────
  ["Choy (ko'k)", 5000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80'],
  ["Choy (qora)", 5000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80'],
  ["Limonli choy", 10000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80'],
  ["Choynak choy", 8000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80'],
  ["Kofe Americano", 12000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&auto=format&fit=crop&q=80'],
  ["Cappuccino", 16000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1534778101976-62847782c213?w=600&auto=format&fit=crop&q=80'],
  ["Latte", 18000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=600&auto=format&fit=crop&q=80'],
  ["Espresso", 10000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop&q=80'],
  ["Kakao", 14000, 'Issiq ichimliklar', ICONS.coffee, 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?w=600&auto=format&fit=crop&q=80'],

  // ── 8. Sovuq ichimliklar ─────────────────────────────────────────────────
  ["Coca-Cola 0.25 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80'],
  ["Coca-Cola 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80'],
  ["Coca-Cola 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80'],
  ["Coca-Cola 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80'],
  ["Coca-Cola 2 l", 20000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=600&auto=format&fit=crop&q=80'],

  ["Pepsi 0.25 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Pepsi 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Pepsi 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Pepsi 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Pepsi 2 l", 20000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],

  ["Fanta 0.25 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Fanta 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Fanta 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Fanta 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Fanta 2 l", 20000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],

  ["Sprite 0.25 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["Sprite 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["Sprite 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["Sprite 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["Sprite 2 l", 20000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],

  ["Mirinda 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Mirinda 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],
  ["Mirinda 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1624517452488-04869289c4ca?w=600&auto=format&fit=crop&q=80'],

  ["7UP 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["7UP 1 l", 13000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],
  ["7UP 1.5 l", 16000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&auto=format&fit=crop&q=80'],

  ["Dinay 0.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Dinay 1 l", 12000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Dinay 1.5 l", 15000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],

  ["Bonaqua 0.5 l", 4000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Bonaqua 1 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Bonaqua 1.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],

  ["Hydrolife 0.5 l", 4000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Hydrolife 1 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Hydrolife 1.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],

  ["Nestle 0.5 l", 4000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Nestle 1 l", 6000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],
  ["Nestle 1.5 l", 8000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1559839914-ba2ac67781b2?w=600&auto=format&fit=crop&q=80'],

  ["Red Bull 0.25 l", 20000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Red Bull 0.5 l", 30000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Flash 0.25 l", 9000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Flash 0.5 l", 14000, 'Sovuq ichimliklar', ICONS.local_bar, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],

  // ── 9. Sharbatlar ────────────────────────────────────────────────────────
  ["Pulpy 0.2 l", 7000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Pulpy 1 l", 18000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Rich 0.2 l", 9000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Rich 1 l", 22000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Sandora 0.2 l", 9000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Sandora 1 l", 22000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Nar sharbati 0.2 l", 10000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Nar sharbati 1 l", 25000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Olma sharbati 0.2 l", 6000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Olma sharbati 1 l", 16000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Apelsin sharbati 0.2 l", 7000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],
  ["Apelsin sharbati 1 l", 18000, 'Sharbatlar', ICONS.emoji_food_beverage, 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=600&auto=format&fit=crop&q=80'],

  // ── 10. Boshqa ───────────────────────────────────────────────────────────
  ["Limonad (uyda tayyorlangan)", 18000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80'],
  ["Mors", 14000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80'],
  ["Ayron", 8000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80'],
  ["Qatiq", 8000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80'],
  ["Kompot", 10000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80'],
  ["Mojito limon", 18000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Mojito qulupnay", 20000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=600&auto=format&fit=crop&q=80'],
  ["Muzli choy", 14000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&auto=format&fit=crop&q=80'],
  ["Smuzi", 22000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1505252585461-04db1eb84625?w=600&auto=format&fit=crop&q=80'],
  ["Milkshake", 20000, 'Boshqa', ICONS.water, 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80'],
];

/**
 * Seed a brand-new cafe workspace with sensible defaults
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

  await restoreDefaultMenu(cafeId, client);
  await seedDefaultHallsAndTables(client, cafeId);

  await client.query(
    'INSERT INTO customers (cafe_id, name, phone, email, loyalty_points) VALUES ($1,$2,$3,$4,$5)',
    [cafeId, 'Tasodifiy mijoz', '-', '', 0]
  );
};

/**
 * Ensures that the cafe has default categories and products.
 */
const ensureCafeSeeded = async (cafeId) => {
  try {
    const cafeExists = await db.query('SELECT 1 FROM cafes WHERE cafe_id = $1', [cafeId]);
    if (cafeExists.rows.length === 0) {
      await db.withTransaction(async (client) => {
        await seedNewCafe(client, cafeId, 'ZAVERO');
      });
      console.log(`🌱 [Seed] Brand new cafe "${cafeId}" initialized with starter setup.`);
      return;
    }
  } catch (err) {
    console.error('ensureCafeSeeded error:', err.message);
  }
};

/**
 * Force-restores or seeds default categories and products for a cafe.
 * Idempotent: Only inserts missing items, never overwrites or deletes existing items.
 */
const restoreDefaultMenu = async (cafeId, externalClient = null) => {
  const runner = async (client) => {
    const categoryIds = {};

    // 1. Ensure categories exist
    for (const [name, icon] of DEFAULT_CATEGORIES) {
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

    // 2. Foydalanuvchi tomonidan o'chirilgan taomlar ro'yxatini olish
    let deletedNames = new Set();
    try {
      const delR = await client.query(
        'SELECT LOWER(TRIM(product_name)) as name FROM deleted_products WHERE cafe_id = $1',
        [cafeId]
      );
      deletedNames = new Set(delR.rows.map((r) => r.name));
    } catch (_) {}

    // 3. Ensure dishes/products exist (faqat o'chirilmagan va bazada yo'q bo'lganlarini qo'shish)
    for (const [name, price, catName, icon, imageUrl] of DEFAULT_PRODUCTS) {
      const lowerName = name.toLowerCase().trim();
      if (deletedNames.has(lowerName)) {
        continue; // O'chirilgan ovqat HECH QACHON qayta qo'shilmaydi!
      }

      const catId = categoryIds[catName];
      if (catId) {
        const existingP = await client.query(
          'SELECT id FROM products WHERE cafe_id = $1 AND LOWER(TRIM(name)) = LOWER(TRIM($2))',
          [cafeId, name]
        );
        if (existingP.rows.length === 0) {
          await client.query(
            'INSERT INTO products (cafe_id, name, price, category_id, stock, icon_code_point, image_url) VALUES ($1,$2,$3,$4,$5,$6,$7)',
            [cafeId, name, price, catId, 100, icon, imageUrl || null]
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
