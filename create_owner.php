<?php
// Run from the command line in the site root:
//   php create_owner.php "Full Name" owner@example.com "StrongPassword"
if (PHP_SAPI !== 'cli') { http_response_code(403); exit('CLI only.'); }
foreach ([__DIR__ . '/db_config.php', dirname(__DIR__) . '/db_config.php'] as $c) { if (is_file($c)) { require_once $c; break; } }
if (!function_exists('getDB')) exit("db_config.php not found next to this file or one level up.\n");
[$self, $name, $email, $pass] = array_pad($argv, 4, '');
if ($name === '' || $email === '' || strlen($pass) < 8) {
    exit("Usage: php create_owner.php \"Full Name\" email password(8+ chars)\n");
}
$stmt = getDB()->prepare("INSERT INTO owner_manager (full_name,email,password_hash) VALUES (:n,:e,:p)");
$stmt->execute([':n' => $name, ':e' => $email, ':p' => password_hash($pass, PASSWORD_DEFAULT)]);
echo "Owner/manager created: {$email}\n";
