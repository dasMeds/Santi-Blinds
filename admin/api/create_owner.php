<?php
// Run from the command line in the site root:
//   php create_owner.php "Full Name" owner@example.com "StrongPassword"
if (PHP_SAPI !== 'cli') { http_response_code(403); exit('CLI only.'); }
require_once __DIR__ . '/db_config.php';
[$self, $name, $email, $pass] = array_pad($argv, 4, '');
if ($name === '' || $email === '' || strlen($pass) < 8) {
    exit("Usage: php create_owner.php \"Full Name\" email password(8+ chars)\n");
}
$stmt = getDB()->prepare("INSERT INTO owner_manager (full_name,email,password_hash) VALUES (:n,:e,:p)");
$stmt->execute([':n' => $name, ':e' => $email, ':p' => password_hash($pass, PASSWORD_DEFAULT)]);
echo "Owner/manager created: {$email}\n";
