<?php
// ============================================================
//  Creates the owner/manager login (table: owner_manager).
//  Run ONCE from your browser on this computer:
//    http://localhost/santiblinds/create_admin.php?name=Your+Name&email=you@example.com&password=YourPassword
//  Then DELETE THIS FILE.
// ============================================================
header('Content-Type: text/plain; charset=utf-8');

// Localhost only.
if (!in_array($_SERVER['REMOTE_ADDR'] ?? '', ['127.0.0.1', '::1'], true)) { http_response_code(403); exit('Forbidden.'); }

// Find db_config.php: next to this file, one level up, or in the web root.
$docRoot = rtrim(str_replace('\\', '/', $_SERVER['DOCUMENT_ROOT'] ?? ''), '/');
$candidates = array_unique(array_filter([
    __DIR__ . '/db_config.php',
    dirname(__DIR__) . '/db_config.php',
    $docRoot ? $docRoot . '/db_config.php' : null,
    $docRoot ? dirname($docRoot) . '/db_config.php' : null,
]));
$config = null;
foreach ($candidates as $c) { if (is_file($c)) { $config = $c; break; } }
if (!$config) {
    http_response_code(500);
    exit("db_config.php was not found. Looked in:\n  " . implode("\n  ", $candidates)
       . "\n\nPut db_config.php in " . __DIR__ . " (the admin API expects it in the same folder as the 'admin' folder), then reload.");
}
require_once $config;

$name     = trim($_GET['name'] ?? '');
$email    = strtolower(trim($_GET['email'] ?? ''));
$password = (string)($_GET['password'] ?? '');

if ($name === '' || $email === '' || $password === '') {
    http_response_code(400);
    exit("Usage: create_admin.php?name=Full+Name&email=you@example.com&password=atleast8chars");
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) exit('Please give a valid email address.');
if (strlen($password) < 8) exit('Password must be at least 8 characters.');

try {
    $pdo = getDB();
    $check = $pdo->prepare("SELECT owner_id FROM owner_manager WHERE email = :e");
    $check->execute([':e' => $email]);
    if ($check->fetch()) exit("An account for {$email} already exists.");

    $pdo->prepare("INSERT INTO owner_manager (full_name, email, password_hash) VALUES (:n, :e, :p)")
        ->execute([':n' => $name, ':e' => $email, ':p' => password_hash($password, PASSWORD_DEFAULT)]);
} catch (PDOException $e) {
    error_log('create_admin: ' . $e->getMessage());
    http_response_code(500);
    exit("Database error: " . $e->getMessage() . "\n\nIf it says the table 'owner_manager' doesn't exist, import schema.sql in phpMyAdmin first.");
}

echo "Admin account created for {$email}.\nUsing config: {$config}\n\nDELETE THIS FILE NOW.";