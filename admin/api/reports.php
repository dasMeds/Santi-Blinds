<?php
require_once __DIR__ . '/config.php';
requireLogin();
$pdo = getDB();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') fail(405, 'Method not allowed.');

$from = trim((string)($_GET['from'] ?? ''));
$to = trim((string)($_GET['to'] ?? ''));
$isDate = static function ($value): bool {
    if ($value === '') return true;
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/D', $value)) return false;
    $date = DateTime::createFromFormat('!Y-m-d', $value);
    return $date !== false && $date->format('Y-m-d') === $value;
};
if (!$isDate($from) || !$isDate($to)) fail(422, 'Dates must use YYYY-MM-DD format.');
if ($from !== '' && $to !== '' && $from > $to) fail(422, 'The start date must be on or before the end date.');

$where = [];
$params = [];
if ($from !== '') {
    $where[] = 'o.order_date >= :from_date';
    $params[':from_date'] = $from . ' 00:00:00';
}
if ($to !== '') {
    $where[] = 'o.order_date < DATE_ADD(:to_date, INTERVAL 1 DAY)';
    $params[':to_date'] = $to;
}

$sql = "SELECT o.order_id, c.full_name, c.address,
               MAX(o.status) AS status, SUM(o.quantity) AS quantity,
               SUM(o.total_amount) AS amount, MIN(o.order_date) AS order_date,
               GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ', ') AS products,
               COALESCE((SELECT s.amount_paid FROM sale s WHERE s.order_id = o.order_id LIMIT 1), 0) AS paid_amount
        FROM orders o
        JOIN customer c ON c.customer_id = o.customer_id
        JOIN product p ON p.product_id = o.product_id";
if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
$sql .= ' GROUP BY o.order_id, c.full_name, c.address ORDER BY order_date DESC, o.order_id DESC';
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll();

$revenue = 0.0;
$completed = 0;
$pending = 0;
foreach ($rows as &$row) {
    $row['quotation_ref'] = null;
    $row['quantity'] = (int)$row['quantity'];
    $row['amount'] = (float)$row['amount'];
    $row['paid_amount'] = (float)$row['paid_amount'];
    if ($row['status'] === 'Completed') {
        $completed++;
        $revenue += $row['paid_amount'];
    }
    if ($row['status'] === 'Pending') $pending++;
}
unset($row);

echo json_encode([
    'success' => true,
    'stats' => [
        'orders' => count($rows),
        'completed_orders' => $completed,
        'pending_orders' => $pending,
        'revenue' => $revenue,
    ],
    'orders' => $rows,
]);
