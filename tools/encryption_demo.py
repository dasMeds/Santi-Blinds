#!/usr/bin/env python3
"""
Santi Blinds - encryption demonstration (Python mirror of crypto_lib.php).

Same design as the PHP code that protects the live database:
  * AES-256-GCM, random 96-bit IV per value, 128-bit auth tag
  * column name ("table.column") bound in as Additional Authenticated Data
  * stored format:  ENC1.<keyId>.<base64( iv | tag | ciphertext )>
  * keys derived with HKDF-SHA256 from a 32-byte master key (separate sub-keys
    for encryption and for the HMAC "blind index" used for lookups)

Run:  python3 encryption_demo.py        (needs:  pip install cryptography)
It creates a throw-away SQLite database - it never touches your real data.
"""
import base64, hashlib, hmac, os, re, sqlite3, tempfile
from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF

# ───────────────────────── crypto (mirrors crypto_lib.php) ─────────────────────────
def derive(master: bytes, info: bytes) -> bytes:
    return HKDF(algorithm=hashes.SHA256(), length=32, salt=None, info=info).derive(master)

def make_ring(*entries):                       # entries: ("k1", master_bytes), newest first
    ring = {"current": entries[0][0], "keys": {}}
    for kid, master in entries:
        ring["keys"][kid] = {"enc": derive(master, b"santiblinds/enc/v1"),
                             "bidx": derive(master, b"santiblinds/bidx/v1")}
    return ring

def enc_field(ring, plain, ctx):
    if plain is None or plain == "":
        return plain
    kid = ring["current"]
    iv = os.urandom(12)
    out = AESGCM(ring["keys"][kid]["enc"]).encrypt(iv, plain.encode(), ctx.encode())  # ct || tag
    ct, tag = out[:-16], out[-16:]
    return f"ENC1.{kid}.{base64.b64encode(iv + tag + ct).decode()}"

def dec_field(ring, stored, ctx):
    if stored is None or stored == "":
        return stored
    _, kid, blob = stored.split(".", 2)
    raw = base64.b64decode(blob)
    iv, tag, ct = raw[:12], raw[12:28], raw[28:]
    return AESGCM(ring["keys"][kid]["enc"]).decrypt(iv, ct + tag, ctx.encode()).decode()

def blind_index(ring, value):
    if not value or not value.strip():
        return None
    v = value.strip().lower().encode()
    return hmac.new(ring["keys"][ring["current"]]["bidx"], v, hashlib.sha256).hexdigest()

# ───────────────────────── pretty printing ─────────────────────────
def h(title):  print(f"\n{'═'*78}\n  {title}\n{'═'*78}")
def short(v, n=46):
    v = "NULL" if v is None else str(v)
    return v if len(v) <= n else v[:n] + "…"
def show(db, sql):
    cur = db.execute(sql); cols = [c[0] for c in cur.description]; rows = cur.fetchall()
    w = [max(len(c), *(len(short(r[i])) for r in rows)) for i, c in enumerate(cols)]
    print("  " + " | ".join(c.ljust(w[i]) for i, c in enumerate(cols)))
    print("  " + "-+-".join("-" * x for x in w))
    for r in rows: print("  " + " | ".join(short(r[i]).ljust(w[i]) for i in range(len(cols))))

# ───────────────────────── demo ─────────────────────────
path = os.path.join(tempfile.mkdtemp(), "santiblinds_demo.db")
db = sqlite3.connect(path)
db.execute("""CREATE TABLE customers (id INTEGER PRIMARY KEY, fname TEXT, lname TEXT, email TEXT,
              email_bidx TEXT, phone TEXT, location TEXT)""")
db.execute("""CREATE TABLE order_details (order_id INTEGER PRIMARY KEY, delivery_address TEXT)""")
people = [("Maria", "Santos", "maria.santos@example.com", "0917 123 4567", "Makati City"),
          ("James", "Reyes", "james.reyes@example.com", "0918 234 5678", "BGC, Taguig"),
          ("Claire", "Mendoza", "claire.mendoza@example.com", "0919 345 6789", "Quezon City")]
for p in people:
    db.execute("INSERT INTO customers (fname,lname,email,phone,location) VALUES (?,?,?,?,?)", p)
db.execute("INSERT INTO order_details VALUES (1, 'Unit 12B, 88 Aurora Blvd, Quezon City')")
db.commit()

def raw_bytes_contain(needle):                  # simulates an attacker reading the DB file / backup
    db.commit()
    return needle.encode() in open(path, "rb").read()

h("1. BEFORE - how the data is stored today (plaintext)")
print("  What phpMyAdmin, a stolen backup (.sql / DB file) or an SQL-injection dump shows:\n")
show(db, "SELECT id, fname, lname, email, phone, location FROM customers")
print()
show(db, "SELECT * FROM order_details")
print(f"\n  Searching the raw database file for 'maria.santos@example.com': "
      f"{'FOUND' if raw_bytes_contain('maria.santos@example.com') else 'not found'}")
print(f"  Searching the raw database file for '88 Aurora Blvd':           "
      f"{'FOUND' if raw_bytes_contain('88 Aurora Blvd') else 'not found'}")

h("2. ENCRYPT - same logic as tools/encrypt_existing_data.php")
master = os.urandom(32)
ring = make_ring(("k1", master))
print("  Master key: 32 random bytes held OUTSIDE the database and web root (never printed here).")
print("  Per-value: random IV + AES-256-GCM, column name bound as authenticated data.\n")
for (cid, fname, lname, email, phone, loc) in db.execute(
        "SELECT id,fname,lname,email,phone,location FROM customers").fetchall():
    db.execute("UPDATE customers SET fname=?, lname=?, email=?, email_bidx=?, phone=?, location=? WHERE id=?",
               (enc_field(ring, fname, "customers.fname"), enc_field(ring, lname, "customers.lname"),
                enc_field(ring, email, "customers.email"), blind_index(ring, email),
                enc_field(ring, phone, "customers.phone"), enc_field(ring, loc, "customers.location"), cid))
