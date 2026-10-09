-- ============================================================
--  OPTIONAL demo data so the admin pages aren't empty.
--  Import AFTER schema.sql. Do NOT import on your live site.
--  Dates are relative to NOW(), so "this month" stats work.
-- ============================================================
USE santiblinds;

INSERT INTO customers (fname, lname, email, phone, location, created_at) VALUES
('Maria',  'Santos',  'maria.santos@example.com',  '0917 123 4567', 'Makati City',    DATE_SUB(NOW(), INTERVAL 150 DAY)),
('James',  'Reyes',   'james.reyes@example.com',   '0918 234 5678', 'BGC, Taguig',    DATE_SUB(NOW(), INTERVAL 120 DAY)),
('Claire', 'Mendoza', 'claire.mendoza@example.com','0919 345 6789', 'Quezon City',    DATE_SUB(NOW(), INTERVAL 90 DAY)),
('Paolo',  'Villanueva','paolo.v@example.com',     '0920 456 7890', 'Valenzuela City',DATE_SUB(NOW(), INTERVAL 40 DAY)),
('Anna',   'Cruz',    'anna.cruz@example.com',     '0921 567 8901', 'Pasig City',     DATE_SUB(NOW(), INTERVAL 10 DAY));

INSERT INTO orders (customer_id, product_type, quantity, amount, status, specifications, order_date) VALUES
(1, 'Roller Blinds',   4, 18500.00, 'Completed',         'Living room, 4 windows. Blackout, light grey. Inside mount.',          DATE_SUB(NOW(), INTERVAL 140 DAY)),
(2, 'Motorized Blinds',6, 96000.00, 'Completed',         'Office floor-to-ceiling, remote + app control, dim-out fabric.',       DATE_SUB(NOW(), INTERVAL 110 DAY)),
(3, 'Roman Blinds',    2, 14200.00, 'Completed',         'Master bedroom, linen look, cream. Outside mount.',                    DATE_SUB(NOW(), INTERVAL 75 DAY)),
(1, 'Venetian Blinds', 3, 11700.00, 'Completed',         'Home office, 50mm aluminium slats, white.',                            DATE_SUB(NOW(), INTERVAL 50 DAY)),
(4, 'Roller Blinds',   5, 21000.00, 'Completed',         'Showroom cafe windows, sunscreen 5%, charcoal.',                       DATE_SUB(NOW(), INTERVAL 25 DAY)),
(3, 'Venetian Blinds', 2,  8400.00, 'Ready for Install', 'Kids room. Wood-look 50mm, walnut.',                                   DATE_SUB(NOW(), INTERVAL 12 DAY)),
(5, 'Roman Blinds',    3, 21900.00, 'Processing',        'Dining area, blackout lining, sage green. Measurements taken on site.',DATE_SUB(NOW(), INTERVAL 6 DAY)),
(2, 'Motorized Blinds',2, 34500.00, 'Pending',           'Condo bedroom, quiet motor, white. Install after unit turnover.',      DATE_SUB(NOW(), INTERVAL 3 DAY)),
(5, 'Roller Blinds',   1,  4200.00, 'Cancelled',         'Customer changed mind.',                                               DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 'Roller Blinds',   2,  9000.00, 'Completed',         'Storage room, basic blackout.',                                        DATE_SUB(NOW(), INTERVAL 1 DAY));

INSERT INTO inventory (material_name, category, quantity_available, unit, reorder_level) VALUES
('Blackout Roller Fabric - Grey',  'Fabric',      42, 'm',   20),
('Sunscreen 5% Fabric - Charcoal', 'Fabric',      15, 'm',   20),
('Linen-look Roman Fabric - Cream','Fabric',      30, 'm',   15),
('Aluminium Slats 50mm - White',   'Slats',      120, 'pcs', 60),
('Wood-look Slats 50mm - Walnut',  'Slats',       35, 'pcs', 40),
('Roller Tube 38mm',               'Hardware',    60, 'pcs', 25),
('Headrail Brackets',              'Hardware',   200, 'pcs', 80),
('Tubular Motor (Quiet)',          'Motorized',    8, 'pcs', 10),
('Remote Controller',              'Motorized',   14, 'pcs',  6);
