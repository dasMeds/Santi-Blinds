-- ============================================================
-- Santi Blinds — upgrade an EXISTING database (safe to re-run)
-- Back up first. Import in phpMyAdmin on the santiblinds database.
-- Fresh installs do NOT need this: database/schema.sql already has it.
--
-- Fixes: TC020/TC021 (inquiry columns), TC027/TC030 (orders.is_archived),
--        TC043 (customer_activity), plus ISO 9001 record controls.
-- Works on MariaDB and MySQL 8 (columns are added only when missing).
-- ============================================================
USE santiblinds;

DROP PROCEDURE IF EXISTS santi_add_column;
DELIMITER $$
CREATE PROCEDURE santi_add_column(IN tbl VARCHAR(64), IN col VARCHAR(64), IN ddl VARCHAR(500))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = tbl AND COLUMN_NAME = col) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN `', col, '` ', ddl);
    PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;
  END IF;
END$$
DELIMITER ;

CALL santi_add_column('orders', 'is_archived', 'TINYINT(1) NOT NULL DEFAULT 0');
CALL santi_add_column('quotation', 'reviewed_by', 'INT NULL');
CALL santi_add_column('quotation', 'reviewed_at', 'DATETIME NULL');
CALL santi_add_column('inquiry', 'interest', 'VARCHAR(120) NULL');
CALL santi_add_column('inquiry', 'preferred_contact', 'VARCHAR(60) NULL');
CALL santi_add_column('inquiry', 'rooms', 'VARCHAR(60) NULL');
CALL santi_add_column('inquiry', 'budget', 'VARCHAR(60) NULL');
CALL santi_add_column('inquiry', 'consent', 'TINYINT(1) NOT NULL DEFAULT 1');
DROP PROCEDURE santi_add_column;

ALTER TABLE inquiry MODIFY product_id INT NULL;

-- Indexes: ignore "duplicate key name" if you re-run this file.
-- (Only the first run needs them.)
SET @has := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'orders' AND INDEX_NAME = 'idx_orders_archived');
SET @sql := IF(@has = 0, 'ALTER TABLE orders ADD INDEX idx_orders_archived (is_archived)', 'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

SET @has := (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'quotation' AND CONSTRAINT_NAME = 'fk_quotation_reviewed_by');
SET @sql := IF(@has = 0, 'ALTER TABLE quotation ADD CONSTRAINT fk_quotation_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES owner_manager(owner_id) ON DELETE SET NULL', 'SELECT 1');
PREPARE st FROM @sql; EXECUTE st; DEALLOCATE PREPARE st;

CREATE TABLE IF NOT EXISTS customer_activity (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NULL,
  action      VARCHAR(60) NOT NULL,
  details     TEXT NULL,
  email       VARCHAR(160) NULL,
  ip_address  VARCHAR(45) NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_activity_created (created_at),
  INDEX idx_activity_throttle (email, action, created_at),
  FOREIGN KEY (customer_id) REFERENCES customer(customer_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_status_history (
  history_id  INT AUTO_INCREMENT PRIMARY KEY,
  order_id    INT NOT NULL,
  old_status  VARCHAR(30) NULL,
  new_status  VARCHAR(30) NOT NULL,
  changed_by  VARCHAR(160) NOT NULL,   -- admin name, or 'Customer #id'
  changed_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_osh_order (order_id, changed_at)
) ENGINE=InnoDB;


DROP TRIGGER IF EXISTS admin_audit_log_no_update;
DROP TRIGGER IF EXISTS admin_audit_log_no_delete;
DROP TRIGGER IF EXISTS customer_activity_no_update;
DROP TRIGGER IF EXISTS customer_activity_no_delete;
DROP TRIGGER IF EXISTS order_status_history_no_update;
DROP TRIGGER IF EXISTS order_status_history_no_delete;

DELIMITER $$
CREATE TRIGGER admin_audit_log_no_update BEFORE UPDATE ON admin_audit_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are append-only';
END$$
CREATE TRIGGER admin_audit_log_no_delete BEFORE DELETE ON admin_audit_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Audit records are append-only';
END$$
CREATE TRIGGER customer_activity_no_update BEFORE UPDATE ON customer_activity
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity records are append-only';
END$$
CREATE TRIGGER customer_activity_no_delete BEFORE DELETE ON customer_activity
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Activity records are append-only';
END$$
CREATE TRIGGER order_status_history_no_update BEFORE UPDATE ON order_status_history
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status history is append-only';
END$$
CREATE TRIGGER order_status_history_no_delete BEFORE DELETE ON order_status_history
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Status history is append-only';
END$$
DELIMITER ;

