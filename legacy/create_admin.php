<?php

if (($_SERVER['REMOTE_ADDR'] ?? '') !== '127.0.0.1' && ($_SERVER['REMOTE_ADDR'] ?? '') !== '::1') { exit; }

require_once __DIR__ . '/db_config.php';

$username = trim($_GET['username'] ?? '');
$password = $_GET['password'] ?? '';
$name     = trim($_GET['name'] ?? $username);

if (!$username || !$password) {
    http_response_code(400);
    die('Usage: create_admin.php?username=...&password=...&name=...');
}
if (strlen($password) < 8) {
    die('Password must be at least 8 characters.');
}

$pdo = getDB();

$check = $pdo->prepare("SELECT id FROM admin_users WHERE username = :u");
$check->execute([':u' => $username]);
if ($check->fetch()) {
    die("Username '{$username}' already exists.");
}

$hash = password_hash($password, PASSWORD_DEFAULT);
$stmt = $pdo->prepare("INSERT INTO admin_users (username, password_hash, full_name) VALUES (:u, :p, :n)");
$stmt->execute([':u' => $username, ':p' => $hash, ':n' => $name]);

echo "Admin account '{$username}' created successfully. DELETE THIS FILE NOW.";
