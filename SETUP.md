# Santi Blinds — running the site + admin panel on XAMPP

## 1. Put the project in htdocs
Extract this folder to `C:\xampp\htdocs\santiblinds\`:

```
htdocs/santiblinds/
├── index.html, about.html, contact.html, gallery.html, process.html, products.html
├── order.html               <-- NEW: register / login / customize / quote / order
├── css/style.css
├── javascript/script.js
├── images/                  <-- COPY YOUR images folder contents here
├── video/                   <-- COPY YOUR video folder here (Demoreel.mp4)
├── db_config.php            <-- DB + Gmail settings + encryption key location
├── crypto_lib.php           <-- NEW: AES-256-GCM field encryption (loaded by db_config.php)
├── enquiries.php            <-- contact-form handler
├── create_admin.php         <-- run once, then DELETE
├── .htaccess                <-- blocks browser access to db_config.php / .sql files
├── PHPMailer/src/*.php
├── portal/                  <-- NEW: customer API used by order.html (11 files)
│   └── config.php, catalog_lib.php, catalog.php, register.php, login.php, logout.php,
│       me.php, customization.php, quotation.php, order.php
├── database/                <-- schema.sql, migrate_encryption.sql, sample_data.sql (don't upload to live site)
├── tools/                   <-- NEW: generate_key.php, encrypt_existing_data.php, encryption_demo.php (CLI only)
└── admin/
    ├── admin-login.html, admin-dashboard.html, ... (9 pages; NEW: admin-customizations)
    └── api/                 <-- config.php, login.php, orders.php, ... (14 files; NEW:
                                 customizations.php, quotations.php, activity.php)
```

Keep that exact nesting: the admin pages call `./api/...` and `api/config.php`
loads `../../db_config.php`. Likewise `portal/config.php` loads `../db_config.php`.

Images the pages expect in `images/`: Icon.png, SantiLogoNoBg.png, Dinna.png,
Romano.png, Adrian.png, Product_1..6.png, and 1..14.png. Video: `video/Demoreel.mp4`.

## 2. Start XAMPP
In the XAMPP Control Panel start **Apache** and **MySQL**.
Use PHP 8.0 or newer (current XAMPP versions are fine).

## 3. Create the database
1. Open http://localhost/phpmyadmin
2. **Import** -> choose `database/schema.sql` -> **Import** (creates `santiblinds` + 11 tables).
   **Upgrading an existing database?** Import the new `schema.sql` again. It only adds the
   5 new tables (`customer_accounts`, `customizations`, `quotations`, `order_details`,
   `customer_activity`) and never touches your data.
3. *(Optional demo data)* Import `database/sample_data.sql` the same way.

`db_config.php` already matches XAMPP defaults (`root`, empty password).

## 3b. Turn on database encryption (required)
Names, e-mails, phone numbers, addresses, notes and IP addresses are stored AES-256-GCM
encrypted (details: `ENCRYPTION.md`). The app will not work without a key.

1. **Generate the key.** From a terminal in the project folder:
   ```
   C:\xampp\php\php.exe tools\generate_key.php
   ```
   This writes `C:\xampp\santiblinds_keys\keys.txt` (outside `htdocs`, see `ENC_KEY_FILE`
   in `db_config.php`). **Back this file up somewhere separate from the database.**
   If it is lost, the encrypted data cannot be recovered.
2. **Existing database from before encryption?** Back it up, import
   `database/migrate_encryption.sql` once, then encrypt the old rows:
   ```
   C:\xampp\php\php.exe tools\encrypt_existing_data.php
   ```
   Fresh install: `schema.sql` already has the right columns. If you also import
   `sample_data.sql`, run `encrypt_existing_data.php` afterwards.
3. In `db_config.php` set `ENC_ALLOW_LEGACY_PLAINTEXT` to `false` once step 2 is done.
4. See it working: `C:\xampp\php\php.exe tools\encryption_demo.php --db`

`db_config.php` now reads `SANTI_DB_USER`, `SANTI_DB_PASS` and the Gmail settings from
environment variables when they exist (XAMPP defaults otherwise). On the live site, set them
in the server environment instead of typing passwords into the file.

## 4. Create your admin login
Visit (change the values; password min. 8 characters):

```
http://localhost/santiblinds/create_admin.php?username=admin&password=ChangeMe123&name=Your%20Name
```

Expect: "Admin account 'admin' created successfully." Then **delete `create_admin.php`**.

## 5. Open the site
- Public site:  http://localhost/santiblinds/index.html
- Admin login:  http://localhost/santiblinds/admin/admin-login.html

Always browse through `http://localhost/...`, never by double-clicking an .html file.

## 6. Test the contact form
Submit http://localhost/santiblinds/contact.html, then in phpMyAdmin check
`santiblinds` -> `enquiries`. The row is saved even if email isn't configured.
While `MAIL_*` in `db_config.php` are still placeholders, the email step is skipped
(a note is written to Apache's error.log) and the form still succeeds.

## 7. Test the Order flow
1. Open http://localhost/santiblinds/order.html (or click **Order** in the nav).
2. **Register**, then you are sent to **Log in** (registration does not log you in).
3. **Customize** a blind -> *Save Design & Continue*.
4. Optionally click **Get a Quotation**, then **Place Order** or **Purchase**.
5. In the admin panel check: **Customers** (new account, plus the **Customer Activity** list under it),
   **Customizations**, **Orders** (new row with type + payment + address in the detail
   window, plus the **Quotations** list under it) and the **Dashboard** counters.

Prices are placeholders: edit the numbers in `portal/catalog_lib.php` to match your real
price list. Prices are always recalculated on the server. No payment is processed online;
"Purchase" records the chosen method (GCash / Bank Transfer / Cash on Installation) and the
admin confirms payment.

## Email notifications (optional)
Fill in `MAIL_FROM`, `MAIL_TO`, `MAIL_APP_PASSWORD` in `db_config.php`
(Google Account -> Security -> 2-Step Verification -> App passwords).
On localhost, TLS verification is relaxed so Gmail works on XAMPP without a CA bundle.
On the live site it is fully verified.

## Troubleshooting
| Symptom | Cause / fix |
|---|---|
| "Could not reach the server" on login | Apache not running, or nesting wrong (`admin/api/login.php` must exist). |
| "Server error: SQLSTATE[HY000] [1049] Unknown database" | `schema.sql` not imported. |
| "...[2002] No connection could be made" | MySQL not started in XAMPP. |
| "Server returned an unexpected response" | A PHP error. Read `C:\xampp\apache\logs\error.log`. |
| Pages bounce back to login | Not browsing via `http://localhost/...`, or session cookie blocked. |
| Contact form: "Could not reach enquiries.php" | Apache off, or `enquiries.php` not in the site root. |
| Order page: "Could not reach the server" | Apache off, `portal/` folder missing, or page opened as a file instead of via `http://localhost/...`. |
| Order page: "Server error: ...doesn't exist" | New tables missing. Re-import `database/schema.sql`. |
| Logos/images/video missing | Copy your `images/` and `video/` folders into the project root. |
| "Encryption key not found" | Run `tools/generate_key.php`, and check `ENC_KEY_FILE` in `db_config.php` points at the key file. |
| "Decryption failed for customers.phone ..." | The key file was replaced/lost, or a value was edited by hand in phpMyAdmin. Restore the original key file. |
| Customer cannot log in after upgrading | `encrypt_existing_data.php` has not been run yet (it fills the e-mail lookup index). |
| `create_admin.php` shows a blank page | It only runs from localhost; open it via `http://localhost/...`. |
