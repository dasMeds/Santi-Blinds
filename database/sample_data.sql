-- ============================================================
--  Demo data for admin dashboard testing.
--  Import AFTER schema.sql. Do NOT import on a live site.
--  The dates are relative to NOW(), so monthly stats remain useful.
-- ============================================================
USE santiblinds;

-- Customers used by the admin dashboard and customer list screens.
INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'Maria Santos', 'maria.santos@example.com', '0917 123 4567', 'Makati City', NULL, DATE_SUB(NOW(), INTERVAL 150 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'maria.santos@example.com');

INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'James Reyes', 'james.reyes@example.com', '0918 234 5678', 'BGC, Taguig', NULL, DATE_SUB(NOW(), INTERVAL 120 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'james.reyes@example.com');

INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'Claire Mendoza', 'claire.mendoza@example.com', '0919 345 6789', 'Quezon City', NULL, DATE_SUB(NOW(), INTERVAL 90 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'claire.mendoza@example.com');

INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'Paolo Villanueva', 'paolo.v@example.com', '0920 456 7890', 'Valenzuela City', NULL, DATE_SUB(NOW(), INTERVAL 40 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'paolo.v@example.com');

INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'Anna Cruz', 'anna.cruz@example.com', '0921 567 8901', 'Pasig City', NULL, DATE_SUB(NOW(), INTERVAL 10 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'anna.cruz@example.com');

INSERT INTO customer (full_name, email, phone, address, password_hash, created_at)
SELECT 'Sarah Lim', 'sarah.lim@example.com', '0932 111 2233', 'Cebu City', NULL, DATE_SUB(NOW(), INTERVAL 7 DAY)
WHERE NOT EXISTS (SELECT 1 FROM customer WHERE email = 'sarah.lim@example.com');

-- Sample quotations to exercise the quote workflow.
INSERT INTO quotation (customer_id, total_amount, status, valid_until, created_at)
SELECT c.customer_id, 18400.00, 'Accepted', DATE_ADD(NOW(), INTERVAL 30 DAY), DATE_SUB(NOW(), INTERVAL 18 DAY)
FROM customer c
WHERE c.email = 'maria.santos@example.com'
  AND NOT EXISTS (SELECT 1 FROM quotation WHERE customer_id = c.customer_id AND total_amount = 18400.00);

INSERT INTO quotation_item (quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount)
SELECT q.quotation_id,
       p.product_id,
       m.material_id,
       col.color_id,
       180.0, 210.0, 2, 9200.00, 18400.00
