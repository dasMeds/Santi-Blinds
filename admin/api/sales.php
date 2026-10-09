<?php
require_once __DIR__ . '/config.php';
requireLogin();
$pdo = getDB();

$byMonth = $pdo->query(
    "SELECT DATE_FORMAT(sale_date, '%Y-%m') AS month,
            COALESCE(SUM(amount_paid),0) AS revenue, COUNT(*) AS orders
     FROM sale
     WHERE sale_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
     GROUP BY month ORDER BY month ASC"
)->fetchAll();

// Completed order items, grouped by product
$byProduct = $pdo->query(
    "SELECT p.name AS product, SUM(o.quantity) AS units,
            COALESCE(SUM(o.total_amount),0) AS revenue
     FROM orders o JOIN product p ON p.product_id = o.product_id
     WHERE o.status = 'Completed'
     GROUP BY p.product_id, p.name ORDER BY revenue DESC"
)->fetchAll();

$totals = $pdo->query("SELECT COALESCE(SUM(amount_paid),0) AS t, COALESCE(AVG(amount_paid),0) AS a, COUNT(*) AS n FROM sale")->fetch();

echo json_encode([
    'success'         => true,
    'total_revenue'   => (float)$totals['t'],
    'avg_sale_value'  => (float)$totals['a'],
    'sales_count'     => (int)$totals['n'],
    'by_month'        => $byMonth,
    'by_product'      => $byProduct,
]);
