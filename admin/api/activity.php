<?php
// GET ?action=&limit=  -> customer activity log (newest first)
require_once __DIR__ . '/config.php';
requireLogin();
$pdo = getDB();

$limit = isset($_GET['limit']) ? min(500, max(1, (int)$_GET['limit'])) : 200;

$where = []; $params = [];
if (!empty($_GET['action'])) { $where[] = 'a.action = :act'; $params[':act'] = (string)$_GET['action']; }

$sql = "SELECT a.id, a.action, a.details, a.email, a.ip_address, a.created_at,
               c.full_name
        FROM customer_activity a
        LEFT JOIN customer c ON c.customer_id = a.customer_id";
if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
$sql .= ' ORDER BY a.created_at DESC, a.id DESC LIMIT :limit';

$stmt = $pdo->prepare($sql);
foreach ($params as $k => $v) $stmt->bindValue($k, $v);
$stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
$stmt->execute();

echo json_encode(['success' => true, 'activity' => $stmt->fetchAll()]);