FROM quotation q
JOIN product p ON p.name = 'Roller Blinds'
JOIN material m ON m.name = 'Blackout'
JOIN color col ON col.name = 'Charcoal'
WHERE q.customer_id = (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com')
  AND q.total_amount = 18400.00
  AND NOT EXISTS (SELECT 1 FROM quotation_item WHERE quotation_id = q.quotation_id AND product_id = p.product_id);

INSERT INTO quotation (customer_id, total_amount, status, valid_until, created_at)
SELECT c.customer_id, 32150.00, 'Pending', DATE_ADD(NOW(), INTERVAL 21 DAY), DATE_SUB(NOW(), INTERVAL 9 DAY)
FROM customer c
WHERE c.email = 'james.reyes@example.com'
  AND NOT EXISTS (SELECT 1 FROM quotation WHERE customer_id = c.customer_id AND total_amount = 32150.00);

INSERT INTO quotation_item (quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount)
SELECT q.quotation_id,
       p.product_id,
       m.material_id,
       col.color_id,
       210.0, 240.0, 1, 32150.00, 32150.00
FROM quotation q
JOIN product p ON p.name = 'Motorized Blinds'
JOIN material m ON m.name = 'Light-filtering'
JOIN color col ON col.name = 'Ivory White'
WHERE q.customer_id = (SELECT customer_id FROM customer WHERE email = 'james.reyes@example.com')
  AND q.total_amount = 32150.00
  AND NOT EXISTS (SELECT 1 FROM quotation_item WHERE quotation_id = q.quotation_id AND product_id = p.product_id);

-- A broader set of order rows so the admin status filters are not empty.
INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1001,
  (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com'),
  (SELECT quotation_id FROM quotation WHERE customer_id = (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com') AND total_amount = 18400.00 ORDER BY quotation_id DESC LIMIT 1),
  (SELECT product_id FROM product WHERE name = 'Roller Blinds'),
  (SELECT material_id FROM material WHERE name = 'Blackout'),
  (SELECT color_id FROM color WHERE name = 'Charcoal'),
  180.0, 210.0, 2, 9200.00, 18400.00, 'Completed', DATE_SUB(NOW(), INTERVAL 140 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1001
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roller Blinds')
  AND total_amount = 18400.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1002,
  (SELECT customer_id FROM customer WHERE email = 'james.reyes@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Motorized Blinds'),
  (SELECT material_id FROM material WHERE name = 'Light-filtering'),
  (SELECT color_id FROM color WHERE name = 'Ivory White'),
  220.0, 240.0, 1, 32150.00, 32150.00, 'Completed', DATE_SUB(NOW(), INTERVAL 110 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1002
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'james.reyes@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Motorized Blinds')
  AND total_amount = 32150.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1003,
  (SELECT customer_id FROM customer WHERE email = 'claire.mendoza@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Roman Blinds'),
  (SELECT material_id FROM material WHERE name = 'Blackout'),
  (SELECT color_id FROM color WHERE name = 'Natural Linen'),
  160.0, 200.0, 2, 17500.00, 35000.00, 'Completed', DATE_SUB(NOW(), INTERVAL 75 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1003
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'claire.mendoza@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roman Blinds')
  AND total_amount = 35000.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1004,
  (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Venetian Blinds'),
  (SELECT material_id FROM material WHERE name = 'Wood Grain'),
  (SELECT color_id FROM color WHERE name = 'Walnut'),
  130.0, 180.0, 3, 4700.00, 14100.00, 'Completed', DATE_SUB(NOW(), INTERVAL 50 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1004
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'maria.santos@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Venetian Blinds')
  AND total_amount = 14100.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1005,
  (SELECT customer_id FROM customer WHERE email = 'paolo.v@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Roller Blinds'),
  (SELECT material_id FROM material WHERE name = 'Sunscreen'),
  (SELECT color_id FROM color WHERE name = 'Charcoal'),
  150.0, 190.0, 5, 4200.00, 21000.00, 'Completed', DATE_SUB(NOW(), INTERVAL 25 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1005
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'paolo.v@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roller Blinds')
  AND total_amount = 21000.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1006,
  (SELECT customer_id FROM customer WHERE email = 'claire.mendoza@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Venetian Blinds'),
  (SELECT material_id FROM material WHERE name = 'Wood Grain'),
  (SELECT color_id FROM color WHERE name = 'Dark Chocolate'),
  120.0, 150.0, 2, 7600.00, 15200.00, 'Ready for Install', DATE_SUB(NOW(), INTERVAL 12 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1006
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'claire.mendoza@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Venetian Blinds')
  AND total_amount = 15200.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1007,
  (SELECT customer_id FROM customer WHERE email = 'anna.cruz@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Roman Blinds'),
  (SELECT material_id FROM material WHERE name = 'Blackout'),
  (SELECT color_id FROM color WHERE name = 'Navy Blue'),
  170.0, 200.0, 3, 7300.00, 21900.00, 'Processing', DATE_SUB(NOW(), INTERVAL 6 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1007
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'anna.cruz@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roman Blinds')
  AND total_amount = 21900.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1008,
  (SELECT customer_id FROM customer WHERE email = 'james.reyes@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Motorized Blinds'),
  (SELECT material_id FROM material WHERE name = 'Light-filtering'),
  (SELECT color_id FROM color WHERE name = 'Steel Grey'),
  240.0, 200.0, 1, 34500.00, 34500.00, 'Pending', DATE_SUB(NOW(), INTERVAL 3 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1008
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'james.reyes@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Motorized Blinds')
  AND total_amount = 34500.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1009,
  (SELECT customer_id FROM customer WHERE email = 'sarah.lim@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Roller Blinds'),
  (SELECT material_id FROM material WHERE name = 'Light-filtering'),
  (SELECT color_id FROM color WHERE name = 'Crimson Red'),
  100.0, 120.0, 1, 4200.00, 4200.00, 'Cancelled', DATE_SUB(NOW(), INTERVAL 2 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1009
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'sarah.lim@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roller Blinds')
  AND total_amount = 4200.00
);

INSERT INTO orders (order_id, customer_id, quotation_id, product_id, material_id, color_id, width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
SELECT
  1010,
  (SELECT customer_id FROM customer WHERE email = 'paolo.v@example.com'),
  NULL,
  (SELECT product_id FROM product WHERE name = 'Roller Blinds'),
  (SELECT material_id FROM material WHERE name = 'Blackout'),
  (SELECT color_id FROM color WHERE name = 'Jet Black'),
  110.0, 140.0, 2, 4500.00, 9000.00, 'Completed', DATE_SUB(NOW(), INTERVAL 1 DAY)
WHERE NOT EXISTS (
  SELECT 1 FROM orders WHERE order_id = 1010
  AND customer_id = (SELECT customer_id FROM customer WHERE email = 'paolo.v@example.com')
  AND product_id = (SELECT product_id FROM product WHERE name = 'Roller Blinds')
  AND total_amount = 9000.00
);

-- Completed orders stored as paid sales for the revenue reports.
INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1001, 18400.00, 'Cash', DATE_SUB(NOW(), INTERVAL 140 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1001);

INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1002, 32150.00, 'GCash', DATE_SUB(NOW(), INTERVAL 110 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1002);

INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1003, 35000.00, 'Bank Transfer', DATE_SUB(NOW(), INTERVAL 75 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1003);

INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1004, 14100.00, 'Cash', DATE_SUB(NOW(), INTERVAL 50 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1004);

INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1005, 21000.00, 'GCash', DATE_SUB(NOW(), INTERVAL 25 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1005);

INSERT INTO sale (order_id, amount_paid, payment_method, sale_date)
SELECT 1010, 9000.00, 'Bank Transfer', DATE_SUB(NOW(), INTERVAL 1 DAY)
WHERE NOT EXISTS (SELECT 1 FROM sale WHERE order_id = 1010);

-- Customer inquiries to validate the inquiry workflow and admin triage.
INSERT INTO inquiry (customer_id, product_id, message, status, created_at)
SELECT c.customer_id,
       p.product_id,
       'We need a quote for sliding bedroom panels with a soft grey finish and smart-lift option.',
       'New',
       DATE_SUB(NOW(), INTERVAL 15 DAY)
FROM customer c
JOIN product p ON p.name = 'Vertical Blinds'
WHERE c.email = 'maria.santos@example.com'
  AND NOT EXISTS (SELECT 1 FROM inquiry WHERE customer_id = c.customer_id AND product_id = p.product_id);

INSERT INTO inquiry (customer_id, product_id, message, status, created_at)
SELECT c.customer_id,
       p.product_id,
       'Interested in blackout fabric for a child''s room and would like installation cost details.',
       'Follow Up',
       DATE_SUB(NOW(), INTERVAL 8 DAY)
FROM customer c
JOIN product p ON p.name = 'Roman Blinds'
WHERE c.email = 'anna.cruz@example.com'
  AND NOT EXISTS (SELECT 1 FROM inquiry WHERE customer_id = c.customer_id AND product_id = p.product_id);

INSERT INTO inquiry (customer_id, product_id, message, status, created_at)
SELECT c.customer_id,
       p.product_id,
       'Do you have a quiet motorized option with app control for the office?',
       'Resolved',
       DATE_SUB(NOW(), INTERVAL 4 DAY)
FROM customer c
JOIN product p ON p.name = 'Motorized Blinds'
WHERE c.email = 'james.reyes@example.com'
  AND NOT EXISTS (SELECT 1 FROM inquiry WHERE customer_id = c.customer_id AND product_id = p.product_id);

-- Lower some stock values to trigger the low-stock admin alerts.
UPDATE product
SET stock_qty = CASE
  WHEN name = 'Roller Blinds' THEN 3
  WHEN name = 'Venetian Blinds' THEN 8
  WHEN name = 'Roman Blinds' THEN 5
  WHEN name = 'Vertical Blinds' THEN 12
  WHEN name = 'Cellular / Honeycomb' THEN 2
  WHEN name = 'Motorized Blinds' THEN 1
  ELSE stock_qty
END;

-- Optional audit trail so admin activity pages have visible sample entries.
INSERT INTO admin_audit_log (owner_id, admin_name, action, details, created_at)
SELECT owner_id, 'Santi Blinds Owner', 'Seed data import', 'Loaded demo customers, quotations, orders, sales, and inquiry records.', NOW()
FROM owner_manager
WHERE email = 'owner@santiblinds.com'
  AND NOT EXISTS (SELECT 1 FROM admin_audit_log WHERE action = 'Seed data import' AND details = 'Loaded demo customers, quotations, orders, sales, and inquiry records.');
