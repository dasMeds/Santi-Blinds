-- ============================================================
-- Santi Blinds analytical warehouse
-- Run AFTER database/schema.sql on the same MySQL/MariaDB server.
-- This script does not alter the santiblinds operational schema.
--
-- Load strategy: a daily full reconciliation into this separate schema.
-- The source has no reliable updated_at columns, so an ID-watermark-only
-- incremental load would miss status, sale, and descriptor changes.
-- ============================================================

CREATE DATABASE IF NOT EXISTS santiblinds_dw
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE santiblinds_dw;

-- ------------------------------------------------------------
-- DIMENSIONS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_date (
  date_key       INT NOT NULL PRIMARY KEY,
  calendar_date  DATE NULL UNIQUE,
  year_num       SMALLINT NOT NULL,
  quarter_num    TINYINT NOT NULL,
  month_num      TINYINT NOT NULL,
  month_name     VARCHAR(12) NOT NULL,
  day_num        TINYINT NOT NULL,
  weekday_num    TINYINT NOT NULL,
  weekday_name   VARCHAR(12) NOT NULL,
  is_weekend     TINYINT(1) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_customer (
  customer_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_customer_id INT NOT NULL,
  account_type       VARCHAR(16) NOT NULL,
  valid_from         DATETIME NOT NULL,
  valid_to           DATETIME NOT NULL,
  is_current         TINYINT(1) NOT NULL,
  UNIQUE KEY uq_customer_source (source_customer_id),
  KEY ix_customer_current (is_current)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_product (
  product_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_product_id INT NOT NULL,
  product_name      VARCHAR(120) NOT NULL,
  blind_type        VARCHAR(60) NOT NULL,
  category_name     VARCHAR(80) NOT NULL,
  valid_from        DATETIME NOT NULL,
  valid_to          DATETIME NOT NULL,
  is_current        TINYINT(1) NOT NULL,
  UNIQUE KEY uq_product_source (source_product_id),
  KEY ix_product_current (is_current)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_material (
  material_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_material_id INT NOT NULL,
  material_name      VARCHAR(80) NOT NULL,
  UNIQUE KEY uq_material_source (source_material_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_color (
  color_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_color_id INT NOT NULL,
  color_name      VARCHAR(80) NOT NULL,
  hex_code        CHAR(7) NOT NULL,
  UNIQUE KEY uq_color_source (source_color_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_status (
  status_key    INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  status_type   VARCHAR(16) NOT NULL,
  source_status VARCHAR(30) NOT NULL,
  report_status VARCHAR(30) NOT NULL,
  is_completed  TINYINT(1) NOT NULL DEFAULT 0,
  is_cancelled  TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_status (status_type, source_status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS dim_payment_method (
  payment_method_key INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  method_name        VARCHAR(30) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- FACTS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact_order (
  order_key             BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_order_id       INT NOT NULL,
  source_quotation_id   INT NULL,
  source_sale_id        INT NULL,
  customer_key          BIGINT NOT NULL,
  order_date_key        INT NOT NULL,
  revenue_date_key      INT NOT NULL,
  status_key            INT NOT NULL,
  payment_method_key    INT NULL,
  line_count            INT NOT NULL,
  unit_count            INT NOT NULL,
  order_amount          DECIMAL(12,2) NOT NULL,
  recorded_paid_amount  DECIMAL(12,2) NULL,
  revenue_amount        DECIMAL(12,2) NOT NULL,
  order_count           TINYINT NOT NULL DEFAULT 1,
  UNIQUE KEY uq_fact_order_source (source_order_id),
  KEY ix_fact_order_customer (customer_key),
  KEY ix_fact_order_date (order_date_key),
  KEY ix_fact_order_revenue_date (revenue_date_key),
  KEY ix_fact_order_status (status_key),
  CONSTRAINT fk_fact_order_customer
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
  CONSTRAINT fk_fact_order_date
    FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_fact_order_revenue_date
    FOREIGN KEY (revenue_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_fact_order_status
    FOREIGN KEY (status_key) REFERENCES dim_status(status_key),
  CONSTRAINT fk_fact_order_payment
    FOREIGN KEY (payment_method_key) REFERENCES dim_payment_method(payment_method_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_order_line (
  order_line_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_line_id       INT NOT NULL,
  source_order_id      INT NOT NULL,
  source_quotation_id  INT NULL,
  customer_key         BIGINT NOT NULL,
  product_key          BIGINT NOT NULL,
  material_key         BIGINT NOT NULL,
  color_key            BIGINT NOT NULL,
  order_date_key       INT NOT NULL,
  status_key           INT NOT NULL,
  quantity             INT NOT NULL,
  width_cm             DECIMAL(6,1) NOT NULL,
  height_cm            DECIMAL(6,1) NOT NULL,
  physical_area_sqm    DECIMAL(10,4) NOT NULL,
  billable_area_sqm    DECIMAL(10,4) NOT NULL,
  unit_price           DECIMAL(10,2) NOT NULL,
  line_amount          DECIMAL(12,2) NOT NULL,
  UNIQUE KEY uq_fact_order_line_source (source_line_id),
  KEY ix_order_line_order (source_order_id),
  KEY ix_order_line_customer (customer_key),
  KEY ix_order_line_product (product_key),
  KEY ix_order_line_date (order_date_key),
  CONSTRAINT fk_order_line_customer
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
  CONSTRAINT fk_order_line_product
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
  CONSTRAINT fk_order_line_material
    FOREIGN KEY (material_key) REFERENCES dim_material(material_key),
  CONSTRAINT fk_order_line_color
    FOREIGN KEY (color_key) REFERENCES dim_color(color_key),
  CONSTRAINT fk_order_line_date
    FOREIGN KEY (order_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_order_line_status
    FOREIGN KEY (status_key) REFERENCES dim_status(status_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_quotation_line (
  quotation_line_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_quotation_item_id INT NOT NULL,
  source_quotation_id      INT NOT NULL,
  customer_key             BIGINT NOT NULL,
  product_key              BIGINT NOT NULL,
  material_key             BIGINT NOT NULL,
  color_key                BIGINT NOT NULL,
  quote_date_key           INT NOT NULL,
  valid_until_date_key     INT NOT NULL,
  status_key               INT NOT NULL,
  quantity                 INT NOT NULL,
  width_cm                 DECIMAL(6,1) NOT NULL,
  height_cm                DECIMAL(6,1) NOT NULL,
  quoted_unit_price        DECIMAL(10,2) NOT NULL,
  quoted_line_amount       DECIMAL(12,2) NOT NULL,
  is_converted             TINYINT(1) NOT NULL,
  UNIQUE KEY uq_fact_quote_line_source (source_quotation_item_id),
  KEY ix_quote_line_quote (source_quotation_id),
  KEY ix_quote_line_date (quote_date_key),
  CONSTRAINT fk_quote_line_customer
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
  CONSTRAINT fk_quote_line_product
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
  CONSTRAINT fk_quote_line_material
    FOREIGN KEY (material_key) REFERENCES dim_material(material_key),
  CONSTRAINT fk_quote_line_color
    FOREIGN KEY (color_key) REFERENCES dim_color(color_key),
  CONSTRAINT fk_quote_line_date
    FOREIGN KEY (quote_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_quote_line_valid_date
    FOREIGN KEY (valid_until_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_quote_line_status
    FOREIGN KEY (status_key) REFERENCES dim_status(status_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_inquiry (
  inquiry_key       BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source_inquiry_id INT NOT NULL,
  customer_key      BIGINT NOT NULL,
  product_key       BIGINT NOT NULL,
  inquiry_date_key  INT NOT NULL,
  status_key        INT NOT NULL,
  inquiry_count     TINYINT NOT NULL DEFAULT 1,
  UNIQUE KEY uq_fact_inquiry_source (source_inquiry_id),
  KEY ix_inquiry_date (inquiry_date_key),
  CONSTRAINT fk_inquiry_customer
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
  CONSTRAINT fk_inquiry_product
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
  CONSTRAINT fk_inquiry_date
    FOREIGN KEY (inquiry_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_inquiry_status
    FOREIGN KEY (status_key) REFERENCES dim_status(status_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fact_inventory_snapshot (
  snapshot_date_key INT NOT NULL,
  product_key       BIGINT NOT NULL,
  snapshot_at       DATETIME NOT NULL,
  available_qty     INT NOT NULL,
  low_stock_flag    TINYINT(1) NOT NULL,
  PRIMARY KEY (snapshot_date_key, product_key),
  CONSTRAINT fk_inventory_snapshot_date
    FOREIGN KEY (snapshot_date_key) REFERENCES dim_date(date_key),
  CONSTRAINT fk_inventory_snapshot_product
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key)
) ENGINE=InnoDB;

-- Materialized daily management summary. Rebuilt atomically from fact_order.
CREATE TABLE IF NOT EXISTS agg_daily_sales (
  revenue_date_key       INT NOT NULL PRIMARY KEY,
  completed_order_count  INT NOT NULL,
  units_sold             BIGINT NOT NULL,
  revenue_amount         DECIMAL(14,2) NOT NULL,
  average_order_revenue  DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_agg_daily_sales_date
    FOREIGN KEY (revenue_date_key) REFERENCES dim_date(date_key)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS etl_run (
  run_id                 BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  started_at             DATETIME NOT NULL,
  completed_at           DATETIME NULL,
  run_status             VARCHAR(16) NOT NULL,
  source_order_lines     BIGINT NOT NULL DEFAULT 0,
  source_quotation_lines BIGINT NOT NULL DEFAULT 0,
  source_inquiries       BIGINT NOT NULL DEFAULT 0,
  error_message          VARCHAR(1000) NULL,
  KEY ix_etl_run_started (started_at)
) ENGINE=InnoDB;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER
VIEW vw_warehouse_reconciliation AS
SELECT 'order_line_count' AS metric,
       CAST(COUNT(*) AS DECIMAL(20,2)) AS source_value,
       CAST((SELECT COUNT(*) FROM fact_order_line) AS DECIMAL(20,2))
         AS warehouse_value
FROM santiblinds.orders
UNION ALL
SELECT 'order_line_amount',
       COALESCE(SUM(total_amount), 0),
       (SELECT COALESCE(SUM(line_amount), 0) FROM fact_order_line)
FROM santiblinds.orders
UNION ALL
SELECT 'order_count',
       CAST(COUNT(DISTINCT order_id) AS DECIMAL(20,2)),
       CAST((SELECT COUNT(*) FROM fact_order) AS DECIMAL(20,2))
FROM santiblinds.orders
UNION ALL
SELECT 'completed_revenue',
       COALESCE(SUM(
         CASE WHEN UPPER(TRIM(source_order.raw_status)) IN
                    ('COMPLETED', 'READY', 'READY FOR INSTALL')
              THEN COALESCE(source_sale.amount_paid, source_order.order_amount)
              ELSE 0 END), 0),
       (SELECT COALESCE(SUM(revenue_amount), 0) FROM fact_order)
FROM (
  SELECT order_id AS source_order_id,
         MIN(status) AS raw_status,
         SUM(total_amount) AS order_amount
  FROM santiblinds.orders
  GROUP BY order_id
) AS source_order
LEFT JOIN santiblinds.sale source_sale
  ON source_sale.order_id = source_order.source_order_id
UNION ALL
SELECT 'quotation_line_count',
       CAST(COUNT(*) AS DECIMAL(20,2)),
       CAST((SELECT COUNT(*) FROM fact_quotation_line) AS DECIMAL(20,2))
FROM santiblinds.quotation_item
UNION ALL
SELECT 'inquiry_count',
       CAST(COUNT(*) AS DECIMAL(20,2)),
       CAST((SELECT COUNT(*) FROM fact_inquiry) AS DECIMAL(20,2))
FROM santiblinds.inquiry
UNION ALL
SELECT 'current_inventory_product_count',
       CAST(COUNT(*) AS DECIMAL(20,2)),
       CAST((SELECT COUNT(*) FROM fact_inventory_snapshot
             WHERE snapshot_date_key =
               CAST(DATE_FORMAT(CURDATE(), '%Y%m%d') AS UNSIGNED))
            AS DECIMAL(20,2))
FROM santiblinds.product;

-- ------------------------------------------------------------
-- UNIFIED, PII-MINIMIZED SOURCE VIEWS
-- The raw status is retained here; customer names, contacts, passwords,
-- inquiry text, and other free text are deliberately excluded.
-- ------------------------------------------------------------
CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_customer AS
SELECT customer_id AS source_customer_id,
       CASE WHEN password_hash IS NULL THEN 'Guest' ELSE 'Registered' END AS account_type,
       created_at AS source_created_at
FROM santiblinds.customer;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_product AS
SELECT p.product_id AS source_product_id,
       COALESCE(NULLIF(TRIM(p.name), ''), 'Unknown Product') AS product_name,
       COALESCE(NULLIF(TRIM(p.blind_type), ''), 'Unknown') AS blind_type,
       COALESCE(NULLIF(TRIM(c.name), ''), 'Uncategorized') AS category_name
FROM santiblinds.product p
LEFT JOIN santiblinds.category c ON c.category_id = p.category_id;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_material AS
SELECT material_id AS source_material_id,
       COALESCE(NULLIF(TRIM(name), ''), 'Unknown Material') AS material_name
FROM santiblinds.material;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_color AS
SELECT color_id AS source_color_id,
       COALESCE(NULLIF(TRIM(name), ''), 'Unknown Color') AS color_name,
       COALESCE(NULLIF(TRIM(hex_code), ''), '#000000') AS hex_code
FROM santiblinds.color;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_order_line AS
SELECT o.line_id AS source_line_id,
       o.order_id AS source_order_id,
       o.quotation_id AS source_quotation_id,
       o.customer_id AS source_customer_id,
       o.product_id AS source_product_id,
       o.material_id AS source_material_id,
       o.color_id AS source_color_id,
       o.status AS raw_status,
       o.quantity,
       o.width_cm,
       o.height_cm,
       o.unit_price,
       o.total_amount AS line_amount,
       o.order_date AS order_datetime
FROM santiblinds.orders o;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_quotation_line AS
SELECT qi.quotation_item_id AS source_quotation_item_id,
       q.quotation_id AS source_quotation_id,
       q.customer_id AS source_customer_id,
       qi.product_id AS source_product_id,
       qi.material_id AS source_material_id,
       qi.color_id AS source_color_id,
       q.status AS raw_status,
       qi.quantity,
       qi.width_cm,
       qi.height_cm,
       qi.unit_price AS quoted_unit_price,
       qi.total_amount AS quoted_line_amount,
       q.created_at AS quote_datetime,
       q.valid_until AS valid_until_datetime
FROM santiblinds.quotation_item qi
JOIN santiblinds.quotation q ON q.quotation_id = qi.quotation_id;

CREATE OR REPLACE ALGORITHM=UNDEFINED SQL SECURITY INVOKER VIEW stg_inquiry AS
SELECT i.enquiry_id AS source_inquiry_id,
       i.customer_id AS source_customer_id,
       i.product_id AS source_product_id,
       i.status AS raw_status,
       i.created_at AS inquiry_datetime
FROM santiblinds.inquiry i;

-- ------------------------------------------------------------
-- FULL RECONCILIATION ETL
-- All source rows are extracted on each run because the OLTP schema has no
-- dependable change timestamp. Unique source identifiers make loads
-- rerunnable; upserts propagate changed statuses and sale information.
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_load_warehouse;

DELIMITER $$

CREATE PROCEDURE sp_load_warehouse()
SQL SECURITY INVOKER
BEGIN
  DECLARE v_run_id BIGINT DEFAULT NULL;
  DECLARE v_min_date DATE;
  DECLARE v_max_date DATE;
  DECLARE v_day DATE;
  DECLARE v_error_message VARCHAR(1000);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    IF v_run_id IS NOT NULL THEN
      GET DIAGNOSTICS CONDITION 1 v_error_message = MESSAGE_TEXT;
    END IF;
    ROLLBACK;
    IF v_run_id IS NOT NULL THEN
      UPDATE etl_run
      SET completed_at = CURRENT_TIMESTAMP,
          run_status = 'FAILED',
          error_message = v_error_message
      WHERE run_id = v_run_id;
    END IF;
    RESIGNAL;
  END;

  INSERT INTO etl_run (started_at, run_status)
  VALUES (CURRENT_TIMESTAMP, 'RUNNING');
  SET v_run_id = LAST_INSERT_ID();

  START TRANSACTION;

  -- Seed the explicit unknown date member and all reporting dates required
  -- by source events, including future quotation expiry dates.
  INSERT INTO dim_date
    (date_key, calendar_date, year_num, quarter_num, month_num, month_name,
     day_num, weekday_num, weekday_name, is_weekend)
  VALUES
    (0, NULL, 0, 0, 0, 'Unknown', 0, 0, 'Unknown', 0)
  ON DUPLICATE KEY UPDATE date_key = VALUES(date_key);

  SELECT MIN(source_date), MAX(source_date)
    INTO v_min_date, v_max_date
  FROM (
    SELECT DATE(order_datetime) AS source_date FROM stg_order_line
    UNION ALL
    SELECT DATE(sale_date) FROM santiblinds.sale
    UNION ALL
    SELECT DATE(quote_datetime) FROM stg_quotation_line
    UNION ALL
    SELECT DATE(valid_until_datetime) FROM stg_quotation_line
    UNION ALL
    SELECT DATE(inquiry_datetime) FROM stg_inquiry
    UNION ALL
    SELECT CURDATE()
  ) AS source_dates;

  SET v_day = v_min_date;
  WHILE v_day <= v_max_date DO
    INSERT IGNORE INTO dim_date
      (date_key, calendar_date, year_num, quarter_num, month_num, month_name,
       day_num, weekday_num, weekday_name, is_weekend)
    VALUES
      (CAST(DATE_FORMAT(v_day, '%Y%m%d') AS UNSIGNED),
       v_day,
       YEAR(v_day),
       QUARTER(v_day),
       MONTH(v_day),
       DATE_FORMAT(v_day, '%M'),
       DAYOFMONTH(v_day),
       WEEKDAY(v_day) + 1,
       DATE_FORMAT(v_day, '%W'),
       IF(WEEKDAY(v_day) IN (5, 6), 1, 0));
    SET v_day = DATE_ADD(v_day, INTERVAL 1 DAY);
  END WHILE;

  -- Status aliases are preserved in stg_* views and mapped to report labels.
  INSERT INTO dim_status
    (status_type, source_status, report_status, is_completed, is_cancelled)
  SELECT status_type,
         source_status,
         CASE
           WHEN UPPER(source_status) IN ('READY', 'READY FOR INSTALL', 'COMPLETED')
             THEN 'Completed'
           WHEN UPPER(source_status) IN ('CANCELLED', 'CANCELED')
             THEN 'Cancelled'
           ELSE CONCAT(UPPER(LEFT(source_status, 1)),
                       LOWER(SUBSTRING(source_status, 2)))
         END AS report_status,
         IF(UPPER(source_status) IN
              ('READY', 'READY FOR INSTALL', 'COMPLETED'), 1, 0),
         IF(UPPER(source_status) IN ('CANCELLED', 'CANCELED'), 1, 0)
  FROM (
    SELECT 'ORDER' AS status_type,
           COALESCE(NULLIF(TRIM(raw_status), ''), 'Unknown') AS source_status
    FROM stg_order_line
    UNION
    SELECT 'QUOTATION',
           COALESCE(NULLIF(TRIM(raw_status), ''), 'Unknown')
    FROM stg_quotation_line
    UNION
    SELECT 'INQUIRY',
           COALESCE(NULLIF(TRIM(raw_status), ''), 'Unknown')
    FROM stg_inquiry
    UNION SELECT 'ORDER', 'Unknown'
    UNION SELECT 'QUOTATION', 'Unknown'
    UNION SELECT 'INQUIRY', 'Unknown'
  ) AS statuses
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    report_status = VALUES(report_status),
    is_completed = VALUES(is_completed),
    is_cancelled = VALUES(is_cancelled);

  INSERT INTO dim_customer
    (source_customer_id, account_type, valid_from, valid_to, is_current)
  VALUES (0, 'Unknown', '1000-01-01 00:00:00', '9999-12-31 23:59:59', 1)
  ON DUPLICATE KEY UPDATE account_type = VALUES(account_type);

  INSERT INTO dim_customer
    (source_customer_id, account_type, valid_from, valid_to, is_current)
  SELECT source_customer_id, account_type, source_created_at,
         '9999-12-31 23:59:59', 1
  FROM stg_customer
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    account_type = VALUES(account_type),
    valid_from = LEAST(valid_from, VALUES(valid_from)),
    valid_to = '9999-12-31 23:59:59',
    is_current = 1;

  INSERT INTO dim_product
    (source_product_id, product_name, blind_type, category_name,
     valid_from, valid_to, is_current)
  VALUES (0, 'Unknown Product', 'Unknown', 'Uncategorized',
          '1000-01-01 00:00:00', '9999-12-31 23:59:59', 1)
  ON DUPLICATE KEY UPDATE product_name = VALUES(product_name);

  INSERT INTO dim_product
    (source_product_id, product_name, blind_type, category_name,
     valid_from, valid_to, is_current)
  SELECT source_product_id, product_name, blind_type, category_name,
         '1000-01-01 00:00:00', '9999-12-31 23:59:59', 1
  FROM stg_product
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    product_name = VALUES(product_name),
    blind_type = VALUES(blind_type),
    category_name = VALUES(category_name),
    valid_to = '9999-12-31 23:59:59',
    is_current = 1;

  INSERT INTO dim_material (source_material_id, material_name)
  VALUES (0, 'Unknown Material')
  ON DUPLICATE KEY UPDATE material_name = VALUES(material_name);

  INSERT INTO dim_material (source_material_id, material_name)
  SELECT source_material_id, material_name
  FROM stg_material
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE material_name = VALUES(material_name);

  INSERT INTO dim_color (source_color_id, color_name, hex_code)
  VALUES (0, 'Unknown Color', '#000000')
  ON DUPLICATE KEY UPDATE color_name = VALUES(color_name);

  INSERT INTO dim_color (source_color_id, color_name, hex_code)
  SELECT source_color_id, color_name, hex_code
  FROM stg_color
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    color_name = VALUES(color_name),
    hex_code = VALUES(hex_code);

  INSERT INTO dim_payment_method (method_name)
  VALUES ('Unknown')
  ON DUPLICATE KEY UPDATE method_name = VALUES(method_name);

  INSERT INTO dim_payment_method (method_name)
  SELECT DISTINCT COALESCE(NULLIF(TRIM(payment_method), ''), 'Unknown')
  FROM santiblinds.sale
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE method_name = VALUES(method_name);

  -- One fact row per orders.order_id. Sale/payment data is joined once at
  -- the order grain to avoid multiplying revenue across order lines.
  INSERT INTO fact_order
    (source_order_id, source_quotation_id, source_sale_id, customer_key,
     order_date_key, revenue_date_key, status_key, payment_method_key,
     line_count, unit_count, order_amount, recorded_paid_amount,
     revenue_amount, order_count)
  SELECT grouped.source_order_id,
         grouped.source_quotation_id,
         sale.sale_id,
         customer.customer_key,
         COALESCE(order_date.date_key, 0),
         COALESCE(revenue_date.date_key, 0),
         status.status_key,
         payment.payment_method_key,
         grouped.line_count,
         grouped.unit_count,
         grouped.order_amount,
         sale.amount_paid,
         CASE WHEN status.is_completed = 1
              THEN COALESCE(sale.amount_paid, grouped.order_amount)
              ELSE 0 END,
         1
  FROM (
    SELECT source_order_id,
           MIN(source_quotation_id) AS source_quotation_id,
           MIN(source_customer_id) AS source_customer_id,
           MIN(order_datetime) AS order_datetime,
           MIN(raw_status) AS raw_status,
           COUNT(DISTINCT source_line_id) AS line_count,
           SUM(quantity) AS unit_count,
           SUM(line_amount) AS order_amount
    FROM stg_order_line
    GROUP BY source_order_id
  ) AS grouped
  JOIN dim_customer customer
    ON customer.source_customer_id = grouped.source_customer_id
  JOIN dim_status status
    ON status.status_type = 'ORDER'
   AND status.source_status = COALESCE(NULLIF(TRIM(grouped.raw_status), ''), 'Unknown')
  LEFT JOIN santiblinds.sale sale ON sale.order_id = grouped.source_order_id
  LEFT JOIN dim_payment_method payment
    ON payment.method_name =
       COALESCE(NULLIF(TRIM(sale.payment_method), ''), 'Unknown')
  LEFT JOIN dim_date order_date
    ON order_date.calendar_date = DATE(grouped.order_datetime)
  LEFT JOIN dim_date revenue_date
    ON revenue_date.calendar_date =
       DATE(COALESCE(sale.sale_date, grouped.order_datetime))
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    source_quotation_id = VALUES(source_quotation_id),
    source_sale_id = VALUES(source_sale_id),
    customer_key = VALUES(customer_key),
    order_date_key = VALUES(order_date_key),
    revenue_date_key = VALUES(revenue_date_key),
    status_key = VALUES(status_key),
    payment_method_key = VALUES(payment_method_key),
    line_count = VALUES(line_count),
    unit_count = VALUES(unit_count),
    order_amount = VALUES(order_amount),
    recorded_paid_amount = VALUES(recorded_paid_amount),
    revenue_amount = VALUES(revenue_amount),
    order_count = VALUES(order_count);

  -- One fact row per orders.line_id. Historical line price/amount is kept.
  INSERT INTO fact_order_line
    (source_line_id, source_order_id, source_quotation_id, customer_key,
     product_key, material_key, color_key, order_date_key, status_key,
     quantity, width_cm, height_cm, physical_area_sqm, billable_area_sqm,
     unit_price, line_amount)
  SELECT line.source_line_id,
         line.source_order_id,
         line.source_quotation_id,
         customer.customer_key,
         product.product_key,
         material.material_key,
         color.color_key,
         COALESCE(date_dim.date_key, 0),
         status.status_key,
         line.quantity,
         line.width_cm,
         line.height_cm,
         ROUND(line.width_cm * line.height_cm / 10000 * line.quantity, 4),
         ROUND(GREATEST(1, line.width_cm * line.height_cm / 10000)
               * line.quantity, 4),
         line.unit_price,
         line.line_amount
  FROM stg_order_line line
  JOIN dim_customer customer
    ON customer.source_customer_id = line.source_customer_id
  JOIN dim_product product
    ON product.source_product_id = line.source_product_id
  JOIN dim_material material
    ON material.source_material_id = line.source_material_id
  JOIN dim_color color
    ON color.source_color_id = line.source_color_id
  JOIN dim_status status
    ON status.status_type = 'ORDER'
   AND status.source_status = COALESCE(NULLIF(TRIM(line.raw_status), ''), 'Unknown')
  LEFT JOIN dim_date date_dim
    ON date_dim.calendar_date = DATE(line.order_datetime)
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    source_order_id = VALUES(source_order_id),
    source_quotation_id = VALUES(source_quotation_id),
    customer_key = VALUES(customer_key),
    product_key = VALUES(product_key),
    material_key = VALUES(material_key),
    color_key = VALUES(color_key),
    order_date_key = VALUES(order_date_key),
    status_key = VALUES(status_key),
    quantity = VALUES(quantity),
    width_cm = VALUES(width_cm),
    height_cm = VALUES(height_cm),
    physical_area_sqm = VALUES(physical_area_sqm),
    billable_area_sqm = VALUES(billable_area_sqm),
    unit_price = VALUES(unit_price),
    line_amount = VALUES(line_amount);

  -- One fact row per quotation_item. Conversion is determined by the
  -- existence of a related order, not by counting quote line rows.
  INSERT INTO fact_quotation_line
    (source_quotation_item_id, source_quotation_id, customer_key,
     product_key, material_key, color_key, quote_date_key,
     valid_until_date_key, status_key, quantity, width_cm, height_cm,
     quoted_unit_price, quoted_line_amount, is_converted)
  SELECT line.source_quotation_item_id,
         line.source_quotation_id,
         customer.customer_key,
         product.product_key,
         material.material_key,
         color.color_key,
         COALESCE(quote_date.date_key, 0),
         COALESCE(valid_date.date_key, 0),
         status.status_key,
         line.quantity,
         line.width_cm,
         line.height_cm,
         line.quoted_unit_price,
         line.quoted_line_amount,
         EXISTS (
           SELECT 1
           FROM santiblinds.orders related_order
           WHERE related_order.quotation_id = line.source_quotation_id
         )
  FROM stg_quotation_line line
  JOIN dim_customer customer
    ON customer.source_customer_id = line.source_customer_id
  JOIN dim_product product
    ON product.source_product_id = line.source_product_id
  JOIN dim_material material
    ON material.source_material_id = line.source_material_id
  JOIN dim_color color
    ON color.source_color_id = line.source_color_id
  JOIN dim_status status
    ON status.status_type = 'QUOTATION'
   AND status.source_status = COALESCE(NULLIF(TRIM(line.raw_status), ''), 'Unknown')
  LEFT JOIN dim_date quote_date
    ON quote_date.calendar_date = DATE(line.quote_datetime)
  LEFT JOIN dim_date valid_date
    ON valid_date.calendar_date = DATE(line.valid_until_datetime)
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    source_quotation_id = VALUES(source_quotation_id),
    customer_key = VALUES(customer_key),
    product_key = VALUES(product_key),
    material_key = VALUES(material_key),
    color_key = VALUES(color_key),
    quote_date_key = VALUES(quote_date_key),
    valid_until_date_key = VALUES(valid_until_date_key),
    status_key = VALUES(status_key),
    quantity = VALUES(quantity),
    width_cm = VALUES(width_cm),
    height_cm = VALUES(height_cm),
    quoted_unit_price = VALUES(quoted_unit_price),
    quoted_line_amount = VALUES(quoted_line_amount),
    is_converted = VALUES(is_converted);

  INSERT INTO fact_inquiry
    (source_inquiry_id, customer_key, product_key, inquiry_date_key,
     status_key, inquiry_count)
  SELECT inquiry.source_inquiry_id,
         customer.customer_key,
         product.product_key,
         COALESCE(date_dim.date_key, 0),
         status.status_key,
         1
  FROM stg_inquiry inquiry
  JOIN dim_customer customer
    ON customer.source_customer_id = inquiry.source_customer_id
  JOIN dim_product product
    ON product.source_product_id = inquiry.source_product_id
  JOIN dim_status status
    ON status.status_type = 'INQUIRY'
   AND status.source_status =
       COALESCE(NULLIF(TRIM(inquiry.raw_status), ''), 'Unknown')
  LEFT JOIN dim_date date_dim
    ON date_dim.calendar_date = DATE(inquiry.inquiry_datetime)
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    customer_key = VALUES(customer_key),
    product_key = VALUES(product_key),
    inquiry_date_key = VALUES(inquiry_date_key),
    status_key = VALUES(status_key),
    inquiry_count = VALUES(inquiry_count);

  -- Remove facts whose source rows have been deleted, keeping this a full
  -- reconciliation rather than an insert-only historical append.
  DELETE FROM fact_inquiry
  WHERE NOT EXISTS (
    SELECT 1 FROM stg_inquiry source_row
    WHERE source_row.source_inquiry_id = fact_inquiry.source_inquiry_id
  );

  DELETE FROM fact_quotation_line
  WHERE NOT EXISTS (
    SELECT 1 FROM stg_quotation_line source_row
    WHERE source_row.source_quotation_item_id =
          fact_quotation_line.source_quotation_item_id
  );

  DELETE FROM fact_order_line
  WHERE NOT EXISTS (
    SELECT 1 FROM stg_order_line source_row
    WHERE source_row.source_line_id = fact_order_line.source_line_id
  );

  DELETE FROM fact_order
  WHERE NOT EXISTS (
    SELECT 1 FROM (
      SELECT DISTINCT source_order_id FROM stg_order_line
    ) source_order
    WHERE source_order.source_order_id = fact_order.source_order_id
  );

  -- Daily current-stock snapshot. Re-running on the same date replaces that
  -- day's snapshot; this is a balance, not an inventory-movement measure.
  INSERT INTO fact_inventory_snapshot
    (snapshot_date_key, product_key, snapshot_at, available_qty, low_stock_flag)
  SELECT CAST(DATE_FORMAT(CURDATE(), '%Y%m%d') AS UNSIGNED),
         product.product_key,
         CURRENT_TIMESTAMP,
         source_product.stock_qty,
         IF(source_product.stock_qty <= 5, 1, 0)
  FROM santiblinds.product source_product
  JOIN dim_product product
    ON product.source_product_id = source_product.product_id
  WHERE 1 = 1
  ON DUPLICATE KEY UPDATE
    snapshot_at = VALUES(snapshot_at),
    available_qty = VALUES(available_qty),
    low_stock_flag = VALUES(low_stock_flag);

  -- Rebuild the compact management summary from order-grain revenue only.
  DELETE FROM agg_daily_sales;
  INSERT INTO agg_daily_sales
    (revenue_date_key, completed_order_count, units_sold, revenue_amount,
     average_order_revenue)
  SELECT order_fact.revenue_date_key,
         SUM(order_fact.order_count),
         SUM(order_fact.unit_count),
         SUM(order_fact.revenue_amount),
         AVG(order_fact.revenue_amount)
  FROM fact_order order_fact
  JOIN dim_status order_status
    ON order_status.status_key = order_fact.status_key
   AND order_status.status_type = 'ORDER'
   AND order_status.is_completed = 1
  GROUP BY order_fact.revenue_date_key;

  UPDATE etl_run
  SET completed_at = CURRENT_TIMESTAMP,
      run_status = 'SUCCEEDED',
      source_order_lines = (SELECT COUNT(*) FROM stg_order_line),
      source_quotation_lines = (SELECT COUNT(*) FROM stg_quotation_line),
      source_inquiries = (SELECT COUNT(*) FROM stg_inquiry)
  WHERE run_id = v_run_id;

  COMMIT;
END$$

DELIMITER ;

-- Destination-driven daily collection. The server's global event_scheduler
-- must be ON for this event to execute; CALL the procedure manually otherwise.
DROP EVENT IF EXISTS ev_santiblinds_dw_daily_load;

DELIMITER $$

CREATE EVENT ev_santiblinds_dw_daily_load
  ON SCHEDULE EVERY 1 DAY
  STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
  ON COMPLETION PRESERVE
  ENABLE
  DO CALL sp_load_warehouse()$$

DELIMITER ;

-- Initial historical backfill and first current-stock snapshot.
CALL sp_load_warehouse();

-- Example analytical report:
-- SELECT d.calendar_date, a.completed_order_count, a.units_sold,
--        a.revenue_amount, a.average_order_revenue
-- FROM agg_daily_sales a
-- JOIN dim_date d ON d.date_key = a.revenue_date_key
-- ORDER BY d.calendar_date;
