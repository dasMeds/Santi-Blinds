<?php
// POST { email, password } -> starts a customer session.
require_once __DIR__ . '/config.php';
requireMethod('POST');
$b        = requestBody();
$email    = strtolower(str($b, 'email', 160));
$password = (string)($b['password'] ?? '');

if ($email === '' || $password === '') {
    respond(['success' => false, 'message' => 'Email and password are required.'], 422);
}
// Throttle: 5 failed attempts per email in 15 minutes. Counted in the database, so clearing
// cookies or opening a new session does not reset it.
const LOGIN_FAIL_LIMIT = 5;
const LOGIN_FAIL_WINDOW_MINUTES = 15;
$pdo = getDB();
$t = $pdo->prepare(
    "SELECT COUNT(*) FROM customer_activity
     WHERE email = :e AND action = 'Login failed'
       AND created_at > (NOW() - INTERVAL " . LOGIN_FAIL_WINDOW_MINUTES . " MINUTE)"
);
$t->execute([':e' => $email]);
if ((int)$t->fetchColumn() >= LOGIN_FAIL_LIMIT) {
    respond(['success' => false, 'message' => 'Too many failed attempts. Please wait a few minutes and try again.'], 429);
}

$stmt = $pdo->prepare(
    "SELECT customer_id, full_name, email, phone, address, password_hash
     FROM customer WHERE email = :e AND password_hash IS NOT NULL LIMIT 1"
);
$stmt->execute([':e' => $email]);
$u = $stmt->fetch();

if (!$u || !password_verify($password, $u['password_hash'])) {
    logActivity($pdo, $u ? (int)$u['customer_id'] : null, 'Login failed', 'Incorrect email or password.', $email);
    respond(['success' => false, 'message' => 'Incorrect email or password.'], 401);
}

session_regenerate_id(true);
$_SESSION['customer_id'] = (int)$u['customer_id'];
logActivity($pdo, (int)$u['customer_id'], 'Login', $u['full_name'] . ' logged in.', $email);

respond(['success' => true, 'customer' => [
    'full_name' => $u['full_name'], 'email' => $u['email'], 'phone' => $u['phone'], 'address' => $u['address'],
]]);
