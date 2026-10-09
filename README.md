# Santi Blinds

A custom PHP + MySQL storefront and management system for a window coverings business. The project includes a marketing website, customer ordering portal, quotation system, and administrative dashboard for managing customers, inventory, orders, and sales.

## Overview

Santi Blinds is built to support a blinds and window-coverings business in Metro Manila. It combines:

- A public storefront for browsing products and services
- A customer portal for registration, login, custom quote generation, and order placement
- An admin area for monitoring stock, sales, and order status
- A relational database for catalog, quotations, orders, payments, and enquiries

## Key Features

### Public website
- Home, About, Products, Gallery, Process, Order, and Contact pages
- Premium branded landing pages and responsive styling
- Product showcase with categories, colors, materials, and images
- Contact / enquiry entry flow

### Customer portal
- Customer registration and login
- Product catalog loading from the database
- Custom blind dimension and quantity validation
- Quotation generation with expiry handling
- Order placement from quotation or direct custom design
- Customer address tracking and order history support

### Admin dashboard
- Owner/admin login and session-based authentication
- KPI overview: order totals, pending orders, customer count, revenue, low-stock items
- Recent orders and status breakdown
- Inventory and sales reporting APIs
- Customer and order management endpoints

### Database model
- Products, categories, materials, and colors
- Quotations and quotation items
- Orders, order status workflow, and sales records
- Customer records and owner-manager accounts
- Enquiries and starter catalog data

## Tech Stack

- PHP 7+ / PHP 8+
- MySQL / MariaDB
- Apache via XAMPP or similar local server
- HTML, CSS, JavaScript

## Project Structure

```text
Santi Blinds/
├── admin/                   # Admin dashboard pages and API endpoints
│   ├── api/                 # Admin authentication and business logic
│   ├── admin-*.html        # Admin pages
│   └── ...
├── portal/                  # Customer-facing portal logic and endpoints
│   ├── config.php
│   ├── catalog.php
│   ├── catalog_lib.php
│   ├── customer_login.php
│   ├── customer_register.php
│   ├── inquiry.php
│   ├── order.php
│   ├── quotation.php
│   └── ...
├── database/
│   ├── schema.sql           # Core database schema
│   ├── sample_data.sql      # Sample/seed data
│   └── migration_accounts_quotations.sql
├── css/                     # Stylesheets
├── javascript/              # Frontend scripts
├── images/                  # Brand and product images
├── video/                   # Demo video assets
├── .htaccess                # Optional server config
├── db_config.php            # Database and mail settings
├── create_admin.php         # One-time admin creation script
├── create_owner.php         # CLI admin creation script
├── about.html               # Marketing pages
├── contact.html             # Contact page
├── gallery.html             # Gallery section
├── index.html               # Landing page
├── order.html               # Order page
├── process.html             # Process page
├── products.html            # Product listing page
├── enquiries.php            # Enquiry handling
├── README.md                # Project documentation
└── ...
```

## Setup Instructions

### 1. Install prerequisites
- Install XAMPP, WAMP, or a similar Apache + MySQL environment
- Ensure PHP and MySQL are available and running

### 2. Place the project in your web root
For a typical XAMPP setup:

```text
C:\xampp\htdocs\Santi Blinds
```

### 3. Create the database
Import the schema into MySQL:

```bash
mysql -u root < database/schema.sql
```

Or import through phpMyAdmin.

If you want sample data:

```bash
mysql -u root < database/sample_data.sql
```

### 4. Configure database settings
Edit `db_config.php` and set your local database credentials:

```php
define('DB_HOST', 'localhost');
define('DB_NAME', 'santiblinds');
define('DB_USER', 'root');
define('DB_PASS', '');
```

You can also configure email settings used for enquiries/notifications:

```php
define('MAIL_FROM', 'your-sending-gmail@gmail.com');
define('MAIL_TO', 'where-you-receive-it@gmail.com');
define('MAIL_APP_PASSWORD', 'xxxx xxxx xxxx xxxx');
```

### 5. Create an admin account
Use the CLI helper:

```bash
php create_owner.php "Full Name" owner@example.com "StrongPassword"
```

Or create via browser once (then remove the script afterward as described in the file comments):

```text
http://localhost/santiblinds/create_admin.php?name=Your+Name&email=you@example.com&password=StrongPassword
```

### 6. Run the app
Open the storefront in a browser:

```text
http://localhost/santiblinds/
```

Open the admin panel (after logging in):

```text
http://localhost/santiblinds/admin/admin-login.html
```

## Typical Workflow

1. Customer browses the product catalog
2. Customer registers/logs in to the portal
3. Customer selects blind options, dimensions, and materials
4. Quotation is created and stored in the database
5. Customer places the order from the quotation or direct design
6. Admin reviews the order through the dashboard
7. Inventory and payment data are updated from the order/sales workflow

## Notes

- The project is designed for local development and demo use.
- `db_config.php` is intended to hold sensitive DB and mail credentials; for production deployment, it should be moved outside the public web root.
- The app includes validation for dimensions, quantity, stock, order throttling, and quotation expiry.

## License

This project is for internal business use and local development unless otherwise stated by the owner.

## Useful Files

- `database/schema.sql` – main database structure and starter catalog
- `portal/catalog_lib.php` – pricing and quotation logic
- `portal/order.php` – order creation and stock deduction
- `admin/api/dashboard.php` – admin KPI and dashboard metrics
- `create_owner.php` – admin account creation helper
