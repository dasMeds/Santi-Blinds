<?php
require_once __DIR__ . '/config.php';
requireLogin();
$pdo = getDB();

$totalOrders    = (int)$pdo->query("SELECT COUNT(DISTINCT order_id) FROM orders")->fetchColumn();
$pendingOrders  = (int)$pdo->query("SELECT COUNT(DISTINCT order_id) FROM orders WHERE status = 'Pending'")->fetchColumn();
$totalCustomers = (int)$pdo->query("SELECT COUNT(*) FROM customer")->fetchColumn();

$revenueThisMonth = (float)$pdo->query(
    "SELECT COALESCE(SUM(amount_paid),0) FROM sale
     WHERE MONTH(sale_date) = MONTH(CURDATE()) AND YEAR(sale_date) = YEAR(CURDATE())"
)->fetchColumn();
$revenueTotal = (float)$pdo->query("SELECT COALESCE(SUM(amount_paid),0) FROM sale")->fetchColumn();

$low = $pdo->prepare("SELECT COUNT(*) FROM product WHERE stock_qty <= :lvl");
$low->execute([':lvl' => LOW_STOCK_LEVEL]);

$recentOrders = $pdo->query(
    "SELECT o.order_id, c.full_name, MAX(o.status) AS status, SUM(o.total_amount) AS amount,
            MIN(o.order_date) AS order_date,
            GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ', ') AS products
     FROM orders o
     JOIN customer c ON c.customer_id = o.customer_id
     JOIN product p  ON p.product_id  = o.product_id
     GROUP BY o.order_id, c.full_name
     ORDER BY order_date DESC, o.order_id DESC LIMIT 5"
)->fetchAll();

$statusBreakdown = $pdo->query(
    "SELECT status, COUNT(DISTINCT order_id) AS count FROM orders GROUP BY status"
)->fetchAll();

echo json_encode([
    'success' => true,
    'stats' => [
        'total_orders'       => $totalOrders,
        'pending_orders'     => $pendingOrders,
        'total_customers'    => $totalCustomers,
        'revenue_this_month' => $revenueThisMonth,
        'revenue_total'      => $revenueTotal,
        'low_stock_items'    => (int)$low->fetchColumn(),
    ],
    'recent_orders'    => $recentOrders,
    'status_breakdown' => $statusBreakdown,
]);
