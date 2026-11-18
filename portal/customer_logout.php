<?php
// POST -> ends the customer session only (an admin login in the same browser is left alone).
require_once __DIR__ . '/config.php';
requireMethod('POST');
if (!empty($_SESSION['customer_id'])) {
    logActivity(getDB(), (int)$_SESSION['customer_id'], 'Logout', 'Customer logged out.');
}
unset($_SESSION['customer_id']);
session_regenerate_id(true);
respond(['success' => true]);
