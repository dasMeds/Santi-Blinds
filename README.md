# Santi Blinds

Santi Blinds is a custom PHP + MySQL storefront and management system for a window-coverings business. The project combines a public marketing site, a customer portal, and an admin dashboard for catalog management, quotations, customer accounts, sales tracking, and order fulfilment.

## What is included

- Public storefront pages for home, about, products, gallery, process, order, and contact
- Customer portal for registration, login, customization, quotation, and order placement
- Admin dashboard with KPI cards, sales and order reporting, inventory views, and customer management
- Relational database schema for products, quotation items, orders, payments, inquiries, and owner/admin access
- AES-256-GCM field encryption for sensitive personal and customer data

## Tech stack

- PHP 8+
- MySQL / MariaDB
- Apache via XAMPP or similar local server
- HTML, CSS, JavaScript
- Optional encryption via custom PHP crypto library

## Current project structure

```text
santiblinds/
├── admin/
│   ├── api/
│   │   ├── config.php
│   │   ├── login.php
│   │   ├── dashboard.php
│   │   ├── customers.php
│   │   ├── orders.php
│   │   ├── quotations.php
│   │   ├── customizations.php
│   │   ├── inventory.php
│   │   ├── sales.php
│   │   ├── reports.php
│   │   ├── activity.php
│   │   ├── audit.php
│   │   ├── create_owner.php
│   │   └── ...
│   ├── admin-login.html
│   ├── admin-dashboard.html
│   ├── admin-customers.html
│   ├── admin-orders.html
│   ├── admin-quotations.html
│   ├── admin-customizations.html
│   ├── admin-products.html
│   ├── admin-inventory.html
│   ├── admin-sales.html
│   ├── admin-reports.html
│   ├── admin-activity.html
│   ├── admin-audit.html
│   └── index.php
├── portal/
│   ├── config.php
│   ├── catalog.php
│   ├── catalog_lib.php
│   ├── customer_login.php
│   ├── customer_register.php
│   ├── customer_session.php
│   ├── customization.php
│   ├── inquiry.php
│   ├── login.php
│   ├── logout.php
│   ├── me.php
│   ├── order.php
│   ├── quotation.php
│   └── register.php
├── database/
│   ├── schema.sql
│   ├── sample_data.sql
│   ├── migrate_encryption.sql
│   ├── migrate_ready_status.sql
│   └── database_authorization.sql
├── tools/
│   ├── generate_key.php
│   ├── encrypt_existing_data.php
│   ├── encryption_demo.php
│   └── encryption_demo.py
├── css/
├── javascript/
├── images/
├── video/
├── .htaccess
├── db_config.php
├── crypto_lib.php
├── ENCRYPTION.md
├── SETUP.md
├── README.md
├── index.html
├── about.html
├── products.html
├── gallery.html
├── process.html
├── order.html
├── contact.html
├── enquiries.php
├── create_admin.php
├── create_owner.php
└── ...
```

## Key setup notes

- The project is designed for local development and demo hosting on XAMPP.
- `db_config.php` loads the database and mail settings and can also read environment variables for credentials.
- Sensitive customer data is encrypted using the PHP crypto layer described in `ENCRYPTION.md`.
- The repository includes legacy and newer admin helpers; the current database schema uses the `owner_manager` table.

## Quick start

1. Place the project in `C:\xampp\htdocs\santiblinds`.
2. Start Apache and MySQL in XAMPP.
3. Import `database/schema.sql` in phpMyAdmin, optionally followed by `database/sample_data.sql`.
4. Configure `db_config.php` and, if using encryption, generate and protect the encryption key.
5. Create the owner/admin account, then open the public site and admin login.
6. For full setup steps, see [SETUP.md](C:/xampp/htdocs/santiblinds/SETUP.md).

## Common URLs

- Public site: `http://localhost/santiblinds/`
- Customer order flow: `http://localhost/santiblinds/order.html`
- Admin login: `http://localhost/santiblinds/admin/admin-login.html`

## Notes

- The app expects Apache to serve the project through `http://localhost/...`; opening files directly from the filesystem can break session and path assumptions.
- The root `.htaccess` blocks direct access to `db_config.php`, SQL files, and some documentation files.
- The app stores no card number data; payment method is recorded as a chosen option rather than processed online.
- For deployment, move secrets outside the public web root or set them via environment variables.

## License

This project is intended for internal business use and local demonstration unless otherwise stated by the owner.