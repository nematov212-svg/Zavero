-- ============================================================
-- ZAVERO POS — PostgreSQL Schema (multi-tenant by cafe_id)
-- ============================================================

-- 1. CAFES (workspace / tenant)
CREATE TABLE IF NOT EXISTS cafes (
    cafe_id VARCHAR(64) PRIMARY KEY,
    cafe_name VARCHAR(150) NOT NULL DEFAULT 'ZAVERO Cafe',
    receipt_name VARCHAR(150),
    owner_name VARCHAR(150) DEFAULT '',
    owner_phone VARCHAR(40) DEFAULT '',
    owner_email VARCHAR(150) DEFAULT '',
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, blocked, expired
    start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS receipt_name VARCHAR(150);
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS owner_name VARCHAR(150) DEFAULT '';
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS owner_phone VARCHAR(40) DEFAULT '';
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS owner_email VARCHAR(150) DEFAULT '';
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE cafes ADD COLUMN IF NOT EXISTS end_date TIMESTAMP WITH TIME ZONE;
CREATE INDEX IF NOT EXISTS idx_cafes_status ON cafes(status);

-- 2. USERS (login accounts, belong to a cafe)
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    username VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(120) DEFAULT '',
    surname VARCHAR(120) DEFAULT '',
    phone VARCHAR(40) DEFAULT '',
    email VARCHAR(150) DEFAULT '',
    role VARCHAR(30) NOT NULL DEFAULT 'admin',
    salary NUMERIC(15,2) DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    must_change_password BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_users_cafe ON users(cafe_id);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- 2b. EMPLOYEES
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    name VARCHAR(120) DEFAULT '',
    surname VARCHAR(120) DEFAULT '',
    username VARCHAR(60) DEFAULT '',
    email VARCHAR(150) DEFAULT '',
    phone VARCHAR(40) DEFAULT '',
    role VARCHAR(20) NOT NULL DEFAULT 'cashier',
    salary NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE employees ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_employees_cafe ON employees(cafe_id);

-- 3. CATEGORIES
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    name VARCHAR(120) NOT NULL,
    icon_code_point BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE categories ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_categories_cafe ON categories(cafe_id);

-- 4. PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    name VARCHAR(150) NOT NULL,
    price NUMERIC(15,2) NOT NULL DEFAULT 0,
    category_id INTEGER,
    stock INTEGER NOT NULL DEFAULT 0,
    icon_code_point BIGINT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE products ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
ALTER TABLE products ADD COLUMN IF NOT EXISTS icon_code_point BIGINT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;
CREATE INDEX IF NOT EXISTS idx_products_cafe ON products(cafe_id);

-- 5. HALLS
CREATE TABLE IF NOT EXISTS halls (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    name VARCHAR(120) NOT NULL,
    icon_code_point BIGINT NOT NULL,
    image_asset TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE halls ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_halls_cafe ON halls(cafe_id);

-- 6. TABLES (restaurant tables)
CREATE TABLE IF NOT EXISTS restaurant_tables (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    hall_id INTEGER NOT NULL,
    number INTEGER NOT NULL,
    seats INTEGER NOT NULL DEFAULT 4,
    status VARCHAR(20) NOT NULL DEFAULT 'free',
    order_id VARCHAR(20),
    total NUMERIC(15,2) NOT NULL DEFAULT 0,
    started_by VARCHAR(60),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'free';
ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS total NUMERIC(15,2) DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_tables_cafe ON restaurant_tables(cafe_id);

-- 7. TABLE ORDERS
CREATE TABLE IF NOT EXISTS table_orders (
    table_id INTEGER PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    items JSONB NOT NULL DEFAULT '[]',
    note TEXT DEFAULT '',
    started_by VARCHAR(60),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE table_orders ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_table_orders_cafe ON table_orders(cafe_id);

-- 8. CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    name VARCHAR(150) NOT NULL,
    phone VARCHAR(40) DEFAULT '',
    email VARCHAR(150) DEFAULT '',
    loyalty_points INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE customers ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_customers_cafe ON customers(cafe_id);

-- 9. RECEIPTS
CREATE TABLE IF NOT EXISTS receipts (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    items JSONB NOT NULL DEFAULT '[]',
    total NUMERIC(15,2) NOT NULL DEFAULT 0,
    method VARCHAR(20) NOT NULL DEFAULT 'cash',
    cashier_name VARCHAR(150) DEFAULT '',
    table_number INTEGER,
    hall_name VARCHAR(120),
    cash_paid NUMERIC(15,2) DEFAULT 0,
    card_paid NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(120);
CREATE INDEX IF NOT EXISTS idx_receipts_cafe_date ON receipts(cafe_id, date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS idx_receipts_idempotency ON receipts(cafe_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- 10. CUSTOMER ORDERS

CREATE TABLE IF NOT EXISTS customer_orders (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    items JSONB NOT NULL DEFAULT '[]',
    customer_name VARCHAR(150) DEFAULT '',
    phone VARCHAR(40) DEFAULT '',
    type VARCHAR(20) NOT NULL DEFAULT 'dineIn',
    table_number INTEGER,
    hall_id INTEGER,
    delivery_address TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE customer_orders ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_customer_orders_cafe_date ON customer_orders(cafe_id, date DESC);

-- 11. REPORTS
CREATE TABLE IF NOT EXISTS reports (
    cafe_id VARCHAR(64) NOT NULL,
    date_id VARCHAR(10) NOT NULL,
    total_revenue NUMERIC(15,2) NOT NULL DEFAULT 0,
    order_count INTEGER NOT NULL DEFAULT 0,
    product_quantities JSONB NOT NULL DEFAULT '{}',
    product_revenue JSONB NOT NULL DEFAULT '{}',
    top_product VARCHAR(150) DEFAULT '',
    table_revenue JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (cafe_id, date_id)
);
ALTER TABLE reports ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_reports_cafe_date ON reports(cafe_id, date_id DESC);

-- 12. ACTIVITY LOGS
CREATE TABLE IF NOT EXISTS activity_logs (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    action VARCHAR(80) NOT NULL,
    details TEXT DEFAULT '',
    performed_by VARCHAR(150) DEFAULT '',
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE activity_logs ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_activity_cafe ON activity_logs(cafe_id, timestamp DESC);

-- 13. SETTINGS
CREATE TABLE IF NOT EXISTS settings (
    cafe_id VARCHAR(64) PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE settings ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);

-- 14. IMAGES (uploaded product photos — stored in the database itself, not on
-- disk, so they survive Render free-tier restarts/sleep cycles, which wipe
-- the server's local filesystem)
CREATE TABLE IF NOT EXISTS images (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) REFERENCES cafes(cafe_id) ON DELETE CASCADE,
    mime_type VARCHAR(50) NOT NULL,
    data BYTEA NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE images ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_images_cafe ON images(cafe_id);

-- 15. SUBSCRIPTIONS (Cafe billing & access periods)
CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    user_id INTEGER,
    start_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    blocked_at TIMESTAMP WITH TIME ZONE,
    unblocked_at TIMESTAMP WITH TIME ZONE,
    payment_status VARCHAR(20) NOT NULL DEFAULT 'paid',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_subscriptions_cafe ON subscriptions(cafe_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);

-- 16. SUBSCRIPTION EVENTS
CREATE TABLE IF NOT EXISTS subscription_events (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    user_id INTEGER,
    event_type VARCHAR(50) NOT NULL,
    reason TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(150) DEFAULT ''
);
ALTER TABLE subscription_events ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_sub_events_cafe ON subscription_events(cafe_id);

-- 17. DEVICES
CREATE TABLE IF NOT EXISTS devices (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    cafe_id VARCHAR(64) NOT NULL,
    device_name VARCHAR(150) NOT NULL,
    device_type VARCHAR(50) NOT NULL DEFAULT 'desktop',
    device_identifier VARCHAR(150),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT true
);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
ALTER TABLE devices ADD COLUMN IF NOT EXISTS device_identifier VARCHAR(150);
CREATE INDEX IF NOT EXISTS idx_devices_cafe ON devices(cafe_id);
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_ident ON devices(cafe_id, device_identifier);

-- 18. AUDIT LOGS
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    actor_id INTEGER,
    actor_role VARCHAR(50) DEFAULT '',
    cafe_id VARCHAR(64),
    action VARCHAR(80) NOT NULL,
    target_type VARCHAR(80) DEFAULT '',
    target_id VARCHAR(80) DEFAULT '',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_audit_cafe ON audit_logs(cafe_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);

-- 19. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    priority VARCHAR(20) NOT NULL DEFAULT 'normal',
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    created_by VARCHAR(150) DEFAULT 'ZAVERO Director',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS cafe_id VARCHAR(64);
CREATE INDEX IF NOT EXISTS idx_notifications_cafe ON notifications(cafe_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);

-- ============================================================
-- 20. SUPABASE REALTIME REPLICATION SETUP
-- ============================================================
ALTER TABLE restaurant_tables REPLICA IDENTITY FULL;
ALTER TABLE table_orders REPLICA IDENTITY FULL;
ALTER TABLE customer_orders REPLICA IDENTITY FULL;
ALTER TABLE receipts REPLICA IDENTITY FULL;
ALTER TABLE products REPLICA IDENTITY FULL;
ALTER TABLE categories REPLICA IDENTITY FULL;
ALTER TABLE halls REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER TABLE settings REPLICA IDENTITY FULL;

ALTER TABLE cafes ADD COLUMN IF NOT EXISTS is_under_maintenance BOOLEAN DEFAULT false;

-- 20. SUPPORT TICKETS (Texnik yordam va muammolar)
CREATE TABLE IF NOT EXISTS support_tickets (
    id SERIAL PRIMARY KEY,
    cafe_id VARCHAR(64) NOT NULL,
    cafe_name VARCHAR(150),
    user_id INTEGER,
    user_name VARCHAR(150),
    phone VARCHAR(50),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- pending, in_progress, resolved
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP WITH TIME ZONE
);
CREATE INDEX IF NOT EXISTS idx_support_cafe ON support_tickets(cafe_id);
CREATE INDEX IF NOT EXISTS idx_support_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_created ON support_tickets(created_at DESC);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    BEGIN
      ALTER PUBLICATION supabase_realtime ADD TABLE 
        restaurant_tables, 
        table_orders, 
        customer_orders, 
        receipts, 
        products, 
        categories, 
        halls, 
        customers, 
        employees, 
        reports,
        notifications,
        settings,
        support_tickets;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;
END $$;

-- 21. BOT SETTINGS (Telegram Bot & Subscription Configuration)
CREATE TABLE IF NOT EXISTS bot_settings (
    key VARCHAR(64) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 22. TELEGRAM USERS
CREATE TABLE IF NOT EXISTS telegram_users (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT UNIQUE NOT NULL,
    username VARCHAR(120),
    first_name VARCHAR(150),
    last_name VARCHAR(150),
    phone VARCHAR(40),
    cafe_id VARCHAR(64),
    is_subscribed_channels BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tg_users_tid ON telegram_users(telegram_id);
CREATE INDEX IF NOT EXISTS idx_tg_users_cafe ON telegram_users(cafe_id);

-- 23. SUBSCRIPTIONS (Telegram User & Cafe Subscriptions)
CREATE TABLE IF NOT EXISTS subscriptions (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT,
    cafe_id VARCHAR(64),
    plan_name VARCHAR(60) NOT NULL DEFAULT '1 oy (Monthly)',
    amount NUMERIC(15,2) NOT NULL DEFAULT 250000,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'active', -- active, expired, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS telegram_id BIGINT;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS plan_name VARCHAR(60) DEFAULT '1 oy (Monthly)';
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS amount NUMERIC(15,2) DEFAULT 250000;
ALTER TABLE subscriptions ALTER COLUMN cafe_id DROP NOT NULL;
CREATE INDEX IF NOT EXISTS idx_subs_tid ON subscriptions(telegram_id);
CREATE INDEX IF NOT EXISTS idx_subs_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subs_end ON subscriptions(end_date);

-- 24. PAYMENTS (Click, Payme, etc.)
CREATE TABLE IF NOT EXISTS payments (
    id SERIAL PRIMARY KEY,
    telegram_id BIGINT NOT NULL,
    transaction_id VARCHAR(120) UNIQUE NOT NULL,
    provider VARCHAR(30) NOT NULL, -- click, payme, manual, test
    amount NUMERIC(15,2) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'pending', -- pending, completed, failed, cancelled
    raw_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_payments_tid ON payments(telegram_id);
CREATE INDEX IF NOT EXISTS idx_payments_tx ON payments(transaction_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- Seed default bot settings
INSERT INTO bot_settings (key, value) VALUES
  ('required_channel_1', '@zavero_official'),
  ('required_channel_2', '@zavero_pos'),
  ('subscription_price', '250000'),
  ('subscription_days', '30')
ON CONFLICT (key) DO NOTHING;

-- 25. BOT BLOCKED SPAMMERS (Reklama va spam tarqatuvchilarni umrbod bloklash jadvali)
CREATE TABLE IF NOT EXISTS bot_blocked_spammers (
    id SERIAL PRIMARY KEY,
    telegram_id VARCHAR(64) UNIQUE NOT NULL,
    username VARCHAR(120),
    first_name VARCHAR(150),
    reason TEXT NOT NULL DEFAULT 'Spam / Reklama tarqatish',
    message_snippet TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_bot_blocked_spammers_tid ON bot_blocked_spammers(telegram_id);
