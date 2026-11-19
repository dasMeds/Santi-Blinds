<?php
// ============================================================
//  Generate (or rotate) the encryption key.   CLI only.
//    php tools/generate_key.php                 first-time key
//    php tools/generate_key.php --rotate k2     add a NEW current key; old keys stay
//                                               in the file so existing data still opens
//  After rotating, run:  php tools/encrypt_existing_data.php --rotate
// ============================================================
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
require_once __DIR__ . '/../db_config.php';

$rotate = in_array('--rotate', $argv, true);
$ids    = array_values(array_filter(array_slice($argv, 1), fn($a) => $a !== '--rotate'));
$kid    = $ids[0] ?? ('k' . date('Ymd'));
if (!preg_match('/^[A-Za-z0-9_-]{1,16}$/', $kid)) { fwrite(STDERR, "Key id: 1-16 letters/digits/_/-\n"); exit(1); }

$file = ENC_KEY_FILE;
$dir  = dirname($file);
if (!is_dir($dir) && !mkdir($dir, 0700, true)) { fwrite(STDERR, "Cannot create {$dir}\n"); exit(1); }

$existing = is_file($file) ? trim((string)file_get_contents($file)) : '';
if ($existing !== '' && !$rotate) {
    fwrite(STDERR, "A key file already exists at {$file}.\nOverwriting it would make encrypted data unreadable. Use --rotate to add a new key.\n");
    exit(1);
}
if ($existing !== '' && strpos($existing, $kid . ':') !== false) { fwrite(STDERR, "Key id '{$kid}' already exists.\n"); exit(1); }

$line = $kid . ':' . base64_encode(random_bytes(32));
file_put_contents($file, $line . "\n" . ($existing !== '' ? $existing . "\n" : ''), LOCK_EX);
@chmod($file, 0600);

echo "Key '{$kid}' saved to {$file}\n";
echo "  - Keep this file OUTSIDE the web root and BACK IT UP somewhere separate from the database.\n";
echo "  - If the key is lost, the encrypted data can never be recovered.\n";
