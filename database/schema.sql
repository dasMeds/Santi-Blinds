-- ============================================================
-- Santi Blinds — unified database schema + starter data
-- Fresh installation: import this file in phpMyAdmin.
-- Database: santiblinds
--
-- Embedded owner account:
-- Email: owner@santiblinds.com
-- Password: santiowner
-- The password is stored as a PHP password_hash() hash.
-- ============================================================

CREATE DATABASE IF NOT EXISTS santiblinds
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE santiblinds;

-- ------------------------------------------------------------
-- OWNER ACCOUNT
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS owner_manager (
  owner_id      INT AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(160) NOT NULL,
  email         VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Owner/admin sign-ins and write actions are recorded here.
CREATE TABLE IF NOT EXISTS admin_audit_log (
  audit_id    INT AUTO_INCREMENT PRIMARY KEY,
  owner_id    INT NULL,
  admin_name  VARCHAR(160) NOT NULL,
  action      VARCHAR(100) NOT NULL,
  details     TEXT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_created (created_at),
  FOREIGN KEY (owner_id) REFERENCES owner_manager(owner_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Add the built-in owner only if this email does not already exist.
INSERT INTO owner_manager (full_name, email, password_hash)
SELECT 'Santi Blinds Owner',
       'owner@santiblinds.com',
       '$2y$12$2J4tOmzWOJ8Cg3WCRFSIo.0s7tE6knu5R3EyA6NVqlWBa6ZpB9J3C'
WHERE NOT EXISTS (
  SELECT 1 FROM owner_manager WHERE email = 'owner@santiblinds.com'
);

-- ------------------------------------------------------------
-- CUSTOMERS
-- password_hash is NULL for guest/contact-form customers.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer (
  customer_id   INT AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(160) NOT NULL,
  email         VARCHAR(160) NOT NULL,
  phone         VARCHAR(40) NOT NULL,
  address       VARCHAR(255) NULL,
  password_hash VARCHAR(255) NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_customer_email (email)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- PRODUCT CATALOG
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS category (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product (
  product_id  INT AUTO_INCREMENT PRIMARY KEY,
  category_id INT NOT NULL,
  name        VARCHAR(120) NOT NULL,
  blind_type  VARCHAR(60) NOT NULL,
  description VARCHAR(255) NULL,
  base_price  DECIMAL(10,2) NOT NULL,
  image_url   VARCHAR(255) NULL,
  stock_qty   INT NOT NULL DEFAULT 0,
  INDEX idx_product_category (category_id),
  FOREIGN KEY (category_id) REFERENCES category(category_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material (
  material_id    INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(80) NOT NULL,
  price_modifier DECIMAL(10,2) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS color (
  color_id INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(80) NOT NULL,
  hex_code CHAR(7) NOT NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- QUOTATIONS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS quotation (
  quotation_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  status       VARCHAR(30) NOT NULL DEFAULT 'Active',
  valid_until  DATETIME NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_quotation_customer (customer_id),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS quotation_item (
  quotation_item_id INT AUTO_INCREMENT PRIMARY KEY,
  quotation_id INT NOT NULL,
  product_id   INT NOT NULL,
  material_id  INT NOT NULL,
  color_id     INT NOT NULL,
  width_cm     DECIMAL(6,1) NOT NULL,
  height_cm    DECIMAL(6,1) NOT NULL,
  quantity     INT NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  INDEX idx_qitem_quotation (quotation_id),
  FOREIGN KEY (quotation_id) REFERENCES quotation(quotation_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  FOREIGN KEY (material_id) REFERENCES material(material_id),
  FOREIGN KEY (color_id) REFERENCES color(color_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- ORDERS
-- One row per item; items from the same order share order_id.
-- quotation_id is NULL for orders not created from a quotation.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  line_id      INT AUTO_INCREMENT PRIMARY KEY,
  order_id     INT NOT NULL,
  customer_id  INT NOT NULL,
  quotation_id INT NULL,
  product_id   INT NOT NULL,
  material_id  INT NOT NULL,
  color_id     INT NOT NULL,
  width_cm     DECIMAL(6,1) NOT NULL,
  height_cm    DECIMAL(6,1) NOT NULL,
  quantity     INT NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  status       VARCHAR(30) NOT NULL DEFAULT 'Pending',
  order_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_orders_order (order_id),
  INDEX idx_orders_status (status),
  INDEX idx_orders_quotation (quotation_id),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  FOREIGN KEY (quotation_id) REFERENCES quotation(quotation_id),
  FOREIGN KEY (product_id) REFERENCES product(product_id),
  FOREIGN KEY (material_id) REFERENCES material(material_id),
  FOREIGN KEY (color_id) REFERENCES color(color_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- SALES AND INQUIRIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sale (
  sale_id        INT AUTO_INCREMENT PRIMARY KEY,
  order_id       INT NOT NULL UNIQUE,
  amount_paid    DECIMAL(12,2) NOT NULL,
  payment_method VARCHAR(30) NOT NULL DEFAULT 'Cash',
  sale_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS inquiry (
  enquiry_id  INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  product_id  INT NOT NULL,
  message     TEXT NULL,
  status      VARCHAR(30) NOT NULL DEFAULT 'New',
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_inquiry_status (status),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  FOREIGN KEY (product_id) REFERENCES product(product_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- STARTER DATA
-- Each seed is inserted only when the matching name is absent,
-- so re-importing does not duplicate the starter catalog.
-- ------------------------------------------------------------
INSERT INTO category (name)
SELECT 'Fabric' WHERE NOT EXISTS (SELECT 1 FROM category WHERE name = 'Fabric');
INSERT INTO category (name)
SELECT 'Hard Slat' WHERE NOT EXISTS (SELECT 1 FROM category WHERE name = 'Hard Slat');
INSERT INTO category (name)
SELECT 'Smart' WHERE NOT EXISTS (SELECT 1 FROM category WHERE name = 'Smart');

INSERT INTO product
  (category_id, name, blind_type, description, base_price, stock_qty)
SELECT c.category_id, seed.name, seed.blind_type, seed.description, seed.base_price, 50
FROM (
  SELECT 'Roller Blinds' AS name, 'Roller' AS blind_type, 'Clean-lined and modern' AS description, 950.00 AS base_price, 'Fabric' AS category_name
  UNION ALL SELECT 'Venetian Blinds', 'Venetian', 'Aluminium and wood slats', 1400.00, 'Hard Slat'
  UNION ALL SELECT 'Roman Blinds', 'Roman', 'Soft fabric folds', 1800.00, 'Fabric'
  UNION ALL SELECT 'Vertical Blinds', 'Vertical', 'Ideal for large windows', 900.00, 'Fabric'
  UNION ALL SELECT 'Cellular / Honeycomb', 'Cellular', 'Insulating and soft', 1600.00, 'Fabric'
  UNION ALL SELECT 'Motorized Blinds', 'Motorized', 'App, remote and voice control', 3200.00, 'Smart'
) AS seed
JOIN category c ON c.name = seed.category_name
WHERE NOT EXISTS (
  SELECT 1 FROM product p WHERE p.name = seed.name
);

INSERT INTO material (name, price_modifier)
SELECT seed.name, seed.price_modifier
FROM (
  SELECT 'Light-filtering' AS name, 0.00 AS price_modifier
  UNION ALL SELECT 'Blackout', 150.00
  UNION ALL SELECT 'Sheer', 0.00
  UNION ALL SELECT 'Sunscreen', 100.00
  UNION ALL SELECT 'Wood Grain', 400.00
) AS seed
WHERE NOT EXISTS (
  SELECT 1 FROM material m WHERE m.name = seed.name
);

INSERT INTO color (name, hex_code)
SELECT seed.name, seed.hex_code
FROM (
  SELECT 'Ivory White' AS name, '#F5F1E6' AS hex_code
  UNION ALL SELECT 'Natural Linen', '#D8C8A8'
  UNION ALL SELECT 'Charcoal', '#36454F'
  UNION ALL SELECT 'Jet Black', '#111111'
  UNION ALL SELECT 'Steel Grey', '#71797E'
  UNION ALL SELECT 'Navy Blue', '#1F2A44'
  UNION ALL SELECT 'Lavender', '#B9A6D6'
  UNION ALL SELECT 'Deep Purple', '#4B2A6B'
  UNION ALL SELECT 'Walnut', '#5C4033'
  UNION ALL SELECT 'Dark Chocolate', '#3B2A20'
  UNION ALL SELECT 'Crimson Red', '#A4161A'
  UNION ALL SELECT 'Honey Yellow', '#E0A526'
  UNION ALL SELECT 'Tangerine', '#F28C28'
) AS seed
WHERE NOT EXISTS (
  SELECT 1 FROM color c WHERE c.name = seed.name
);
