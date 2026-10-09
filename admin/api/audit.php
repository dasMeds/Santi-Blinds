<?php
require_once __DIR__ . '/config.php';
requireLogin();
if ($_SERVER['REQUEST_METHOD'] !== 'GET') fail(405, 'Method not allowed.');

$limit = filter_var($_GET['limit'] ?? 200, FILTER_VALIDATE_INT);
if ($limit === false || $limit < 1) fail(422, 'The log limit must be a positive integer.');
$limit = min($limit, 500);
$stmt = getDB()->query(
    'SELECT audit_id, admin_name, action, details, created_at
     FROM admin_audit_log ORDER BY audit_id DESC LIMIT ' . $limit
);
echo json_encode(['success' => true, 'logs' => $stmt->fetchAll()]);
