<?php
require_once __DIR__ . '/config.php';
requireLogin();
$pdo    = getDB();
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $stmt = $pdo->prepare(
        "SELECT p.product_id, p.name, p.blind_type, p.base_price, p.stock_qty,
                c.name AS category, (p.stock_qty <= :lvl) AS low_stock
         FROM product p JOIN category c ON c.category_id = p.category_id
         ORDER BY low_stock DESC, p.name ASC"
    );
    $stmt->execute([':lvl' => LOW_STOCK_LEVEL]);
    echo json_encode(['success' => true, 'low_stock_level' => LOW_STOCK_LEVEL, 'inventory' => $stmt->fetchAll()]);
    exit;
}

if ($method === 'POST') {
    $body = requestBody();
    $id   = (int)($body['id'] ?? 0);
    $qty  = $body['stock_qty'] ?? null;
    if (!$id || !is_numeric($qty) || $qty < 0) fail(422, 'A valid product id and stock quantity are required.');

    $stmt = $pdo->prepare("UPDATE product SET stock_qty = :q WHERE product_id = :id");
    $stmt->execute([':q' => (int)$qty, ':id' => $id]);
    echo json_encode(['success' => true]);
    exit;
}

fail(405, 'Method not allowed.');
