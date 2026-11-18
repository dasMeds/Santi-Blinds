# Santi Blinds: database encryption

What is sensitive in this project, how it is now protected, how to see it working, and what encryption does and does not protect you from.

## 1. Sensitive information found

| Data | Where it lives | Why it is sensitive | Protection now |
|---|---|---|---|
| Customer names | `customers.fname/lname`, `enquiries.fname/lname` | Personal data | AES-256-GCM |
| E-mail addresses | `customers.email`, `customer_accounts.email`, `enquiries.email`, `customer_activity.email` | Personal data and the login ID | AES-256-GCM + HMAC blind index (for lookups) |
| Phone numbers | `customers.phone`, `enquiries.phone`, `order_details.contact_no` | Personal data | AES-256-GCM |
| Home / installation address, city | `customers.location`, `enquiries.city`, `order_details.delivery_address` | Physical address of a home | AES-256-GCM |
| Free text typed by customers | `enquiries.message`, `order_details.notes`, `customizations.notes`, `orders.specifications` | People type anything into notes boxes | AES-256-GCM |
| Activity log | `customer_activity.details`, `customer_activity.ip_address` | Contains names, e-mails and IPs | AES-256-GCM |
| Passwords | `admin_users.password_hash`, `customer_accounts.password_hash` | Credentials | Already bcrypt (`password_hash()`). One-way, so left as is. Passwords must never be reversibly encrypted. |
| Server secrets | `db_config.php`: DB password, Gmail App Password | Full database / mailbox access | Now read from environment variables; file blocked in `.htaccess` |
| The encryption key | new | Opens everything above | Stored outside the database **and** outside the web root |

**Deliberately not encrypted:** order amounts, status, dates, quantities, product type, window sizes and payment-method names. Reports (`SUM`, `GROUP BY`, date ranges) need them readable, and on their own they identify nobody, because the link to a person goes through the encrypted customer record. The site stores **no card numbers** (payment is only a recorded method), so there is no card data to protect. Admin usernames/full names and the audit log are low sensitivity and were left readable.

**Other findings (not changed by this work, worth fixing):**
- `db_config.php` had a real-looking DB password in plain text and defined `DB_USER`/`DB_PASS` twice (PHP ignores the second `define()`, so those credentials were never used). Fixed in the new file. If the old file was ever shared or committed, **change that MySQL password**.
- `create_admin.php` takes the new admin password in the URL query string, which ends up in Apache's access log and browser history. Prefer running it once and clearing the log, or switch it to a CLI/POST form.
- Data in transit still needs HTTPS on the live site; this work protects data **at rest**.

## 2. Technique: application-level (field) encryption

Sensitive columns are encrypted by the PHP code **before** they are sent to MySQL and decrypted only when an authorised page needs them.

| Option | Protects against | Misses |
|---|---|---|
| Disk / tablespace encryption (TDE) | Someone stealing the physical disk | Anyone who can query the DB, SQL injection, backups taken through MySQL, phpMyAdmin viewers |
| MySQL `AES_ENCRYPT()` | Partly | Defaults to ECB mode (patterns leak), and the key travels inside SQL text where it shows up in query logs |
| **Field encryption in PHP (chosen)** | DB dumps, SQL injection, stolen backups, hosting staff / DBAs, phpMyAdmin | A compromise of the application server itself (it holds the key) |

Design details (`crypto_lib.php`):

- **AES-256-GCM**: encrypts *and* authenticates, so tampering is detected, not just hidden.
- **Random 96-bit IV for every value**: the same phone number encrypts differently each time.
- **Column binding**: the string `table.column` is authenticated along with the data, so a ciphertext copied into another column or table will not decrypt.
- **Key separation**: a 32-byte master key is expanded with HKDF into one key for encryption and a different one for the blind index.
- **Blind index**: login and "email already registered" need to find a row by e-mail. `email_bidx = HMAC-SHA256(lowercase(email))` using a secret key gives an exact-match lookup without storing the address readable. Without the key, the hashes cannot be guessed offline.
- **Key ring and rotation**: the key file holds `keyId:base64key` lines. The first is used for new writes; older ones still decrypt, so a key can be rotated without downtime.
- **Stored format:** `ENC1.<keyId>.<base64(iv | tag | ciphertext)>`

How a request flows:

```
Customer form --HTTPS--> PHP (holds key) --encrypt--> MySQL stores  ENC1.k1.kfTMAPbW...
Admin page   <--HTTPS--  PHP (holds key) <--decrypt-- MySQL returns ENC1.k1.kfTMAPbW...
```

## 3. What changed

| File | Change |
|---|---|
| `crypto_lib.php` (new) | `encField`, `decField`, `blindIndex`, row helpers |
| `db_config.php` | Loads the library; key location; credentials from environment; duplicate constants removed |
| `enquiries.php` | Encrypts name, e-mail, phone, city, message on insert |
| `portal/register.php`, `login.php`, `me.php`, `config.php` | Encrypt profile on register, look up accounts by blind index, encrypt the activity log |
| `portal/customization.php`, `quotation.php`, `order.php` | Encrypt notes, delivery address, contact number, order specifications |
| `admin/api/*.php` (7 files) | Decrypt for display; text search now filters in PHP because encrypted columns cannot be searched with `LIKE` |
| `database/schema.sql`, `migrate_encryption.sql` | Columns widened to `TEXT`, `email_bidx` columns and indexes added |
| `tools/` (new) | `generate_key.php`, `encrypt_existing_data.php`, `encryption_demo.php`, `encryption_demo.py` |
| `_htaccess` | Also blocks `crypto_lib.php` and key files |

