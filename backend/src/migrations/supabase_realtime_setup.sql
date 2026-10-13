-- ============================================================
-- ZAVERO POS — SUPABASE POSTGRESQL & REALTIME SETUP SCRIPT
-- Run this script in Supabase SQL Editor (https://supabase.com/dashboard/project/_/sql)
-- ============================================================

-- 1. SCHEMAS & FULL REPLICA IDENTITY (Required for Supabase Realtime old/new records)
ALTER TABLE IF EXISTS restaurant_tables REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS table_orders REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS customer_orders REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS receipts REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS products REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS categories REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS halls REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS customers REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS employees REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS reports REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS users REPLICA IDENTITY FULL;
ALTER TABLE IF EXISTS cafes REPLICA IDENTITY FULL;

-- 2. ADD TABLES TO SUPABASE REALTIME PUBLICATION
-- This instructs Supabase Realtime engine to broadcast INSERT, UPDATE, DELETE changes
DO $$
BEGIN
  -- restaurant_tables
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'restaurant_tables'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE restaurant_tables;
  END IF;

  -- table_orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'table_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE table_orders;
  END IF;

  -- customer_orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'customer_orders'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE customer_orders;
  END IF;

  -- receipts
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'receipts'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE receipts;
  END IF;

  -- products
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'products'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE products;
  END IF;

  -- categories
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'categories'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE categories;
  END IF;

  -- halls
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'halls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE halls;
  END IF;

  -- customers
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'customers'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE customers;
  END IF;

  -- employees
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'employees'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE employees;
  END IF;

  -- reports
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE reports;
  END IF;

  -- users
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE users;
  END IF;

  -- cafes
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'cafes'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE cafes;
  END IF;
END $$;

-- 3. ENABLE ROW LEVEL SECURITY (RLS) FOR REALTIME ACCESS CONTROL
-- In Supabase, Realtime respects Row Level Security policies.
-- We enable RLS and add public read policy so clients with anon key can receive realtime stream.
ALTER TABLE restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE table_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE halls ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE cafes ENABLE ROW LEVEL SECURITY;

-- Allow read for anon/authenticated clients so Realtime WebSocket stream works smoothly
DO $$
BEGIN
  -- restaurant_tables
  DROP POLICY IF EXISTS "realtime_read_tables" ON restaurant_tables;
  CREATE POLICY "realtime_read_tables" ON restaurant_tables FOR SELECT USING (true);

  -- table_orders
  DROP POLICY IF EXISTS "realtime_read_table_orders" ON table_orders;
  CREATE POLICY "realtime_read_table_orders" ON table_orders FOR SELECT USING (true);

  -- customer_orders
  DROP POLICY IF EXISTS "realtime_read_customer_orders" ON customer_orders;
  CREATE POLICY "realtime_read_customer_orders" ON customer_orders FOR SELECT USING (true);

  -- receipts
  DROP POLICY IF EXISTS "realtime_read_receipts" ON receipts;
  CREATE POLICY "realtime_read_receipts" ON receipts FOR SELECT USING (true);

  -- products
  DROP POLICY IF EXISTS "realtime_read_products" ON products;
  CREATE POLICY "realtime_read_products" ON products FOR SELECT USING (true);

  -- categories
  DROP POLICY IF EXISTS "realtime_read_categories" ON categories;
  CREATE POLICY "realtime_read_categories" ON categories FOR SELECT USING (true);

  -- halls
  DROP POLICY IF EXISTS "realtime_read_halls" ON halls;
  CREATE POLICY "realtime_read_halls" ON halls FOR SELECT USING (true);

  -- customers
  DROP POLICY IF EXISTS "realtime_read_customers" ON customers;
  CREATE POLICY "realtime_read_customers" ON customers FOR SELECT USING (true);

  -- employees
  DROP POLICY IF EXISTS "realtime_read_employees" ON employees;
  CREATE POLICY "realtime_read_employees" ON employees FOR SELECT USING (true);

  -- reports
  DROP POLICY IF EXISTS "realtime_read_reports" ON reports;
  CREATE POLICY "realtime_read_reports" ON reports FOR SELECT USING (true);

  -- cafes
  DROP POLICY IF EXISTS "realtime_read_cafes" ON cafes;
  CREATE POLICY "realtime_read_cafes" ON cafes FOR SELECT USING (true);
END $$;
