-- ============================================================
--  Santi Blinds - upgrade an EXISTING database for field encryption
--
--  Run ONCE, after taking a backup, then immediately run:
--      php tools/generate_key.php               (first time only)
--      php tools/encrypt_existing_data.php
--
--  What it does: widens the sensitive columns to TEXT (ciphertext is longer than
--  the plaintext) and adds the e-mail "blind index" columns used for lookups.
--  Fresh installs do not need this file - database/schema.sql is already updated.
-- ============================================================
USE santiblinds;

ALTER TABLE customers
  MODIFY fname    TEXT NOT NULL,
  MODIFY lname    TEXT NOT NULL,
  MODIFY email    TEXT NULL,
  MODIFY phone    TEXT NULL,
  MODIFY location TEXT NULL,
  ADD COLUMN email_bidx CHAR(64) NULL AFTER email,
  ADD KEY idx_customers_email_bidx (email_bidx);

-- The old UNIQUE(email) is meaningless on randomised ciphertext; uniqueness moves to the blind index.
ALTER TABLE customer_accounts DROP INDEX uq_account_email;
ALTER TABLE customer_accounts
  MODIFY email TEXT NOT NULL,
  ADD COLUMN email_bidx CHAR(64) NULL AFTER email,
  ADD UNIQUE KEY uq_account_email_bidx (email_bidx);

ALTER TABLE enquiries
  MODIFY fname TEXT NOT NULL,
  MODIFY lname TEXT NOT NULL,
  MODIFY email TEXT NOT NULL,
  MODIFY phone TEXT NULL,
  MODIFY city  TEXT NULL;

ALTER TABLE order_details
  MODIFY delivery_address TEXT NOT NULL,
  MODIFY contact_no       TEXT NULL;

ALTER TABLE customer_activity DROP INDEX idx_act_email;
ALTER TABLE customer_activity
  MODIFY email      TEXT NULL,
  MODIFY ip_address TEXT NULL,
  ADD COLUMN email_bidx CHAR(64) NULL AFTER email,
  ADD KEY idx_act_bidx (email_bidx, action, created_at);

-- orders.specifications, customizations.notes, order_details.notes,
-- enquiries.message and customer_activity.details are already TEXT.
