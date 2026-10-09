-- ============================================================
-- Santi Blinds — 5,000-row dummy data generator
-- Run AFTER importing your unified schema and starter catalog.
--
-- Inserts exactly 5,000 rows:
--   customer        1,000
--   quotation       1,000
--   quotation_item  1,000
--   orders          1,000
--   inquiry         1,000
--
-- Notes:
-- * Uses clearly fictional names, emails, phone numbers, and addresses.
-- * Does not create or modify the embedded owner account.
-- * Raises product stock before inserting orders because the supplied
--   orders triggers reserve inventory for every non-cancelled order line.
-- * Re-running this script creates another batch of 5,000 rows.
-- * Requires the starter category/product/material/color records to exist.
-- ============================================================

USE santiblinds;

DELIMITER $$

DROP PROCEDURE IF EXISTS generate_santiblinds_dummy_data$$

CREATE PROCEDURE generate_santiblinds_dummy_data()
BEGIN
  DECLARE i INT DEFAULT 1;
  DECLARE v_customer_id INT;
  DECLARE v_quotation_id INT;
  DECLARE v_product_id INT;
  DECLARE v_material_id INT;
  DECLARE v_color_id INT;
  DECLARE v_width DECIMAL(6,1);
  DECLARE v_height DECIMAL(6,1);
  DECLARE v_qty INT;
  DECLARE v_unit_price DECIMAL(10,2);
  DECLARE v_total DECIMAL(12,2);
  DECLARE v_status VARCHAR(30);
  DECLARE v_order_id INT;

  DECLARE v_product_min INT;
  DECLARE v_product_max INT;
  DECLARE v_material_min INT;
  DECLARE v_material_max INT;
  DECLARE v_color_min INT;
  DECLARE v_color_max INT;
  DECLARE v_product_count INT;
  DECLARE v_material_count INT;
  DECLARE v_color_count INT;

  SELECT COUNT(*), MIN(product_id), MAX(product_id)
    INTO v_product_count, v_product_min, v_product_max FROM product;
  SELECT COUNT(*), MIN(material_id), MAX(material_id)
    INTO v_material_count, v_material_min, v_material_max FROM material;
  SELECT COUNT(*), MIN(color_id), MAX(color_id)
    INTO v_color_count, v_color_min, v_color_max FROM color;

  IF v_product_count = 0 OR v_material_count = 0 OR v_color_count = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Starter product, material, and color data must exist before generating dummy data.';
  END IF;

  -- Ensure sufficient stock for the 1,000 generated order lines.
  -- The order triggers will subtract the quantities as rows are inserted.
  UPDATE product SET stock_qty = GREATEST(stock_qty, 100000);

  -- 1) 1,000 customers
  SET i = 1;
  WHILE i <= 1000 DO
    INSERT INTO customer
      (full_name, email, phone, address, password_hash, created_at)
    VALUES
      (
        CONCAT(
          ELT(1 + MOD(i - 1, 20),
            'Alex','Jamie','Taylor','Morgan','Jordan','Casey','Riley','Avery',
            'Cameron','Drew','Skyler','Reese','Quinn','Parker','Robin','Sam',
            'Kris','Dana','Lee','Noel'),
          ' ',
          ELT(1 + MOD(i - 1, 25),
            'Santos','Reyes','Cruz','Garcia','Mendoza','Bautista','Dela Cruz',
            'Ramos','Villanueva','Flores','Gonzales','Aquino','Castillo',
            'Navarro','Torres','Rivera','Fernandez','Morales','Gutierrez',
            'Diaz','Lopez','Perez','Santiago','Domingo','Mercado')
        ),
        CONCAT('dummy.customer.', LPAD(i, 4, '0'), '@example.com'),
        CONCAT('+639', LPAD(100000000 + i, 9, '0')),
        CONCAT(
          'Unit ', 1 + MOD(i, 99), ', ',
          ELT(1 + MOD(i - 1, 10),
            'Rizal Street','Mabini Avenue','Bonifacio Road','Luna Street',
            'Del Pilar Street','Quezon Avenue','Burgos Street','Jacinto Road',
            'Katipunan Avenue','Andres Street'),
          ', ',
          ELT(1 + MOD(i - 1, 10),
            'Navotas','Malabon','Caloocan','Quezon City','Manila',
            'Pasig','Makati','Taguig','Marikina','Pasay'),
          ', Philippines'
        ),
        NULL,
        DATE_SUB(NOW(), INTERVAL MOD(i * 13, 900) DAY)
      );
    SET i = i + 1;
  END WHILE;

  -- 2) 1,000 quotations, linked to the 1,000 newly inserted customers.
  SET i = 1;
  WHILE i <= 1000 DO
    SET v_customer_id = (SELECT customer_id
                         FROM customer
                         WHERE email = CONCAT('dummy.customer.', LPAD(i, 4, '0'), '@example.com')
                         LIMIT 1);
    SET v_product_id = v_product_min + MOD(i - 1, v_product_max - v_product_min + 1);
    SET v_material_id = v_material_min + MOD(i - 1, v_material_max - v_material_min + 1);
    SET v_color_id = v_color_min + MOD(i - 1, v_color_max - v_color_min + 1);
    SET v_width = 60 + MOD(i * 7, 181);
    SET v_height = 80 + MOD(i * 11, 221);
    SET v_qty = 1 + MOD(i, 4);
    SET v_unit_price = (SELECT base_price FROM product WHERE product_id = v_product_id)
                     + (SELECT price_modifier FROM material WHERE material_id = v_material_id);
    SET v_total = ROUND(v_unit_price * v_qty * (v_width / 100) * (v_height / 100), 2);

    INSERT INTO quotation
      (customer_id, total_amount, status, valid_until, created_at)
    VALUES
      (
        v_customer_id,
        v_total,
        ELT(1 + MOD(i - 1, 4), 'Active','Approved','Expired','Converted'),
        DATE_ADD(NOW(), INTERVAL (7 + MOD(i, 30)) DAY),
        DATE_SUB(NOW(), INTERVAL MOD(i * 3, 365) DAY)
      );
    SET v_quotation_id = LAST_INSERT_ID();

    -- One quotation item per quotation = 1,000 rows.
    INSERT INTO quotation_item
      (quotation_id, product_id, material_id, color_id,
       width_cm, height_cm, quantity, unit_price, total_amount)
    VALUES
      (v_quotation_id, v_product_id, v_material_id, v_color_id,
       v_width, v_height, v_qty, v_unit_price, v_total);

    SET i = i + 1;
  END WHILE;

  -- 3) 1,000 order lines. Each gets a unique order_id and references
  -- the matching generated customer and quotation.
  SET i = 1;
  WHILE i <= 1000 DO
    SET v_customer_id = (SELECT customer_id
                         FROM customer
                         WHERE email = CONCAT('dummy.customer.', LPAD(i, 4, '0'), '@example.com')
                         LIMIT 1);
    SET v_quotation_id = (
      SELECT q.quotation_id
      FROM quotation q
      WHERE q.customer_id = v_customer_id
      ORDER BY q.quotation_id DESC
      LIMIT 1
    );
    SET v_product_id = v_product_min + MOD(i - 1, v_product_max - v_product_min + 1);
    SET v_material_id = v_material_min + MOD(i + 1, v_material_max - v_material_min + 1);
    SET v_color_id = v_color_min + MOD(i + 2, v_color_max - v_color_min + 1);
    SET v_width = 60 + MOD(i * 5, 181);
    SET v_height = 80 + MOD(i * 9, 221);
    SET v_qty = 1 + MOD(i, 3);
    SET v_unit_price = (SELECT base_price FROM product WHERE product_id = v_product_id)
                     + (SELECT price_modifier FROM material WHERE material_id = v_material_id);
    SET v_total = ROUND(v_unit_price * v_qty * (v_width / 100) * (v_height / 100), 2);
    SET v_status = ELT(1 + MOD(i - 1, 5),
                       'Pending','Processing','Ready for Install','Completed','Cancelled');

    INSERT INTO orders
      (order_id, customer_id, quotation_id, product_id, material_id, color_id,
       width_cm, height_cm, quantity, unit_price, total_amount, status, order_date)
    VALUES
      (
        100000 + i,
        v_customer_id,
        v_quotation_id,
        v_product_id,
        v_material_id,
        v_color_id,
        v_width,
        v_height,
        v_qty,
        v_unit_price,
        v_total,
        v_status,
        DATE_SUB(NOW(), INTERVAL MOD(i * 2, 365) DAY)
      );

    SET i = i + 1;
  END WHILE;

  -- 4) 1,000 inquiries linked to generated customers and valid products.
  SET i = 1;
  WHILE i <= 1000 DO
    SET v_customer_id = (SELECT customer_id
                         FROM customer
                         WHERE email = CONCAT('dummy.customer.', LPAD(i, 4, '0'), '@example.com')
                         LIMIT 1);
    SET v_product_id = v_product_min + MOD(i - 1, v_product_max - v_product_min + 1);

    INSERT INTO inquiry (customer_id, product_id, message, status, created_at)
    VALUES
      (
        v_customer_id,
        v_product_id,
        ELT(1 + MOD(i - 1, 8),
          'Could you provide an estimate for two windows?',
          'Is installation included in the quoted price?',
          'What materials are available for this blind type?',
          'Can this product be made to a custom window size?',
          'How long does installation usually take?',
          'Do you have samples of the available colors?',
          'Can I request blackout material for this product?',
          'Please contact me about measurement and installation options.'),
        ELT(1 + MOD(i - 1, 4), 'New','In Progress','Responded','Closed'),
        DATE_SUB(NOW(), INTERVAL MOD(i * 5, 365) DAY)
      );

    SET i = i + 1;
  END WHILE;
