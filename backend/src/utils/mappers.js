// Maps Postgres rows -> JSON shapes expected by the Flutter models' fromJson() constructors.

const num = (v) => (v === null || v === undefined ? 0 : parseFloat(v));

const mapCartItems = (items) => {
  const arr = Array.isArray(items) ? items : (typeof items === 'string' ? JSON.parse(items) : []);
  return arr;
};

const mapCategory = (r) => ({
  id: r.id,
  name: r.name,
  iconCodePoint: parseInt(r.icon_code_point, 10),
});

const mapProduct = (r) => ({
  id: r.id,
  name: r.name,
  price: num(r.price),
  categoryId: r.category_id,
  stock: r.stock,
  iconCodePoint: parseInt(r.icon_code_point, 10),
  imageUrl: r.image_url,
});

const mapHall = (r) => ({
  id: r.id,
  name: r.name,
  iconCodePoint: parseInt(r.icon_code_point, 10),
  imageAsset: r.image_asset,
});

const mapTable = (r) => ({
  id: r.id,
  hallId: r.hall_id,
  number: r.number,
  seats: r.seats,
  status: r.status,
  orderId: r.order_id,
  total: num(r.total),
});

const mapCustomer = (r) => ({
  id: r.id,
  name: r.name,
  phone: r.phone,
  email: r.email,
  loyaltyPoints: r.loyalty_points,
});

const mapReceipt = (r) => ({
  id: r.id,
  date: new Date(r.date).toISOString(),
  items: mapCartItems(r.items),
  total: num(r.total),
  method: r.method,
  cashierName: r.cashier_name,
  tableNumber: r.table_number,
  hallName: r.hall_name,
  cashPaid: num(r.cash_paid),
  cardPaid: num(r.card_paid),
});

const mapCustomerOrder = (r) => ({
  id: r.id,
  cafeId: r.cafe_id,
  date: new Date(r.date).toISOString(),
  items: mapCartItems(r.items),
  customerName: r.customer_name,
  phone: r.phone,
  type: r.type,
  tableNumber: r.table_number,
  hallId: r.hall_id,
  deliveryAddress: r.delivery_address,
  status: r.status,
});

const mapEmployee = (r) => ({
  id: r.id,
  uid: `${r.id}`,
  name: r.name,
  surname: r.surname,
  username: r.username,
  email: r.email,
  phone: r.phone,
  password: '',
  role: r.role,
  salary: num(r.salary),
  ownerId: r.cafe_id,
  cafeId: r.cafe_id,
  createdAt: new Date(r.created_at).toISOString(),
});

const mapReport = (r) => ({
  dateId: r.date_id,
  totalRevenue: num(r.total_revenue),
  orderCount: r.order_count,
  productQuantities: r.product_quantities || {},
  productRevenue: r.product_revenue || {},
  topProduct: r.top_product || '',
  tableRevenue: r.table_revenue || {},
  updatedAt: new Date(r.updated_at).toISOString(),
});

module.exports = {
  mapCartItems,
  mapCategory,
  mapProduct,
  mapHall,
  mapTable,
  mapCustomer,
  mapReceipt,
  mapCustomerOrder,
  mapEmployee,
  mapReport,
};
