-- ============================================================
--  Santi Blinds — migration for an EXISTING database (re-runnable)
--  Adds customer accounts (customer.password_hash) and quotations.
--  Import in phpMyAdmin (Import tab). Safe to run more than once:
--  every step is skipped if it was already applied.
-- ============================================================
USE santiblinds;

-- Foreign keys need InnoDB tables (does nothing if they already are).
ALTER TABLE customer ENGINE=InnoDB;
ALTER TABLE product  ENGINE=InnoDB;
ALTER TABLE material ENGINE=InnoDB;
ALTER TABLE color    ENGINE=InnoDB;
ALTER TABLE orders   ENGINE=InnoDB;

-- 1) customer.password_hash
SET @s = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE customer ADD COLUMN password_hash VARCHAR(255) NULL AFTER address',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'customer' AND COLUMN_NAME = 'password_hash');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

-- 2) quotation tables
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
  FOREIGN KEY (product_id)   REFERENCES product(product_id),
  FOREIGN KEY (material_id)  REFERENCES material(material_id),
  FOREIGN KEY (color_id)     REFERENCES color(color_id)
) ENGINE=InnoDB;

-- 3) orders.quotation_id (column, index, foreign key — each only if missing)
SET @s = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE orders ADD COLUMN quotation_id INT NULL AFTER customer_id',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND COLUMN_NAME = 'quotation_id');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

SET @s = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE orders ADD INDEX idx_orders_quotation (quotation_id)',
  'SELECT 1')
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND INDEX_NAME = 'idx_orders_quotation');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;

SET @s = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE orders ADD CONSTRAINT fk_orders_quotation FOREIGN KEY (quotation_id) REFERENCES quotation(quotation_id)',
  'SELECT 1')
  FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND CONSTRAINT_NAME = 'fk_orders_quotation');
PREPARE st FROM @s; EXECUTE st; DEALLOCATE PREPARE st;
