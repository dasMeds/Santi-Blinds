<?php
require_once __DIR__ . '/config.php';
requireLogin();
$pdo = getDB();

if ($_SERVER['REQUEST_METHOD'] !== 'GET') fail(405, 'Method not allowed.');

$where = [];
$params = [];
if (!empty($_GET['search'])) {
    $search = trim((string)$_GET['search']);
    $where[] = '(c.full_name LIKE :customer OR c.email LIKE :email OR CAST(q.quotation_id AS CHAR) LIKE :reference';
    $digits = preg_replace('/\D+/', '', $search);
    if ($digits !== '') {
        $where[count($where) - 1] .= ' OR q.quotation_id = :reference_id';
        $params[':reference_id'] = (int)$digits;
    }
    $where[count($where) - 1] .= ')';
    $like = '%' . $search . '%';
    $params[':customer'] = $like;
    $params[':email'] = $like;
    $params[':reference'] = $like;
}
$statusFilter = (string)($_GET['status'] ?? '');
if (in_array($statusFilter, ['Active', 'Ordered', 'Expired'], true)) {
    $where[] = "CASE
        WHEN q.status = 'Ordered' THEN 'Ordered'
        WHEN q.valid_until < NOW() THEN 'Expired'
        ELSE 'Active'
    END = :status";
    $params[':status'] = $statusFilter;
}

$sql = "SELECT q.quotation_id, q.total_amount, q.status AS stored_status, q.valid_until, q.created_at,
               c.full_name, c.email,
               (SELECT COUNT(*) FROM quotation_item qi WHERE qi.quotation_id = q.quotation_id) AS item_count,
               (SELECT MIN(o.order_id) FROM orders o WHERE o.quotation_id = q.quotation_id) AS order_id,
               (SELECT MAX(o.status) FROM orders o WHERE o.quotation_id = q.quotation_id) AS order_status,
               CASE
                   WHEN q.status = 'Ordered' THEN 'Ordered'
                   WHEN q.valid_until < NOW() THEN 'Expired'
                   ELSE 'Active'
               END AS display_status
        FROM quotation q JOIN customer c ON c.customer_id = q.customer_id";
if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
$sql .= ' ORDER BY q.quotation_id DESC';

$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll();
if (!$rows) {
    echo json_encode(['success' => true, 'quotations' => []]);
    exit;
}

$ids = array_map('intval', array_column($rows, 'quotation_id'));
$in = implode(',', array_fill(0, count($ids), '?'));
$itemStmt = $pdo->prepare(
    "SELECT qi.quotation_id, p.name AS product, p.blind_type, m.name AS material, col.name AS color,
            qi.width_cm, qi.height_cm, qi.quantity, qi.unit_price, qi.total_amount
     FROM quotation_item qi
     JOIN product p ON p.product_id = qi.product_id
     JOIN material m ON m.material_id = qi.material_id
     JOIN color col ON col.color_id = qi.color_id
     WHERE qi.quotation_id IN ($in)
     ORDER BY qi.quotation_item_id"
);
$itemStmt->execute($ids);
$itemsByQuote = [];
foreach ($itemStmt->fetchAll() as $item) {
    $itemsByQuote[(int)$item['quotation_id']][] = $item;
}

$quotations = array_map(static function ($row) use ($itemsByQuote) {
    $id = (int)$row['quotation_id'];
    return [
        'quotation_id' => $id,
        'reference' => sprintf('QT-%05d', $id),
        'customer' => $row['full_name'],
        'email' => $row['email'],
        'status' => $row['display_status'],
        'total_amount' => (float)$row['total_amount'],
        'item_count' => (int)$row['item_count'],
        'valid_until' => $row['valid_until'],
        'created_at' => $row['created_at'],
        'order_id' => $row['order_id'] ? (int)$row['order_id'] : null,
        'order_status' => $row['order_status'],
        'items' => $itemsByQuote[$id] ?? [],
    ];
}, $rows);

echo json_encode(['success' => true, 'quotations' => $quotations]);