addr = db.execute("SELECT delivery_address FROM order_details").fetchone()[0]
db.execute("UPDATE order_details SET delivery_address=?",
           (enc_field(ring, addr, "order_details.delivery_address"),))
db.commit()

h("3. AFTER - what an attacker with the database (but not the key) sees")
show(db, "SELECT id, fname, lname, email, phone, location FROM customers")
print()
show(db, "SELECT id, email_bidx FROM customers")
print()
show(db, "SELECT * FROM order_details")
print(f"\n  Raw file search for 'maria.santos@example.com': "
      f"{'FOUND' if raw_bytes_contain('maria.santos@example.com') else 'not found'}")
print(f"  Raw file search for '88 Aurora Blvd':           "
      f"{'FOUND' if raw_bytes_contain('88 Aurora Blvd') else 'not found'}")
n1 = db.execute("SELECT COUNT(*) FROM customers WHERE phone LIKE '%0917%'").fetchone()[0]
n2 = db.execute("SELECT COUNT(*) FROM customers WHERE email = 'maria.santos@example.com'").fetchone()[0]
print(f"  SQL injection style query  WHERE phone LIKE '%0917%'            -> {n1} rows")
print(f"  SQL injection style query  WHERE email = 'maria.santos@...'     -> {n2} rows")

h("4. AUTHORISED APPLICATION - has the key, so it can read the data")
for (cid, fn, ln, em, ph, lc) in db.execute("SELECT id,fname,lname,email,phone,location FROM customers"):
    print(f"  #{cid}: {dec_field(ring, fn,'customers.fname')} {dec_field(ring, ln,'customers.lname')} | "
          f"{dec_field(ring, em,'customers.email')} | {dec_field(ring, ph,'customers.phone')} | "
          f"{dec_field(ring, lc,'customers.location')}")

h("5. RANDOMISED ENCRYPTION - identical values do not look identical")
a = enc_field(ring, "0917 123 4567", "customers.phone"); b = enc_field(ring, "0917 123 4567", "customers.phone")
print(f"  encrypt('0917 123 4567') #1: {short(a, 60)}\n  encrypt('0917 123 4567') #2: {short(b, 60)}")
print(f"  Same ciphertext? {a == b}   Both decrypt to the same phone? "
      f"{dec_field(ring, a,'customers.phone') == dec_field(ring, b,'customers.phone')}")
print("  -> an attacker cannot tell which customers share a phone/city, nor spot repeated values.")

h("6. BLIND INDEX - looking up a customer (login) without decrypting the table")
login = "  Maria.Santos@Example.com "
row = db.execute("SELECT id FROM customers WHERE email_bidx = ?", (blind_index(ring, login),)).fetchone()
print(f"  Login lookup for {login!r} (case/space-insensitive) -> customer id {row[0] if row else None}")
other = make_ring(("kX", os.urandom(32)))
print(f"  Same e-mail indexed with a different key -> {short(blind_index(other, login), 24)} (no match)")
print("  -> only someone holding the key can compute the index, so e-mails cannot be guessed offline.")

h("7. INTEGRITY - tampering is detected (GCM authentication tag)")
stored = db.execute("SELECT phone FROM customers WHERE id=1").fetchone()[0]
head, blob = stored.rsplit(".", 1); raw = bytearray(base64.b64decode(blob)); raw[-1] ^= 0x01
forged = head + "." + base64.b64encode(bytes(raw)).decode()
try:
    dec_field(ring, forged, "customers.phone"); print("  tampered value accepted  (BAD)")
except InvalidTag:
    print("  Flipped ONE bit of the stored phone ciphertext -> decryption REFUSED (InvalidTag)")

h("8. CONTEXT BINDING - ciphertext cannot be moved to another column")
phone_ct = db.execute("SELECT phone FROM customers WHERE id=1").fetchone()[0]
try:
    dec_field(ring, phone_ct, "customers.email"); print("  accepted  (BAD)")
except InvalidTag:
    print("  phone ciphertext pasted into the e-mail column -> decryption REFUSED")
    print("  -> stops an attacker with write access from swapping values between rows/columns.")

h("9. WRONG KEY - the stolen database alone is useless")
wrong = make_ring(("k1", os.urandom(32)))
try:
    dec_field(wrong, phone_ct, "customers.phone"); print("  decrypted with wrong key  (BAD)")
except InvalidTag:
    print("  Attacker guesses/generates another key -> decryption REFUSED (no partial plaintext)")

h("10. KEY ROTATION - new key for new writes, old data still readable")
master2 = os.urandom(32)
ring2 = make_ring(("k2", master2), ("k1", master))          # newest first, old key kept
print(f"  before: {short(phone_ct, 30)}")
plain = dec_field(ring2, phone_ct, "customers.phone")        # readable via old key id in the ring
new_ct = enc_field(ring2, plain, "customers.phone")
print(f"  after : {short(new_ct, 30)}   (re-encrypted under k2; blind index recomputed too)")
print(f"  both decrypt to: {dec_field(ring2, phone_ct,'customers.phone')} / {dec_field(ring2, new_ct,'customers.phone')}")
print("\nDone. (Temp DB:", path, ")")
