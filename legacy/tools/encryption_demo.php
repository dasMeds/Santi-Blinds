<?php
// ============================================================
//  Encryption demonstration (CLI):   php tools/encryption_demo.php [--db]
//  Uses a throw-away key, so it never touches your real data.
//  --db additionally shows 3 REAL rows of `customers`: raw (what an attacker
//       sees) next to decrypted (what the application sees).
// ============================================================
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }

putenv('SANTI_ENC_KEYS=demo1:' . base64_encode(random_bytes(32)));   // demo key, not the real one
require_once __DIR__ . '/../crypto_lib.php';

function h(string $t): void { echo "\n" . str_repeat('=', 74) . "\n  {$t}\n" . str_repeat('=', 74) . "\n"; }
function cut(?string $s, int $n = 64): string { $s = $s ?? 'NULL'; return strlen($s) > $n ? substr($s, 0, $n) . '...' : $s; }

$phone = '0917 123 4567';
$email = 'maria.santos@example.com';

h('1. Encrypt');
$ct = encField($phone, 'customers.phone');
echo "  plaintext : {$phone}\n  stored    : " . cut($ct) . "\n  format    : ENC1.<keyId>.<base64(iv | tag | ciphertext)>\n";
echo "  decrypted : " . decField($ct, 'customers.phone') . "\n";

h('2. Randomised: same value, different ciphertext');
$a = encField($phone, 'customers.phone'); $b = encField($phone, 'customers.phone');
echo "  #1 " . cut($a) . "\n  #2 " . cut($b) . "\n  identical? " . var_export($a === $b, true) . "\n";

h('3. Blind index: look up by e-mail without storing it readable');
echo "  blindIndex('  Maria.Santos@Example.com ') = " . cut(blindIndex('  Maria.Santos@Example.com '), 40) . "\n";
echo "  blindIndex('maria.santos@example.com')    = " . cut(blindIndex($email), 40) . "\n";
echo "  equal (case/space-insensitive)? " . var_export(blindIndex('  Maria.Santos@Example.com ') === blindIndex($email), true) . "\n";

h('4. Tampering is detected');
[$p, $kid, $blob] = explode('.', $ct, 3);
$raw = base64_decode($blob); $raw[strlen($raw) - 1] = $raw[strlen($raw) - 1] ^ "\x01";
try { decField("{$p}.{$kid}." . base64_encode($raw), 'customers.phone'); echo "  accepted (BAD)\n"; }
catch (RuntimeException $e) { echo "  one bit flipped -> REFUSED: " . $e->getMessage() . "\n"; }

h('5. Ciphertext cannot be moved to another column');
try { decField($ct, 'customers.email'); echo "  accepted (BAD)\n"; }
catch (RuntimeException $e) { echo "  phone ciphertext read as e-mail -> REFUSED: " . $e->getMessage() . "\n"; }

if (in_array('--db', $argv, true)) {
    h('6. REAL database rows (uses your real key)');
    require_once __DIR__ . '/../db_config.php';
    putenv('SANTI_ENC_KEYS=');                                         // stop using the demo key ...
    encKeyring(true);                                                  // ... and load the real one from ENC_KEY_FILE
    $rows = getDB()->query('SELECT id, fname, email, phone FROM customers ORDER BY id LIMIT 3')->fetchAll();
    foreach ($rows as $r) {
        echo "  #{$r['id']} RAW      : " . cut($r['fname'], 30) . ' | ' . cut($r['email'], 30) . ' | ' . cut($r['phone'], 30) . "\n";
        echo "     DECRYPTED: " . decField($r['fname'], 'customers.fname') . ' | ' . decField($r['email'], 'customers.email')
           . ' | ' . decField($r['phone'], 'customers.phone') . "\n";
    }
}
echo "\nDone.\n";
