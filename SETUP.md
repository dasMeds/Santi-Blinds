# Santi Blinds setup guide

This guide reflects the current repository layout and the setup steps that match the code in this project.

## 1. Requirements

Use a local Apache + MySQL stack such as XAMPP.

Recommended:

- Apache running on port 80
- MySQL running on localhost
- PHP 8.0+
- Git (optional, for pulling updates)

Place the project in the web root, for example:

```text
C:\xampp\htdocs\santiblinds\
```

The project expects to be served through `http://localhost/...` and not opened directly from disk.

## 2. Project layout

This repository contains both the public storefront and the internal admin tooling:

- `index.html`, `about.html`, `products.html`, `gallery.html`, `process.html`, `order.html`, `contact.html` for the public website
- `portal/` for customer registration, login, customizations, quotations, and order endpoints
- `admin/` for the admin UI and API endpoints
- `database/` for schema and migration SQL scripts
- `tools/` for encryption key generation and data migration utilities
- `db_config.php` for database, mail, and encryption settings

The root `.htaccess` denies direct browser access to `db_config.php`, SQL files, and some documentation files.

## 3. Create the database

1. Start Apache and MySQL in XAMPP.
2. Open `http://localhost/phpmyadmin`.
3. Create a database named `santiblinds` if needed.
4. Import `database/schema.sql`.
5. Optional: import `database/sample_data.sql` for starter content.

Before importing, make sure the database does not already contain an older version of the same app unless you intend to upgrade it.

### Upgrade notes

- `database/migrate_ready_status.sql` converts legacy order statuses into the newer completed state.
- `database/migrate_encryption.sql` adds the encryption-related columns and indexes needed for the customer data protection layer.

## 4. Configure the application

Edit `db_config.php` and set your local database credentials.

Default XAMPP values are already close to this:

```php
<?php

define('DB_HOST', 'localhost');
define('DB_NAME', 'santiblinds');
define('DB_USER', 'root');
define('DB_PASS', '');
define('DB_CHARSET', 'utf8mb4');

define('MAIL_FROM', 'your-sending-gmail@gmail.com');
define('MAIL_TO', 'where-you-receive-it@gmail.com');
define('MAIL_APP_PASSWORD', 'xxxx xxxx xxxx xxxx');
```

The current file also supports environment-based overrides when the host environment provides values. This is safer for local and production setups.

## 5. Enable encryption (required for current sensitive-data flow)

The project includes AES-256-GCM field encryption for customer names, contact details, and order notes. This is described in `ENCRYPTION.md`.

### Generate the key

Run this from the project root:

```bash
C:\xampp\php\php.exe tools\generate_key.php
```

This writes the key outside the web root, in the path configured by `ENC_KEY_FILE` in `db_config.php`.

Important:

- Back up the key file in a separate location from the database.
- If the key is lost, encrypted values cannot be recovered.
- For a fresh install, `database/schema.sql` already includes the encryption-ready table structure.

### Existing database migration

If the database existed before the encryption changes, import the migration SQL first, then encrypt the old rows:

```bash
C:\xampp\php\php.exe tools\encrypt_existing_data.php
```

For a fresh installation, this step is usually only needed when using a database seeded with older plaintext records.

Once the migration is completed, set `ENC_ALLOW_LEGACY_PLAINTEXT` to `false` in `db_config.php`.

To validate the setup, run:

```bash
C:\xampp\php\php.exe tools\encryption_demo.php --db
```

## 6. Create the admin owner account

The current schema uses the `owner_manager` table and stores a bcrypt hash in `password_hash`.

### Preferred CLI helper

Run the helper from the project root:

```bash
php admin\api\create_owner.php "Full Name" owner@example.com "StrongPassword"
```

The helper is intended to insert a new row into the `owner_manager` table. Use a password of at least 8 characters.

### If the helper is not usable in your current copy

Create the record directly in MySQL or use the older browser helper as a fallback only for legacy setups:

```text
http://localhost/santiblinds/create_admin.php?username=admin&password=StrongPassword&name=Admin
```

This older helper is legacy and depends on an older schema. It is not the current default path for the project.

The schema file also seeds a default owner account:

- Email: `owner@santiblinds.com`
- Password: `santiowner`

This default account is only a starter convenience for local demo use.

## 7. Run the app

Open the public site:

```text
http://localhost/santiblinds/
```

Open the customer order flow:

```text
http://localhost/santiblinds/order.html
```

Open the admin panel:

```text
http://localhost/santiblinds/admin/admin-login.html
```

The app relies on session cookies and local routing, so always access the project through `http://localhost/...` rather than double-clicking HTML files.

## 8. Test the basic flows

### Contact form

- Submit the form on the public site.
- Check the `santiblinds` database in phpMyAdmin.
- Look for rows in the `inquiry` or related enquiry table depending on the schema version you imported.

### Customer order flow

1. Visit the order page.
2. Register a customer account.
3. Log in to the portal.
4. Customize a blind and save the design.
5. Generate a quotation and place an order.
6. Verify the new order and customer activity in the admin dashboard.

### Admin dashboard

After logging in to `admin-login.html`, verify that the dashboard reflects the stored data and that customer/order reports are populating correctly.

## 9. Email configuration

Mail settings are defined in `db_config.php`:

```php
define('MAIL_FROM', 'your-sending-gmail@gmail.com');
define('MAIL_TO', 'where-you-receive-it@gmail.com');
define('MAIL_APP_PASSWORD', 'xxxx xxxx xxxx xxxx');
```

For Gmail, generate an app password from the Google account security settings. The project also supports the current environment-variable approach for safer credentials handling.

## 10. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Could not reach the server` | Apache/MySQL not running | Start both services in XAMPP |
| `Unknown database` | Database not imported | Import `database/schema.sql` |
| `SQLSTATE[HY000] [2002]` | MySQL connection failed | Start MySQL and check DB credentials |
| Pages redirect to login | Session/cookie issue or wrong URL | Use `http://localhost/...` and ensure cookies are enabled |
| Missing images or video | Assets not copied to the project root | Check `images/` and `video/` folders |
| `Encryption key not found` | Key file absent or wrong location | Run `tools/generate_key.php` and verify `ENC_KEY_FILE` |
| Old customer values not decrypting | Legacy plaintext not migrated | Run `encrypt_existing_data.php` and confirm `ENC_ALLOW_LEGACY_PLAINTEXT` |
| Admin login fails | Wrong password or old schema mismatch | Recreate the `owner_manager` record or check the hashed password |

## 11. Security notes

- Keep `db_config.php` outside the public web root in production or rely on environment variables.
- Do not commit live credentials or real app passwords to version control.
- The encryption key is a critical secret and should be stored separately from the database.
- The project intentionally avoids storing card numbers; payment is tracked by method rather than processing online.

## 12. Relevant files

- `db_config.php` — database and mail settings
- `crypto_lib.php` — encryption helpers
- `ENCRYPTION.md` — security and encryption documentation
- `database/schema.sql` — current schema
- `portal/catalog_lib.php` — pricing and quotation logic
- `admin/api/dashboard.php` — dashboard metrics and summaries
- `tools/generate_key.php` — encryption key generation