END$$

CALL generate_santiblinds_dummy_data()$$
DROP PROCEDURE IF EXISTS generate_santiblinds_dummy_data$$

DELIMITER ;

-- Verify inserted rows (expected 1,000 in each of these five tables).
SELECT 'customer' AS table_name, COUNT(*) AS rows_added
FROM customer
WHERE email LIKE 'dummy.customer.%@example.com'
UNION ALL
SELECT 'quotation', COUNT(*)
FROM quotation q
JOIN customer c ON c.customer_id = q.customer_id
WHERE c.email LIKE 'dummy.customer.%@example.com'
UNION ALL
SELECT 'quotation_item', COUNT(*)
FROM quotation_item qi
JOIN quotation q ON q.quotation_id = qi.quotation_id
JOIN customer c ON c.customer_id = q.customer_id
WHERE c.email LIKE 'dummy.customer.%@example.com'
UNION ALL
SELECT 'orders', COUNT(*)
FROM orders o
JOIN customer c ON c.customer_id = o.customer_id
WHERE c.email LIKE 'dummy.customer.%@example.com'
UNION ALL
SELECT 'inquiry', COUNT(*)
FROM inquiry i
JOIN customer c ON c.customer_id = i.customer_id
WHERE c.email LIKE 'dummy.customer.%@example.com';