The admin pages and `script.js` needed **no changes**: the API still returns plain values to a logged-in admin.

## 4. Setup

See section 3b of `SETUP.md`. In short: `generate_key.php`, then (existing database only) `migrate_encryption.sql` and `encrypt_existing_data.php`, then set `ENC_ALLOW_LEGACY_PLAINTEXT` to `false`.

## 5. Demonstration

Two demos use the same algorithm and format:

- `python3 tools/encryption_demo.py` builds a throw-away database and walks through ten checks. The full output is in `demo_output.txt`.
- `php tools/encryption_demo.php [--db]` does the key checks with the PHP library; `--db` shows real rows from your database, raw next to decrypted.

**Before vs after, customer #1** (from the demo run):

| Column | Before (plaintext) | After (what is stored) |
|---|---|---|
| fname | Maria | `ENC1.k1.kfTMAPbW7fG5H8DoFqculUcD7GcDegcUwE7Y/n…` |
| lname | Santos | `ENC1.k1.L2jsW0StLD169V72h1qTPafmp2jXOT8pq9a5mo…` |
| email | maria.santos@example.com | `ENC1.k1.MluhSqtyJbUTSjvzdCqObZlJ1pYqxFrShQxr5w…` |
| phone | 0917 123 4567 | `ENC1.k1.WxoCflgTAe3f6Gcs8rFeP6Q/87BKxGIDflWsgl…` |
| location | Makati City | `ENC1.k1.EDzIYkDh470aVBFDbGKPW+6YYK1U8WRYV/Anlf…` |
| email_bidx | n/a | `d2fc326e39f0fc3edd2647cf383e04b1adada60689b214…` |

**What the demo proved:**

| # | Check | Result |
|---|---|---|
| 1 | Search the raw database file for the customer's e-mail / address | Found before encryption, **not found** after |
| 2 | Attacker-style SQL: `WHERE phone LIKE '%0917%'` and `WHERE email = 'maria.santos@...'` | **0 rows** each |
| 3 | The application, holding the key, reads the rows | Original names, e-mails, phones, locations restored |
| 4 | Encrypt the same phone number twice | Two different ciphertexts, both decrypt correctly |
| 5 | Look up `"  Maria.Santos@Example.com "` via the blind index | Finds customer 1; a different key produces a different index |
| 6 | Flip a single bit in stored ciphertext | Decryption **refused** (authentication tag fails) |
| 7 | Paste the phone ciphertext into the e-mail column | Decryption **refused** (column binding) |
| 8 | Decrypt with a wrong key | Decryption **refused**, no partial plaintext |
| 9 | Rotate to a new key | Old data still opens; re-encrypted data carries the new key id |

## 6. How this protects the data

| Threat | Before | After |
|---|---|---|
| Stolen database backup or `.sql` export | Every customer's details readable | Rows of `ENC1...` text; useless without the key file, which is not in the backup |
| SQL injection that dumps tables | Attacker reads names, phones, addresses | Attacker gets ciphertext; the key is never in the database |
| Hosting staff, a DBA, or anyone with phpMyAdmin access | Can browse all customers | Sees ciphertext only |
| Attacker with write access edits or swaps values | Silent corruption | Detected: decryption fails for edited or moved values |
| Offline guessing of e-mails or phone numbers | Trivial (they are plaintext) | Infeasible: random IV and a secret-keyed index |
| Spotting duplicates or patterns across rows | Easy | Not possible; identical values look different |

**What it does not protect against.** Be clear about these limits:
- If an attacker gets **both** the database and the key (for example, full control of the web server), everything can be decrypted, because the application must hold the key to work. Keep the key file outside the web root, readable only by the web-server account, and never in the same backup as the database.
- A logged-in admin sees decrypted data, and the CSV export contains it. Encryption does not stop a stolen admin session or a malicious admin.
- **If the key is lost, the data is gone.** Back up `keys.txt` separately from the database.
- Encrypted columns cannot be searched or sorted in SQL. Admin search now runs in PHP, which is fine at this shop's size but would need rethinking at tens of thousands of customers.
- Also worth doing: use a least-privilege MySQL user for the site instead of `root`, require HTTPS, and add a login throttle to `admin/api/login.php` (the customer portal already has one).

## 7. Testing status

Only the algorithm and format were executed here, in Python, because PHP was not available in the environment where this was prepared. The PHP files were reviewed and bracket-checked but **not run**. Before relying on them, test on XAMPP:

1. `php tools/encryption_demo.php` should end with "REFUSED" lines for steps 4 and 5.
2. Register, log in, save a design, request a quote and place an order on `order.html`.
3. Submit the contact form.
4. Open each admin page (Customers, Orders, Customizations, Quotations, Activity, Reports) and try the search box.
5. In phpMyAdmin, confirm `customers`, `order_details` and `customer_activity` now show `ENC1...` values.
