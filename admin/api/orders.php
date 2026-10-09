<?php
// ============================================================
//  Santi Blinds — Admin API: orders
//  GET  ?search=&status=   -> list of orders (one row per order_id)
//  GET  ?id=12             -> one order with its items + sale
//  POST {id,status,payment_method} -> update status; a Completed
//        order is recorded in `sale`, any other status removes it.
//  Location: admin/api/orders.php
// ============================================================
require_once __DIR__ . '/config.php';
requireLogin();
$pdo    = getDB();
$method = $_SERVER['REQUEST_METHOD'];

const PAYMENT_METHODS = ['Cash', 'GCash', 'Bank Transfer'];

if ($method === 'GET') {

    // ---- one order ----
    if (!empty($_GET['id'])) {
        $id = (int)$_GET['id'];

        $h = $pdo->prepare(
            "SELECT o.order_id, c.full_name, c.phone, c.email, c.address,
                    MAX(o.status) AS status, MIN(o.order_date) AS order_date,
                    SUM(o.total_amount) AS amount, MAX(o.quotation_id) AS quotation_id
             FROM orders o JOIN customer c ON c.customer_id = o.customer_id
             WHERE o.order_id = :id
             GROUP BY o.order_id, c.full_name, c.phone, c.email, c.address"
        );
        $h->execute([':id' => $id]);
        $order = $h->fetch();
        if (!$order) fail(404, 'Order not found.');
        $order['quotation_ref'] = $order['quotation_id'] ? sprintf('QT-%05d', (int)$order['quotation_id']) : null;
        unset($order['quotation_id']);

        $i = $pdo->prepare(
            "SELECT p.name AS product, p.blind_type, m.name AS material,
                    col.name AS color, col.hex_code,
                    o.width_cm, o.height_cm, o.quantity, o.unit_price, o.total_amount
             FROM orders o
             JOIN product  p   ON p.product_id   = o.product_id
             JOIN material m   ON m.material_id  = o.material_id
             JOIN color    col ON col.color_id   = o.color_id
             WHERE o.order_id = :id
             ORDER BY o.product_id, o.material_id, o.color_id"
        );
        $i->execute([':id' => $id]);

        $s = $pdo->prepare("SELECT payment_method, amount_paid, sale_date FROM sale WHERE order_id = :id");
        $s->execute([':id' => $id]);

        echo json_encode([
            'success' => true,
            'order'   => $order,
            'items'   => $i->fetchAll(),
            'sale'    => $s->fetch() ?: null,
        ]);
        exit;
    }

    // ---- list ----
    $where = []; $params = [];
    if (!empty($_GET['status'])) {
        $where[] = "o.status = :st";
        $params[':st'] = $_GET['status'];
    }
    if (!empty($_GET['search'])) {
        $where[] = "(c.full_name LIKE :s1 OR p.name LIKE :s2)";
        $like = '%' . $_GET['search'] . '%';
        $params[':s1'] = $like; $params[':s2'] = $like;
    }
    $sql = "SELECT o.order_id, c.full_name, MAX(o.status) AS status,
                   SUM(o.quantity) AS quantity, SUM(o.total_amount) AS amount,
                   MIN(o.order_date) AS order_date, MAX(o.quotation_id) AS quotation_id,
                   GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ', ') AS products
            FROM orders o
            JOIN customer c ON c.customer_id = o.customer_id
            JOIN product  p ON p.product_id  = o.product_id";
    if ($where) $sql .= ' WHERE ' . implode(' AND ', $where);
    $sql .= " GROUP BY o.order_id, c.full_name ORDER BY order_date DESC, o.order_id DESC";

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = array_map(function ($r) {
        // NULL quotation_id = a direct order placed from the design.
        $r['quotation_ref'] = $r['quotation_id'] ? sprintf('QT-%05d', (int)$r['quotation_id']) : null;
        unset($r['quotation_id']);
        return $r;
    }, $stmt->fetchAll());
    echo json_encode(['success' => true, 'orders' => $rows]);
    exit;
}

if ($method === 'POST') {
    $b      = requestBody();
    $id     = (int)($b['id'] ?? 0);
    $status = (string)($b['status'] ?? '');
    $pay    = (string)($b['payment_method'] ?? 'Cash');

    if (!$id) fail(422, 'A valid order id is required.');
    if (!in_array($status, ORDER_STATUSES, true)) fail(422, 'Invalid status.');
    if (!in_array($pay, PAYMENT_METHODS, true)) $pay = 'Cash';

    $pdo->beginTransaction();
    try {
        $t = $pdo->prepare("SELECT COALESCE(SUM(total_amount),0) AS amount, COUNT(*) AS n FROM orders WHERE order_id = :id");
        $t->execute([':id' => $id]);
        $row = $t->fetch();
        if ((int)$row['n'] === 0) { $pdo->rollBack(); fail(404, 'Order not found.'); }

        // Cancelling gives the stock back; un-cancelling takes it again.
        $o = $pdo->prepare("SELECT MAX(status) FROM orders WHERE order_id = :id");
        $o->execute([':id' => $id]);
        $oldStatus = (string)$o->fetchColumn();

        if ($oldStatus !== $status && ($oldStatus === 'Cancelled' || $status === 'Cancelled')) {
            $lines = $pdo->prepare("SELECT product_id, SUM(quantity) AS qty FROM orders WHERE order_id = :id GROUP BY product_id ORDER BY product_id");
            $lines->execute([':id' => $id]);
            $adj = $pdo->prepare($status === 'Cancelled'
                ? "UPDATE product SET stock_qty = stock_qty + :q WHERE product_id = :p"
                : "UPDATE product SET stock_qty = GREATEST(0, stock_qty - :q) WHERE product_id = :p");
            foreach ($lines->fetchAll() as $ln) {
                $adj->execute([':q' => (int)$ln['qty'], ':p' => (int)$ln['product_id']]);
            }
        }

        $pdo->prepare("UPDATE orders SET status = :s WHERE order_id = :id")
            ->execute([':s' => $status, ':id' => $id]);

        if ($status === 'Completed') {
            $pdo->prepare(
                "INSERT INTO sale (order_id, amount_paid, payment_method)
                 VALUES (:id, :amt, :pm)
                 ON DUPLICATE KEY UPDATE amount_paid = VALUES(amount_paid), payment_method = VALUES(payment_method)"
            )->execute([':id' => $id, ':amt' => $row['amount'], ':pm' => $pay]);
        } else {
            $pdo->prepare("DELETE FROM sale WHERE order_id = :id")->execute([':id' => $id]);
        }
        $pdo->commit();
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
    echo json_encode(['success' => true]);
    exit;
}

fail(405, 'Method not allowed.');
