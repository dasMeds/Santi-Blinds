-- ============================================================
--  Santi Blinds — database schema + starter data
--  Import in phpMyAdmin (Import tab) or:  mysql -u root < schema.sql
-- ============================================================
CREATE DATABASE IF NOT EXISTS santiblinds CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE santiblinds;

CREATE TABLE IF NOT EXISTS owner_manager (
  owner_id      INT AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(160) NOT NULL,
  email         VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customer (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  full_name   VARCHAR(160) NOT NULL,
  email       VARCHAR(160) NOT NULL,
  phone       VARCHAR(40)  NOT NULL,
  address     VARCHAR(255) NULL,
  password_hash VARCHAR(255) NULL,                 -- NULL = guest (e.g. contact-form inquiry), set = registered account
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_customer_email (email)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS category (
  category_id INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(80) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product (
  product_id  INT AUTO_INCREMENT PRIMARY KEY,
  category_id INT NOT NULL,
  name        VARCHAR(120) NOT NULL,
  blind_type  VARCHAR(60)  NOT NULL,
  description VARCHAR(255) NULL,
  base_price  DECIMAL(10,2) NOT NULL,          -- price per square metre
  image_url   VARCHAR(255) NULL,
  stock_qty   INT NOT NULL DEFAULT 0,
  FOREIGN KEY (category_id) REFERENCES category(category_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS material (
  material_id    INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(80) NOT NULL,
  price_modifier DECIMAL(10,2) NOT NULL DEFAULT 0   -- flat amount added per blind
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS color (
  color_id INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(80) NOT NULL,
  hex_code CHAR(7) NOT NULL
) ENGINE=InnoDB;

-- A priced quotation a logged-in customer generates from their design.
-- Prices are locked here; the order is placed from the quotation until valid_until.
CREATE TABLE IF NOT EXISTS quotation (
  quotation_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id  INT NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  status       VARCHAR(30) NOT NULL DEFAULT 'Active',   -- Active | Ordered (Expired is derived from valid_until)
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
  FOREIGN KEY (product_id)   REFERENCES product(product_id),
  FOREIGN KEY (material_id)  REFERENCES material(material_id),
  FOREIGN KEY (color_id)     REFERENCES color(color_id)
) ENGINE=InnoDB;

-- One row per item; items of the same order share order_id.
CREATE TABLE IF NOT EXISTS orders (
  line_id      INT AUTO_INCREMENT PRIMARY KEY,
  order_id     INT NOT NULL,
  customer_id  INT NOT NULL,
  quotation_id INT NULL,                           -- the quotation this order was placed from (NULL for older orders)
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
  FOREIGN KEY (product_id)  REFERENCES product(product_id),
  FOREIGN KEY (material_id) REFERENCES material(material_id),
  FOREIGN KEY (color_id)    REFERENCES color(color_id)
) ENGINE=InnoDB;

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
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  FOREIGN KEY (product_id)  REFERENCES product(product_id)
) ENGINE=InnoDB;

-- ---------------- Starter catalog (edit prices to suit) ----------------
INSERT INTO category (name) VALUES ('Fabric'), ('Hard Slat'), ('Smart');

INSERT INTO product (category_id, name, blind_type, description, base_price, stock_qty) VALUES
 (1, 'Roller Blinds',       'Roller',    'Clean-lined and modern',           950.00,  50),
 (2, 'Venetian Blinds',     'Venetian',  'Aluminium and wood slats',        1400.00,  50),
 (1, 'Roman Blinds',        'Roman',     'Soft fabric folds',               1800.00,  50),
 (1, 'Vertical Blinds',     'Vertical',  'Ideal for large windows',          900.00,  50),
 (1, 'Cellular / Honeycomb','Cellular',  'Insulating and soft',             1600.00,  50),
 (3, 'Motorized Blinds',    'Motorized', 'App, remote and voice control',   3200.00,  50);

INSERT INTO material (name, price_modifier) VALUES
 ('Light-filtering', 0.00), ('Blackout', 150.00), ('Sheer', 0.00),
 ('Sunscreen', 100.00), ('Wood Grain', 400.00);

INSERT INTO color (name, hex_code) VALUES
 ('Ivory White','#F5F1E6'), ('Natural Linen','#D8C8A8'), ('Charcoal','#36454F'),
 ('Jet Black','#111111'), ('Steel Grey','#71797E'), ('Navy Blue','#1F2A44'),
 ('Lavender','#B9A6D6'), ('Deep Purple','#4B2A6B'), ('Walnut','#5C4033'),
 ('Dark Chocolate','#3B2A20'), ('Crimson Red','#A4161A'), ('Honey Yellow','#E0A526'),
 ('Tangerine','#F28C28');
